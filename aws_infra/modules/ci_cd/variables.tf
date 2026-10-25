# -------------------------------------------------------------------
# NAMING
# -------------------------------------------------------------------
variable "role_name" {
  type        = string
  description = "Name of the CI/CD IAM role."
  default     = "cicd-pipeline-role"
}

# -------------------------------------------------------------------
# GITHUB OIDC TRUST
# -------------------------------------------------------------------
variable "github_repo" {
  type        = string
  description = "GitHub repository name allowed to assume the CI/CD role. e.g: repo:owner/repository"
}

variable "create_github_oidc_provider" {
  type        = bool
  description = "Whether this module should create the account-level GitHub OIDC provider."
  default     = true
}

variable "github_oidc_provider_arn" {
  type        = string
  description = "ARN of an existing GitHub OIDC provider. Required when create_github_oidc_provider is false."
  default     = null

  validation {
    condition     = (var.create_github_oidc_provider && var.github_oidc_provider_arn == null) || (!var.create_github_oidc_provider && var.github_oidc_provider_arn != null)
    error_message = "Set github_oidc_provider_arn only when create_github_oidc_provider is false."
  }
}

# -------------------------------------------------------------------
# PERMISSIONS
# -------------------------------------------------------------------
variable "policy_statements" {
  description = "IAM permission statements granted to the CI/CD role. Supply one statement per actions/resources combination."
  type = list(object({
    sid       = optional(string)
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
  }))
  default = [
    {
      actions   = [
        "ec2:*",
        "ecs:*",
        "eks:*",
        "ecr:*",
        "s3:*",
        "rds:*",
        "dynamodb:*",
        "elasticache:*",
        "lambda:*",
        "apigateway:*",
        "states:*",
        "sqs:*",
        "sns:*",
        "events:*",
        "scheduler:*",
        "logs:*",
        "cloudwatch:*",
        "autoscaling:*",
        "application-autoscaling:*",
        "elasticloadbalancing:*",
        "cloudformation:*",
        "route53:*",
        "acm:*",
        "cloudfront:*",
        "kms:*",
        "secretsmanager:*",
        "ssm:*",
        "backup:*",
        "wafv2:*",
        "cloudtrail:*",
        "config:*",
        "codebuild:*",
        "codepipeline:*",
        "codeartifact:*",
        "glue:*",
        "athena:*",
        "iam:*"
      ]
      resources = ["*"]
    }
  ]

  validation {
    condition = length(var.allowed_statements) > 0 && alltrue([
      for statement in var.allowed_statements :
      contains(["Allow", "Deny"], statement.effect) &&
      length(statement.actions) > 0 &&
      length(statement.resources) > 0
    ])
    error_message = "Provide at least one statement; each statement must have an Allow or Deny effect and non-empty actions and resources."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the role and IAM policies."
  default     = {}
}
