output "vpc_id" { value = aws_vpc.jenkins_vpc.id }
output "public_subnet_ids" { value = [aws_subnet.public_a.id, aws_subnet.public_b.id] }
output "private_subnet_id" { value = aws_subnet.private.id }