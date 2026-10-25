import argparse
import configparser
import logging
import os
import sys

from pathlib import Path

from watch_rag_providers import create_embedder, create_vector_store, create_chat, SearchHit

logger = logging.getLogger(__name__)

config = configparser.ConfigParser()
config_path = Path(__file__).resolve().parent.parent / "watch_rag.properties"
if not config_path.is_file():
    raise FileNotFoundError(f"Config file not found: {config_path}")
config.read(config_path)

LOG_LEVEL_ENV_VAR = "WATCH_RAG_LOG_LEVEL"

QDRANT_URL = config.get("VectorDB", "qdrant.url")
QUERY_LIMIT = config.getint("VectorDB", "query.limit")

LLM_MODEL_NAME = (
    os.getenv("LLM_MODEL_NAME", "").strip()
    or config.get("LLM", "ollama.model.name")
)
VECTORDB_DB_NAME = (
    os.getenv("VECTORDB_DB_NAME", "").strip()
    or config.get("VectorDB", "collection.name")
)
VECTORDB_MODEL_NAME = (
    os.getenv("VECTORDB_MODEL_NAME", "").strip()
    or config.get("Model", "sentence_transformer_model.name")
)

OLLAMA_URL = config.get("LLM", "ollama.url")
S3_VECTOR_BUCKET=os.getenv("S3_VECTOR_BUCKET")
VECTOR_EMBEDDER_PROVIDER=os.getenv("VECTOR_EMBEDDER_PROVIDER")


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

def query_in_vector_db(query_text: str, brand: str, family: str) -> list[SearchHit]:
    vector_store = create_vector_store(S3_VECTOR_BUCKET, QDRANT_URL, VECTORDB_DB_NAME)
    try:
        #if not vector_store.database_exists():
        #    raise ValueError(f"Vector database '{VECTORDB_DB_NAME}' does not exist. Please create it first.")

        filter_dict: dict[str, Any] = {}
        if (brand != None and brand.strip() != ""):
            filter.Brand = brand
        if (family != None and family.strip() != ""):
            filter.Family = family

        embedder = create_embedder(VECTOR_EMBEDDER_PROVIDER, VECTORDB_MODEL_NAME)
        query_vector = embedder.embed_all(query_text)

        result = vector_store.search(
            vector=query_vector,
            filters=filter_dict,
            limit=QUERY_LIMIT
        )

        return result
    finally:
        vector_store.close()


def embed_result_in_prompt(query_text: str, result: SearchHit) -> str:
    context = "\n\n".join(
        (
            f"- Brand: {p.metadata.get('Brand')}\n- Family: {p.metadata.get('Family')}"
            f"- Name: {p.metadata.get('Name')}\n- Reference: {p.metadata.get('Reference')}"
            f"- Movement: {p.metadata.get('Movement')}\n- Complications: {p.metadata.get('Movement_Functions')}"
            f"- Material: {p.metadata.get('Case Material')}\n- Glass: {p.metadata.get('Glass')}"
            f"- Back: {p.metadata.get('Back')}\n- Shape: {p.metadata.get('Shape')}"
            f"- Diameter: {p.metadata.get('Diameter')}\n- Height: {p.metadata.get('Height')}"
            f"- W/R: {p.metadata.get('W/R')}\n- Dial Color: {p.metadata.get('Dial Color')} "
            f"- Hands: {p.metadata.get('Hands')}\n- Description: {p.metadata.get('Description')}"
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
    llm_client = create_chat(VECTOR_EMBEDDER_PROVIDER, LLM_MODEL_NAME, OLLAMA_URL)
    response = llm_client.complete(prompt=prompt)
    content = (response.message.content or "").strip()
    if content:
        return content
    thinking = getattr(response.message, "thinking", None)
    if thinking:
        return str(thinking).strip()
    logger.error(f"Ollama model '{LLM_MODEL_NAME}' returned an empty response.")
    raise RuntimeError(f"Ollama model '{LLM_MODEL_NAME}' returned an empty response.")


def rag_query(query_text: str, brand: str, family: str) -> str:
    vector_db_results = query_in_vector_db(query_text, brand, family)

    for search_hit in vector_db_results:
        logger.debug(f"Brand: {search_hit.metadata.get('Brand')}, Family: {search_hit.metadata.get('Family')}, Name: {search_hit.metadata.get('Name')}, Reference: {search_hit.metadata.get('Reference')}")

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
