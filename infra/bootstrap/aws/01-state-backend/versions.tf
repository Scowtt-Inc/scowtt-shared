terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0"
    }
  }

  # Intentionally NO backend block — this stack creates the backend.
  # On first apply state is local. After apply, run:
  #   tofu init -migrate-state -backend-config=backend.hcl
  # to push state to the bucket created here.
}
