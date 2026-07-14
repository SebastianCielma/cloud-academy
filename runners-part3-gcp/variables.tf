variable "project_id" {
  description = "The Google Cloud Project ID."
  type        = string
}

variable "region" {
  description = "The Google Cloud region where the cluster is located."
  type        = string
}

variable "cluster_name" {
  description = "The name of the existing GKE cluster."
  type        = string
}

variable "github_repository" {
  description = "The GitHub repository URL"
  type        = string
}

variable "github_pat" {
  description = "GitHub Personal Access Token for Runner Controller."
  type        = string
  sensitive   = true
}