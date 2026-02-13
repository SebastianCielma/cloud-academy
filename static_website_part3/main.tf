# main.tf

# 1. Moduł S3 (Teraz czysty, nie prosi już o cloudfront_arn)
module "s3" {
  source      = "./modules/s3"
  bucket_name = var.website_bucket_name
}

# 2. Moduł WAF (Bezpieczeństwo)
# ... (tu pewnie masz definicję WAF albo używasz pliku waf.tf - to jest OK)

# 3. Moduł CloudFront
module "cloudfront" {
  source             = "./modules/cloudfront"
  origin_domain_name = module.s3.bucket_domain_name
  origin_id          = module.s3.bucket_id
  
  # Zmienne z Part 3
  waf_arn                 = aws_wafv2_web_acl.main.arn
  logs_bucket_domain_name = module.s3.logs_bucket_domain_name

  tags = {
    project = "static-website"
  }
}

# 4. POLICY - Tu łączymy S3 i CloudFront (Rozwiązanie problemu pętli!)
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = module.s3.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${module.s3.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })
}