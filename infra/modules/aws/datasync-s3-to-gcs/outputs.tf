output "task_arn" {
  description = "ARN of the DataSync task."
  value       = aws_datasync_task.this.arn
}

output "task_name" {
  description = "Name of the DataSync task."
  value       = aws_datasync_task.this.name
}

output "source_location_arn" {
  description = "ARN of the S3 source location."
  value       = aws_datasync_location_s3.source.arn
}

output "destination_location_arn" {
  description = "ARN of the GCS (object storage) destination location."
  value       = aws_datasync_location_object_storage.destination.arn
}

output "source_role_arn" {
  description = "ARN of the auto-generated source IAM role assumed by DataSync."
  value       = aws_iam_role.source.arn
}

output "log_group_name" {
  description = "CloudWatch log group receiving DataSync transfer logs."
  value       = aws_cloudwatch_log_group.task.name
}
