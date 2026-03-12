resource "aws_db_subnet_group" "this" {
  name       = "finpay-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Name        = "FinPay DB Subnet Group"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "finpay-${var.environment}-rds-sg"
  description = "Security Group for FinPay RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow PostgreSQL traffic only from Backend Security Group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.backend_sg_id]
  }


  egress {
    description     = "Allow outbound traffic only to Backend Security Group"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [var.backend_sg_id]
  }

  tags = {
    Name        = "finpay-${var.environment}-rds-sg"
    Environment = var.environment
  }
}

resource "aws_db_instance" "this" {
  identifier     = "finpay-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az = true

  publicly_accessible = false
  storage_encrypted   = true


  skip_final_snapshot = false

  tags = {
    Environment = var.environment
  }
}