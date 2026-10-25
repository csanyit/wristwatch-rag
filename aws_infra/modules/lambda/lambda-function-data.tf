# Current version of the artifact, so that uploading a new zip to the same key redeploys the function (requires a versioned bucket)
data "aws_s3_object" "artifact" {
  count = var.artifact_config.s3_object_version == null ? 1 : 0

  bucket = var.artifact_config.s3_bucket
  key    = var.artifact_config.s3_key
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    sid     = "LambdaTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_inline_policy" {

  statement {
    sid       = "LambdaLog"
    effect    = "Allow"
    resources = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lambda_function_name}:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:List*",
      "s3:Get*"
    ]
    resources = [
      "arn:aws:s3:::${var.artifact_config.s3_bucket}",
      "arn:aws:s3:::${var.artifact_config.s3_bucket}/*",
    ]
  }

  dynamic "statement" {
    for_each = coalesce(var.dead_letter_queue_enabled, false) ? [1] : []

    content {
      sid       = "ForwardtoSQS"
      effect    = "Allow"
      resources = [aws_sqs_queue.this[0].arn]

      actions = [
        "sqs:SendMessage"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.dead_letter_queue_enabled ? [1] : []

    content {
      sid    = "EncryptLambdaDLQMessages"
      effect = "Allow"
      resources = [
        local.lambda_kms_key_arn
      ]

      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey*",
      ]
    }
  }

  dynamic "statement" {
    for_each = var.additional_inline_statements

    content {
      sid       = replace(title(replace(statement.key, "_", " ")), " ", "")
      effect    = "Allow"
      resources = statement.value.resources
      actions   = statement.value.actions
    }
  }
}

data "aws_iam_policy_document" "lambda_key_policy" {
  statement {
    sid       = "AllowRootUserAccess"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:*"
    ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }

  statement {
    sid       = "AllowKMSKeyUsage"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values = [
        data.aws_caller_identity.current.account_id
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "logs.${data.aws_region.current.region}.amazonaws.com",
        "s3.${data.aws_region.current.region}.amazonaws.com",
        "lambda.${data.aws_region.current.region}.amazonaws.com",
        "secretsmanager.${data.aws_region.current.region}.amazonaws.com",
        "sns.${data.aws_region.current.region}.amazonaws.com",
        "sqs.${data.aws_region.current.region}.amazonaws.com",
        "kinesis.${data.aws_region.current.region}.amazonaws.com"
      ]
    }
  }

  statement {
    sid       = "AllowCloudWatch"
    effect    = "Allow"
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "logs.${data.aws_region.current.region}.amazonaws.com"
      ]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lambda_function_name}"
      ]
    }
  }
}
