output "state_bucket_name" {
  description = "S3 bucket holding all OpenTofu state for the repo."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  value = aws_s3_bucket.tfstate.arn
}

output "state_lock_table_name" {
  value = aws_dynamodb_table.tfstate_lock.name
}

output "state_lock_table_arn" {
  value = aws_dynamodb_table.tfstate_lock.arn
}
