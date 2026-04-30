output "cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = module.msk.cluster_arn
}

output "bootstrap_brokers_iam" {
  description = "IAM SASL/TLS bootstrap broker endpoints"
  value       = module.msk.bootstrap_brokers_iam
}

output "bootstrap_brokers_tls" {
  description = "TLS bootstrap broker endpoints"
  value       = module.msk.bootstrap_brokers_tls
}

output "security_group_id" {
  description = "MSK security group ID"
  value       = module.msk.security_group_id
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group for MSK broker logs"
  value       = module.msk.cloudwatch_log_group_name
}
