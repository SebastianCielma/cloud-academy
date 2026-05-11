variable "location" {
  description = "Azure region"
  type        = string
  default     = "polandcentral"
}

variable "project_name" {
  description = "Main project name for resources"
  type        = string
  default     = "part2"
}

variable "tags" {
  description = "Common map of tags to apply to all resources."
  type        = map(string)
  default = {
    project = "static-website"
  }
}