variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.30"
  description = "Kubernetes version for the EKS cluster"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the EKS cluster will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the EKS control plane and default node group placement"
}

variable "endpoint_public_access" {
  type        = bool
  default     = false
  description = "Whether the EKS API server endpoint is publicly accessible"
}

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    capacity_type  = string # "ON_DEMAND" or "SPOT"
    min_size       = number
    max_size       = number
    desired_size   = number
    subnet_ids     = optional(list(string))       # overrides cluster subnet_ids for this group
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string # NO_SCHEDULE | NO_EXECUTE | PREFER_NO_SCHEDULE
    })), [])
    disk_size = optional(number, 20)
    ami_type  = optional(string, "AL2_x86_64")
  }))
  description = "Map of managed node group configurations. Use capacity_type = SPOT with multiple instance_types for spot nodes."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all EKS resources"
}
