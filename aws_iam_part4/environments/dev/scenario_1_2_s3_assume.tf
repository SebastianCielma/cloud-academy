# ==============================================================================
# SCENARIO 1 & 2: BROKEN ASSUME ROLE & BROKEN S3 ACCESS
# ==============================================================================

resource "aws_s3_bucket" "scenario_1_2_bucket" {
  bucket        = "iam-troubleshoot-bucket-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "scenario_1_2_bucket_pab" {
  bucket                  = aws_s3_bucket.scenario_1_2_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "secret_document" {
  bucket  = aws_s3_bucket.scenario_1_2_bucket.id
  key     = "data/secret.txt"
}

data "aws_iam_policy_document" "broken_trust_policy" {
  statement {
    sid     = "AllowAssumeRoleButBroken"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["HiddenSecretId123"]
    }
  }
}

resource "aws_iam_role" "scenario_1_2_role" {
  name               = "troubleshoot-role-scenario-1-2"
  assume_role_policy = data.aws_iam_policy_document.broken_trust_policy.json
}

data "aws_iam_policy_document" "broken_s3_policy" {
  statement {
    sid       = "AllowS3ReadBrokenARN"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.scenario_1_2_bucket.arn}/*"] 
  }
}

resource "aws_iam_role_policy" "scenario_1_2_role_policy" {
  name   = "broken-s3-access-policy"
  role   = aws_iam_role.scenario_1_2_role.id
  policy = data.aws_iam_policy_document.broken_s3_policy.json
}