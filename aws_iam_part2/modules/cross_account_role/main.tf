resource "aws_iam_role" "this" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_role_arn
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_read_policy" {
  name = "CrossAccountS3ReadOnly"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = [
          var.allowed_s3_bucket_arn,
          "${var.allowed_s3_bucket_arn}/*"
        ]
      }
    ]
  })
}