# -------------------------------------------------------------------
# GENERAL
# -------------------------------------------------------------------
variable "tags" {
  type        = map(string)
  description = "Common tags for resources"
  default     = {}
}

# -------------------------------------------------------------------
# LAMBDA FUNCTION
# -------------------------------------------------------------------
variable "name" {
  type        = string
  description = "Lambda function's name"
  default     = null
}

variable "description" {
  type        = string
  description = "Description of what the Lambda Function does."
  default     = null
}

variable "artifact_config" {
  description = "Configuration object for lambda artifacts"
  type = object({
    architectures     = list(string) # ["x86_64"]
    handler           = string
    package_type      = optional(string, "Zip")
    runtime           = string
    s3_bucket         = string
    s3_key            = string
    s3_object_version = optional(string, null)
    layers            = list(string)
  })
}

variable "execution_config" {
  description = "Configuration object for the execution environment of the lambda function"
  type = object({
    ephemeral_storage_size         = optional(number, 512) # /tmp in MB
    memory_size                    = optional(number, 128) # memory in MB
    reserved_concurrent_executions = optional(number, -1)
    timeout                        = optional(number, 10) # sec
  })
}

variable "environment_variables" {
  description = "Map of environment variables that are accessible from the function code during execution"
  type        = map(string) # NOTE: Type is crucial here, otherwise defaults to 'string' and throws "type string, got map" error
  default     = {}
}

variable "tracing_config_mode" {
  type        = string
  description = "Tracing config mode of the Lambda function. Can be either PassThrough or Active."
  default     = null

  validation {
    condition     = (var.tracing_config_mode != null) ? contains(["PassThrough", "Active"], var.tracing_config_mode) : true
    error_message = "Tracing config mode must be either PassThrough or Active."
  }
}

variable "dead_letter_queue_enabled" {
  type        = bool
  description = "Enable Dead Letter Queue for the Lambda Function."
  default     = false
}

# -------------------------------------------------------------------
# LAMBDA FUNCTION [EVENT INVOKE]
# -------------------------------------------------------------------
variable "destination_config_enabled" {
  type        = bool
  description = "Enable Lambda Function Event Invoke Config"
  default     = false
}

variable "destination_config_on_success" {
  type        = string
  description = "Manages an asynchronous invocation configuration for a Lambda Function. ARN of the destination resource."
  default     = ""
}

variable "destination_config_on_failure" {
  type        = string
  description = "Manages an asynchronous invocation configuration for a Lambda Function. ARN of the destination resource invoked on failed asynchronous invocations. Left empty (default) to disable."
  default     = ""
}

variable "destination_maximum_event_age_in_seconds" {
  type        = number
  description = "Manages an asynchronous invocation configuration for a Lambda Function. Maximum age of a request that Lambda sends to a function for processing in seconds. Valid values between 60 and 21600."
  default     = 60
}

variable "destination_maximum_retry_attempts" {
  type        = number
  description = "Manages an asynchronous invocation configuration for a Lambda Function. Maximum number of times to retry when the function returns an error. Valid values between 0 and 2."
  default     = 2
}

# -------------------------------------------------------------------
# LAMBDA FUNCTION [ENCRYPTION]
# -------------------------------------------------------------------
variable "create_kms_key" {
  type        = bool
  description = "Create a module-owned KMS key. Set to false to use AWS-managed encryption, or provide kms_key_arn to use an external customer-managed key."
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of an external customer managed KMS key used by the Lambda function, CloudWatch log group, and optional dead-letter queue. When null, the module uses the default AWS keys."
  default     = null

  validation {
    condition = var.kms_key_arn == null || can(regex(
      "^(arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/.+|alias/[a-zA-Z0-9/_-]+)$",
      var.kms_key_arn
    ))
    error_message = "The kms_key_arn value must be null, a valid KMS key ARN, or a valid KMS alias name beginning with `alias/`."
  }

}

# -------------------------------------------------------------------
# LAMBDA FUNCTION [CLOUDWATCH]
# -------------------------------------------------------------------
variable "cloudwatch_lambda_insights_enabled" {
  type        = bool
  description = "Enable CloudWatch Lambda Insights for the Lambda Function."
  default     = false
}

variable "cloudwatch_log_group_retention_in_days" {
  type        = number
  default     = 7
  description = "Number of days to retain log events."
}

# -------------------------------------------------------------------
# LAMBDA FUNCTION [IAM]
# -------------------------------------------------------------------
variable "additional_policies" {
  type        = map(string)
  description = "Additional IAM policies. Key is a user-given name, Value is an IAM policy arn."
  default     = {}
}

variable "additional_inline_statements" {
  type = map(object({
    resources = list(string)
    actions   = list(string)
  }))
  description = "Additional statements for attached inline policy."
  default     = {}
}

# -------------------------------------------------------------------
# LAMBDA FUNCTION [NETWORKING]
# -------------------------------------------------------------------
variable "vpc_id" {
  type        = string
  description = "VPC ID for the Lambda Function. If null, the Lambda function will not be associated with a VPC."
  default     = null

  validation {
    condition     = var.vpc_subnet_ids == null || var.vpc_id != null
    error_message = "The vpc_id value must be provided when vpc_subnet_ids is not null."
  }
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "For network connectivity to AWS resources in a VPC, specify a list of  subnets in the VPC."
  default     = null
}

variable "vpc_security_group_egress" {
  type = map(object({
    cidr_ipv4   = string
    from_port   = string
    to_port     = string
    ip_protocol = string
    description = string
  }))
  description = "Security Group Egress rules."
  default = {
    allow_all = {
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = "-1"
      to_port     = "-1"
      ip_protocol = "-1"
      description = "Allow All Outbound"
    }
  }
}
