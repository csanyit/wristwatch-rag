import logging
import tempfile

from pathlib import Path
from urllib.parse import unquote_plus

import boto3

from vector_db_builder.__main__ import VECTORDB_DB_NAME, build_vector_db, get_log_level

logger = logging.getLogger(__name__)

logging.getLogger().setLevel(get_log_level())

s3_client = boto3.client("s3")


def parse_event(event: dict) -> list[tuple[str, str]]:
    # S3 notifications carry URL-encoded object keys in "Records";
    # direct invocations pass "bucket" and "key" at the top level.
    records = event.get("Records")
    if records:
        return [
            (record["s3"]["bucket"]["name"], unquote_plus(record["s3"]["object"]["key"]))
            for record in records
        ]
    bucket = event.get("bucket")
    key = event.get("key")
    if not bucket or not key:
        raise ValueError("Event must be an S3 notification or contain 'bucket' and 'key'.")
    return [(bucket, key)]


def handler(event: dict, context) -> dict:
    stored_points = 0
    for bucket, key in parse_event(event or {}):
        with tempfile.TemporaryDirectory() as tmp_dir:
            csv_path = Path(tmp_dir) / Path(key).name
            logger.info(f"Downloading s3://{bucket}/{key} to {csv_path}")
            s3_client.download_file(bucket, key, str(csv_path))
            stored_points = build_vector_db(str(csv_path))

    return {"collection": VECTORDB_DB_NAME, "points": stored_points}
