remote_state {
  backend = "s3"
  config = {
    bucket       = "wristwatch-rag-terraform-state-${get_aws_account_id()}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
