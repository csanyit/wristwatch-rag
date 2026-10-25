include "root" {
  path   = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("region.hcl")
}

locals {
  config = read_terragrunt_config("${get_terragrunt_dir()}/config.hcl").locals
}

terraform {
  source = "${get_terragrunt_dir()}/../../../../modules//s3"
}

inputs = {
  name      = local.config.name
  namespace = local.config.namespace

  force_destroy      = local.config.force_destroy
  versioning_enabled = local.config.versioning_enabled

  sse_algorithm     = local.config.encryption.sse_algorithm
  kms_master_key_id = local.config.encryption.kms_master_key_id

  identity_based_policies_creatable = local.config.identity_based_policies_creatable

}
