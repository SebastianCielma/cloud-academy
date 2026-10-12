data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "orders_bucket" {
  bucket = "company-orders-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_object" "test_file" {
  bucket  = aws_s3_bucket.orders_bucket.id
  key     = "test-order.json"
  content = jsonencode({
    order_id = "ORD-999"
    status   = "PAID"
    amount   = 250.50
  })
}