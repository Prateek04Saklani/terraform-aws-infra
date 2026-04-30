provider "aws" {
  region  = "me-south-1"
  profile = "techbuild"
}

# Helm and Kubernetes providers authenticate to the EKS cluster via the AWS CLI
# token exec plugin. The cluster must exist before these providers are usable,
# which is why the first-time apply is staged (see main.tf for ordering notes).

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "me-south-1"]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "me-south-1"]
  }
}
