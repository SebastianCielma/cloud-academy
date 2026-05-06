resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = "finpay/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Project     = "finpay"
  }
}