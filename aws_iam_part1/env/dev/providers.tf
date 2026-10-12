provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "IAM-Security-Migration"
      ManagedBy   = "Terraform"
      Owner       = "Security"
    }
  }
}