# -------------------------------------------------------------------
# BUCKET
# -------------------------------------------------------------------
resource "aws_s3_bucket" "access_log" {
  # checkov:skip=CKV_AWS_144: "Ensure that S3 bucket has cross-region replication enabled"
  # checkov:skip=CKV_AWS_145: "Ensure that S3 buckets are encrypted with KMS by default"
  # checkov:skip=CKV_AWS_21: "Ensure all data stored in the S3 bucket have versioning enabled"
  # checkov:skip=CKV2_AWS_62: "Ensure S3 buckets should have event notifications enabled"
  # checkov:skip=CKV2_AWS_61: "Ensure that an S3 bucket has a lifecycle configuration"
  bucket        = var.use_prefix ? null : local.access_log_bucket_name
  bucket_prefix = var.use_prefix ? local.access_log_bucket_name : null

  force_destroy    = var.force_destroy
  bucket_namespace = var.namespace

  tags = merge(var.tags, var.access_log_tags)

  lifecycle {
    enabled = var.access_log_enabled
  }
}

# -------------------------------------------------------------------
# ENCRYPTION
# -------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "access_log" {
  bucket = aws_s3_bucket.access_log.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled       = false
    blocked_encryption_types = ["NONE"]
  }

  lifecycle {
    enabled = var.access_log_enabled
  }
}

# -------------------------------------------------------------------
# PERMISSIONS
# -------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "access_log" {
  bucket = aws_s3_bucket.access_log.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle {
    enabled = var.access_log_enabled
  }
}

resource "aws_s3_bucket_policy" "access_log_policy" {
  bucket = aws_s3_bucket.access_log.bucket
  policy = data.aws_iam_policy_document.access_log_combined.json

  depends_on = [
    aws_s3_bucket_public_access_block.access_log,
  ]

  lifecycle {
    enabled = var.access_log_enabled
  }
}

resource "aws_s3_bucket_acl" "access_log" {
  bucket = aws_s3_bucket.access_log.bucket
  acl    = "log-delivery-write"

  lifecycle {
    enabled = var.access_log_enabled && local.create_bucket_acl
  }
}

# -------------------------------------------------------------------
# MANAGEMENT
# -------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "access_log_rules" {
  # checkov:skip=CKV_AWS_300: "Ensure S3 lifecycle configuration sets period for aborting failed uploads"
  # One configuration per bucket: S3 keeps a single lifecycle configuration that holds all rules.
  count = var.access_log_enabled && length(local.access_log_lifecycle_rules) > 0 ? 1 : 0

  bucket                                 = aws_s3_bucket.access_log.id
  transition_default_minimum_object_size = var.access_log_lifecycle_rule_transition_default_minimum_object_size

  dynamic "rule" {
    for_each = local.access_log_lifecycle_rules

    content {
      id     = try(replace(rule.value.id != null ? rule.value.id : rule.key, "_", "-"), null)
      status = try(rule.value.enabled ? "Enabled" : "Disabled", tobool(rule.value.status) ? "Enabled" : "Disabled", title(lower(rule.value.status)))

      # Max 1 block - abort_incomplete_multipart_upload
      # NOTE: Cannot be combined with object_size_greater_than or object_size_less_than filters
      dynamic "abort_incomplete_multipart_upload" {
        for_each = (try(rule.value.filter.object_size_greater_than, null) == null && try(rule.value.filter.object_size_less_than, null) == null) ? [true] : []

        content {
          days_after_initiation = try(rule.value.abort_incomplete_multipart_upload_days, 7)
        }
      }

      # Max 1 block - expiration
      dynamic "expiration" {
        for_each = [for t in try(flatten([rule.value.expiration]), []) : t if t != null]

        content {
          date                         = try(expiration.value.date, null)
          days                         = try(expiration.value.days, null)
          expired_object_delete_marker = try(expiration.value.expired_object_delete_marker, null)
        }
      }

      # Several blocks - transition
      dynamic "transition" {
        for_each = [for t in try(flatten([rule.value.transition]), []) : t if t != null]

        content {
          date          = try(transition.value.date, null)
          days          = try(transition.value.days, null)
          storage_class = transition.value.storage_class
        }
      }

      # Max 1 block - noncurrent_version_expiration
      dynamic "noncurrent_version_expiration" {
        for_each = [for t in try(flatten([rule.value.noncurrent_version_expiration]), []) : t if t != null]

        content {
          newer_noncurrent_versions = try(noncurrent_version_expiration.value.newer_noncurrent_versions, null)
          noncurrent_days           = try(noncurrent_version_expiration.value.days, noncurrent_version_expiration.value.noncurrent_days, null)
        }
      }

      # Several blocks - noncurrent_version_transition
      dynamic "noncurrent_version_transition" {
        for_each = [for t in try(flatten([rule.value.noncurrent_version_transition]), []) : t if t != null]

        content {
          newer_noncurrent_versions = try(noncurrent_version_transition.value.newer_noncurrent_versions, null)
          noncurrent_days           = try(noncurrent_version_transition.value.days, noncurrent_version_transition.value.noncurrent_days, null)
          storage_class             = noncurrent_version_transition.value.storage_class
        }
      }

      # Max 1 block - filter - without any key arguments or tags
      dynamic "filter" {
        for_each = length(try(flatten([rule.value.filter]), [])) == 0 ? [true] : []

        content {}
      }

      # Max 1 block - filter - with one key argument or a single tag
      dynamic "filter" {
        for_each = [for v in [for f in try(flatten([rule.value.filter]), []) : f if f != null] : v if max(length(keys(v)), try(length(rule.value.filter.tags), 0) + try(length(rule.value.filter.tag), 0)) == 1]

        content {
          object_size_greater_than = try(filter.value.object_size_greater_than, null)
          object_size_less_than    = try(filter.value.object_size_less_than, null)
          prefix                   = try(filter.value.prefix, null)

          dynamic "tag" {
            for_each = try(filter.value.tags, filter.value.tag, [])

            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      # Max 1 block - filter - with more than one key arguments or multiple tags
      dynamic "filter" {
        for_each = [for v in [for f in try(flatten([rule.value.filter]), []) : f if f != null] : v if max(length(keys(v)), try(length(rule.value.filter.tags), 0) + try(length(rule.value.filter.tag), 0)) > 1]

        content {
          and {
            object_size_greater_than = try(filter.value.object_size_greater_than, null)
            object_size_less_than    = try(filter.value.object_size_less_than, null)
            prefix                   = try(filter.value.prefix, null)
            tags                     = try(filter.value.tags, filter.value.tag, null)
          }
        }
      }
    }
  }
}
