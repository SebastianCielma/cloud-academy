# Wskazujemy na nasz moduł bazy danych (EC2)
terraform {
  source = "../../../modules/database"
}

# Dołączamy główny plik konfiguracyjny
include "root" {
  path = find_in_parent_folders()
}

# 1. Zależność od sieci
dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id          = "vpc-mock123"
    private_subnets = ["subnet-mock1", "subnet-mock2"]
    vpc_cidr_block  = "10.0.0.0/16"
  }
}

# 2. Zależność od klastra EKS (potrzebujemy jego Security Group)
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    node_security_group_id = "sg-mock123"
  }
}

# Przekazujemy zmienne
inputs = {
  environment   = "dev"
  
  # Zgodnie z tabelą z zadania, dla DEV używamy mniejszej maszyny [cite: 44, 45]
  instance_type = "t3.micro" 
  
  # Hasło w środowisku deweloperskim (w produkcji użylibyśmy AWS Secrets Managera)
  db_password   = "SuperSecretDevPassword123!"

  # Zmienne pobierane z innych modułów - zero twardego kodowania! [cite: 60, 61]
  vpc_id         = dependency.network.outputs.vpc_id
  
  # Wybieramy pierwszą prywatną podsieć z listy
  subnet_id      = dependency.network.outputs.private_subnets[0] 
  vpc_cidr       = dependency.network.outputs.vpc_cidr_block
  
  eks_node_sg_id = dependency.eks.outputs.node_security_group_id
}