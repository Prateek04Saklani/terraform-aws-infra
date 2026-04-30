module "eks" {
  source = "../../../modules/eks"

  cluster_name           = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  vpc_id                 = var.vpc_id
  subnet_ids             = var.subnet_ids
  endpoint_public_access = var.endpoint_public_access

  # Node groups are defined here

  node_groups = {
    # Stable ON_DEMAND nodes for kube-system and infra pods
    system = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      disk_size      = 20
      labels = {
        role = "system"
      }
    }

    # Cost-optimised SPOT nodes for non critical app workloads.
    # Multiple instance types improve spot availability and reduce interruptions.
    app-spot = {
      instance_types = ["m5.xlarge", "m5.2xlarge", "m5a.xlarge", "m5a.2xlarge"]
      capacity_type  = "SPOT"
      min_size       = 2
      max_size       = 10
      desired_size   = 1
      disk_size      = 50
      labels = {
        role     = "app"
        capacity = "spot"
      }
      taints = [{
        key    = "workload"
        value  = "app"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Service     = "eks"
    Cluster     = var.cluster_name
  }
}

# ── Karpenter node autoscaler ─────────────────────────────────────────────────
# Manages dynamic scaling for app workload nodes via two NodePools:
#   - app-spot:     SPOT  (m5/m5a/m6i/r5, xlarge/2xlarge), limit 20 CPU / 80Gi
#   - app-ondemand: ON_DEMAND (m5 xlarge), limit 8 CPU / 32Gi
#
# FIRST-TIME APPLY ORDER (bootstrapping a new cluster):
#   1. terraform apply -target=module.eks
#   2. terraform apply -target=module.karpenter.helm_release.karpenter
#   3. terraform apply

module "karpenter" {
  source = "../../../modules/karpenter"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_ca_data   = module.eks.cluster_certificate_authority_data
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  subnet_ids        = var.subnet_ids

  karpenter_version = "1.0.7"

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Service     = "karpenter"
    Cluster     = var.cluster_name
  }
}
