terraform {
  source = "../../../modules/network"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  vpc_name = "finpay-prod-vpc"
  vpc_cidr = "10.1.0.0/16" # Inna adresacja dla produkcji
  
  # Produkcja działa w trzech strefach dostępności
  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  # Pełna redundancja - wyłączamy "single NAT", by mieć NAT w każdej strefie
  single_nat_gateway = false

  tags = {
    Environment = "prod"
  }
}