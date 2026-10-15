data "aws_iam_policy_document" "developer_boundary" {
  statement {
    sid    = "AllowMaxS3CloudWatchSQS"
    effect = "Allow"
    actions = [
      "s3:*",
      "cloudwatch:*",
      "logs:*",
      "sqs:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ExplicitDenyAdminServices"
    effect = "Deny"
    actions = [
      "iam:*",
      "organizations:*",
      "kms:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RegionRestrictionWithGlobalExceptions"
    effect = "Deny"
    not_actions = [
      "iam:*",
      "organizations:*",
      "sts:*",
      "cloudfront:*",
      "route53:*",
      "support:*",
      "budgets:*",
      "waf:*"
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }
}

resource "aws_iam_policy" "developer_boundary" {
  name        = "developer-boundary"
  description = "Guardrail boundary allowing max S3, CW, SQS in EU regions and explicitly denying IAM, Orgs, KMS"
  policy      = data.aws_iam_policy_document.developer_boundary.json
}


data "aws_iam_policy_document" "wildcard_admin" {
  statement {
    sid       = "DeveloperAssignsFullAdmin"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
}

module "overprivileged_developer_role" {
  source = "../../modules/bounded_role"

  role_name             = "dev-wildcard-role"
  trusted_principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  boundary_policy_arn   = aws_iam_policy.developer_boundary.arn
  identity_policy_json  = data.aws_iam_policy_document.wildcard_admin.json
}


data "aws_iam_policy_document" "s3_only" {
  statement {
    sid       = "AllowOnlyS3"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
  }
}

module "underprivileged_developer_role" {
  source = "../../modules/bounded_role"

  role_name             = "dev-s3-only-role"
  trusted_principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  boundary_policy_arn   = aws_iam_policy.developer_boundary.arn
  identity_policy_json  = data.aws_iam_policy_document.s3_only.json
}

data "aws_iam_policy_document" "enforced_role_creation" {
  statement {
    sid    = "AllowCreateRoleOnlyWithBoundary"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePermissionsBoundary"
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/app-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.developer_boundary.arn]
    }
  }

  statement {
    sid    = "DenyBoundaryTampering"
    effect = "Deny"
    actions = [
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:DeleteRolePermissionsBoundary"
    ]
    resources = [
      aws_iam_policy.developer_boundary.arn,
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/app-*"
    ]
  }
}

resource "aws_iam_policy" "developer_delegation_guardrail" {
  name        = "developer-iam-delegation-guardrail"
  description = "Allows developers to create app-* roles ONLY if developer-boundary is attached"
  policy      = data.aws_iam_policy_document.enforced_role_creation.json
}