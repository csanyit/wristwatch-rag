import argparse
import os
from pathlib import Path


ENVIRONMENT_DIRECTORIES = {"dev": "dev", "prod": "prd"}
REGION_DIRECTORIES = {"eu-west-1": "eu-west-1"}
LAMBDA_FUNCTIONS = (
    "rag_query_lambda",
    "vector_db_builder_lambda",
)
SOURCE_DIRECTORIES = {
    "rag_query_lambda": "rag_query",
    "vector_db_builder_lambda": "vector_db_builder",
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate deployment inputs and select the Lambda source directory."
    )
    parser.add_argument(
        "--environment", choices=ENVIRONMENT_DIRECTORIES, required=True
    )
    parser.add_argument("--region", choices=REGION_DIRECTORIES, required=True)
    parser.add_argument("--lambda_name", choices=LAMBDA_FUNCTIONS, required=True)
    args = parser.parse_args()

    target_directory = (
        Path("aws_infra/environments")
        / ENVIRONMENT_DIRECTORIES[args.environment]
        / REGION_DIRECTORIES[args.region]
        / args.lambda_name
    )
    if not target_directory.is_dir():
        parser.error(f"Lambda target directory not found: {target_directory}")

    source_directory = Path("src") / SOURCE_DIRECTORIES[args.lambda_name]
    if not source_directory.is_dir():
        parser.error(f"Lambda source directory not found: {source_directory}")

    properties_file = Path("src/watch_rag.properties")
    if not properties_file.is_file():
        parser.error(f"Shared Lambda properties file not found: {properties_file}")

    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        parser.error("GITHUB_OUTPUT is not set")

    with Path(output_path).open("a", encoding="utf-8") as output:
        output.write(f"source_directory={source_directory.as_posix()}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())