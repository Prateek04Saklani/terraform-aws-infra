output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA role bindings"
  value       = module.eks.oidc_provider_arn
}

output "node_group_ids" {
  description = "Node group IDs"
  value       = module.eks.node_group_ids
}
