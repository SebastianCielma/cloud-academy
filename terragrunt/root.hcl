generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      ManagedBy   = "Terragrunt"
      Project     = "FinPay"
    }
  }
}
EOF
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "finpay-terraform-state-${get_aws_account_id()}"
    
    key            = "${path_relative_to_include()}/terraform.tfstate"
    
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "finpay-terraform-locks"
  }
}