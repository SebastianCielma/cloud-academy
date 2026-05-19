variable "location" {
  type        = string
  default     = "westeurope"
  description = "Azure region."
}

variable "name" {
  type        = string
  default     = "aca-troubleshoot"
  description = "Resource name prefix."
}

variable "dns_zone_name" {
  type        = string
  default     = null
  description = "Optional Azure DNS zone name to create A record for App Gateway (e.g., example.com). Leave null to skip."
}

variable "dns_record_name" {
  type        = string
  default     = "app"
  description = "Relative DNS record name in the zone (e.g., 'app' -> app.example.com)."
}

variable "container_image" {
  type        = string
  default     = "myregistry.azurecr.io/web:latest"
  description = "Initial image for web & worker (you'll switch to ACR later)."
}

variable "container_port" {
  type        = number
  default     = 80
  description = "Application container port."
}

variable "web_min_replicas" {
  type    = number
  default = 1
}

variable "web_max_replicas" {
  type    = number
  default = 6
}

variable "http_concurrency" {
  type        = number
  default     = 50
  description = "Scale rule: max concurrent HTTP requests per replica for ACA."
}
