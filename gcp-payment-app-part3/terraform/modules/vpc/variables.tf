variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "payment-vpc"
}

variable "subnet_name" {
  description = "Name of the subnetwork"
  type        = string
  default     = "payment-subnet"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.0.0/16"
}