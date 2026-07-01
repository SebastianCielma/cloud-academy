terraform {
  backend "gcs" {
    bucket = "akademiasebastianckuba-tf-state"
    prefix = "terraform/state/part3-core-infra"
  }
}