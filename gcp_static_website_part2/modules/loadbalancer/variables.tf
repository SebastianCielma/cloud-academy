variable "prefix" {
  type        = string
  description = "Prefix applied to all load balancer resources."
}

variable "bucket_name" {
  type        = string
  description = "Name of the backend bucket created in the storage module."
}

variable "tags" {
  type        = map(string)
  description = "Labels to apply to the forwarding rule."
  default     = {}
}