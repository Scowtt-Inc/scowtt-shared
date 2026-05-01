output "bucket_name" {
  description = "Name of the destination GCS bucket."
  value       = local.bucket_name
}

output "bucket_url" {
  description = "gs:// URL of the destination GCS bucket."
  value       = "gs://${local.bucket_name}"
}

output "service_account_email" {
  description = "Email of the write-only service account whose HMAC key DataSync uses."
  value       = google_service_account.writer.email
}

output "hmac_access_key_id" {
  description = "HMAC access ID. Treated as non-sensitive (analogous to an AWS access key ID)."
  value       = google_storage_hmac_key.this.access_id
}

output "hmac_secret_access_key" {
  description = "HMAC secret. Sensitive — pipe this directly into AWS Secrets Manager."
  value       = google_storage_hmac_key.this.secret
  sensitive   = true
}
