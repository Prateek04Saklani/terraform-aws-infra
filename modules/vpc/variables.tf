variable "cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "app" {
  type        = string
  description = "Application name — used in resource name tags"
}

variable "env" {
  type        = string
  description = "Environment name — used in resource name tags"
}

variable "private_subnets" {
  type = map(object({
    az   = string
    cidr = string
  }))
  description = "Map of private subnets. Key is a short label (e.g. sub-1); value has az (AZ ID) and cidr."
}

variable "public_subnets" {
  type = map(object({
    az   = string
    cidr = string
  }))
  description = "Map of public subnets. Key is a short label (e.g. sub-1); value has az (AZ ID) and cidr."
}

variable "db_subnets" {
  type = map(object({
    az   = string
    cidr = string
  }))
  description = "Map of private DB/data subnets for RDS, Redis, and other data services. Routed via NAT, no public access."
}

variable "log_group" {
  type        = string
  description = "CloudWatch log group name for VPC flow logs"
  default     = "vpc-flow-logs"
}

variable "flow_logs_role_name" {
  type        = string
  description = "Name for the IAM role used by VPC flow logs"
  default     = "vpc-flow-logs-role"
}

variable "flow_log_retention_days" {
  type        = number
  default     = 14
  description = "Retention period in days for VPC flow log CloudWatch log group"
}
