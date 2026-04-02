data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"] 

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
# ------------------------------------------------------------------------
# IAM EC2
# ------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_monitoring_role" {
  name               = "ec2-cloudwatch-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-cloudwatch-ssm-profile"
  role = aws_iam_role.ec2_monitoring_role.name
}

# ------------------------------------------------------------------------
#  EC2 
# ------------------------------------------------------------------------
module "ec2_web" {
  source               = "./modules/ec2_instance"
  ami_id = data.aws_ami.amazon_linux_2023.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  
  instance_name = "web-1"
  env           = "prod"
  app           = "web"
  role          = "frontend"
  auto_alert    = "true"
}

module "ec2_api" {
  source               = "./modules/ec2_instance"
  ami_id = data.aws_ami.amazon_linux_2023.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  
  instance_name = "api-1"
  env           = "prod"
  app           = "api"
  role          = "backend"
  auto_alert    = "true"
}

module "ec2_worker" {
  source               = "./modules/ec2_instance"
  ami_id = data.aws_ami.amazon_linux_2023.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  
  instance_name = "worker-1"
  env           = "prod"
  app           = "worker"
  role          = "processing"
  auto_alert    = "true"
}
