terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "jenkins-part4-tf-state"
    key            = "platform/jenkins.tfstate"    
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true                           
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}