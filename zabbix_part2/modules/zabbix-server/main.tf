data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile
  subnet_id = var.subnet_id

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region = "eu-central-1"
  })

  tags = {
    Name = "Zabbix-Server"
  }
}