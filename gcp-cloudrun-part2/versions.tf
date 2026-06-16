terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {
    bucket = "tf-state-sebastianakademiacloudrun" 
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.15.0"
    }
  }
}

provider "google" {
  project = var.project_id

  default_labels = var.default_tags
}