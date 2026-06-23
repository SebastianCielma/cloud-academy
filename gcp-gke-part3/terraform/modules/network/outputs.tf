output "vpc_name" { value = google_compute_network.vpc.name }
output "vpc_id" { value = google_compute_network.vpc.id }
output "workload_subnet_name" { value = google_compute_subnetwork.workload.name }
output "system_subnet_name" { value = google_compute_subnetwork.system.name }
output "pod_range_name" { value = google_compute_subnetwork.workload.secondary_ip_range[0].range_name }
output "service_range_name" { value = google_compute_subnetwork.workload.secondary_ip_range[1].range_name }