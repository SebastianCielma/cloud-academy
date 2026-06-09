output "load_balancer_ip" {
  description = "The public IP address of the static website load balancer"
  value       = module.loadbalancer.lb_ip_address
}