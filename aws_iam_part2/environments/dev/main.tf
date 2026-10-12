# ====================================
# ACCOUNT A
# ====================================
resource "aws_iam_role" "app_role_a" {
  name = "app-role-a"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
    }]
  })
}

resource "aws_iam_role_policy" "app_role_assume_policy" {
  name = "AssumeRoleAccountB"
  role = aws_iam_role.app_role_a.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "sts:AssumeRole"
      Effect   = "Allow"
      Resource = module.shared_data_role.role_arn
    }]
  })
}

# ======================================
# ACCOUNT B
# ======================================
module "shared_data_role" {
  source = "../../modules/cross_account_role"

  role_name             = "shared-data-reader-role-b"
  trusted_role_arn      = aws_iam_role.app_role_a.arn  
  allowed_s3_bucket_arn = aws_s3_bucket.shared_data.arn
}