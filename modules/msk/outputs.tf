output "cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the MSK cluster"
  value       = aws_msk_cluster.this.cluster_name
}

output "bootstrap_brokers_iam" {
  description = "Bootstrap broker endpoints for IAM SASL/TLS authentication"
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "bootstrap_brokers_tls" {
  description = "Bootstrap broker endpoints for TLS (non-IAM) connections"
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "zookeeper_connect_string" {
  description = "ZooKeeper connection string (empty when using KRaft mode)"
  value       = aws_msk_cluster.this.zookeeper_connect_string
}

output "security_group_id" {
  description = "ID of the MSK security group"
  value       = aws_security_group.msk.id
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for MSK broker logs"
  value       = aws_cloudwatch_log_group.msk.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for MSK broker logs"
  value       = aws_cloudwatch_log_group.msk.arn
}
