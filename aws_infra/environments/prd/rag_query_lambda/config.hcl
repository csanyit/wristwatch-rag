locals {
  aws_region  = "eu-central-1"
  environment = "prd"

  name = "rag_query-${local.environment}"

  artifact = {
    s3_key    = "vector_db_builder/vector_db_builder.zip"
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
