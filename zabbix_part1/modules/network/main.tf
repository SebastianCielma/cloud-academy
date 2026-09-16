# --- ZABBIX SERVER SECURITY GROUP ---
resource "aws_security_group" "zabbix_server_sg" {
  name        = "zabbix-server-sg"
  description = "Security group for Zabbix Server"
  vpc_id      = aws_vpc.zabbix_vpc.id

  ingress {
    description = "Allow Web UI access from admin IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }


  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- ZABBIX AGENT SECURITY GROUP ---
resource "aws_security_group" "zabbix_agent_sg" {
  name        = "zabbix-agent-sg"
  description = "Security group for monitored Linux instances"
  vpc_id      = aws_vpc.zabbix_vpc.id


  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group_rule" "server_ingress_from_agent" {
  type                     = "ingress"
  from_port                = 10051
  to_port                  = 10051
  protocol                 = "tcp"
  security_group_id        = aws_security_group.zabbix_server_sg.id
  source_security_group_id = aws_security_group.zabbix_agent_sg.id
  description              = "Allow active checks from Zabbix Agents"
}

resource "aws_security_group_rule" "agent_ingress_from_server" {
  type                     = "ingress"
  from_port                = 10050
  to_port                  = 10050
  protocol                 = "tcp"
  security_group_id        = aws_security_group.zabbix_agent_sg.id
  source_security_group_id = aws_security_group.zabbix_server_sg.id
  description              = "Allow passive checks from Zabbix Server"
}

resource "aws_vpc" "zabbix_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "Zabbix-VPC" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.zabbix_vpc.id
  tags = { Name = "Zabbix-IGW" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.zabbix_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "Zabbix-Public-Subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.zabbix_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Zabbix-Public-RouteTable" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}