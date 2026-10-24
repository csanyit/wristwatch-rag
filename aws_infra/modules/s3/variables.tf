# -------------------------------------------------------------------
# BUCKET
# -------------------------------------------------------------------
variable "name" {
  type        = string
  description = "Base name of the bucket. Also used to derive the access log bucket and IAM policy names."
}

variable "namespace" {
  type        = string
  default     = "global"
  description = "Forces new resource. Namespace for bucket naming scope. Valid values: `account-regional`, `global`. Defaults to `global`."

  validation {
    condition     = contains(["account-regional", "global"], var.namespace)
    error_message = "Valid values for `namespace` are `account-regional` and `global`."
  }
}

variable "use_prefix" {
  type        = bool
  default     = false
  description = "Whether to use the `bucket_prefix` for the bucket name. If true, the bucket name will be suffixed automatically by AWS to ensure uniqueness."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "A boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable."
}

variable "versioning_enabled" {
  type        = bool
  default     = true
  description = "Sets versioning status to Enabled or Suspended."
}

variable "versioning_force_disabled" {
  type        = bool
  default     = false
  description = <<-EOT
    Only has effects when `versioning_enabled = false`. Disabled status should only be used when creating or
    importing resources that correspond to unversioned S3 buckets.

    WARNING: While the versioning_configuration.status parameter supports Disabled,
             this value is only intended for creating or importing resources that correspond to unversioned S3 buckets.
             Updating the value from Enabled or Suspended to Disabled will result in errors as the
             AWS S3 API does not support returning buckets to an unversioned state.
  EOT
}

variable "versioning_mfa_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether MFA delete is enabled in the bucket versioning configuration. Valid values: Enabled or Disabled."
}

variable "versioning_mfa_id" {
  type        = string
  default     = null
  description = "Concatenation of the authentication device's serial number, a space, and the value that is displayed on your authentication device."
}

variable "transfer_acceleration" {
  description = "(Optional) Sets the accelerate configuration of an existing bucket. Can be Enabled or Suspended."
  type        = string
  default     = null

  validation {
    condition     = var.transfer_acceleration == null || var.transfer_acceleration == "Enabled" || var.transfer_acceleration == "Suspended"
    error_message = "The valid values are `Enabled` and `Suspended`."
  }
}

variable "request_payer" {
  description = "(Optional) Specifies who should bear the cost of Amazon S3 data transfer. Can be either BucketOwner or Requester. By default, the owner of the S3 bucket would incur the costs of any data transfer. See Requester Pays Buckets developer guide for more information."
  type        = string
  default     = null

  validation {
    condition     = var.request_payer == null || var.request_payer == "BucketOwner" || var.request_payer == "Requester"
    error_message = "The valid values are `BucketOwner` and `Requester`."
  }
}

variable "tags" {
  description = "Additional bucket tags."
  type        = map(string)
  default     = {}
}


# -------------------------------------------------------------------
# METADATA
# -------------------------------------------------------------------
variable "metadata_configuration_creatable" {
  description = "Whether to create metadata configuration resource"
  type        = bool
  default     = false
}

variable "metadata_inventory_table_configuration_state" {
  description = "Configuration state of the inventory table, indicating whether the inventory table is enabled or disabled. Valid values: ENABLED, DISABLED"
  type        = string
  default     = null
}

variable "metadata_encryption_configuration" {
  description = "Encryption configuration block"
  type        = any
  default     = null
}

variable "metadata_journal_table_record_expiration_days" {
  description = "Number of days to retain journal table records"
  type        = number
  default     = null
}

variable "metadata_journal_table_record_expiration" {
  description = "Whether journal table record expiration is enabled or disabled. Valid values: ENABLED, DISABLED"
  type        = string
  default     = null
}

# -------------------------------------------------------------------
# ENCRYPTION
# -------------------------------------------------------------------
variable "sse_bucket_key_enabled" {
  description = <<-EOT
    Whether or not to use Amazon S3 Bucket Keys for this bucket.
    When using KMS keys, this can reduce the cost of encryption by decreasing the request traffic from Amazon S3 to KMS, if set to 'true'.
  EOT
  type        = bool
  default     = true
}

variable "sse_blocked_encryption_types" {
  type        = list(string)
  default     = ["NONE"]
  description = <<-EOT
    (Optional) List of server-side encryption types to block for object uploads.
    Valid values are `SSE-C` (blocks uploads using server-side encryption with customer-provided keys) and `NONE` (unblocks all encryption types).
    Starting in March 2026, Amazon S3 will automatically block `SSE-C` uploads for all new buckets.
  EOT

  validation {
    condition = alltrue([
      for encryption_type in var.sse_blocked_encryption_types : contains(["SSE-C", "NONE"], encryption_type)
    ])
    error_message = "Valid values are `SSE-C` and `NONE`."
  }
}

variable "sse_algorithm" {
  type        = string
  description = "The algorithm which will be used for the encryption of the bucket."

  validation {
    condition     = var.sse_algorithm == "AES256" || var.sse_algorithm == "aws:kms"
    error_message = "The valid values are AES256 and aws:kms."
  }
}

variable "kms_master_key_id" {
  type        = string
  default     = null
  description = <<-EOT
    The AWS KMS master key ID used for the SSE-KMS encryption.
    This can only be used when you set the value of sse_algorithm as aws:kms.
    The default aws/s3 AWS KMS master key is used if this element is absent while the sse_algorithm is aws:kms.
EOT
}

# -------------------------------------------------------------------
# PERMISSIONS
# -------------------------------------------------------------------
variable "object_ownership" {
  type        = string
  default     = "BucketOwnerEnforced"
  description = <<-EOT
    ACLs disabled
      Bucket owner enforced (default) - ACLs are disabled, and the bucket owner automatically owns and has full control over every object in the bucket. ACLs no longer affect permissions to data in the S3 bucket.
    ACLs enabled
      Bucket owner preferred - The bucket owner owns and has full control over new objects that other accounts write to the bucket with the bucket-owner-full-control canned ACL.
      Object writer - The AWS account that uploads an object owns the object, has full control over it, and can grant other users access to it through ACLs.
  EOT

  validation {
    condition     = var.object_ownership == "BucketOwnerPreferred" || var.object_ownership == "ObjectWriter" || var.object_ownership == "BucketOwnerEnforced"
    error_message = "The valid values are: BucketOwnerPreferred or ObjectWriter or BucketOwnerEnforced"
  }
}

variable "object_lock_configuration" {
  type = object({
    enabled = bool
    mode    = string
    years   = optional(number)
    days    = optional(number)
  })
  description = <<-EOT
    Configuration block for object locking.
    If enabled only years or days can be passed, not both at the same time, one of them must be null.
    Mode can be GOVERNANCE or COMPLIANCE.
    COMPLIANCE objects can not be deleted anyway (bar account delete) until the days or years are passed.
  EOT

  default = {
    enabled = false
    mode    = null
    years   = null
    days    = null
  }

  validation {
    condition = (
      (var.object_lock_configuration.years != null && var.object_lock_configuration.days == null) ||
      (var.object_lock_configuration.years == null && var.object_lock_configuration.days != null) ||
      !var.object_lock_configuration.enabled
    )
    error_message = "If object locking is enabled then either years or days must be provided but not both."
  }

  validation {
    condition = (
      var.object_lock_configuration.mode == "GOVERNANCE" ||
      var.object_lock_configuration.mode == "COMPLIANCE" ||
      !var.object_lock_configuration.enabled
    )
    error_message = "If object locking is enabled then mode must be either COMPLIANCE or GOVERNANCE."
  }
}

variable "acl" {
  description = <<-EOT
    (Optional) The Canned ACL to apply. Conflicts with `grant`.

               Valid values are: private, public-read, public-read-write, aws-exec-read,
                                 authenticated-read, bucket-owner-read, bucket-owner-full-control, log-delivery-write.

    NOTIFICATION: ACL are depracted and going forward they are disabled by default,
                  so set this to true only on old buckets!
  EOT
  type        = string
  default     = null

  validation {
    condition = anytrue([
      var.acl == "private",
      var.acl == "public-read",
      var.acl == "public-read-write",
      var.acl == "aws-exec-read",
      var.acl == "authenticated-read",
      var.acl == "bucket-owner-read",
      var.acl == "bucket-owner-full-control",
      var.acl == "log-delivery-write",
      var.acl == null
    ])
    error_message = "The valid values are: log-delivery-write or public-read or private"
  }
}

variable "acl_grant" {
  description = "List of ACL policy grants. Used to define custom access control policies."
  type = list(object({
    permission = string
    type       = string
    id         = optional(string)
    uri        = optional(string)
    email      = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for grant in var.acl_grant : anytrue([
        grant.permission == "FULL_CONTROL",
        grant.permission == "WRITE",
        grant.permission == "WRITE_ACP",
        grant.permission == "READ",
        grant.permission == "READ_ACP"
      ])
    ])
    error_message = "Grant permission must be one of: FULL_CONTROL, WRITE, WRITE_ACP, READ, or READ_ACP."
  }

  validation {
    condition = alltrue([
      for grant in var.acl_grant : anytrue([
        grant.type == "CanonicalUser",
        grant.type == "AmazonCustomerByEmail",
        grant.type == "Group"
      ])
    ])
    error_message = "Grantee type must be one of: CanonicalUser, AmazonCustomerByEmail, or Group."
  }
}

variable "acl_owner" {
  description = "Bucket owner's canonical ID and optional display name. Used with access control policy grants."
  type = object({
    id           = string
    display_name = optional(string)
  })
  default = null

  validation {
    condition = var.acl_owner == null || (
      var.acl_owner.id != null &&
      var.acl_owner.id != ""
    )
    error_message = "When acl_owner is provided, the 'id' field is required and must not be empty."
  }
}

variable "cors_rule_configuration" {
  description = "List of maps containing rules for Cross-Origin Resource Sharing (CORS)."
  type = list(object({
    id              = optional(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    allowed_headers = optional(list(string))
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.cors_rule_configuration : (
        can(rule.allowed_methods) && length(rule.allowed_methods) > 0 &&
        can(rule.allowed_origins) && length(rule.allowed_origins) > 0
      )
    ])
    error_message = "Each CORS rule must have non-empty 'allowed_methods' and 'allowed_origins'."
  }
}

variable "identity_based_policies_creatable" {
  type        = bool
  description = "A boolean that indicates a named read-only and a read-write iam policy will be created."
  default     = false
}

# -------------------------------------------------------------------
# INVENTORY / ANALYTICS / METRICS
# -------------------------------------------------------------------

# Inventory

variable "inventory_configuration" {
  description = "Map containing S3 inventory configuration."
  type        = any
  default     = {}
}

variable "inventory_source_account_id" {
  description = "The inventory source account id."
  type        = string
  default     = null
}

variable "inventory_source_bucket_arn" {
  description = "The inventory source bucket ARN."
  type        = string
  default     = null
}

variable "inventory_self_source_destination" {
  description = "Whether or not the inventory source bucket is also the destination bucket."
  type        = bool
  default     = false
}

# Analytics

variable "analytics_configuration" {
  description = "Map containing bucket analytics configuration."
  type        = any
  default     = {}
}

variable "analytics_source_account_id" {
  description = "The analytics source account id."
  type        = string
  default     = null
}

variable "analytics_source_bucket_arn" {
  description = "The analytics source bucket ARN."
  type        = string
  default     = null
}

variable "analytics_self_source_destination" {
  description = "Whether or not the analytics source bucket is also the destination bucket."
  type        = bool
  default     = false
}

# Metrics

variable "metric_configuration" {
  description = "Map containing bucket metric configuration."
  type        = any
  default     = []
}

# -------------------------------------------------------------------
# MANAGEMENT
# -------------------------------------------------------------------
variable "intelligent_tiering_configuration" {
  description = "Map of intelligent tiering configurations. Key is the configuration name/identifier."
  type = map(object({
    status = optional(string, "Enabled")
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
    tiering = map(object({
      days = number
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for config in var.intelligent_tiering_configuration : (
        try(config.status, "Enabled") == "Enabled" ||
        try(config.status, "Enabled") == "Suspended" ||
        try(tobool(config.status), false) != null
      )
    ])
    error_message = "Status must be 'Enabled', 'Suspended', or a valid boolean value."
  }

  validation {
    condition = alltrue([
      for config in var.intelligent_tiering_configuration : (
        length(try(config.tiering, {})) > 0
      )
    ])
    error_message = "Each intelligent tiering configuration must have at least one tiering definition."
  }

  validation {
    condition = alltrue([
      for config in var.intelligent_tiering_configuration : alltrue([
        for tier_name, tier in try(config.tiering, {}) : (
          anytrue([
            tier_name == "ARCHIVE_ACCESS",
            tier_name == "DEEP_ARCHIVE_ACCESS",
            tier_name == "FREQUENT_ACCESS",
            tier_name == "INFREQUENT_ACCESS"
          ])
        )
      ])
    ])
    error_message = "Tiering access tier must be one of: ARCHIVE_ACCESS, DEEP_ARCHIVE_ACCESS, FREQUENT_ACCESS, or INFREQUENT_ACCESS."
  }

  validation {
    condition = alltrue([
      for config in var.intelligent_tiering_configuration : alltrue([
        for tier_name, tier in try(config.tiering, {}) : (
          tier.days > 0
        )
      ])
    ])
    error_message = "Days for each tiering tier must be greater than 0."
  }
}

variable "replication_configuration" {
  description = "Map containing cross-region replication configuration."
  type        = any
  default     = {}
}

variable "lifecycle_rule_configuration" {
  description = "Map of lifecycle rules for S3 bucket object lifecycle management. Key is the rule name/identifier."
  type = map(object({
    enabled                                = optional(bool, true)
    id                                     = optional(string)
    status                                 = optional(string)
    abort_incomplete_multipart_upload_days = optional(number, 7)

    # Expiration configuration
    expiration = optional(object({
      date                         = optional(string)
      days                         = optional(number)
      expired_object_delete_marker = optional(bool)
    }))

    # Transition configuration (multiple storage class transitions)
    transition = optional(list(object({
      date          = optional(string)
      days          = optional(number)
      storage_class = string
    })))

    # Noncurrent version expiration
    noncurrent_version_expiration = optional(object({
      newer_noncurrent_versions = optional(number)
      days                      = optional(number)
      noncurrent_days           = optional(number)
    }))

    # Noncurrent version transitions (multiple storage class transitions)
    noncurrent_version_transition = optional(list(object({
      newer_noncurrent_versions = optional(number)
      days                      = optional(number)
      noncurrent_days           = optional(number)
      storage_class             = string
    })))

    # Filter configuration
    filter = optional(object({
      prefix                   = optional(string)
      object_size_greater_than = optional(number)
      object_size_less_than    = optional(number)
      tags                     = optional(map(string))
      tag = optional(list(object({
        key   = string
        value = string
      })))
    }))
  }))
  default = {
    "default" = {
      id                                     = "auto-archive"
      abort_incomplete_multipart_upload_days = 7
    }
  }
}

variable "lifecycle_rule_transition_default_minimum_object_size" {
  description = "The default minimum object size behavior applied to the lifecycle configuration. Valid values: all_storage_classes_128K (default), varies_by_storage_class"
  type        = string
  default     = null

  validation {
    condition = var.lifecycle_rule_transition_default_minimum_object_size == null || (
      var.lifecycle_rule_transition_default_minimum_object_size == "all_storage_classes_128K" ||
      var.lifecycle_rule_transition_default_minimum_object_size == "varies_by_storage_class"
    )
    error_message = "Valid values are 'all_storage_classes_128K' or 'varies_by_storage_class'."
  }
}

# -------------------------------------------------------------------
# POLICIES [PERMISSIONS - CONTENT]
# -------------------------------------------------------------------

# Conditions

variable "attach_policy" {
  description = "Controls if S3 bucket should have bucket policy attached (set to `true` to use value of `policy` as bucket policy)"
  type        = bool
  default     = true
}

variable "attach_deny_insecure_transport_policy" {
  description = "Controls if S3 bucket should have deny non-SSL transport policy attached"
  type        = bool
  default     = true
}

variable "attach_require_latest_tls_policy" {
  description = "Controls if S3 bucket should require the latest version of TLS"
  type        = bool
  default     = false
}

variable "attach_deny_incorrect_encryption_headers" {
  description = "Controls if S3 bucket should deny incorrect encryption headers policy attached."
  type        = bool
  default     = false
}

variable "attach_deny_incorrect_kms_key_sse" {
  description = "Controls if S3 bucket policy should deny usage of incorrect KMS key SSE."
  type        = bool
  default     = false
}

variable "attach_deny_unencrypted_object_uploads" {
  description = "Controls if S3 bucket should deny unencrypted object uploads policy attached."
  type        = bool
  default     = false
}

variable "attach_deny_ssec_encrypted_object_uploads" {
  description = "Controls if S3 bucket should deny SSEC encrypted object uploads."
  type        = bool
  default     = false
}

variable "attach_cloudfront_distribution_policy" {
  description = "Controls if S3 bucket should allow CloudFront distributions to read objects."
  type        = bool
  default     = false
}

variable "organization_ids" {
  description = "Account IDs in the organization (if any)"
  type        = list(number)
  default     = []
}

variable "attach_deny_presigned_url_request_older_than" {
  description = "Controls if S3 bucket should deny presigned URL requests older than a specified age."
  type        = bool
  default     = false
}

# Configurations

variable "presigned_url_max_age" {
  description = "The maximum age (in seconds) for presigned URL requests. Default is 10 minutes (600 seconds)."
  type        = number
  default     = 600
}

variable "policy" {
  description = "(Optional) A valid bucket policy JSON document. Note that if the policy document is not specific enough (but still valid), Terraform may view the policy as constantly changing in a terraform plan. In this case, please make sure you use the verbose/specific version of the policy. For more information about building AWS IAM policy documents with Terraform, see the AWS IAM Policy Document Guide."
  type        = string
  default     = null
}

variable "block_public_access_skip_destroy" {
  description = "Whether to skip destroying the S3 Bucket Public Access Block configuration when destroying the bucket."
  type        = bool
  default     = false
}

variable "block_public_access_public_acls" {
  description = "Whether Amazon S3 should block public ACLs for this bucket."
  type        = bool
  default     = true
}

variable "block_public_access_public_policy" {
  description = "Whether Amazon S3 should block public bucket policies for this bucket."
  type        = bool
  default     = true
}

variable "block_public_access_ignore_public_acls" {
  description = "Whether Amazon S3 should ignore public ACLs for this bucket."
  type        = bool
  default     = true
}

variable "block_public_access_restrict_public_buckets" {
  description = "Whether Amazon S3 should restrict public bucket policies for this bucket."
  type        = bool
  default     = true
}

# -------------------------------------------------------------------
# POLICIES [SERVICE LOG DELIVERY]
# -------------------------------------------------------------------

# Conditions

variable "attach_elb_log_delivery_policy" {
  description = "Controls if S3 bucket should have ELB log delivery policy attached"
  type        = bool
  default     = false
}

variable "attach_lb_log_delivery_policy" {
  description = "Controls if S3 bucket should have ALB/NLB log delivery policy attached"
  type        = bool
  default     = false
}

variable "attach_cloudtrail_log_delivery_policy" {
  description = "Controls if S3 bucket should have CloudTrail log delivery policy attached"
  type        = bool
  default     = false
}

variable "attach_waf_log_delivery_policy" {
  description = "Controls if S3 bucket should have WAF log delivery policy attached"
  type        = bool
  default     = false
}

variable "attach_policies_for_presigned_url" {
  description = "Controls if S3 bucket should have policies for presigned URLs attached"
  type        = bool
  default     = false
}

# Configurations

variable "presigned_url_principal_arns" {
  description = "(Optional) List of IAM principal ARNs that should be allowed to generate presigned URLs for this bucket."
  type        = list(string)
  default     = []
}

variable "cloudtrail_log_delivery_policy_key_prefix" {
  description = "(Optional) S3 key prefix that follows the name of the bucket you have designated for log file delivery."
  type        = string
  default     = null
}

variable "cloudtrail_log_delivery_policy_source_organizations" {
  description = "(Optional) List of AWS Organization IDs should be allowed to deliver CloudTrail logs to this bucket."
  type        = list(string)
  default     = []
}

variable "lb_log_delivery_policy_source_organizations" {
  description = "(Optional) List of AWS Organization IDs should be allowed to deliver ALB/NLB logs to this bucket."
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------
# POLICIES [INVENTORY / ANALYTICS / METRICS]
# -------------------------------------------------------------------
variable "attach_inventory_destination_policy" {
  description = "Controls if S3 bucket should have bucket inventory destination policy attached."
  type        = bool
  default     = false
}

variable "attach_analytics_destination_policy" {
  description = "Controls if S3 bucket should have bucket analytics destination policy attached."
  type        = bool
  default     = false
}

# -------------------------------------------------------------------
# FILE SYSTEMS
# -------------------------------------------------------------------
variable "file_system_compatible" {
  description = "Controls if S3 bucket should be compatible with S3 File Systems."
  type        = bool
  default     = false
}
