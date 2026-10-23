import argparse
from pathlib import Path

import pandas as pd
import configparser

from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient, models

config = configparser.ConfigParser()
config_path = Path(__file__).resolve().parent.parent / "watch_rag.properties"
if not config_path.is_file():
    raise FileNotFoundError(f"Config file not found: {config_path}")
config.read(config_path)

COLLECTION_NAME = config.get("VectorDB", "collection.name")
QDRANT_URL = config.get("VectorDB", "qdrant.url")
QUERY_LIMIT = config.getint("VectorDB", "query.limit")
MODEL_NAME = config.get("Model", "sentence_transformer_model.name")

def main(query_text: str, brand: str, family: str) -> None:
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

        for point in result.points:
            print(f"Brand: {point.payload.get('Brand')}, Family: {point.payload.get('Family')}, Name: {point.payload.get('Name')}, Reference: {point.payload.get('Reference')}")
    finally:
        client.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load watch data from a CSV file.")
    parser.add_argument("--query_text", help="Text to search for in the Qdrant collection.", type=str, required=True)
    parser.add_argument("--brand", help="Watch brand name to search for in the Qdrant collection.", type=str, required=False)
    parser.add_argument("--family", help="Family in watch brand name to search for in the Qdrant collection.", type=str, required=False)
    args = parser.parse_args()
    main(args.query_text, args.brand, args.family)
