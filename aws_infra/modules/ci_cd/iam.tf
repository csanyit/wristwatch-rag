locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.github_oidc_provider_arn
  policy_name              = "${var.role_name}-policy"
  permission_boundary_name = "${var.role_name}-permission-boundary"
  permissions_boundary_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/${local.permission_boundary_name}"
}

data "aws_iam_policy_document" "prod_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_repo]
    }
  }
}

data "aws_iam_policy_document" "cicd_pipeline_boundary" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  statement {
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:CreateServiceSpecificCredential",
      "iam:UpdateServiceSpecificCredential",
      "iam:ResetServiceSpecificCredential",
      "iam:UploadSSHPublicKey",
      "iam:UpdateSSHPublicKey",
      "iam:CreateAccessKey",
      "iam:AttachUserPolicy",
      "iam:AttachGroupPolicy",
      "iam:PutGroupPolicy",
      "iam:PutUserPolicy",
      "iam:DeleteRolePermissionsBoundary",
      "iam:UpdateAssumeRolePolicy",
      "iam:AddRoleToInstanceProfile"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion"
    ]
    resources = [local.permissions_boundary_arn]
  }
}

data "aws_iam_policy_document" "cicd_pipeline_policy" {
  dynamic "statement" {
    for_each = var.policy_statements
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "cicd_pipeline_boundary" {
  name        = local.permission_boundary_name
  description = "Permissions boundary for the CI/CD role."
  policy      = data.aws_iam_policy_document.cicd_pipeline_boundary.json
  tags        = var.tags
}

resource "aws_iam_policy" "cicd_pipeline" {
  name        = local.policy_name
  description = "Permissions granted to the CI/CD role."
  policy      = data.aws_iam_policy_document.cicd_pipeline_policy.json
  tags        = var.tags
}

resource "aws_iam_role" "cicd_pipeline" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.prod_trust.json
  permissions_boundary = aws_iam_policy.cicd_pipeline_boundary.arn
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "cicd_pipeline" {
  role       = aws_iam_role.cicd_pipeline.name
  policy_arn = aws_iam_policy.cicd_pipeline.arn
}