locals {
  environment = "dev"

  name      = "wristwatch-rag-lambda-code-${local.environment}"
  namespace = "account-regional"

  force_destroy      = false
  versioning_enabled = true

  encryption = {
    sse_algorithm     = "AES256"
    kms_master_key_id = null
  }

  identity_based_policies_creatable = true
}
