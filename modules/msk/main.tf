resource "aws_security_group" "msk" {
  name        = "${var.cluster_name}-msk-sg"
  vpc_id      = var.vpc_id
  description = "Security group for MSK cluster ${var.cluster_name}"

  # Kafka with IAM/SASL auth — TLS port
  ingress {
    description = "Kafka IAM SASL TLS (port 9098)"
    from_port   = 9098
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr_blocks
  }

  # Kafka TLS (client broker encrypted channel)
  ingress {
    description = "Kafka TLS (port 9094)"
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-msk-sg"
  })
}

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.cluster_name}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = var.tags
}

# MSK Cluster — KRaft metadata mode, IAM authentication, TLS encryption
# KRaft eliminates ZooKeeper; available for Kafka 3.7+ on AWS MSK.
# Requires aws provider >= 5.25 for full KRaft support.
resource "aws_msk_cluster" "this" {
  cluster_name           = var.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_storage_volume_size
      }
    }
  }

  # IAM role-based authentication — no username/password
  client_authentication {
    sasl {
      iam = true
    }
    unauthenticated = false
  }

  # Encryption in-transit (TLS enforced) and at rest (AWS-managed key)
  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
    # encryption_at_rest_kms_key_arn omitted → uses AWS-managed key (SSE-KMS)
  }

  # Broker logs → CloudWatch
  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  tags = var.tags
}
