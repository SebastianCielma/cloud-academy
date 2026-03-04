terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "bucket-sebastian-eks-part3" 
    key            = "eks-part3/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "state-lock-sebastian-part3" 
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project = "static-website"
    }
  }
}