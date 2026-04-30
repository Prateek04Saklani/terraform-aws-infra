variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS API server endpoint"
}

variable "cluster_ca_data" {
  type        = string
  description = "Base64-encoded certificate authority data for the cluster"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the OIDC provider (used for IRSA)"
}

variable "oidc_provider_url" {
  type        = string
  description = "URL of the OIDC provider without https:// prefix"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for Karpenter-launched nodes (same subnets as the EKS cluster)"
}

variable "karpenter_version" {
  type        = string
  default     = "1.0.7"
  description = "Karpenter Helm chart version (chart version matches app version for v1.x)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all AWS resources created by this module"
}
