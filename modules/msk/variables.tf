variable "cluster_name" {
  type        = string
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
  description = "Total number of broker nodes. Must be a multiple of the number of AZs (subnets)"
}

variable "broker_instance_type" {
  type        = string
  default     = "kafka.m7g.large"
  description = "EC2 instance type for MSK broker nodes"
}

variable "broker_storage_volume_size" {
  type        = number
  default     = 10
  description = "EBS storage volume size in GiB per broker node"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for broker placement — one subnet per AZ"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID used to create the MSK security group"
}

variable "vpc_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed ingress to MSK brokers (typically the VPC CIDR)"
}

variable "cloudwatch_log_retention_days" {
  type        = number
  default     = 14
  description = "Retention period in days for the MSK CloudWatch log group"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all MSK resources"
}
