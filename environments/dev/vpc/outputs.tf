output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "db_subnet_ids" {
  description = "DB/data subnet IDs"
  value       = module.vpc.db_subnet_ids
}

output "nat_gateway_id" {
  description = "NAT gateway ID"
  value       = module.vpc.nat_gateway_id
}
