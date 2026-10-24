# -------------------------------------------------------------------
# BUCKET
# -------------------------------------------------------------------
resource "aws_s3_bucket" "content" {
  bucket        = var.use_prefix ? null : local.content_bucket_name
  bucket_prefix = var.use_prefix ? local.content_bucket_name : null

  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_configuration.enabled
  bucket_namespace    = var.namespace

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "content" {
  bucket = aws_s3_bucket.content.id
  mfa    = var.versioning_mfa_id

  versioning_configuration {
    # Valid values: "Enabled" or "Suspended" or "Disabled"
    status = var.versioning_enabled ? "Enabled" : (var.versioning_force_disabled ? "Disabled" : "Suspended")

    # Valid values: "Enabled" or "Disabled"
    mfa_delete = var.versioning_mfa_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_accelerate_configuration" "this" {
  count = var.transfer_acceleration != null ? 1 : 0

  bucket = aws_s3_bucket.content.id

  # Valid values: "Enabled" or "Suspended"
  status = lower(var.transfer_acceleration) == "enabled" ? "Enabled" : "Suspended"
}

resource "aws_s3_bucket_request_payment_configuration" "this" {
  count = var.request_payer != null ? 1 : 0

  bucket = aws_s3_bucket.content.id

  # Valid values: "BucketOwner" or "Requester"
  payer = lower(var.request_payer) == "requester" ? "Requester" : "BucketOwner"
}

# -------------------------------------------------------------------
# METADATA
# -------------------------------------------------------------------
resource "aws_s3_bucket_metadata_configuration" "content" {
  count = var.metadata_configuration_creatable ? 1 : 0

  bucket = aws_s3_bucket.content.id

  metadata_configuration {
    inventory_table_configuration {
      configuration_state = var.metadata_inventory_table_configuration_state

      dynamic "encryption_configuration" {
        for_each = var.metadata_encryption_configuration != null ? [var.metadata_encryption_configuration] : []
        content {
          kms_key_arn   = try(encryption_configuration.value.kms_key_arn, null)
          sse_algorithm = encryption_configuration.value.sse_algorithm
        }
      }
    }

    journal_table_configuration {
      record_expiration {
        days       = var.metadata_journal_table_record_expiration_days
        expiration = var.metadata_journal_table_record_expiration
      }
    }
  }
}

# -------------------------------------------------------------------
# ENCRYPTION
# -------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "content_aes" {
  for_each = var.sse_algorithm == "AES256" ? { sse_algorithm = "AES256" } : {}

  bucket = aws_s3_bucket.content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.sse_algorithm
    }
    blocked_encryption_types = var.sse_blocked_encryption_types
    bucket_key_enabled       = false
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "content_kms_awskey" {
  for_each = var.sse_algorithm == "aws:kms" && local.kms_key_id == {} ? { sse_algorithm = "aws:kms" } : {}

  bucket = aws_s3_bucket.content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.sse_algorithm
    }
    blocked_encryption_types = var.sse_blocked_encryption_types
    bucket_key_enabled       = var.sse_bucket_key_enabled
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "content_kms_masterkey" {
  for_each = var.sse_algorithm == "aws:kms" && local.kms_key_id != {} ? { sse_algorithm = "aws:kms" } : {}

  bucket = aws_s3_bucket.content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.kms_master_key_id == null ? "aws/s3" : var.kms_master_key_id
    }
    blocked_encryption_types = var.sse_blocked_encryption_types
    bucket_key_enabled       = var.sse_bucket_key_enabled
  }
}

# -------------------------------------------------------------------
# PERMISSIONS
# -------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "content" {

  bucket = aws_s3_bucket.content.id

  block_public_acls       = var.block_public_access_public_acls
  block_public_policy     = var.block_public_access_public_policy
  ignore_public_acls      = var.block_public_access_ignore_public_acls
  restrict_public_buckets = var.block_public_access_restrict_public_buckets
  skip_destroy            = var.block_public_access_skip_destroy
}

resource "aws_s3_bucket_ownership_controls" "content" {
  bucket = local.attach_policy ? aws_s3_bucket_policy.content[0].id : aws_s3_bucket.content.id

  rule {
    object_ownership = var.object_ownership
  }

  # This `depends_on` is to prevent "A conflicting conditional operation is currently in progress against this resource."
  depends_on = [
    aws_s3_bucket_policy.content,
    aws_s3_bucket_public_access_block.content,
    aws_s3_bucket.content
  ]
}

resource "aws_s3_bucket_acl" "this" {
  count = local.create_bucket_acl ? 1 : 0

  bucket = aws_s3_bucket.content.id

  acl = var.acl

  dynamic "access_control_policy" {
    for_each = length(local.grants) > 0 ? [true] : []

    content {
      dynamic "grant" {
        for_each = local.grants

        content {
          permission = grant.value.permission

          grantee {
            type          = grant.value.type
            id            = try(grant.value.id, null)
            uri           = try(grant.value.uri, null)
            email_address = try(grant.value.email, null)
          }
        }
      }

      owner {
        id = try(var.acl_owner.id, data.aws_canonical_user_id.this[0].id)
      }
    }
  }

  # This `depends_on` is to prevent "AccessControlListNotSupported: The bucket does not allow ACLs."
  depends_on = [
    aws_s3_bucket_ownership_controls.content
  ]
}

resource "aws_s3_bucket_object_lock_configuration" "content" {
  count = var.object_lock_configuration.enabled ? 1 : 0

  bucket = aws_s3_bucket.content.id

  rule {
    default_retention {
      mode  = var.object_lock_configuration.mode
      days  = var.object_lock_configuration.days
      years = var.object_lock_configuration.years
    }
  }
}

resource "aws_s3_bucket_policy" "content" {
  count = local.attach_policy ? 1 : 0

  # Chain resources (s3_bucket -> s3_bucket_public_access_block -> s3_bucket_policy )
  # to prevent "A conflicting conditional operation is currently in progress against this resource."
  # Ref: https://github.com/hashicorp/terraform-provider-aws/issues/7628

  bucket = aws_s3_bucket.content.id
  policy = local.policy

  depends_on = [
    aws_s3_bucket_public_access_block.content
  ]
}

resource "aws_s3_bucket_cors_configuration" "this" {
  count = length(local.cors_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.content.id

  dynamic "cors_rule" {
    for_each = local.cors_rules

    content {
      id              = try(cors_rule.value.id, null)
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      allowed_headers = try(cors_rule.value.allowed_headers, null)
      expose_headers  = try(cors_rule.value.expose_headers, null)
      max_age_seconds = try(cors_rule.value.max_age_seconds, null)
    }
  }
}

# -------------------------------------------------------------------
# MANAGEMENT
# -------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "content_rules" {
  count = length(local.lifecycle_rules) > 0 ? 1 : 0

  bucket                                 = aws_s3_bucket.content.id
  transition_default_minimum_object_size = var.lifecycle_rule_transition_default_minimum_object_size

  dynamic "rule" {
    for_each = local.lifecycle_rules

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
          noncurrent_days           = try(noncurrent_version_expiration.value.noncurrent_days, null) != null ? noncurrent_version_expiration.value.noncurrent_days : try(noncurrent_version_expiration.value.days, null)
        }
      }

      # Several blocks - noncurrent_version_transition
      dynamic "noncurrent_version_transition" {
        for_each = [for t in try(flatten([rule.value.noncurrent_version_transition]), []) : t if t != null]

        content {
          newer_noncurrent_versions = try(noncurrent_version_transition.value.newer_noncurrent_versions, null)
          noncurrent_days           = try(noncurrent_version_transition.value.noncurrent_days, null) != null ? noncurrent_version_transition.value.noncurrent_days : try(noncurrent_version_transition.value.days, null)
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

  depends_on = [
    # Must have bucket versioning enabled first
    aws_s3_bucket_versioning.content,
    # Must wait for replication configuration to propagate
    aws_s3_bucket_replication_configuration.this
  ]
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "content" {
  for_each = { for k, v in local.intelligent_tiering : k => v }

  name   = each.key
  bucket = aws_s3_bucket.content.id
  status = try(tobool(each.value.status) ? "Enabled" : "Disabled", title(lower(each.value.status)), null)

  # Max 1 block - filter
  dynamic "filter" {
    for_each = length(try(flatten([each.value.filter]), [])) == 0 ? [] : [true]

    content {
      prefix = try(each.value.filter.prefix, null)
      tags   = try(each.value.filter.tags, null)
    }
  }

  dynamic "tiering" {
    for_each = each.value.tiering

    content {
      access_tier = tiering.key
      days        = tiering.value.days
    }
  }
}

resource "aws_s3_bucket_metric" "content" {
  for_each = { for k, v in local.metric_configuration : k => v }

  name   = each.value.name
  bucket = aws_s3_bucket.content.id

  dynamic "filter" {
    for_each = length(try(flatten([each.value.filter]), [])) == 0 ? [] : [true]
    content {
      prefix = try(each.value.filter.prefix, null)
      tags   = try(each.value.filter.tags, null)
    }
  }
}

resource "aws_s3_bucket_inventory" "content" {
  for_each = { for k, v in var.inventory_configuration : k => v }

  name                     = each.key
  bucket                   = try(each.value.bucket, aws_s3_bucket.content.id)
  included_object_versions = each.value.included_object_versions
  enabled                  = try(each.value.enabled, true)
  optional_fields          = try(each.value.optional_fields, null)

  destination {
    bucket {
      bucket_arn = try(each.value.destination.bucket_arn, aws_s3_bucket.content.arn)
      format     = try(each.value.destination.format, null)
      account_id = try(each.value.destination.account_id, null)
      prefix     = try(each.value.destination.prefix, null)

      dynamic "encryption" {
        for_each = length(try(flatten([each.value.destination.encryption]), [])) == 0 ? [] : [true]

        content {

          dynamic "sse_kms" {
            for_each = each.value.destination.encryption.encryption_type == "sse_kms" ? [true] : []

            content {
              key_id = try(each.value.destination.encryption.kms_key_id, null)
            }
          }

          dynamic "sse_s3" {
            for_each = each.value.destination.encryption.encryption_type == "sse_s3" ? [true] : []

            content {
            }
          }
        }
      }
    }
  }

  schedule {
    frequency = each.value.frequency
  }

  dynamic "filter" {
    for_each = length(try(flatten([each.value.filter]), [])) == 0 ? [] : [true]

    content {
      prefix = try(each.value.filter.prefix, null)
    }
  }
}

resource "aws_s3_bucket_analytics_configuration" "content" {
  for_each = { for k, v in var.analytics_configuration : k => v }

  bucket = aws_s3_bucket.content.id
  name   = each.key

  dynamic "filter" {
    for_each = length(try(flatten([each.value.filter]), [])) == 0 ? [] : [true]

    content {
      prefix = try(each.value.filter.prefix, null)
      tags   = try(each.value.filter.tags, null)
    }
  }

  dynamic "storage_class_analysis" {
    for_each = length(try(flatten([each.value.storage_class_analysis]), [])) == 0 ? [] : [true]

    content {

      data_export {
        output_schema_version = try(each.value.storage_class_analysis.output_schema_version, null)

        destination {

          s3_bucket_destination {
            bucket_arn        = try(each.value.storage_class_analysis.destination_bucket_arn, aws_s3_bucket.content.arn)
            bucket_account_id = try(each.value.storage_class_analysis.destination_account_id, data.aws_caller_identity.current.id)
            format            = try(each.value.storage_class_analysis.export_format, "CSV")
            prefix            = try(each.value.storage_class_analysis.export_prefix, null)
          }
        }
      }
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "this" {
  count = length(keys(var.replication_configuration)) > 0 ? 1 : 0

  bucket = aws_s3_bucket.content.id
  role   = var.replication_configuration["role"]

  dynamic "rule" {
    for_each = flatten(try([var.replication_configuration["rule"]], [var.replication_configuration["rules"]], []))

    content {
      id       = try(rule.value.id, null)
      priority = try(rule.value.priority, null)
      status   = try(tobool(rule.value.status) ? "Enabled" : "Disabled", title(lower(rule.value.status)), "Enabled")

      dynamic "delete_marker_replication" {
        for_each = flatten(try([rule.value.delete_marker_replication_status], [rule.value.delete_marker_replication], []))

        content {
          # Valid values: "Enabled" or "Disabled"
          status = try(tobool(delete_marker_replication.value) ? "Enabled" : "Disabled", title(lower(delete_marker_replication.value)))
        }
      }

      # Amazon S3 does not support this argument according to:
      # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration
      # More infor about what does Amazon S3 replicate?
      # https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-what-is-isnot-replicated.html
      dynamic "existing_object_replication" {
        for_each = flatten(try([rule.value.existing_object_replication_status], [rule.value.existing_object_replication], []))

        content {
          # Valid values: "Enabled" or "Disabled"
          status = try(tobool(existing_object_replication.value) ? "Enabled" : "Disabled", title(lower(existing_object_replication.value)))
        }
      }

      dynamic "destination" {
        for_each = try(flatten([rule.value.destination]), [])

        content {
          bucket        = destination.value.bucket
          storage_class = try(destination.value.storage_class, null)
          account       = try(destination.value.account_id, destination.value.account, null)

          dynamic "access_control_translation" {
            for_each = try(flatten([destination.value.access_control_translation]), [])

            content {
              owner = title(lower(access_control_translation.value.owner))
            }
          }

          dynamic "encryption_configuration" {
            for_each = flatten([try(destination.value.encryption_configuration.replica_kms_key_id, destination.value.replica_kms_key_id, [])])

            content {
              replica_kms_key_id = encryption_configuration.value
            }
          }

          dynamic "replication_time" {
            for_each = try(flatten([destination.value.replication_time]), [])

            content {
              # Valid values: "Enabled" or "Disabled"
              status = try(tobool(replication_time.value.status) ? "Enabled" : "Disabled", title(lower(replication_time.value.status)), "Disabled")

              dynamic "time" {
                for_each = try(flatten([replication_time.value.minutes]), [])

                content {
                  minutes = replication_time.value.minutes
                }
              }
            }

          }

          dynamic "metrics" {
            for_each = try(flatten([destination.value.metrics]), [])

            content {
              # Valid values: "Enabled" or "Disabled"
              status = try(tobool(metrics.value.status) ? "Enabled" : "Disabled", title(lower(metrics.value.status)), "Disabled")

              dynamic "event_threshold" {
                for_each = try(flatten([metrics.value.minutes]), [])

                content {
                  minutes = metrics.value.minutes
                }
              }
            }
          }
        }
      }

      dynamic "source_selection_criteria" {
        for_each = try(flatten([rule.value.source_selection_criteria]), [])

        content {
          dynamic "replica_modifications" {
            for_each = flatten([try(source_selection_criteria.value.replica_modifications.enabled, source_selection_criteria.value.replica_modifications.status, [])])

            content {
              # Valid values: "Enabled" or "Disabled"
              status = try(tobool(replica_modifications.value) ? "Enabled" : "Disabled", title(lower(replica_modifications.value)), "Disabled")
            }
          }

          dynamic "sse_kms_encrypted_objects" {
            for_each = flatten([try(source_selection_criteria.value.sse_kms_encrypted_objects.enabled, source_selection_criteria.value.sse_kms_encrypted_objects.status, [])])

            content {
              # Valid values: "Enabled" or "Disabled"
              status = try(tobool(sse_kms_encrypted_objects.value) ? "Enabled" : "Disabled", title(lower(sse_kms_encrypted_objects.value)), "Disabled")
            }
          }
        }
      }

      # Max 1 block - filter - without any key arguments or tags
      dynamic "filter" {
        for_each = length(try(flatten([rule.value.filter]), [])) == 0 ? [true] : []

        content {}
      }

      # Max 1 block - filter - with one key argument or a single tag
      dynamic "filter" {
        for_each = [for v in try(flatten([rule.value.filter]), []) : v if max(length(keys(v)), length(try(rule.value.filter.tags, rule.value.filter.tag, []))) == 1]

        content {
          prefix = try(filter.value.prefix, null)

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
        for_each = [for v in try(flatten([rule.value.filter]), []) : v if max(length(keys(v)), length(try(rule.value.filter.tags, rule.value.filter.tag, []))) > 1]

        content {
          and {
            prefix = try(filter.value.prefix, null)
            tags   = try(filter.value.tags, filter.value.tag, null)
          }
        }
      }
    }
  }

  # Must have bucket versioning enabled first
  depends_on = [
    aws_s3_bucket_versioning.content
  ]
}
