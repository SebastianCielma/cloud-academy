# ------------
# ECS Cluster
# ------------
resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# -----------------
# TASK DEFINITION
# -----------------
# Web task definition
resource "aws_ecs_task_definition" "web" {
  family                   = "${var.name}-web"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.web.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "web"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.alb_health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 2
        startPeriod = 10
      }
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  depends_on = [
    aws_iam_role.task_execution,
    aws_iam_role.task_role
  ]
}

# -----------------
# SERVICE
# -----------------
# Web service behind ALB
resource "aws_ecs_service" "web" {
  name             = "${var.name}-web"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.web.arn
  desired_count    = var.web_desired_count
  launch_type      = "FARGATE"
  platform_version = "1.4.0"

  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false 
  }

  load_balancer {
    container_name   = "web"
    container_port   = var.container_port
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  health_check_grace_period_seconds = 60

  lifecycle {
    ignore_changes = [desired_count] 
  }

  depends_on = [
    aws_subnet.private_a,
    aws_subnet.private_b,
    aws_security_group.tasks,
    aws_lb_target_group.web,
    aws_ecs_cluster.this,
    aws_ecs_task_definition.web
  ]
}

