variable "role_name" {
  type        = string
  description = "Name of the IAM role governed by Permission Boundary"
}

variable "trusted_principal_arn" {
  type        = string
  description = "ARN of the principal allowed to assume this role"
}

variable "boundary_policy_arn" {
  type        = string
  description = "ARN of the Permission Boundary policy attached to the role"
}

variable "identity_policy_json" {
  type        = string
  description = "JSON document defining the requested identity permissions"
}