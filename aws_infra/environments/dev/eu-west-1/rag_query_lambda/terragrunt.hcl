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

inputs = {
  name        = local.config.name
  description = "Executes RAG pipeline and returns its response"

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
    layers        = []
  }

  execution_config = local.config.execution

  environment_variables = {
    WATCH_RAG_LOG_LEVEL = local.config.log_level
  }

  create_kms_key                         = true
  cloudwatch_log_group_retention_in_days = local.config.log_group_retention_in_days

}
