locals {
  environment = "prd"

  name = "rag_query-${local.environment}"

  artifact = {
    s3_key    = "rag_query_lambda/rag_query_lambda.zip"
    runtime   = "python3.12"
    handler   = "rag_query.lambda_handler.handler"
  }

  execution = {
    memory_size            = 2048
    timeout                = 600
    ephemeral_storage_size = 1024
  }

  log_level                   = "INFO"
  log_group_retention_in_days = 7
}
