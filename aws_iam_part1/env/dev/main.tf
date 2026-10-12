module "orders_app_role" {
  source = "../../modules/iam_s3_role"

  role_name           = var.app_role_name
  trusted_account_ids = var.allowed_account_ids
  external_id         = var.partner_external_id

  s3_bucket_arn       = aws_s3_bucket.orders_bucket.arn
}