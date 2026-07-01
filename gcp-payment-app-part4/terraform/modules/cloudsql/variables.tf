variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "network_id" {
  description = "ID of the VPC network where DB will be created"
  type        = string
}

variable "db_tier" {
  description = "The machine type to use"
  type        = string
  default     = "db-custom-1-3840" 
}