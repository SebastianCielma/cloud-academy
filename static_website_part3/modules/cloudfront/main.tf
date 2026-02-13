# modules/cloudfront/main.tf

resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name              = var.origin_domain_name
    origin_id                = var.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  
  # --- 1. WAF (Bezpieczeństwo) ---
  web_acl_id = var.waf_arn

  # --- 2. LOGGING (Monitoring) ---
  logging_config {
    include_cookies = false
    bucket          = var.logs_bucket_domain_name # Logi lecą do bucketa z kroku 2
    prefix          = "cf-logs/"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.origin_id

    # --- 3. HTTPS ENFORCEMENT (Bezpieczeństwo) ---
    viewer_protocol_policy = "redirect-to-https" # Wymuszamy HTTPS (301)

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # --- 4. CUSTOM ERROR PAGES (User Experience) ---
  # Obsługa błędu 403 (np. WAF block)
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/error.html" # Musimy wgrać ten plik do S3!
    error_caching_min_ttl = 10
  }

  # Obsługa błędu 404 (Not Found)
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  price_class = "PriceClass_100" # Najtańsza opcja (USA/Europa)

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = var.tags
}

# (Zasób OAC zostaje bez zmian)
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.origin_id}-oac"
  description                       = "Managed by Terraform"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}