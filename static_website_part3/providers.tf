# providers.tf (POPRAWIONA TREŚĆ)

# --- USUŃ BLOK terraform { ... } JEŚLI TU JEST ---

# Główny region (Szwecja)
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project   = "StaticWebsite-Part3"
      ManagedBy = "Terraform"
    }
  }
}

# Alias dla USA (Wymagany dla WAF)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}