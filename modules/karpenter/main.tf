# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Look up the EKS cluster to get its auto-created primary security group.
# This is the SG shared between the control plane and all worker nodes.
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# ── Subnet & security group tagging for Karpenter discovery ───────────────────
# Karpenter uses tag-based discovery to find which subnets and security groups
# to use when launching nodes. We tag the same subnets as the EKS cluster and
# the EKS-managed cluster primary SG.

resource "aws_ec2_tag" "subnet_karpenter_discovery" {
  for_each    = toset(var.subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "cluster_sg_karpenter_discovery" {
  resource_id = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# ── Karpenter node IAM role ───────────────────────────────────────────────────
# Nodes launched by Karpenter assume this role. It is separate from the MNG
# node role so permissions and lifecycles are managed independently.

resource "aws_iam_role" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# SSM policy lets the node register with SSM for debugging and patch management
resource "aws_iam_role_policy_attachment" "karpenter_node_ssm_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ── EKS Access Entry for Karpenter node role ──────────────────────────────────
# EKS 1.29+ uses Access Entries instead of the aws-auth ConfigMap.
# EC2_LINUX type automatically grants the node the necessary cluster permissions.

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"

  tags = var.tags
}

# ── SQS interruption queue ────────────────────────────────────────────────────
# Karpenter polls this queue for EC2 lifecycle events and performs graceful
# node drains before spot instances are terminated (2-minute warning window).

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300 # 5 min; events are consumed immediately
  sqs_managed_sse_enabled   = true

  tags = var.tags
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.karpenter_interruption.arn
      Principal = {
        Service = ["events.amazonaws.com", "sqs.amazonaws.com"]
      }
    }]
  })
}

# ── EventBridge rules → SQS ───────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "${var.cluster_name}-karpenter-spot-interruption"
  description = "Karpenter: EC2 Spot Instance Interruption Warning"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "${var.cluster_name}-karpenter-rebalance"
  description = "Karpenter: EC2 Instance Rebalance Recommendation"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule = aws_cloudwatch_event_rule.karpenter_rebalance.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  name        = "${var.cluster_name}-karpenter-instance-state"
  description = "Karpenter: EC2 Instance State-change Notification"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  rule = aws_cloudwatch_event_rule.karpenter_instance_state_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_scheduled_change" {
  name        = "${var.cluster_name}-karpenter-scheduled-change"
  description = "Karpenter: AWS Health Scheduled Change Event"
  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_scheduled_change" {
  rule = aws_cloudwatch_event_rule.karpenter_scheduled_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# ── Karpenter controller IRSA role ────────────────────────────────────────────
# The Karpenter controller pod uses this role via the OIDC provider.

data "aws_iam_policy_document" "karpenter_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "${var.cluster_name}-karpenter-controller-role"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "karpenter_controller" {
  # Allow EC2 Fleet and RunInstances — scoped to resources tagged by Karpenter
  statement {
    sid    = "AllowScopedEC2InstanceActions"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}::image/*",
      "arn:aws:ec2:${data.aws_region.current.name}::snapshot/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:spot-instances-request/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:security-group/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:subnet/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:launch-template/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:network-interface/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:instance/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:volume/*",
    ]
  }

  # Allow creating fleet/instance/launch-template resources only when tagged
  # with the cluster name and a nodepool label (safety scope)
  statement {
    sid    = "AllowScopedResourceCreationWithTags"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:*:fleet/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:instance/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:volume/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:network-interface/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:launch-template/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:spot-instances-request/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  # Allow CreateTags only during resource creation actions
  statement {
    sid    = "AllowScopedResourceCreationTagging"
    effect = "Allow"
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:*:fleet/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:instance/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:volume/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:network-interface/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:launch-template/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:spot-instances-request/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances", "CreateFleet", "CreateLaunchTemplate"]
    }
  }

  # Allow tagging existing instances (e.g. adding nodeclaim tag post-launch)
  statement {
    sid    = "AllowScopedResourceTagReplacement"
    effect = "Allow"
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:*:instance/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodeclaim"
      values   = ["*"]
    }
  }

  # Allow termination and cleanup — scoped to Karpenter-owned resources only
  statement {
    sid    = "AllowScopedDeletion"
    effect = "Allow"
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:*:instance/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:launch-template/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  # Read-only EC2 discovery — region-scoped
  statement {
    sid    = "AllowRegionalReadActions"
    effect = "Allow"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [data.aws_region.current.name]
    }
  }

  # Global read actions that have no region condition support
  statement {
    sid    = "AllowGlobalReadActions"
    effect = "Allow"
    actions = [
      "ec2:DescribeVolumes",
      "iam:GetInstanceProfile",
      "pricing:GetProducts",
    ]
    resources = ["*"]
  }

  # SSM for resolving the latest EKS-optimised AMI ID
  statement {
    sid    = "AllowSSMReadActions"
    effect = "Allow"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}::parameter/aws/service/*",
    ]
  }

  # SQS for spot interruption queue
  statement {
    sid    = "AllowSQSInterruptionQueue"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.karpenter_interruption.arn]
  }

  # Instance profile management — Karpenter creates and manages profiles
  # on behalf of EC2NodeClass when the `role` field is used
  statement {
    sid    = "AllowInstanceProfileActions"
    effect = "Allow"
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*",
    ]
  }

  # PassRole — Karpenter passes the node IAM role to EC2 during launch
  statement {
    sid    = "AllowPassNodeRole"
    effect = "Allow"
    actions = ["iam:PassRole"]
    resources = [aws_iam_role.karpenter_node.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  # EKS cluster read — Karpenter needs to discover the cluster endpoint
  statement {
    sid    = "AllowEKSClusterRead"
    effect = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
    ]
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.cluster_name}-karpenter-controller-policy"
  description = "Karpenter controller IAM policy for cluster ${var.cluster_name}"
  policy      = data.aws_iam_policy_document.karpenter_controller.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ── Karpenter Helm release ────────────────────────────────────────────────────
# The chart is hosted on OCI (ECR public) — no separate repository add needed.
# Karpenter runs on the `system` managed node group (no Karpenter-managed taint),
# ensuring it survives node pool changes.

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version

  values = [
    yamlencode({
      settings = {
        clusterName       = var.cluster_name
        interruptionQueue = aws_sqs_queue.karpenter_interruption.name
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller.arn
        }
      }
      controller = {
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { cpu = "1",    memory = "1Gi" }
        }
      }
      # Pin Karpenter controller pods to the `system` managed node group
      nodeSelector = { role = "system" }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller,
    aws_eks_access_entry.karpenter_node,
  ]
}

# ── EC2NodeClass ──────────────────────────────────────────────────────────────
# Defines AWS-specific node configuration: AMI family, IAM role, and how
# Karpenter discovers subnets and security groups (via the tags we added above).
#
# APPLY ORDER NOTE: kubernetes_manifest resources require the Karpenter CRDs
# (installed by the Helm chart above) to exist before they can be planned.
# On a brand-new cluster run:
#   terraform apply -target=module.eks
#   terraform apply -target=module.karpenter.helm_release.karpenter
#   terraform apply

resource "kubernetes_manifest" "ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      # AL2 resolves to the latest EKS-optimised Amazon Linux 2 AMI via SSM
      amiFamily = "AL2"

      # Karpenter auto-creates and manages the EC2 instance profile for this role
      role = aws_iam_role.karpenter_node.name

      subnetSelectorTerms = [{
        tags = { "karpenter.sh/discovery" = var.cluster_name }
      }]

      securityGroupSelectorTerms = [{
        tags = { "karpenter.sh/discovery" = var.cluster_name }
      }]

      tags = merge(var.tags, {
        "karpenter.sh/discovery" = var.cluster_name
      })
    }
  }

  depends_on = [helm_release.karpenter]
}

# ── NodePool: milvus-spot ─────────────────────────────────────────────────────
# Spot nodes for Milvus workloads — cost-optimised, multiple instance families
# to maximise spot availability. Karpenter consolidates empty nodes after 30s.
# Disruption budget: up to 10% of nodes can be disrupted simultaneously.

resource "kubernetes_manifest" "nodepool_app_spot" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "app-spot"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            role     = "milvus"
            capacity = "spot"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              # Broad instance family selection improves spot availability
              key      = "karpenter.k8s.aws/instance-family"
              operator = "In"
              values   = ["m5", "m5a", "m6i", "r5"]
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = ["xlarge", "2xlarge"]
            },
          ]
          taints = [{
            key    = "workload"
            value  = "milvus"
            effect = "NoSchedule"
          }]
        }
      }
      limits = {
        cpu    = "20"  # ~5x m5.xlarge (4 vCPU) or ~2x m5.2xlarge (8 vCPU)
        memory = "80Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "30s"
        budgets = [{
          nodes = "10%" # at most 10% of spot nodes disrupted at once
        }]
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2_node_class]
}

# ── NodePool: milvus-ondemand ─────────────────────────────────────────────────
# On-demand baseline for Milvus — absorbs spot interruptions and provides
# stable capacity for stateful Milvus components (etcd, MinIO). Conservative
# disruption settings: only scale down when fully empty, 1 node at a time,
# wait 5 minutes before acting.

resource "kubernetes_manifest" "nodepool_app_ondemand" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "app-ondemand"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            role     = "milvus"
            capacity = "ondemand"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.k8s.aws/instance-family"
              operator = "In"
              values   = ["m5"]
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = ["xlarge"]
            },
          ]
          taints = [{
            key    = "workload"
            value  = "milvus"
            effect = "NoSchedule"
          }]
        }
      }
      limits = {
        cpu    = "8"   # ~2x m5.xlarge (4 vCPU each)
        memory = "32Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "5m"
        budgets = [{
          nodes = "1" # only 1 on-demand node may be disrupted at a time
        }]
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2_node_class]
}
