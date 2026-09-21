provider "aws" {
  region = "eu-central-1"
}

resource "aws_iam_role" "ssm_role" {
  name = "zabbix-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "zabbix-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role_policy" "ssm_parameter_read" {
  name = "zabbix-read-db-password"
  role = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = aws_ssm_parameter.zabbix_db_pass.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "zabbix_cloudwatch_read" {
  name = "zabbix-cloudwatch-read"
  role = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      }
    ]
  })
}


module "network" {
  source   = "../../modules/network"
  admin_ip = var.admin_ip
}

module "zabbix_server" {
  source               = "../../modules/zabbix-server"
  security_group_id    = module.network.zabbix_server_sg_id
  subnet_id            = module.network.subnet_id 
  
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
}

module "zabbix_agents" {
  source               = "../../modules/zabbix-agent"
  count                = 2
  security_group_id    = module.network.zabbix_agent_sg_id
  subnet_id            = module.network.subnet_id 
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  zabbix_server_ip     = module.zabbix_server.private_ip
  agent_hostname       = "Zabbix-Agent-${count.index + 1}"
}

resource "random_password" "zabbix_db_pass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "zabbix_db_pass" {
  name  = "/zabbix/db/password"
  type  = "SecureString"
  value = random_password.zabbix_db_pass.result
}

resource "aws_db_instance" "managed_db" {
  identifier             = "zabbix-managed-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  username               = "dbadmin"
  password               = random_password.zabbix_db_pass.result
  db_subnet_group_name   = module.network.rds_subnet_group_name
  vpc_security_group_ids = [module.network.zabbix_agent_sg_id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  
  tags = { Name = "Zabbix-Managed-RDS" }
}

resource "aws_iam_user" "zabbix_cloudwatch" {
  name = "zabbix-api-reader"
}

resource "aws_iam_user_policy" "zabbix_cloudwatch_policy" {
  name = "zabbix-cloudwatch-read-policy"
  user = aws_iam_user.zabbix_cloudwatch.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "rds:DescribeDBInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DescribeAlarmsForMetric",
          "ec2:DescribeVolumes",
          "rds:DescribeEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "zabbix_cloudwatch_key" {
  user = aws_iam_user.zabbix_cloudwatch.name
}