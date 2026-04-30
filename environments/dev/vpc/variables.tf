variable "cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "app" {
  type        = string
  description = "Application name"
}

variable "env" {
  type        = string
  default     = "dev"
  description = "Environment name"
}

variable "log_group" {
  type        = string
  description = "CloudWatch log group name for VPC flow logs"
}

variable "flow_logs_role_name" {
  type        = string
  description = "IAM role name for VPC flow logs"
}
