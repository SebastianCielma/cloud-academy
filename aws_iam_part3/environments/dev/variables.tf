variable "aws_region" {
  type        = string
  default     = "eu-central-1"
  description = "Primary AWS region"
}

variable "allowed_regions" {
  type        = list(string)
  default     = ["eu-central-1", "eu-west-1"]
  description = "List of allowed AWS regions for Guardrails"
}

variable "enable_organizations_scp" {
  type        = bool
  default     = false
  description = "Set to true if running in an AWS Organizations Management Account"
}

variable "organization_target_id" {
  type        = string
  default     = "r-0000" # Przykładowe ID Root/OU lub Account ID do podpięcia SCP
  description = "Target Root ID, OU ID, or Account ID for SCP attachment"
}