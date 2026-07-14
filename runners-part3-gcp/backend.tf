terraform {
  backend "gcs" {
    bucket = "finpay-tf-state-akademiasebastianckuba"
    prefix = "terraform/runners/state"
  }
}