# providers.tf
provider "aws" {
  region = var.aws_region
  # Remember to inject your own AWS profile
  profile = var.aws_profile
}
