variable "bucket_name" {
  type        = string
  description = "Name of the GCS bucket. Must be globally unique."
}

variable "region" {
  type        = string
  description = "Location for the GCS bucket."
}

variable "tags" {
  type        = map(string)
  description = "Labels to apply to the bucket (GCP equivalent of tags)."
  default     = {}
}

variable "index_html_path" {
  type        = string
  description = "Local file path to the index.html file."
}

variable "error_html_path" {
  type        = string
  description = "Local file path to the 404.html file."
}