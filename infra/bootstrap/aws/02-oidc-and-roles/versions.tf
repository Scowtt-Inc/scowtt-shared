terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0"
    }
  }

  # Backend configured via backend.hcl (uses the bucket from 01-state-backend).
  backend "s3" {}
}
