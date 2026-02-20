# ------------------------------------------------------
# Application Auto Scaling target for ECS Service (web)
# ------------------------------------------------------
resource "aws_appautoscaling_target" "web" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.web.name}"
  min_capacity       = var.web_min_capacity
  max_capacity       = var.web_max_capacity
}

