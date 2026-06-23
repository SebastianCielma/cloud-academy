output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "gke_cluster_location" {
  value = module.gke.cluster_location
}

output "bastion_name" {
  value = module.bastion.bastion_name
}

output "bastion_zone" {
  value = module.bastion.bastion_zone
}