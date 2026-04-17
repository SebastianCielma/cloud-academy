module "networking" {
  source = "./modules/networking"
  
  az_a = "${var.aws_region}a"
  az_b = "${var.aws_region}b"
}

module "security" {
  source      = "./modules/security"
  vpc_id      = module.networking.vpc_id
  allowed_ips = [var.my_ip] 
}

module "jenkins_node" {
  source            = "./modules/jenkins_node"
  subnet_id         = module.networking.private_subnet_id
  security_group_id = module.security.jenkins_ec2_sg_id
  iam_profile_name  = module.security.jenkins_instance_profile_name
  availability_zone = "${var.aws_region}a"
}

resource "aws_lb" "jenkins_alb" {
  name               = "jenkins-platform-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security.alb_sg_id]
  subnets            = module.networking.public_subnet_ids 

  tags = { Name = "jenkins-alb" }
}

resource "aws_lb_target_group" "jenkins_tg" {
  name     = "jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.networking.vpc_id

  health_check {
    path                = "/login"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_target_group_attachment" "jenkins_attach" {
  target_group_arn = aws_lb_target_group.jenkins_tg.arn
  target_id        = module.jenkins_node.instance_id
  port             = 8080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.jenkins_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_tg.arn
  }
}