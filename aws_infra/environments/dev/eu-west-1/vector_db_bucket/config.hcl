locals {
  environment = "dev"

  name = "watch-specification-vector-db-${local.environment}"

  force_destroy = false

  encryption = {
    sse_type    = "AES256"
    kms_key_arn = null
  }

  identity_based_policies_creatable = true
  bucket_policy                     = null
  tags                              = {}
  indexes                           = {
    "watch-rag-db" = {
      dimension                    = 384
      distance_metric              = "euclidean"
    }
  }
}
