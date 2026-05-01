variable "role_name" {
  description = "IAM role name. Must be unique in the account."
  type        = string
}

variable "role_description" {
  description = "Human-readable description shown in IAM console."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider in this account."
  type        = string
}

variable "github_owner_id" {
  description = <<-EOT
    Numeric GitHub organization (or user) ID. Adds an aud-independent
    StringEquals guard to the trust policy so the role can never be assumed
    by a same-named org/user that's not yours. Find it via:
        gh api orgs/<ORG_NAME> -q .id
        # or for a user
        gh api users/<USER_NAME> -q .id
  EOT
  type        = string
}

variable "github_org" {
  description = "GitHub org/user that owns the repo (used to construct sub claims)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name (no org prefix)."
  type        = string
}

variable "trust_pull_request" {
  description = "If true, the role can be assumed by jobs running on a pull_request event from this repo."
  type        = bool
  default     = false
}

variable "trust_branches" {
  description = "Branches in the repo whose workflow runs can assume the role. Empty disables branch-based trust."
  type        = list(string)
  default     = []
}

variable "trust_environments" {
  description = <<-EOT
    GitHub Environment names whose workflow runs can assume the role.
    Strongly recommended for any role with write access — environments
    can require human approval and limit which branches deploy them.
    Example: ["aws-datasync-dev"].
  EOT
  type        = list(string)
  default     = []
}

variable "trust_tags" {
  description = "Tag refs (vN.M.P) whose workflow runs can assume the role. Empty disables tag-based trust."
  type        = list(string)
  default     = []
}

variable "policy_jsons" {
  description = "List of inline IAM policy JSON documents attached to the role."
  type        = list(string)
}

variable "permissions_boundary_arn" {
  description = "Optional managed policy used as the role's permissions boundary."
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Maximum credential lifetime (seconds) for sessions assumed via this role. AWS minimum is 3600."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags applied to the role."
  type        = map(string)
  default     = {}
}
