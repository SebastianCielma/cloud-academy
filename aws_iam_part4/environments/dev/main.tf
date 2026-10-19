data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}