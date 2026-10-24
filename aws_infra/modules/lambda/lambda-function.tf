resource "aws_lambda_function" "this" {
  architectures = var.artifact_config.architectures
  description   = var.description
  function_name = local.lambda_function_name
  handler       = var.artifact_config.handler

  memory_size  = var.execution_config.memory_size
  timeout      = var.execution_config.timeout
  package_type = var.artifact_config.package_type

  reserved_concurrent_executions = var.execution_config.reserved_concurrent_executions
  role                           = aws_iam_role.lambda.arn
  runtime                        = var.artifact_config.runtime
  kms_key_arn                    = var.kms_key_arn
  s3_bucket                      = var.artifact_config.s3_bucket
  s3_key                         = var.artifact_config.s3_key
  s3_object_version              = local.artifact_s3_object_version

  layers = var.artifact_config.layers

  ephemeral_storage {
    size = var.execution_config.ephemeral_storage_size
  }

  dynamic "environment" {
    for_each = var.environment_variables != null ? [var.environment_variables] : []

    content {
      variables = environment.value
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_enabled != false ? [var.dead_letter_queue_enabled] : []

    content {
      target_arn = aws_sqs_queue.this[0].arn
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_config_mode != null ? [true] : []

    content {
      mode = var.tracing_config_mode
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null ? [1] : []

    content {
      security_group_ids = [aws_security_group.this[0].id]
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy_attachment.lambda_cloudwatch_insights,
    aws_iam_role_policy_attachment.lambda_xray,
    aws_cloudwatch_log_group.this,
  ]

  tags = var.tags
}

resource "aws_lambda_function_event_invoke_config" "this" {
  count = var.destination_config_enabled ? 1 : 0

  function_name = aws_lambda_function.this.function_name

  maximum_event_age_in_seconds = var.destination_maximum_event_age_in_seconds
  maximum_retry_attempts       = var.destination_maximum_retry_attempts

  destination_config {

    on_success {
      destination = var.destination_config_on_success
    }

    on_failure {
      destination = var.destination_config_on_failure
    }
  }

  lifecycle {
    ignore_changes = [
      destination_config,
    ]
  }
}
