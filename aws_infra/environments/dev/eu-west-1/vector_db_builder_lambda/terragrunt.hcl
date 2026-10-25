include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("region.hcl")
}

locals {
  config = read_terragrunt_config("${get_terragrunt_dir()}/config.hcl").locals
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//lambda"
}

dependency "lambda_bucket" {
  config_path = "../lambda_code_bucket"

  mock_outputs = {
    content_bucket = {
      arn               = "arn:aws:s3:::mock-lambda-bucket"
      bucket            = "mock-bucket"
      s3_object_version = "mock-version"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "specification_bucket" {
  config_path = "../watch_specification_files_bucket"

  mock_outputs = {
    content_bucket = {
      arn    = "arn:aws:s3:::mock-bucket"
      bucket = "mock-bucket"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "vector_db_bucket" {
  config_path = "../vector_db_bucket"

  mock_outputs = {
    vector_bucket_name = "mock-vector-bucket"
    vector_index_arns = {
      "watch-rag-db" = "arn:aws:s3vectors:eu-west-1:000000000000:bucket/mock-bucket/index/watch-rag-db"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name        = local.config.name
  description = "Builds the watch vector database from CSV files in S3"

  artifact_config = {
    architectures = ["x86_64"]
    handler       = local.config.artifact.handler
    runtime       = local.config.artifact.runtime
    s3_bucket     = dependency.lambda_bucket.outputs.content_bucket.bucket
    s3_key        = local.config.artifact.s3_key
    s3_object_version = try(
      dependency.lambda_bucket.outputs.content_bucket.s3_object_version,
      null,
    )
    layers = []
  }

  execution_config = local.config.execution

  environment_variables = {
    WATCH_RAG_LOG_LEVEL      = local.config.log_level
    S3_VECTOR_BUCKET         = dependency.vector_db_bucket.outputs.vector_bucket_name
    VECTOR_EMBEDDER_PROVIDER = "bedrock"
    VECTORDB_MODEL_NAME      = "mistral.mistral-7b-instruct-v0:2"
  }

  create_kms_key                         = false
  cloudwatch_log_group_retention_in_days = local.config.log_group_retention_in_days

  additional_inline_statements = {
    read_source_data = {
      actions = ["s3:GetObject"]
      resources = [
        "${dependency.specification_bucket.outputs.content_bucket.arn}/*",
      ]
    }
    manage_vectors = {
      actions = [
        "s3vectors:PutVectors",
        "s3vectors:DeleteVectors",
      ]
      resources = [
        dependency.vector_db_bucket.outputs.vector_index_arns["watch-rag-db"],
      ]
    }
    invoke_bedrock_model = {
      actions = [
        "bedrock:InvokeModel",
      ]
      resources = [
        "arn:aws:bedrock:eu-west-1::foundation-model/mistral.mistral-7b-instruct-v0:2",
      ]
    }
  }

}
