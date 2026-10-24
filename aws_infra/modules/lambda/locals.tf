locals {
  lambda_function_name = var.name

  artifact_s3_object_version = var.artifact_config.s3_object_version != null ? var.artifact_config.s3_object_version : one(data.aws_s3_object.artifact[*].version_id)
}