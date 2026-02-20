# ------------
# ALB SG
# ------------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_vpc.main]
}

# --------------
# ECS tasks SG
# --------------
resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks-sg"
  description = "ECS tasks security group"
  vpc_id      = aws_vpc.main.id


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_vpc.main,
    aws_security_group.alb
  ]
}
