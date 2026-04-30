variable "cluster_name" {
  type        = string
  default     = "test-app"
  description = "Name of the EKS cluster"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.32"
  description = "Kubernetes version"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the control plane and node groups (private subnets recommended)"
}

variable "endpoint_public_access" {
  type        = bool
  default     = false
  description = "Expose the EKS API server endpoint publicly"
}

