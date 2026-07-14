variable "github_repository" {
  type        = string
}

variable "github_pat" {
  type        = string
  sensitive   = true 
}

variable "runner_namespace" {
  type        = string
  default     = "actions-runner-system"
}

variable "runner_scale_set_name" {
  type        = string
  default     = "k8s-runner"
}