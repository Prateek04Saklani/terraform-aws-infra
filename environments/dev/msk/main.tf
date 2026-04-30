module "msk" {
  source = "../../../modules/msk"

  cluster_name               = var.cluster_name
  kafka_version              = var.kafka_version
  number_of_broker_nodes     = var.number_of_broker_nodes
  broker_instance_type       = var.broker_instance_type
  broker_storage_volume_size = var.broker_storage_volume_size
  subnet_ids                 = var.subnet_ids
  vpc_id                     = var.vpc_id
  vpc_cidr_blocks            = var.vpc_cidr_blocks

  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Service     = "msk"
    Cluster     = var.cluster_name
  }
}
