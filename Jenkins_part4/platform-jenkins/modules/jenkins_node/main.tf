data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "jenkins_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.medium" 
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile = var.iam_profile_name

  tags = {
    Name = "jenkins-controller"
  }
}

resource "aws_ebs_volume" "jenkins_data" {
  availability_zone = var.availability_zone
  size              = 30 
  type              = "gp3" 

  tags = {
    Name = "jenkins-home-data"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.jenkins_data.id
  instance_id = aws_instance.jenkins_server.id
}