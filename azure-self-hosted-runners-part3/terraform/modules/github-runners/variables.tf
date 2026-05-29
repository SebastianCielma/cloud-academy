variable "github_config_url" {
  description = "URL to the GitHub repository or organization for runner registration"
  type        = string
}

variable "github_pat" {
  description = "GitHub Personal Access Token for runner authentication"
  type        = string
  sensitive   = true
}
