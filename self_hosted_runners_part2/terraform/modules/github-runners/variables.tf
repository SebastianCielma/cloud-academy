variable "github_config_url" {
  description = "URL to the repository"
  type        = string
}

variable "github_pat" {
  description = "GitHub Personal Access Token for the runners"
  type        = string
  sensitive   = true
}