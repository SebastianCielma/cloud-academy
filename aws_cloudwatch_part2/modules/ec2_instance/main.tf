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