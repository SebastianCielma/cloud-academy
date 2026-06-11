module "storage" {
  source          = "./modules/storage"
  bucket_name     = var.bucket_name
  log_bucket_name = var.log_bucket_name
  region          = var.region
  project_id      = var.project_id
  tags            = var.tags
  
  index_html_path = "./website/index.html"
  error_html_path = "./website/404.html"
  html_4xx_path   = "./website/4xx.html"
  html_5xx_path   = "./website/5xx.html"
}

module "loadbalancer" {
  source      = "./modules/loadbalancer"
  prefix      = "my-static-site"
  bucket_name = module.storage.bucket_name
  tags        = var.tags
}

module "monitoring" {
  source      = "./modules/monitoring"
  prefix      = "my-static-site"
  alert_email = var.alert_email
}