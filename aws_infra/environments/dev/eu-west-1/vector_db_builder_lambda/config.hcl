locals {
  environment = "dev"

  name = "vector_db_builder-${local.environment}"

  artifact = {
    s3_key    = "vector_db_builder_lambda/vector_db_builder_lambda.zip"
    runtime   = "python3.12"
    handler   = "vector_db_builder.lambda_handler.handler"
  }

  execution = {
    memory_size            = 2048
    timeout                = 600
    ephemeral_storage_size = 1024
  }

  log_level                   = "INFO"
  log_group_retention_in_days = 7
}
