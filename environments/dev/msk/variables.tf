variable "cluster_name" {
  type        = string
  default     = "baraka-prod"
  description = "Name of the MSK cluster"
}

variable "kafka_version" {
  type        = string
  default     = "3.9.x.kraft"
  description = "Kafka version for the MSK cluster"
}

variable "number_of_broker_nodes" {
  type        = number
  default     = 3
  description = "Total broker count — must be a multiple of the number of subnets (AZs). Default: 3 (1 per AZ)"
}

variable "broker_instance_type" {
  type        = string
  default     = "kafka.m7g.large"
  description = "Instance type for MSK broker nodes"
}

variable "broker_storage_volume_size" {
  type        = number
  default     = 10
  description = "EBS volume size per broker in GiB"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where MSK will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Three subnet IDs (one per AZ) for broker placement"
  validation {
    condition     = length(var.subnet_ids) == 3
    error_message = "Exactly 3 subnet IDs are required (one per availability zone)."
  }
}

variable "vpc_cidr_blocks" {
  type        = list(string)
  description = "VPC CIDR blocks allowed to connect to the MSK brokers"
}

variable "cloudwatch_log_retention_days" {
  type        = number
  default     = 30
  description = "Retention period in days for MSK CloudWatch broker logs"
}
