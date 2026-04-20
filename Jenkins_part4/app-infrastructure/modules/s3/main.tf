resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "app_bucket" {
  bucket        = "cloud-academy-app-data-${var.env}-${random_string.suffix.result}"
  force_destroy = true
}