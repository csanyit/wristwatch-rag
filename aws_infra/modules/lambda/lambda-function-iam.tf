resource "aws_iam_role" "lambda" {
  name               = "${local.lambda_function_name}-role"
  description        = "Lambda role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${local.lambda_function_name}-role-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_inline_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_additional_policies" {
  for_each = var.additional_policies

  policy_arn = each.value
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count = var.vpc_subnet_ids != null ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_insights" {
  count = var.cloudwatch_lambda_insights_enabled ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  count = var.tracing_config_mode != null ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.lambda.name
}
