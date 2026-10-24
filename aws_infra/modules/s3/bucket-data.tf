# -------------------------------------------------------------------
# POLICIES [ACTION]
# -------------------------------------------------------------------
data "aws_iam_policy_document" "read_only" {
  dynamic "statement" {
    for_each = local.read_only_policy_statements

    content {
      sid       = replace(title(replace(statement.key, "_", " ")), " ", "")
      effect    = "Allow"
      resources = statement.value.resources
      actions   = statement.value.actions
    }
  }
}

data "aws_iam_policy_document" "read_write" {
  dynamic "statement" {
    for_each = local.read_write_policy_statements

    content {
      sid       = replace(title(replace(statement.key, "_", " ")), " ", "")
      effect    = "Allow"
      resources = statement.value.resources
      actions   = statement.value.actions
    }
  }
}

# -------------------------------------------------------------------
# POLICIES [PERMISSIONS]
# -------------------------------------------------------------------
data "aws_iam_policy_document" "combined" {
  count = local.attach_policy ? 1 : 0

  source_policy_documents = compact([
    # Generic policies
    var.attach_policy ? var.policy : "",
    # Access policies
    var.attach_require_latest_tls_policy ? data.aws_iam_policy_document.require_latest_tls[0].json : "",
    var.attach_deny_insecure_transport_policy ? data.aws_iam_policy_document.deny_insecure_transport[0].json : "",
    var.attach_deny_unencrypted_object_uploads ? data.aws_iam_policy_document.deny_unencrypted_object_uploads[0].json : "",
    var.attach_deny_ssec_encrypted_object_uploads ? data.aws_iam_policy_document.deny_ssec_encrypted_object_uploads[0].json : "",
    var.attach_deny_incorrect_kms_key_sse ? data.aws_iam_policy_document.deny_incorrect_kms_key_sse[0].json : "",
    var.attach_deny_incorrect_encryption_headers ? data.aws_iam_policy_document.deny_incorrect_encryption_headers[0].json : "",
    var.attach_deny_presigned_url_request_older_than ? data.aws_iam_policy_document.deny_presigned_url_request_older_than[0].json : "",
    var.attach_cloudfront_distribution_policy ? data.aws_iam_policy_document.allow_cloudfront_from_org[0].json : "",
    # Log delivery policies
    var.attach_elb_log_delivery_policy ? data.aws_iam_policy_document.elb_log_delivery[0].json : "",
    var.attach_lb_log_delivery_policy ? data.aws_iam_policy_document.lb_log_delivery[0].json : "",
    var.attach_cloudtrail_log_delivery_policy ? data.aws_iam_policy_document.cloudtrail_log_delivery[0].json : "",
    var.attach_waf_log_delivery_policy ? data.aws_iam_policy_document.waf_log_delivery[0].json : "",
    # Inventory and analytics policies
    var.attach_inventory_destination_policy || var.attach_analytics_destination_policy ? data.aws_iam_policy_document.inventory_and_analytics_destination_policy[0].json : "",
    var.attach_policies_for_presigned_url ? data.aws_iam_policy_document.policies_for_presigned_url[0].json : "",
  ])
}

# -------------------------------------------------------------------
# POLICIES [SERVICES]
# -------------------------------------------------------------------
data "aws_iam_policy_document" "allow_cloudfront_from_org" {
  count = var.attach_cloudfront_distribution_policy ? 1 : 0

  statement {
    sid    = "AllowCloudFrontFromOrg"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values   = var.organization_ids
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudfront::*:distribution/*"]
    }
  }
}

# -------------------------------------------------------------------
# POLICIES [SECURITY]
# -------------------------------------------------------------------
data "aws_iam_policy_document" "deny_insecure_transport" {
  count = var.attach_deny_insecure_transport_policy ? 1 : 0

  statement {
    sid    = "denyInsecureTransport"
    effect = "Deny"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.content.arn,
      "${aws_s3_bucket.content.arn}/*",
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
}

data "aws_iam_policy_document" "require_latest_tls" {
  count = var.attach_require_latest_tls_policy ? 1 : 0

  statement {
    sid    = "denyOutdatedTLS"
    effect = "Deny"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.content.arn,
      "${aws_s3_bucket.content.arn}/*",
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
}

data "aws_iam_policy_document" "deny_incorrect_encryption_headers" {
  count = var.attach_deny_incorrect_encryption_headers ? 1 : 0

  statement {
    sid    = "denyIncorrectEncryptionHeaders"
    effect = "Deny"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/*"
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
}

data "aws_iam_policy_document" "deny_incorrect_kms_key_sse" {
  count = var.attach_deny_incorrect_kms_key_sse ? 1 : 0

  statement {
    sid    = "denyIncorrectKmsKeySse"
    effect = "Deny"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/*"
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
}

data "aws_iam_policy_document" "deny_unencrypted_object_uploads" {
  count = var.attach_deny_unencrypted_object_uploads ? 1 : 0

  statement {
    sid    = "denyUnencryptedObjectUploads"
    effect = "Deny"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/*"
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
}

data "aws_iam_policy_document" "deny_ssec_encrypted_object_uploads" {
  count = var.attach_deny_ssec_encrypted_object_uploads ? 1 : 0

  statement {
    sid    = "denySSECEncryptedObjectUploads"
    effect = "Deny"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/*"
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
}

data "aws_iam_policy_document" "deny_presigned_url_request_older_than" {
  count = var.attach_deny_presigned_url_request_older_than ? 1 : 0

  statement {
    sid    = "denyPresignedUrlRequestOlderThan"
    effect = "Deny"

    actions = [
      "s3:*"
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/*"
    ]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "NumericGreaterThan"
      variable = "s3:signatureAge"
      values   = [try(var.presigned_url_max_age * 1000, null)]
    }
  }
}

data "aws_iam_policy_document" "policies_for_presigned_url" {
  count = var.attach_policies_for_presigned_url && length(var.presigned_url_principal_arns) > 0 ? 1 : 0

  statement {
    sid    = "AllowPresignedUrls"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.presigned_url_principal_arns
    }
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.content.arn}/*"]

  }
}

# -------------------------------------------------------------------
# POLICIES [SERVICE LOG DELIVERY]
# -------------------------------------------------------------------
# ALB/NLB
data "aws_iam_policy_document" "elb_log_delivery" {
  count = var.attach_elb_log_delivery_policy ? 1 : 0

  # Policy for AWS Regions created before August 2022 (e.g. US East (N. Virginia), Asia Pacific (Singapore), Asia Pacific (Sydney), Asia Pacific (Tokyo), Europe (Ireland))
  dynamic "statement" {
    for_each = { for k, v in local.elb_service_accounts : k => v if k == data.aws_region.current.region }

    content {
      sid = format("ELBRegion%s", title(statement.key))

      principals {
        type        = "AWS"
        identifiers = [format("arn:%s:iam::%s:root", data.aws_partition.current.partition, statement.value)]
      }

      effect = "Allow"

      actions = [
        "s3:PutObject",
      ]

      resources = [
        "${aws_s3_bucket.content.arn}/*",
      ]
    }
  }

  # Policy for AWS Regions created after August 2022 (e.g. Asia Pacific (Hyderabad), Asia Pacific (Melbourne), Europe (Spain), Europe (Zurich), Middle East (UAE))
  statement {
    sid = "AlbNlbLogDeliveryWrite"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/*",
    ]
  }
}

# Policy for Log deliver like: VPC Flow Logs
data "aws_iam_policy_document" "lb_log_delivery" {
  count = var.attach_lb_log_delivery_policy ? 1 : 0

  statement {
    sid = "LogDeliveryWrite"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    dynamic "condition" {
      for_each = length(var.lb_log_delivery_policy_source_organizations) > 0 ? [true] : []

      content {
        test     = "StringEquals"
        variable = "aws:ResourceOrgID"
        values   = var.lb_log_delivery_policy_source_organizations
      }
    }
  }

  statement {
    sid = "LogDeliveryAclCheck"

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.content.arn,
    ]

    dynamic "condition" {
      for_each = length(var.lb_log_delivery_policy_source_organizations) > 0 ? [true] : []

      content {
        test     = "StringEquals"
        variable = "aws:ResourceOrgID"
        values   = var.lb_log_delivery_policy_source_organizations
      }
    }
  }
}

# WAF
data "aws_iam_policy_document" "waf_log_delivery" {
  count = var.attach_waf_log_delivery_policy ? 1 : 0

  statement {
    sid = "WafLogDeliveryWrite"

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/AWSLogs/${data.aws_caller_identity.current.id}/*",
    ]

    condition {
      test     = "StringEquals"
      values   = ["bucket-owner-full-control"]
      variable = "s3:x-amz-acl"
    }

    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.id]
      variable = "aws:SourceAccount"
    }

    condition {
      test     = "ArnLike"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.id}:*"]
      variable = "aws:SourceArn"
    }
  }

  statement {
    sid = "WafLogDeliveryAclCheck"

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
    ]

    resources = [
      aws_s3_bucket.content.arn,
    ]

    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.id]
      variable = "aws:SourceAccount"
    }

    condition {
      test     = "ArnLike"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.id}:*"]
      variable = "aws:SourceArn"
    }
  }
}

# CloudTrail
data "aws_iam_policy_document" "cloudtrail_log_delivery" {
  count = var.attach_cloudtrail_log_delivery_policy ? 1 : 0

  statement {
    sid = "AWSCloudTrailAclCheck"

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
    ]

    resources = [
      aws_s3_bucket.content.arn,
    ]

    dynamic "condition" {
      for_each = length(var.cloudtrail_log_delivery_policy_source_organizations) > 0 ? [true] : []

      content {
        test     = "StringEquals"
        variable = "aws:ResourceOrgID"
        values   = var.cloudtrail_log_delivery_policy_source_organizations
      }
    }
  }

  statement {
    sid = "AWSCloudTrailWrite"

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = compact([
      aws_s3_bucket.content.arn,
      var.cloudtrail_log_delivery_policy_key_prefix != null ? "${aws_s3_bucket.content.arn}/${var.cloudtrail_log_delivery_policy_key_prefix}/*" : null,
      var.cloudtrail_log_delivery_policy_key_prefix != null ? "${aws_s3_bucket.content.arn}/${var.cloudtrail_log_delivery_policy_key_prefix}/AWSLogs/*" : "${aws_s3_bucket.content.arn}/AWSLogs/*",
    ])

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values = [
        "bucket-owner-full-control",
      ]
    }

    dynamic "condition" {
      for_each = length(var.cloudtrail_log_delivery_policy_source_organizations) > 0 ? [true] : []

      content {
        test     = "StringEquals"
        variable = "aws:ResourceOrgID"
        values   = var.cloudtrail_log_delivery_policy_source_organizations
      }
    }
  }
}

# -------------------------------------------------------------------
# POLICIES [INVENTORY AND ANALYTICS]
# -------------------------------------------------------------------
# Inventory and analytics destination bucket requires a bucket policy to allow source to PutObjects
# https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html#example-bucket-policies-use-case-9
data "aws_iam_policy_document" "inventory_and_analytics_destination_policy" {
  count = var.attach_inventory_destination_policy || var.attach_analytics_destination_policy ? 1 : 0

  statement {
    sid    = "destinationInventoryAndAnalyticsPolicy"
    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.content.arn}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = compact(distinct([
        var.inventory_self_source_destination ? aws_s3_bucket.content.arn : var.inventory_source_bucket_arn,
        var.analytics_self_source_destination ? aws_s3_bucket.content.arn : var.analytics_source_bucket_arn
      ]))
    }

    condition {
      test = "StringEquals"
      values = compact(distinct([
        var.inventory_self_source_destination ? data.aws_caller_identity.current.id : var.inventory_source_account_id,
        var.analytics_self_source_destination ? data.aws_caller_identity.current.id : var.analytics_source_account_id
      ]))
      variable = "aws:SourceAccount"
    }

    condition {
      test     = "StringEquals"
      values   = ["bucket-owner-full-control"]
      variable = "s3:x-amz-acl"
    }
  }
}
