import argparse
import configparser
import logging
import os
import sys

import pandas as pd

from pathlib import Path
from watch_rag_providers import create_embedder, create_vector_store, VectorPayload

logger = logging.getLogger(__name__)

config = configparser.ConfigParser()
config_path = Path(__file__).resolve().parent.parent / "watch_rag.properties"
if not config_path.is_file():
    raise FileNotFoundError(f"Config file not found: {config_path}")
config.read(config_path)

LOG_LEVEL_ENV_VAR = "WATCH_RAG_LOG_LEVEL"
BATCH_SIZE = config.getint("VectorDB", "collection.insert.batch.size")
QDRANT_COLLECTION_NAME = config.get("VectorDB", "collection.name")
QDRANT_URL = config.get("VectorDB", "qdrant.url")
MODEL_NAME = config.get("Model", "sentence_transformer_model.name")
S3_VECTOR_BUCKET=os.getenv("S3_VECTOR_BUCKET")
S3_VECTOR_INDEX=os.getenv("S3_VECTOR_INDEX")
VECTOR_EMBEDDER_PROVIDER=os.getenv("VECTOR_EMBEDDER_PROVIDER", "")

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

def get_dataframe(csv_path: str) -> pd.DataFrame:
    data_frame = pd.read_csv(csv_path, sep=';')
    data_frame = data_frame.fillna('')
    data_frame = data_frame.loc[
        data_frame["Brand"].astype("string").str.strip().ne("")
    ]
    return data_frame

def create_vectors(data_frame: pd.DataFrame) -> list[list[float]]:
    embedder = create_embedder(VECTOR_EMBEDDER_PROVIDER, MODEL_NAME)
    def create_text_representation(row):
            return (
                f"Brand: {row['Brand']}, Family: {row['Family']}, Name: {row['Name']}, "
                f"Reference: {row['Reference']}. "
                f"Movement: {row['Movement_Caliber']} ({row['Movement_Functions']}). "
                f"Case: {row['Case Material']}, Shape: {row['Shape']}, "
                f"Diameter: {row['Diameter']}, Height: {row['Height']}, Water Resistance: {row['W/R']}. "
                f"Dial Color: {row['Dial Color']}, Indexes: {row['Indexes']}, Hands: {row['Hands']}. "
                f"Glass: {row['Glass']}, Back: {row['Back']}. "
                f"Information: {row['Description']}. "
            )
    watch_specifications = data_frame.apply(create_text_representation, axis=1).tolist()
    return embedder.embed_all(watch_specifications)

def build_vector_db(csv_path: str) -> int:
    vector_store = create_vector_store(S3_VECTOR_BUCKET, S3_VECTOR_INDEX, QDRANT_URL, QDRANT_COLLECTION_NAME)
    try:
        logger.info(f"Vector store connection is ready")

        logger.info(f"Loading watch data from CSV file: {csv_path}")
        data_frame = get_dataframe(csv_path)
        logger.info(f"Loaded {len(data_frame)} watch specifications. Creating vector representations...")
        vectors = create_vectors(data_frame)
        logger.info(f"Created {len(vectors)} vector representations. Storing them in Qdrant collection '{QDRANT_COLLECTION_NAME}'...")

        logger.info(f"Creating collection '{QDRANT_COLLECTION_NAME}' in Qdrant...")
        vector_store.prepare_database(vectors.shape[1])

        logger.info(f"Storing {len(vectors)} vectors in Qdrant collection '{QDRANT_COLLECTION_NAME}'...")
        points: list[VectorPayload] = []
        for vector_idx, (idx, row) in enumerate(data_frame.iterrows()):
            points.append(
                VectorPayload(
                    id=idx,
                    vector=vectors[vector_idx].tolist(),
                    payload=row.to_dict()
                )
            )

        logger.info(f"Upserting {len(points)} points into Qdrant collection '{QDRANT_COLLECTION_NAME}'...")
        total_points = vector_store.store(points, BATCH_SIZE)
        logger.info(f"Successfully stored {len(points)} points in Qdrant collection '{QDRANT_COLLECTION_NAME}'.")
        return total_points
    finally:
        vector_store.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load watch data from a CSV file.")
    parser.add_argument("csv_path", help="Path to the watch data CSV file.")
    args = parser.parse_args()
    configure_logging()
    build_vector_db(args.csv_path)
