resource_group_name = "rg-payment-platform"
location            = "westeurope"
environment         = "production"
registry_name       = "acrpaymentplatform123"

vnet_address_space = ["10.0.0.0/16"]

subnet_prefixes = {
  public   = "10.0.1.0/24"
  aks      = "10.0.4.0/22"
  security = "10.0.8.0/24"
  database = "10.0.9.0/24"
}

aks_node_count = 2
aks_min_count  = 1
aks_max_count  = 3
aks_vm_size    = "Standard_D2s_v3"

db_admin_username = "pgadmin"

log_retention_days = 30

tags = {
  Environment = "Production"
  Project     = "PaymentPlatform"
  ManagedBy   = "Terraform"
}

# github_pat is provided via TF_VAR_github_pat environment variable
# Do NOT hardcode sensitive values here
