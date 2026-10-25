resource "aws_iam_policy" "read_only" {
  count = var.identity_based_policies_creatable ? 1 : 0

  name   = local.read_only_policy_name
  policy = data.aws_iam_policy_document.read_only.json
  tags   = var.tags
}

resource "aws_iam_policy" "read_write" {
  count = var.identity_based_policies_creatable ? 1 : 0

  name   = local.read_write_policy_name
  policy = data.aws_iam_policy_document.read_write.json
  tags   = var.tags
}
