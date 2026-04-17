# terraform-aws-infra

Terraform modules for AWS infrastructure — EKS, VPC, IAM, RDS, and Kafka (MSK). Production-grade patterns with remote state, environment separation, and security best practices.

---

## Overview

This repository contains modular, reusable Terraform for provisioning AWS infrastructure. Each module is independently usable and follows consistent conventions. Environment configs in `environments/` wire modules together for dev and prod deployments.

Built as a public reference for real-world DevOps and infrastructure-as-code patterns.

---

## Repository Structure

```
terraform-aws-infra/
├── bootstrap/          # One-time setup: S3 bucket + DynamoDB table for remote state
├── modules/
│   ├── vpc/            # VPC, subnets, NAT gateway, route tables, security groups
│   ├── eks/            # EKS cluster, managed node groups, OIDC, core add-ons
│   ├── iam/            # IAM roles, policies, IRSA (IAM Roles for Service Accounts)
│   ├── security/       # KMS keys, GuardDuty, SecurityHub
│   ├── rds/            # RDS Aurora/Postgres, parameter groups, subnet groups
│   ├── msk/            # Amazon MSK (managed Kafka)
│   └── kafka-helm/     # Self-hosted Kafka via Helm on EKS
└── environments/
    ├── dev/            # Dev environment — calls modules with dev-specific vars
    └── prod/           # Prod environment — calls modules with prod-specific vars
```

---

## Modules

| Module | Description |
|---|---|
| `vpc` | Creates a VPC with public/private subnets across AZs, NAT gateway, and route tables |
| `eks` | Provisions an EKS cluster with managed node groups, OIDC provider, and essential add-ons |
| `iam` | Reusable IAM roles and policies; includes IRSA helper for EKS workloads |
| `security` | KMS customer-managed keys, GuardDuty enablement, SecurityHub standards |
| `rds` | Aurora PostgreSQL or RDS Postgres with subnet groups, parameter groups, and encryption |
| `msk` | Amazon MSK cluster with broker configuration, security groups, and CloudWatch logging |
| `kafka-helm` | Self-hosted Kafka on EKS using the Helm provider (Strimzi or Bitnami) |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with appropriate credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (for EKS interaction)
- [helm](https://helm.sh/docs/intro/install/) (for `kafka-helm` module)

---

## Getting Started

### 1. Bootstrap remote state

Before applying any environment, create the S3 bucket and DynamoDB table used for Terraform state:

```bash
cd bootstrap
terraform init
terraform apply
```

### 2. Deploy an environment

```bash
cd environments/dev
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

---

## State Management

Remote state is stored in S3 with DynamoDB locking. The `bootstrap/` directory provisions these resources. Each environment references the backend independently.

```hcl
terraform {
  backend "s3" {
    bucket         = "your-tf-state-bucket"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

---

## Environments

| Environment | Purpose |
|---|---|
| `dev` | Development workloads — smaller instance types, relaxed policies |
| `prod` | Production workloads — HA setup, stricter security, larger nodes |

---

## Security Practices

- All S3 buckets and RDS instances are encrypted at rest via KMS
- EKS uses private API endpoint with OIDC-based workload identity (IRSA)
- IAM follows least-privilege — no wildcard `*` actions in module policies
- GuardDuty and SecurityHub enabled by default in the `security` module
- Secrets are not stored in state — use AWS Secrets Manager or Parameter Store

---

## Contributing

This is a personal portfolio project. Feel free to open issues or PRs if you spot something worth improving.

---

## License

[MIT](LICENSE)
