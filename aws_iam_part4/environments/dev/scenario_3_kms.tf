# ==============================================================================
# SCENARIO 3: KMS ENCRYPTED S3 OBJECT
# ==============================================================================

resource "aws_kms_key" "scenario_3_key" {
  description             = "Key for Scenario 3 KMS troubleshooting"
  deletion_window_in_days = 7
  enable_key_rotation     = false
}

resource "aws_s3_bucket" "scenario_3_kms_bucket" {
  bucket        = "iam-kms-troubleshoot-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "scenario_3_encryption" {
  bucket = aws_s3_bucket.scenario_3_kms_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.scenario_3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_object" "encrypted_secret" {
  bucket     = aws_s3_bucket.scenario_3_kms_bucket.id
  key        = "secure/kms-secret.json"
  content    = "{\"status\": \"You successfully decrypted the file\"}"
  kms_key_id = aws_kms_key.scenario_3_key.arn
}

data "aws_iam_policy_document" "scenario_3_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "scenario_3_role" {
  name               = "troubleshoot-role-scenario-3"
  assume_role_policy = data.aws_iam_policy_document.scenario_3_trust.json
}

data "aws_iam_policy_document" "scenario_3_identity_policy" {
  statement {
    sid       = "AllowS3GetObjectPerfectly"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.scenario_3_kms_bucket.arn}/*"]
  }
  
  statement {
    sid       = "AllowKMSDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.scenario_3_key.arn]
  }
}

resource "aws_iam_role_policy" "scenario_3_policy_attachment" {
  name   = "s3-only-no-kms-policy"
  role   = aws_iam_role.scenario_3_role.id
  policy = data.aws_iam_policy_document.scenario_3_identity_policy.json
}