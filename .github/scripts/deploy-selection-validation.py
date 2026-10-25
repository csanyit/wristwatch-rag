import argparse
import os
from pathlib import Path


ENVIRONMENT_DIRECTORIES = {"dev": "dev", "prod": "prd"}
REGION_DIRECTORIES = {"eu-west-1": "eu-west-1"}
MODULES = (
    "lambda_code_bucket",
    "rag_query_lambda",
    "vector_db_bucket",
    "vector_db_builder_lambda",
    "watch_specification_files_bucket",
)
ACTIONS = {
    "plan": "plan",
    "apply": "apply",
    "destroy-plan": "plan -destroy",
    "destroy-apply": "apply -destroy",
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate deployment inputs and select the Terragrunt directory."
    )
    parser.add_argument("--action", choices=ACTIONS, required=True)
    parser.add_argument(
        "--environment", choices=ENVIRONMENT_DIRECTORIES, required=True
    )
    parser.add_argument(
            "--region", choices=REGION_DIRECTORIES, required=True
        )
    parser.add_argument("--module", choices=MODULES, required=True)
    args = parser.parse_args()

    directory = (
        Path("aws_infra/environments")
        / ENVIRONMENT_DIRECTORIES[args.environment]
        / REGION_DIRECTORIES[args.region]
        / args.module
    )
    config = directory / "terragrunt.hcl"
    if not config.is_file():
        parser.error(f"Terragrunt configuration not found: {config}")

    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        parser.error("GITHUB_OUTPUT is not set")

    with Path(output_path).open("a", encoding="utf-8") as output:
        output.write(f"directory={directory.as_posix()}\n")
        output.write(f"terragrunt_command={ACTIONS[args.action]}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())