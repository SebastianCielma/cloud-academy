resource "aws_sns_topic" "alerts" {
  provider = aws.us_east_1
  name     = "static-website-alerts"
}

resource "aws_cloudwatch_metric_alarm" "high_5xx_errors" {
  provider            = aws.us_east_1
  alarm_name          = "High-5xx-Error-Rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Alarm when 5xx error rate exceeds 5%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = module.cloudfront.distribution_id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_waf_blocks" {
  provider            = aws.us_east_1
  alarm_name          = "High-WAF-Blocked-Requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000
  alarm_description   = "Alarm when WAF blocked requests exceed 1000 in 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = "cloudfront-rate-limit"
    Region = "us-east-1"
    Rule   = "ALL"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}