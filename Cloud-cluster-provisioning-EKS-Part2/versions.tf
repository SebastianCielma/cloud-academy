terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "bucket-part2-sebastian"
    key            = "eks-minimal/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock-sebastian"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}