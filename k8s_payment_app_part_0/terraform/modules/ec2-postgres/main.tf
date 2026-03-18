resource "aws_security_group" "postgres_ec2" {
  name_prefix = "finpay-${var.environment}-postgres-ec2-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow PostgreSQL access strictly from EKS worker nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "finpay-${var.environment}-postgres-ec2-sg"
    Environment = var.environment
  }
}

resource "aws_iam_role" "postgres_ssm_role" {
  name = "finpay-${var.environment}-postgres-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.postgres_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "postgres_profile" {
  name = "finpay-${var.environment}-postgres-profile"
  role = aws_iam_role.postgres_ssm_role.name
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "postgres" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.postgres_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.postgres_profile.name

  user_data = templatefile("${path.module}/user_data.sh", {
    db_password = var.db_password
  })

  tags = {
    Name        = "finpay-${var.environment}-postgres-vm"
    Environment = var.environment
  }
}
