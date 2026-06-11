output "load_balancer_https_ip" {
  description = "The public IP address of the HTTPS load balancer."
  value       = module.loadbalancer.lb_ip_address
}