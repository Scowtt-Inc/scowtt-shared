terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0" # task_mode = "ENHANCED" requires >= 5.60
    }
  }
}
