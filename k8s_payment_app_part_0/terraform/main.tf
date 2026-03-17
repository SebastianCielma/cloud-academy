module "vpc" {
  source          = "./modules/vpc"
  vpc_name        = var.vpc_name
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  tags = {
    Environment = var.environment
    Project     = "finpay"
  }
}

module "database" {
  source = "./modules/rds"

  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = var.vpc_cidr
  private_subnets = module.vpc.private_subnets
  backend_sg_id   = module.kubernetes.node_security_group_id

  db_username = "postgres"
  db_password = var.db_password

}

module "kubernetes" {
  source = "./modules/eks"

  cluster_name = "finpay-${var.environment}-cluster"
  environment  = var.environment

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}

module "ecr" {
  source = "./modules/ecr"

  environment      = var.environment
  repository_names = ["payment-api", "payment-worker"]
}

data "aws_eks_cluster" "cluster" {
  name = module.kubernetes.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.kubernetes.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "finpay" {
  name      = "finpay"
  chart     = "${path.module}/../helm/finpay"
  namespace = "default"

  values = [
    templatefile("${path.module}/../helm/finpay/values-${var.environment}.yaml", {})
  ]

  set {
    name  = "config.dbUrl"
    value = "jdbc:postgresql://${module.database.db_endpoint}/paymentdb"
  }

  set {
    name  = "config.dbPassword"
    value = var.db_password
  }

  depends_on = [
    module.kubernetes,
    module.database
  ]
}