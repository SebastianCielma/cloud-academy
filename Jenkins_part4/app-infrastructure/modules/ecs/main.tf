resource "aws_ecs_cluster" "app_cluster" {
  name = "cloud-academy-cluster-${var.env}"
}