
output "instance_ids" {
  description = "Map of instance name → EC2 instance ID"
  value       = module.ec2_fleet.instance_ids
}

output "private_ips" {
  description = "Map of instance name → private IP address"
  value       = module.ec2_fleet.private_ips
}
