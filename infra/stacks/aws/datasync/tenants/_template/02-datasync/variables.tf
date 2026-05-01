variable "tenant_id" {
  description = "Tenant identifier — must match the value used in 01-gcp-target."
  type        = string
}

variable "environment" {
  description = "Deployment environment tag."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "source_s3_bucket_arn" {
  description = "ARN of the source S3 bucket DataSync reads from."
  type        = string
  default     = "arn:aws:s3:::scowtt-crm-data-bucket-dev"
}

variable "destination_bucket_name" {
  description = "Destination GCS bucket name (output of 01-gcp-target.destination_bucket_name)."
  type        = string
}

variable "hmac_secret_name" {
  description = "Name of the AWS Secrets Manager secret holding the HMAC key (output of 01-gcp-target.hmac_secret_name)."
  type        = string
}
