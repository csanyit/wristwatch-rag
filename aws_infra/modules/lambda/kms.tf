resource "aws_kms_key" "lambda_key" {
  count = var.create_kms_key ? 1 : 0

  description             = "KMS key for Lambda"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.lambda_key_policy.json

  tags = var.tags
}
