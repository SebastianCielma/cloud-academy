resource "aws_ecr_repository" "app_repo" {
  name                 = "cloud-academy-app-${var.env}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}