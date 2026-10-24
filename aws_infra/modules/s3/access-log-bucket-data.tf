# -------------------------------------------------------------------
# POLICIES [PERMISSIONS]
# -------------------------------------------------------------------
data "aws_iam_policy_document" "access_log_combined" {
  source_policy_documents = compact([
    # Generic policies
    var.access_log_attach_policy ? var.access_log_policy : "",
    # Access policies
    var.access_log_attach_require_latest_tls_policy ? data.aws_iam_policy_document.access_log_require_latest_tls.json : "",
    var.access_log_attach_deny_insecure_transport_policy ? data.aws_iam_policy_document.access_log_deny_insecure_transport.json : "",
    var.access_log_attach_deny_unencrypted_object_uploads ? data.aws_iam_policy_document.access_log_deny_unencrypted_object_uploads.json : "",
    var.access_log_attach_deny_ssec_encrypted_object_uploads ? data.aws_iam_policy_document.access_log_deny_ssec_encrypted_object_uploads.json : "",
    var.access_log_attach_deny_incorrect_kms_key_sse ? data.aws_iam_policy_document.access_log_deny_incorrect_kms_key_sse.json : "",
    var.access_log_attach_deny_incorrect_encryption_headers ? data.aws_iam_policy_document.access_log_deny_incorrect_encryption_headers.json : "",
    # Log delivery policies
    data.aws_iam_policy_document.access_log_delivery.json,
  ])

  lifecycle {
    enabled = var.access_log_enabled
  }
}

data "aws_iam_policy_document" "access_log_deny_insecure_transport" {
  statement {
    sid    = "denyInsecureTransport"
    effect = "Deny"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.access_log.arn,
      "${aws_s3_bucket.access_log.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false"
      ]
    }
  }

  lifecycle {
    enabled = var.access_log_enabled && var.access_log_attach_deny_insecure_transport_policy
  }
}

data "aws_iam_policy_document" "access_log_require_latest_tls" {
  statement {
    sid    = "denyOutdatedTLS"
    effect = "Deny"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.access_log.arn,
      "${aws_s3_bucket.access_log.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values = [
        "1.2"
      ]
    }
  }

  lifecycle {
    enabled = var.access_log_enabled && var.access_log_attach_require_latest_tls_policy
  }
}

data "aws_iam_policy_document" "access_log_deny_incorrect_encryption_headers" {
  statement {
    sid    = "denyIncorrectEncryptionHeaders"
    effect = "Deny"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.access_log.arn}/*"
    ]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = try(var.sse_algorithm, null) == "aws:kms" ? ["aws:kms"] : ["AES256"]
    }
  }

  lifecycle {
    enabled = var.access_log_enabled && var.access_log_attach_deny_incorrect_encryption_headers
  }
}

data "aws_iam_policy_document" "access_log_deny_incorrect_kms_key_sse" {
  statement {
    sid    = "denyIncorrectKmsKeySse"
    effect = "Deny"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.access_log.arn}/*"
    ]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [try(var.kms_master_key_id, null)]
    }
  }

  lifecycle {
    enabled = var.access_log_enabled && var.access_log_attach_deny_incorrect_kms_key_sse
  }
}

data "aws_iam_policy_document" "access_log_deny_unencrypted_object_uploads" {
  statement {
    sid    = "denyUnencryptedObjectUploads"
    effect = "Deny"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.access_log.arn}/*"
    ]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = [true]
    }
  }

  lifecycle {
    enabled = var.access_log_enabled && var.access_log_attach_deny_unencrypted_object_uploads
  }
}

data "aws_iam_policy_document" "access_log_deny_ssec_encrypted_object_uploads" {
  statement {
    sid    = "denySSECEncryptedObjectUploads"
    effect = "Deny"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.access_log.arn}/*"
    ]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption-customer-algorithm"
      values   = [false]
    }
  }

  lifecycle {
    enabled = var.access_log_enabled && var.access_log_attach_deny_ssec_encrypted_object_uploads
  }
}

# Grant access to S3 log delivery group for server access logging
# https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-ownership-migrating-acls-prerequisites.html#object-ownership-server-access-logs
# https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html#grant-log-delivery-permissions-general
data "aws_iam_policy_document" "access_log_delivery" {

  statement {
    sid = "AWSAccessLogDeliveryWrite"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.access_log.arn}/*",
    ]

    condition {
      test     = "ArnLike"
      values   = ["arn:aws:s3:::${aws_s3_bucket.content.id}"]
      variable = "aws:SourceArn"
    }

    dynamic "condition" {
      for_each = length(var.access_log_delivery_policy_source_buckets) != 0 ? [true] : []
      content {
        test     = "ForAnyValue:ArnLike"
        variable = "aws:SourceArn"
        values   = var.access_log_delivery_policy_source_buckets
      }
    }

    dynamic "condition" {
      for_each = length(var.access_log_delivery_policy_source_accounts) != 0 ? [true] : []
      content {
        test     = "ForAnyValue:StringEquals"
        variable = "aws:SourceAccount"
        values   = var.access_log_delivery_policy_source_accounts
      }
    }

    dynamic "condition" {
      for_each = length(var.access_log_delivery_policy_source_organizations) > 0 ? [true] : []

      content {
        test     = "StringEquals"
        variable = "aws:ResourceOrgID"
        values   = var.access_log_delivery_policy_source_organizations
      }
    }
  }

  statement {
    sid = "AWSAccessLogDeliveryAclCheck"

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
    ]

    resources = [
      aws_s3_bucket.access_log.arn,
    ]

    dynamic "condition" {
      for_each = length(var.access_log_delivery_policy_source_organizations) > 0 ? [true] : []

      content {
        test     = "StringEquals"
        variable = "aws:ResourceOrgID"
        values   = var.access_log_delivery_policy_source_organizations
      }
    }
  }

  lifecycle {
    enabled = var.access_log_enabled
  }
}
