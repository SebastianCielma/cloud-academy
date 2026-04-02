# ------------------------------------------------------------------------
# AMAZON SNS
# ------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "SystemStressAlerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "sebastianakademiacloud@gmail.com" 
}

# ------------------------------------------------------------------------
#  IAM ROLE FOR LAMBDA
# ------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "alert-evaluator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "lambda-observability-permissions"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:DescribeInstances", "cloudwatch:DescribeAlarms", "cloudwatch:GetMetricData"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ------------------------------------------------------------------------
#  LAMBDA
# ------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/alert_handler.py"
  output_path = "${path.module}/lambda/alert_handler.zip"
}

resource "aws_lambda_function" "alert_evaluator" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "EvaluateSystemQuorum"
  role             = aws_iam_role.lambda_role.arn
  handler          = "alert_handler.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# ------------------------------------------------------------------------
#  EVENTBRIDGE RULE
# ------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "alarm_trigger" {
  name        = "CaptureCloudWatchAlarms"
  description = "Triggers Lambda when any alarm enters the ALARM state"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [{
        prefix = "StressAlarm-"
      }]
      state = {
        value = ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.alarm_trigger.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.alert_evaluator.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_evaluator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarm_trigger.arn
}