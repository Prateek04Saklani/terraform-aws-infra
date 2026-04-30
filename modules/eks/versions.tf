terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.43"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}
