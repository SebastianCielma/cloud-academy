provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "StaticWebsite-Part3"
      ManagedBy = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}