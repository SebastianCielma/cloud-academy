# waf.tf

resource "aws_wafv2_web_acl" "main" {
  provider    = aws.us_east_1 # Używamy providera z USA
  name        = "cloudfront-rate-limit"
  description = "Rate limiting for CloudFront (100 req/min)"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Reguła: Blokuj powyżej 100 zapytań/min z jednego IP
  rule {
    name     = "RateLimit-100"
    priority = 1

    action {
      block {} # Zablokuj
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit100"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "MainWAF"
    sampled_requests_enabled   = true
  }
}