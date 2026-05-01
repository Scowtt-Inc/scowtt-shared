variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_org" {
  description = "GitHub org/user owning this repo."
  type        = string
}

variable "github_repo" {
  description = "Repo name."
  type        = string
  default     = "scowtt-shared"
}

variable "github_owner_id" {
  description = "Numeric GitHub owner ID (gh api orgs/<ORG> -q .id)."
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the OpenTofu state bucket from stack 01-state-backend."
  type        = string
}

variable "state_lock_table_name" {
  description = "Name of the lock table from stack 01-state-backend."
  type        = string
}

variable "source_s3_bucket_arn" {
  description = "ARN of the source S3 bucket DataSync reads from."
  type        = string
  default     = "arn:aws:s3:::scowtt-crm-data-bucket-dev"
}

variable "tags" {
  type = map(string)
  default = {
    "managed-by" = "opentofu"
    "stack"      = "bootstrap/aws/02-oidc-and-roles"
    "repo"       = "Scowtt-Inc/scowtt-shared"
  }
}
