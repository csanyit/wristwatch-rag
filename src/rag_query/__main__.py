import argparse
import configparser
import logging
import os
import sys

from ollama import Client
from pathlib import Path
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient, models

logger = logging.getLogger(__name__)

config = configparser.ConfigParser()
config_path = Path(__file__).resolve().parent.parent / "watch_rag.properties"
if not config_path.is_file():
    raise FileNotFoundError(f"Config file not found: {config_path}")
config.read(config_path)

COLLECTION_NAME = config.get("VectorDB", "collection.name")
QDRANT_URL = config.get("VectorDB", "qdrant.url")
QUERY_LIMIT = config.getint("VectorDB", "query.limit")
MODEL_NAME = config.get("Model", "sentence_transformer_model.name")
OLLAMA_URL = config.get("LLM", "ollama.url")
OLLAMA_MODEL_NAME = config.get("LLM", "ollama.model.name")
LOG_LEVEL_ENV_VAR = "WATCH_RAG_LOG_LEVEL"


def get_log_level() -> int:
    raw_level = os.environ.get(LOG_LEVEL_ENV_VAR)
    if raw_level is None or not raw_level.strip():
        raw_level = config.get("Logging", "level")
    level_name = raw_level.strip().upper()
    level = getattr(logging, level_name, None)
    if not isinstance(level, int):
        raise ValueError(
            f"Invalid log level '{raw_level}'. "
            f"Set Logging.level or {LOG_LEVEL_ENV_VAR} to DEBUG, INFO, WARNING, ERROR, or CRITICAL."
        )
    return level


def configure_logging() -> None:
    logging.basicConfig(
        level=get_log_level(),
        stream=sys.stdout,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    )

def query_in_vector_db(query_text: str, brand: str, family: str) -> list[models.ScoredPoint]:
    client = QdrantClient(url=QDRANT_URL)
    try:
        if not client.collection_exists(collection_name=COLLECTION_NAME):
            raise ValueError(f"Collection '{COLLECTION_NAME}' does not exist in Qdrant. Please create it first.")

        query_must_conditions = []
        if (brand != None and brand.strip() != ""):
            query_must_conditions.append(
                models.FieldCondition(
                    key="Brand",
                    match=models.MatchValue(value=brand)
                )
            )
        if (family != None and family.strip() != ""):
            query_must_conditions.append(
                models.FieldCondition(
                    key="Family",
                    match=models.MatchValue(value=family)
                )
            )

        encoder = SentenceTransformer(MODEL_NAME)
        query_vector = encoder.encode(query_text).tolist()

        result = client.query_points(
            collection_name=COLLECTION_NAME,
            query=query_vector,
            query_filter=models.Filter(must=query_must_conditions),
            with_payload=True,
            with_vectors=False,
            limit=QUERY_LIMIT
        )
        return result.points
    finally:
        client.close()


def embed_result_in_prompt(query_text: str, result: models.ScoredPoint) -> str:
    context = "\n\n".join(
        (
            f"- Brand: {p.payload.get('Brand')}\n- Family: {p.payload.get('Family')}"
            f"- Name: {p.payload.get('Name')}\n- Reference: {p.payload.get('Reference')}"
            f"- Movement: {p.payload.get('Movement')}\n- Complications: {p.payload.get('Movement_Functions')}"
            f"- Material: {p.payload.get('Case Material')}\n- Glass: {p.payload.get('Glass')}"
            f"- Back: {p.payload.get('Back')}\n- Shape: {p.payload.get('Shape')}"
            f"- Diameter: {p.payload.get('Diameter')}\n- Height: {p.payload.get('Height')}"
            f"- W/R: {p.payload.get('W/R')}\n- Dial Color: {p.payload.get('Dial Color')} "
            f"- Hands: {p.payload.get('Hands')}\n- Description: {p.payload.get('Description')}"
        )
        for p in result
    )
    prompt = (
        "User searched for watches by these parameters:\n"
        f"{query_text}\n\n"
        "Relevant watches from the database:\n"
        f"{context}\n\n"
        "Create a summary of the relevant watches and provide a recommendation based on the user's search parameters."
    )
    return prompt


def infer_with_llm(prompt: str) -> str:
    client = Client(host=OLLAMA_URL)
    response = client.chat(
        model=OLLAMA_MODEL_NAME,
        messages=[{"role": "user", "content": prompt}],
    )
    content = (response.message.content or "").strip()
    if content:
        return content
    thinking = getattr(response.message, "thinking", None)
    if thinking:
        return str(thinking).strip()
    logger.error(f"Ollama model '{OLLAMA_MODEL_NAME}' returned an empty response.")
    raise RuntimeError(f"Ollama model '{OLLAMA_MODEL_NAME}' returned an empty response.")


def rag_query(query_text: str, brand: str, family: str) -> str:
    vector_db_results = query_in_vector_db(query_text, brand, family)

    for point in vector_db_results:
        logger.debug(f"Brand: {point.payload.get('Brand')}, Family: {point.payload.get('Family')}, Name: {point.payload.get('Name')}, Reference: {point.payload.get('Reference')}")

    rag_prompt = embed_result_in_prompt(query_text, vector_db_results)
    logger.debug(f"RAG Prompt:\n{rag_prompt}\n")
    return infer_with_llm(rag_prompt)


def main(query_text: str, brand: str, family: str) -> None:
    llm_response = rag_query(query_text, brand, family)
    print(f"LLM Response:\n{llm_response}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load watch data from a CSV file.")
    parser.add_argument("--query_text", help="Text to search for in the Qdrant collection.", type=str, required=True)
    parser.add_argument("--brand", help="Watch brand name to search for in the Qdrant collection.", type=str, required=False)
    parser.add_argument("--family", help="Family in watch brand name to search for in the Qdrant collection.", type=str, required=False)
    args = parser.parse_args()
    configure_logging()
    main(args.query_text, args.brand, args.family)
