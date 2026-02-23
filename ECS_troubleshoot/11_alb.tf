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
    target_group_arn = aws_lb_target_group.web.arn
  }

  depends_on = [ aws_lb.this , aws_lb_target_group.web ]
}

resource "aws_lb_target_group" "web" {
  name        = "ecs-web-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip" 
  
  vpc_id      = aws_vpc.main.id 

  health_check {
    path                = "/" 
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200" 
  }
}
