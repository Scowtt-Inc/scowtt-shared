output "role_arn" {
  description = "ARN of the created role. Pass into GitHub repo variables."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  value = aws_iam_role.this.name
}

output "trusted_subs" {
  description = "Resolved list of OIDC sub claims this role trusts. Use to debug 'AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity'."
  value       = local.trusted_subs
}
