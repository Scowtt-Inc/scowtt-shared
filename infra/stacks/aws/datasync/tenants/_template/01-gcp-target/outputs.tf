output "destination_bucket_name" {
  description = "Name of the destination GCS bucket. Pass this to the 02-datasync stack."
  value       = module.gcp_target.bucket_name
}

output "destination_bucket_url" {
  value = module.gcp_target.bucket_url
}

output "service_account_email" {
  value = module.gcp_target.service_account_email
}

output "hmac_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret that holds the HMAC key."
  value       = aws_secretsmanager_secret.hmac.arn
}

output "hmac_secret_name" {
  description = "Name of the secret. The 02-datasync stack reads this via data source."
  value       = aws_secretsmanager_secret.hmac.name
}
