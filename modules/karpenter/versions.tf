terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.43"
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
}
