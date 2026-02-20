############################
# VPC + Subnets + Routing  
############################

# ------------------
# VPC
# ------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

# ------------------
# Public Subnet A
# ------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-a"
    Tier = "public"
  }
}

# ------------------
# Public Subnet B
# ------------------
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = var.azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-b"
    Tier = "public"
  }
}

# ------------------
# Private Subnet A
# ------------------
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = var.azs[0]

  tags = {
    Name = "${var.name}-private-a"
    Tier = "private"
  }
}

# ------------------
# Private Subnet B
# ------------------
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = var.azs[1]

  tags = {
    Name = "${var.name}-private-b"
    Tier = "private"
  }
}

# --------------------------------------
# Internet Gateway (for public subnets)
# --------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# -------------------------------------------------
# Elastic IP for single NAT Gateway (lab-friendly)
# -------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.name}-nat-eip"
  }
}

# ---------------------------------
# NAT Gateway in Public Subnet A
# ---------------------------------
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${var.name}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ------------------------------------------------------
# Route Table for PUBLIC subnets (default route -> IGW)
# ------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-rt-public"
  }
}

# -------------------------------------------------
# Route Table Associations (Public)
# -------------------------------------------------
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# --------------------------------------------------------
# Route Table for PRIVATE subnets (default route -> NAT)
# --------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # default route to NAT
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.name}-rt-private"
  }
}

# -------------------------------------------------
# Route Table Associations (Private)
# -------------------------------------------------
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

