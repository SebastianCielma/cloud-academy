data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "shared_data" {
  bucket = "shared-data-b-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_object" "public_file" {
  bucket  = aws_s3_bucket.shared_data.id
  key     = "public/data.json"
  content = jsonencode({ message = "This is a public file in Account B" })
}

resource "aws_s3_object" "private_file" {
  bucket  = aws_s3_bucket.shared_data.id
  key     = "private/secret.json"
  content = jsonencode({ message = "TOP SECRET - Should be blocked by Explicit Deny" })
}

resource "aws_s3_bucket_policy" "shared_data_policy" {
  bucket = aws_s3_bucket.shared_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ExplicitDenyPrivatePrefix"
        Effect    = "Deny"
        Principal = {
          AWS = module.shared_data_role.role_arn
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.shared_data.arn}/private/*"
      },
      {
        Sid       = "RequireVPCEndpoint"
        Effect    = "Deny"
        Principal = {
          AWS = module.shared_data_role.role_arn
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.shared_data.arn}/*"
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = "vpce-12345678"
          }
        }
      }
    ]
  })
}