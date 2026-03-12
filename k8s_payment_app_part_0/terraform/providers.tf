terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "finpay-tf-state-sebastian-akademia"
    key            = "finpay/production/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "finpay-tf-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Project     = "FinPay"
      Environment = "Production"
      ManagedBy   = "Terraform"
    }
  }
}