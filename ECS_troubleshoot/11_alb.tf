# ------------
# ALB
# ------------
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  depends_on         = [aws_subnet.private_a, aws_subnet.private_b, aws_security_group.alb]
}

# ------------
# Listener
# ------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
  }

  depends_on = [ aws_lb.this , aws_lb_target_group.web ]
}
