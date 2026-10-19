# ==============================================================================
# SCENARIO 7: ROLE CHAINING & ABAC 
# ==============================================================================

resource "aws_s3_bucket" "abac_bucket" {
  bucket        = "iam-abac-bucket-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_object" "abac_object_alpha" {
  bucket  = aws_s3_bucket.abac_bucket.id
  key     = "project-alpha-data.txt"
  content = "Sekretne dane Projektu Alpha"
  tags = {
    Project = "alpha" 
  }
}

resource "aws_s3_object" "abac_object_beta" {
  bucket  = aws_s3_bucket.abac_bucket.id
  key     = "project-beta-data.txt"
  tags = {
    Project = "beta"
  }
}

data "aws_iam_policy_document" "abac_role_a_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "abac_role_a" {
  name               = "scenario-7-role-a"
  assume_role_policy = data.aws_iam_policy_document.abac_role_a_trust.json
}

data "aws_iam_policy_document" "abac_role_a_policy" {
  statement {
    effect  = "Allow"
    actions   = ["sts:AssumeRole", "sts:TagSession"] 
    resources = [aws_iam_role.abac_role_b.arn]
  }
}

resource "aws_iam_role_policy" "abac_role_a_attach" {
  name   = "allow-assume-role-b-with-tags"
  role   = aws_iam_role.abac_role_a.id
  policy = data.aws_iam_policy_document.abac_role_a_policy.json
}

data "aws_iam_policy_document" "abac_role_b_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.abac_role_a.arn]
    }
  }
}

resource "aws_iam_role" "abac_role_b" {
  name               = "scenario-7-role-b"
  assume_role_policy = data.aws_iam_policy_document.abac_role_b_trust.json
}

data "aws_iam_policy_document" "abac_role_b_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.abac_bucket.arn}/*"]
    
    condition {
      test     = "StringEquals"
      variable = "s3:ExistingObjectTag/Project"
      values   = ["$${aws:PrincipalTag/Project}"]
    }
  }
}

resource "aws_iam_role_policy" "abac_role_b_attach" {
  name   = "abac-s3-access"
  role   = aws_iam_role.abac_role_b.id
  policy = data.aws_iam_policy_document.abac_role_b_policy.json
}