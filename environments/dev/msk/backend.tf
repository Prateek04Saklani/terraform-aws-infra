terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.43"
    }
  }

  backend "s3" {
    bucket  = "your-tf-state-bucket"
    key     = "dev/msk/terraform.tfstate"
    region  = "us-east-1"
    profile = ""
    encrypt = true

    # S3 native state locking — no DynamoDB table required (Terraform >= 1.6)
    use_lockfile = true
  }
}
