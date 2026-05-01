output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "deployer_boundary_arn" {
  description = "Permissions boundary that all roles created by deployers MUST attach."
  value       = aws_iam_policy.deployer_boundary.arn
}

# ----- Role ARNs you wire into GitHub repo variables -----

output "readonly_pr_role_arn" {
  description = "AWS_ROLE_PR_PLAN — assumed by tofu-plan.yml on pull_request."
  value       = module.role_readonly_pr.role_arn
}

output "datasync_deployer_dev_role_arn" {
  description = "AWS_ROLE_DATASYNC_DEPLOYER_DEV — assumed by tofu-apply.yml in env aws-datasync-dev."
  value       = module.role_datasync_deployer_dev.role_arn
}

output "bootstrap_maintainer_role_arn" {
  description = "AWS_ROLE_BOOTSTRAP_MAINTAINER — assumed by manual maintenance runs."
  value       = module.role_bootstrap_maintainer.role_arn
}
