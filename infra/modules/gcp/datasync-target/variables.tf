variable "tenant_id" {
  description = "Tenant identifier — used in resource names and labels."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$", var.tenant_id))
    error_message = "tenant_id must be 3-30 chars, lowercase alphanumeric + hyphens (GCP SA name limits)."
  }
}

variable "gcp_project_id" {
  description = "GCP project that hosts the destination bucket."
  type        = string
}

variable "gcp_region" {
  description = "GCS bucket location. Use a multi-region (US, EU, ASIA) or a region (us-east1, etc.)."
  type        = string
  default     = "US"
}

variable "destination_bucket_name" {
  description = "Name of the destination GCS bucket. Must be globally unique."
  type        = string
}

variable "create_bucket" {
  description = <<-EOT
    If true (default), this module creates the destination bucket.
    If false, the module assumes the bucket already exists and only reads it
    via a data source — useful when the bucket is owned by another stack and
    we just need to grant write access + mint an HMAC key.
  EOT
  type    = bool
  default = true
}

variable "enable_apis" {
  description = "Enable required GCP APIs on the project (storage, iam, iamcredentials)."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to created GCP resources."
  type        = map(string)
  default     = {}
}
