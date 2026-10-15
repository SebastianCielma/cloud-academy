data "aws_iam_policy_document" "trust_policy" {
  statement {
    sid     = "AllowAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.trusted_principal_arn]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  permissions_boundary = var.boundary_policy_arn
  assume_role_policy   = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy" "identity_permissions" {
  name   = "${var.role_name}-identity-policy"
  role   = aws_iam_role.this.id
  policy = var.identity_policy_json
}