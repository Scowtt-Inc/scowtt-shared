variable "aws_region" {
  description = "Region the state bucket and lock table live in."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for OpenTofu state."
  type        = string
}

variable "state_lock_table_name" {
  description = "DynamoDB table name for OpenTofu state locks."
  type        = string
  default     = "scowtt-tfstate-locks"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    "managed-by" = "opentofu"
    "stack"      = "bootstrap/aws/01-state-backend"
    "repo"       = "Scowtt-Inc/scowtt-shared"
  }
}
