terraform {
  required_version = ">= 1.3.0"

  backend "s3" {
    bucket         = "eks-bucket-sebastian-akademia" 
    key            = "eks-minimal/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}