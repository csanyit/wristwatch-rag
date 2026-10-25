include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("region.hcl")
}

locals {
  config = read_terragrunt_config("${get_terragrunt_dir()}/config.hcl").locals
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//s3_vectors"
}

inputs = {
  name                              = local.config.name
  force_destroy                     = local.config.force_destroy
  encryption                        = local.config.encryption
  identity_based_policies_creatable = local.config.identity_based_policies_creatable
  bucket_policy                     = local.config.bucket_policy
  tags                              = local.config.tags
  indexes                           = local.config.indexes
}
