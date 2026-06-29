variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "network_id" {
  description = "The VPC network to host the cluster in"
  type        = string
}

variable "subnet_name" {
  description = "The subnetwork to host the cluster in"
  type        = string
}

variable "cluster_name" {
  type    = string
  default = "payment-cluster"
}