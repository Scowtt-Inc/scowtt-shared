variable "tenant_id" {
  description = "Tenant identifier."
  type        = string
}

variable "environment" {
  description = "Deployment environment tag (dev/staging/prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Region for AWS Secrets Manager."
  type        = string
  default     = "us-east-1"
}

variable "gcp_project_id" {
  description = "GCP project that hosts the destination bucket."
  type        = string
}

variable "gcp_region" {
  description = "GCS bucket location (multi-region or region)."
  type        = string
  default     = "US"
}

variable "destination_bucket_name" {
  description = "Name of the destination GCS bucket — globally unique."
  type        = string
}

variable "create_bucket" {
  description = "True = this stack creates the bucket. False = bucket already exists."
  type        = bool
  default     = true
}
