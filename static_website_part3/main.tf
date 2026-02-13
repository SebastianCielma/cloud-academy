module "s3" {
  source      = "./modules/s3"
  bucket_name = var.website_bucket_name
}

module "cloudfront" {
  source             = "./modules/cloudfront"
  origin_domain_name = module.s3.bucket_domain_name
  origin_id          = module.s3.bucket_id

  waf_arn                 = aws_wafv2_web_acl.main.arn
  logs_bucket_domain_name = module.s3.logs_bucket_domain_name

  tags = {
    project = "static-website"
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = module.s3.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })
}