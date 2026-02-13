resource "aws_cloudwatch_dashboard" "main" {
  provider       = aws.us_east_1
  dashboard_name = "StaticWebsite-Monitor-Part3"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", module.cloudfront.distribution_id, "Region", "Global"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Total Requests"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", module.cloudfront.distribution_id, "Region", "Global"],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", module.cloudfront.distribution_id, "Region", "Global"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Error Rates (4xx & 5xx)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", "cloudfront-rate-limit", "Region", "us-east-1", "Rule", "ALL"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "WAF Blocked Requests"
          period  = 300
        }
      }
    ]
  })
}