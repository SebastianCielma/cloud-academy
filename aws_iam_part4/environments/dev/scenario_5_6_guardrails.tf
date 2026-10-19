# ==============================================================================
# SCENARIO 5 & 6: GUARDRAILS (PERMISSION BOUNDARY & SCP)
# ==============================================================================

data "aws_iam_policy_document" "assume_role_root" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

data "aws_iam_policy_document" "scenario_5_boundary" {
  statement {
    sid       = "AllowEverything"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
  
  statement {
    sid       = "DenyIAMUserCreation"
    effect    = "Deny"
    actions   = ["iam:CreateUser"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "scenario_5_boundary_policy" {
  name        = "scenario-5-permission-boundary"
  description = "Boundary that allows everything EXCEPT creating IAM users"
  policy      = data.aws_iam_policy_document.scenario_5_boundary.json
}

resource "aws_iam_role" "scenario_5_role" {
  name                 = "scenario-5-developer-role"
  assume_role_policy   = data.aws_iam_policy_document.assume_role_root.json
  permissions_boundary = aws_iam_policy.scenario_5_boundary_policy.arn
}

resource "aws_iam_role_policy_attachment" "scenario_5_admin_attach" {
  role       = aws_iam_role.scenario_5_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_iam_policy_document" "scenario_6_scp" {
  statement {
    sid       = "PreventCloudTrailTampering"
    effect    = "Deny"
    actions   = ["cloudtrail:StopLogging"]
    resources = ["*"]
  }
}