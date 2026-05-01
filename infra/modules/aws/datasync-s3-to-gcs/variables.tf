variable "tenant_id" {
  description = "Unique tenant identifier. Used as the S3 source prefix and in resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$", var.tenant_id))
    error_message = "tenant_id must be 3-64 chars, lowercase alphanumeric + hyphens, and start/end alphanumeric."
  }
}

variable "name_prefix" {
  description = "Prefix for all created resource names. Defaults to 'datasync-<tenant_id>'."
  type        = string
  default     = null
}

# ---------- Source (AWS S3) ----------

variable "source_s3_bucket_arn" {
  description = "ARN of the source S3 bucket (e.g. arn:aws:s3:::scowtt-crm-data-bucket-dev)."
  type        = string
}

variable "source_subdirectory" {
  description = "Subdirectory inside the source bucket. Defaults to '/<tenant_id>'. Must start with '/'."
  type        = string
  default     = null
}

# ---------- Destination (GCS via S3 interop) ----------

variable "destination_bucket_name" {
  description = "Name of the destination GCS bucket (no scheme, no path). Example: 'tenant-a-crm-sync'."
  type        = string
}

variable "destination_subdirectory" {
  description = "Subdirectory inside the destination GCS bucket. Must start with '/'."
  type        = string
  default     = "/"
}

variable "gcs_interop_endpoint" {
  description = "GCS S3-interoperability endpoint hostname."
  type        = string
  default     = "storage.googleapis.com"
}

variable "gcs_hmac_access_key_id" {
  description = "HMAC access key ID for the destination GCS service account (write-only perms)."
  type        = string
  sensitive   = true
}

variable "gcs_hmac_secret_access_key" {
  description = "HMAC secret access key for the destination GCS service account."
  type        = string
  sensitive   = true
}

# ---------- Task ----------

variable "task_mode" {
  description = "DataSync task mode. ENHANCED supports agentless S3-to-object-storage transfers."
  type        = string
  default     = "ENHANCED"

  validation {
    condition     = contains(["BASIC", "ENHANCED"], var.task_mode)
    error_message = "task_mode must be BASIC or ENHANCED."
  }
}

variable "schedule_expression" {
  description = "DataSync task schedule (rate or cron expression)."
  type        = string
  default     = "rate(1 hour)"
}

variable "agent_arns" {
  description = <<-EOT
    DataSync agent ARNs. ENHANCED-mode tasks transferring between S3 and
    object storage are agentless — leave empty. BASIC mode requires at
    least one agent ARN.
  EOT
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Retention for the CloudWatch log group used by the DataSync task."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to all created resources."
  type        = map(string)
  default     = {}
}
