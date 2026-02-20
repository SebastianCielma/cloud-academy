# -----------------------
# ECS Logs
# -----------------------
resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${var.name}-web"
  retention_in_days = 14
}

