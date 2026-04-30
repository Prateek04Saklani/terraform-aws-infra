terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.43"
    }
  }

  backend "s3" {
    bucket         = "techbuid-terraform-state"
    key            = "dev/vpc/terraform.tfstate"
    region         = "ap-south-1"
    use_lockfile   = true
    profile        = "techbuild"
    encrypt        = true
  }
}
