terraform {
  backend "s3" {
    bucket         = "jenkins-part4-tf-state" 
    key            = "app/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "eu-central-1"
}

locals {
  env = terraform.workspace == "default" ? "dev" : terraform.workspace
}

module "ecr" {
  source = "./modules/ecr"
  env    = local.env
}

module "ecs" {
  source             = "./modules/ecs"
  env                = local.env
  ecr_repository_url = module.ecr.repository_url 
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}