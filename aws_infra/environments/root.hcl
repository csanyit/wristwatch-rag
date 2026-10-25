locals {
  state_region = "eu-central-1"
  default_tags = {
    "project" = "wristwatch-rag"
  }
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "wristwatch-rag-terraform-state-${get_aws_account_id()}-${local.state_region}-an"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.state_region
    encrypt      = true
    use_lockfile = true
  }
}