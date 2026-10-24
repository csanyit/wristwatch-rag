include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  config = read_terragrunt_config("${get_terragrunt_dir()}/config.hcl").locals
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules//lambda"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.config.aws_region}"
    }
  EOF
}

dependency "lambda_bucket" {
  config_path = "../lambda_code_bucket"

  mock_outputs = {
    content_bucket = {
      arn    = "arn:aws:s3:::mock-lambda-bucket"
      bucket = "mock-bucket"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name        = local.config.name
  description = "Executes RAG pipeline and returns it's response"

  artifact_config = {
    architectures = ["x86_64"]
    handler       = local.config.artifact.handler
    runtime       = local.config.artifact.runtime
    s3_bucket     = dependency.lambda_bucket.outputs.content_bucket.bucket
    s3_key        = local.config.artifact.s3_key
    layers        = []
  }

  execution_config = local.config.execution

  environment_variables = {
    WATCH_RAG_LOG_LEVEL = local.config.log_level
  }

  create_kms_key                         = true
  cloudwatch_log_group_retention_in_days = local.config.log_group_retention_in_days

  tags = {
    "project" = "wristwatch-rag"
  }
}
