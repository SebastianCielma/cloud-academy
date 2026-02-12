module "s3" {
  source = "./modules/s3"

  bucket_name    = var.website_bucket_name
  cloudfront_arn = module.cloudfront.distribution_arn
}

module "cloudfront" {
  source = "./modules/cloudfront"

  bucket_id          = module.s3.bucket_id
  bucket_domain_name = module.s3.bucket_domain_name
}