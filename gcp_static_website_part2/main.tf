module "storage" {
  source          = "./modules/storage"
  bucket_name     = var.bucket_name
  region          = var.region
  tags            = var.tags
  index_html_path = "./website/index.html"
  error_html_path = "./website/404.html"
}

module "loadbalancer" {
  source      = "./modules/loadbalancer"
  prefix      = "my-static-site"
  bucket_name = module.storage.bucket_name
  tags        = var.tags
}