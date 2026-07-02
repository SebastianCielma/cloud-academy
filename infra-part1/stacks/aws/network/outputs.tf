output "vpc_id" {
  value = aws_vpc.academy.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "academy_api_security_group_id" {
  value = aws_security_group.academy_api.id
}

