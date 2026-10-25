variable "name" {
  type        = string
  description = "Name of the S3 Vectors bucket."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Whether to delete all indexes and vectors when destroying the bucket."
}

variable "encryption" {
  type = object({
    sse_type    = string
    kms_key_arn = optional(string)
  })
  description = "Encryption configuration for the S3 Vectors bucket."

  validation {
    condition = contains(["AES256", "aws:kms"], var.encryption.sse_type) && (
      var.encryption.sse_type == "aws:kms"
      ? can(regex("^arn:[^:]+:kms:", var.encryption.kms_key_arn))
      : var.encryption.kms_key_arn == null
    )
    error_message = "Encryption must use AES256 without a KMS key, or aws:kms with a KMS key ARN."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to the vector bucket and its indexes."
}

variable "bucket_policy" {
  type        = string
  default     = null
  description = "Optional JSON resource policy to attach to the vector bucket."

  validation {
    condition     = var.bucket_policy == null || can(jsondecode(var.bucket_policy))
    error_message = "bucket_policy must be valid JSON."
  }
}

variable "identity_based_policies_creatable" {
  type        = bool
  default     = false
  description = "Whether to create IAM policies for read-only and read-write vector access."
}

variable "indexes" {
  type = map(object({
    dimension                    = number
    distance_metric              = string
    data_type                    = optional(string, "float32")
    non_filterable_metadata_keys = optional(list(string), [])
    encryption = optional(object({
      sse_type    = optional(string, "AES256")
      kms_key_arn = optional(string)
    }))
    tags = optional(map(string), {})
  }))
  default     = {}
  description = "Vector indexes to create in this bucket. Index dimensions and configuration cannot be changed after creation."

  validation {
    condition = alltrue([
      for name, index in var.indexes :
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", name)) &&
      index.dimension >= 1 &&
      index.dimension <= 4096 &&
      index.dimension == floor(index.dimension) &&
      contains(["cosine", "euclidean"], index.distance_metric) &&
      index.data_type == "float32" &&
      length(index.non_filterable_metadata_keys) <= 10 &&
      length(distinct(index.non_filterable_metadata_keys)) == length(index.non_filterable_metadata_keys) &&
      alltrue([
        for key in index.non_filterable_metadata_keys :
        length(key) >= 1 && length(key) <= 63
      ])
    ])
    error_message = "Index names must be 3-63 lowercase letters, numbers, hyphens, or dots and start/end with a letter or number. Indexes require an integer dimension from 1 to 4096, a cosine or euclidean metric, float32 data, and at most 10 unique valid non-filterable metadata keys."
  }

  validation {
    condition = alltrue([
      for index in values(var.indexes) :
      index.encryption == null || (
        index.encryption.sse_type == "aws:kms"
        ? can(regex("^arn:[^:]+:kms:", index.encryption.kms_key_arn))
        : index.encryption.sse_type == "AES256" && index.encryption.kms_key_arn == null
      )
    ])
    error_message = "Index encryption must use AES256 without a KMS key, or aws:kms with a KMS key ARN."
  }
}
