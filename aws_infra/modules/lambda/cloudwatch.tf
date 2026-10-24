resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.kms_key_arn

  lifecycle {
    prevent_destroy = false
  }

  tags = var.tags
}
