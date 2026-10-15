data "aws_iam_policy_document" "scp_guardrails" {
  statement {
    sid    = "ProtectCloudTrailAndSecurityLogs"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
      "logs:DeleteLogGroup",
      "logs:DeleteLogStream",
      "logs:PutRetentionPolicy"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PreventLeavingOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }

  statement {
    sid    = "RegionRestrictionGuardrail"
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

resource "aws_organizations_policy" "security_guardrails" {
  count = var.enable_organizations_scp ? 1 : 0

  name        = "enterprise-security-guardrails-scp"
  description = "SCP blocking CloudTrail tampering, leaving Org, and unauthorized regions"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.scp_guardrails.json
}

resource "aws_organizations_policy_attachment" "security_guardrails_attachment" {
  count = var.enable_organizations_scp ? 1 : 0

  policy_id = aws_organizations_policy.security_guardrails[0].id
  target_id = var.organization_target_id
}