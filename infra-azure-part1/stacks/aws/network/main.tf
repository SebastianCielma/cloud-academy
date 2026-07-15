resource "aws_vpc" "academy" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name        = "terraops-${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.academy.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name        = "terraops-${var.environment}-public"
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

resource "aws_internet_gateway" "academy" {
  vpc_id = aws_vpc.academy.id

  tags = {
    Name        = "terraops-${var.environment}-igw"
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.academy.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.academy.id
  }

  tags = {
    Name        = "terraops-${var.environment}-public-rt"
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "academy_api" {
  name        = "terraops-${var.environment}-academy-api"
  description = "Academy Control API access"
  vpc_id      = aws_vpc.academy.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "terraops-${var.environment}-academy-api"
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

