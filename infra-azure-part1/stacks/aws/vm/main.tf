data "aws_vpc" "academy" {
  tags = {
    Name        = "terraops-${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

data "aws_subnet" "public" {
  tags = {
    Name        = "terraops-${var.environment}-public"
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

data "aws_security_group" "academy_api" {
  tags = {
    Name        = "terraops-${var.environment}-academy-api"
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "academy_api" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.public.id
  vpc_security_group_ids      = [data.aws_security_group.academy_api.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    environment  = var.environment
    app_port     = var.app_port
    database_url = var.database_url
  })

  tags = {
    Name        = "terraops-${var.environment}-academy-api"
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

