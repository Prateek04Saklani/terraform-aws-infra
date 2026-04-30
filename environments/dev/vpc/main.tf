module "vpc" {
  source = "../../../modules/vpc"

  cidr                = var.cidr
  app                 = var.app
  env                 = var.env
  log_group           = var.log_group
  flow_logs_role_name = var.flow_logs_role_name

  # Subnet definitions are structural decisions — kept in code, not tfvars.
  private_subnets = {
    sub-1 = { az = "aps1-az1", cidr = "10.0.0.0/19" }
    sub-2 = { az = "aps1-az2", cidr = "10.0.32.0/19" }
    sub-3 = { az = "aps1-az3", cidr = "10.0.64.0/19" }
  }

  public_subnets = {
    sub-1 = { az = "aps1-az1", cidr = "10.0.96.0/22" }
    sub-2 = { az = "aps1-az2", cidr = "10.0.100.0/22" }
    sub-3 = { az = "aps1-az3", cidr = "10.0.104.0/22" }
  }

  # Isolated subnets for RDS, Redis, and other data services.
  # Routed via NAT (private route table) — no direct internet access.
  db_subnets = {
    sub-1 = { az = "aps1-az1", cidr = "10.0.108.0/22" }
    sub-2 = { az = "aps1-az2", cidr = "10.0.112.0/22" }
    sub-3 = { az = "aps1-az3", cidr = "10.0.116.0/22" }
  }
}
