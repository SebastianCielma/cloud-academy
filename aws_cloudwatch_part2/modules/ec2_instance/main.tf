resource "aws_instance" "this" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  iam_instance_profile = var.iam_instance_profile

  tags = {
    Name      = var.instance_name
    Env       = var.env
    App       = var.app
    Role      = var.role
    AutoAlert = var.auto_alert
  }
}

# ------------------------------------------------------------------------
# ALARM - METRIC MATH
# ------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "system_stress" {
  alarm_name          = "StressAlarm-${var.instance_name}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 3
  alarm_description   = "Stress alarm ${var.instance_name}: min. 3 of 4"

  metric_query {
    id          = "e1"
    expression  = "IF(m1 > 80, 1, 0) + IF(m2 > 20, 1, 0) + IF(m3 > 85, 1, 0) + IF(m4 > 500000000, 1, 0)"
    label       = "StressAlarm"
    return_data = true 
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      period      = 60
      stat        = "Average"
      dimensions = {
        InstanceId = aws_instance.this.id
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "cpu_usage_iowait"
      namespace   = "CWAgent"
      period      = 60
      stat        = "Average"
      dimensions = {
        InstanceId = aws_instance.this.id
      }
    }
  }

  metric_query {
    id = "m3"
    metric {
      metric_name = "disk_used_percent"
      namespace   = "CWAgent"
      period      = 60
      stat        = "Average"
      dimensions = {
        InstanceId = aws_instance.this.id
        path       = "/"
      }
    }
  }

  metric_query {
    id = "m4"
    metric {
      metric_name = "net_bytes_sent"
      namespace   = "CWAgent"
      period      = 60
      stat        = "Average"
      dimensions = {
        InstanceId = aws_instance.this.id
        interface  = "eth0"
      }
    }
  }
}