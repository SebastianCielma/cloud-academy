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
}