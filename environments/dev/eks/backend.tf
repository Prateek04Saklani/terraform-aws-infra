terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.43"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27"
    }
  }

  backend "s3" {
    bucket         = "techbuid-terraform-state"
    key            = "dev/eks/terraform.tfstate"
    region         = "ap-south-1"
    profile        = "techbuild"
    encrypt        = true
    use_lockfile   = true
  }
}
