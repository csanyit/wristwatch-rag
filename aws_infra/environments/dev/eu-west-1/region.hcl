locals {
  aws_region = basename(dirname(get_terragrunt_dir()))
  default_tags = read_terragrunt_config(
    find_in_parent_folders("root.hcl")
  ).locals.default_tags
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"

      default_tags {
        tags = ${jsonencode(local.default_tags)}
      }
    }
  EOF
}