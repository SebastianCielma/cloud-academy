terraform {
  backend "gcs" {
    bucket = "bucket-sebastian-akademia-static"
    prefix = "terraform/state/static-website"
  }
}