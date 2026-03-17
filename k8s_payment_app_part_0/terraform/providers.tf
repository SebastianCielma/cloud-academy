terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  backend "s3" {
    bucket         = "bucket-sebastian-eks-part3"
    key            = "payment-app/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "state-lock-sebastian-part3"
    encrypt        = true
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