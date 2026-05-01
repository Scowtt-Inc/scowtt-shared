provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

data "aws_caller_identity" "this" {}
data "aws_partition" "this" {}

locals {
  account_id = data.aws_caller_identity.this.account_id
  partition  = data.aws_partition.this.partition

  state_bucket_arn = "arn:${local.partition}:s3:::${var.state_bucket_name}"
  lock_table_arn   = "arn:${local.partition}:dynamodb:${var.aws_region}:${local.account_id}:table/${var.state_lock_table_name}"
}

# ===========================================================================
# GitHub Actions OIDC identity provider (created exactly once per account).
# ===========================================================================

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # Provided for clients that still verify thumbprints. AWS performs library-
  # based validation of GitHub's certificate chain regardless.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ===========================================================================
# Permissions boundary applied to ROLES THE DEPLOYERS CREATE.
# Even if a deployer role were abused, any role it spawns can't escape this.
# ===========================================================================

data "aws_iam_policy_document" "deployer_boundary" {
  # Allow the workload's own working set: DataSync, Logs, S3 read on source,
  # Secrets read for HMAC. Anything else (notably iam:CreateUser, ec2:*,
  # organizations:*, sts:AssumeRole on cross-account roles) is implicitly denied.
  statement {
    effect = "Allow"
    actions = [
      "datasync:*",
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:ListTagsForResource",
      "logs:PutResourcePolicy",
      "logs:DeleteResourcePolicy",
      "logs:DescribeResourcePolicies",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetObject",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "iam:GetRole",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
    ]
    resources = ["*"]
  }

  # Explicit denies — defense in depth.
  statement {
    sid       = "DenyIamUserOps"
    effect    = "Deny"
    actions   = ["iam:CreateUser", "iam:CreateAccessKey", "iam:DeleteUser", "iam:UpdateUser"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyOrganizationsAndAccount"
    effect    = "Deny"
    actions   = ["organizations:*", "account:*", "billing:*"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyKmsAdmin"
    effect    = "Deny"
    actions   = ["kms:ScheduleKeyDeletion", "kms:Disable*", "kms:CancelKeyDeletion"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deployer_boundary" {
  name        = "scowtt-deployer-boundary"
  description = "Permissions boundary applied to all roles created by GHA deployer roles."
  policy      = data.aws_iam_policy_document.deployer_boundary.json
}

# ===========================================================================
# Policy fragments shared by deployer + readonly roles.
# All state access scoped to the AWS DataSync state-key prefix.
# ===========================================================================

data "aws_iam_policy_document" "state_access_full" {
  statement {
    sid     = "ListStateBucket"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["aws/datasync/*"]
    }
  }

  statement {
    sid    = "ReadWriteOwnStateKeys"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${local.state_bucket_arn}/aws/datasync/*"]
  }

  statement {
    sid    = "Locks"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [local.lock_table_arn]
  }
}

data "aws_iam_policy_document" "state_access_readonly" {
  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["aws/datasync/*"]
    }
  }

  statement {
    sid       = "ReadOwnStateKeys"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket_arn}/aws/datasync/*"]
  }

  # Plan still acquires/releases a lock — narrowly scoped here, no UpdateItem.
  statement {
    sid    = "PlanLocks"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [local.lock_table_arn]
  }
}

# ===========================================================================
# Workload write policy — DataSync mutations.
# Scoped to the datasync-* role naming convention via iam:PassRole condition.
# ===========================================================================

data "aws_iam_policy_document" "datasync_write" {
  statement {
    sid       = "DataSyncFull"
    effect    = "Allow"
    actions   = ["datasync:*"]
    resources = ["*"]
  }

  statement {
    sid    = "ManageModuleRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
    ]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/datasync-*"]

    # Force the boundary to be set on every created role — privilege escalation
    # via "create a role without my boundary" is structurally impossible.
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.deployer_boundary.arn]
    }
  }

  statement {
    sid       = "PassDataSyncRoleToService"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:${local.partition}:iam::${local.account_id}:role/datasync-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["datasync.amazonaws.com"]
    }
  }

  statement {
    sid    = "CWLogsForDataSync"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:ListTagsForResource",
      "logs:PutResourcePolicy",
      "logs:DeleteResourcePolicy",
      "logs:DescribeResourcePolicies",
    ]
    resources = ["*"]
  }

  # Source-bucket S3 read access intentionally lives in the auto-generated
  # source IAM role created per-tenant by modules/aws/datasync-s3-to-gcs.
  # The deployer role doesn't read the source bucket directly — it just
  # creates DataSync resources via the DataSync API.

  statement {
    sid    = "ManageDataSyncHmacSecrets"
    effect = "Allow"
    actions = [
      # Read (used by 02-datasync stack and by plan refresh)
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
      # Write (used by 01-gcp-target stack to mirror the HMAC)
      "secretsmanager:UpdateSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:DeleteSecret",
      "secretsmanager:RestoreSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
    ]
    resources = [
      "arn:${local.partition}:secretsmanager:${var.aws_region}:${local.account_id}:secret:datasync/*",
    ]
  }

  # CreateSecret has no resource yet at API call time, so it's scoped via
  # a name condition rather than a resource ARN.
  statement {
    sid       = "CreateDataSyncHmacSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:CreateSecret"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "secretsmanager:Name"
      values   = ["datasync/*"]
    }
  }
}

data "aws_iam_policy_document" "datasync_read" {
  # PR plans need to refresh state from real AWS — read-only on the workload.
  statement {
    sid    = "DescribeReadOnlyAws"
    effect = "Allow"
    actions = [
      "datasync:Describe*",
      "datasync:List*",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRoleTags",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "logs:DescribeResourcePolicies",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetObject",
    ]
    resources = ["*"]
  }

  # Secrets refresh — scoped to datasync/* only, so a leaked PR-plan token
  # can never read other workloads' secrets (e.g. a db master password).
  statement {
    sid    = "ReadDataSyncSecretsForPlanRefresh"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = [
      "arn:${local.partition}:secretsmanager:${var.aws_region}:${local.account_id}:secret:datasync/*",
    ]
  }

  # Listing is by definition account-wide, but ListSecrets returns no values.
  statement {
    sid       = "ListSecretsAccountWide"
    effect    = "Allow"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }
}

# ===========================================================================
# Role 1: PR-only readonly. Used by tofu-plan.yml on pull_request.
# ===========================================================================

module "role_readonly_pr" {
  source = "../modules/github-oidc-role"

  role_name        = "scowtt-gha-readonly-pr"
  role_description = "Read-only AWS access for tofu plan on pull requests in scowtt-shared."

  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  github_owner_id   = var.github_owner_id
  github_org        = var.github_org
  github_repo       = var.github_repo

  trust_pull_request = true

  policy_jsons = [
    data.aws_iam_policy_document.datasync_read.json,
    data.aws_iam_policy_document.state_access_readonly.json,
  ]

  max_session_duration = 3600
}

# ===========================================================================
# Role 2: per-environment deployer. Used by tofu-apply.yml after env approval.
# Only assumable when the workflow is running in environment 'aws-datasync-dev'.
# ===========================================================================

module "role_datasync_deployer_dev" {
  source = "../modules/github-oidc-role"

  role_name        = "scowtt-gha-datasync-deployer-dev"
  role_description = "Apply DataSync changes in the dev environment of scowtt-shared."

  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  github_owner_id   = var.github_owner_id
  github_org        = var.github_org
  github_repo       = var.github_repo

  trust_environments = ["aws-datasync-dev"]

  policy_jsons = [
    data.aws_iam_policy_document.datasync_write.json,
    data.aws_iam_policy_document.state_access_full.json,
  ]

  max_session_duration = 3600
}

# ===========================================================================
# Role 3: bootstrap maintainer. For humans (or a manually-dispatched workflow)
# updating bootstrap/. Restricted to a special 'bootstrap-maintenance' env so
# even committers can't trigger it without explicit env approval.
# ===========================================================================

data "aws_iam_policy_document" "bootstrap_maintainer" {
  # Broad: managing IdP, bootstrap roles, and state backend stack.
  # Still constrained to bootstrap-relevant resources.
  statement {
    effect = "Allow"
    actions = [
      "iam:*",
    ]
    resources = [
      "arn:${local.partition}:iam::${local.account_id}:role/scowtt-gha-*",
      "arn:${local.partition}:iam::${local.account_id}:role/scowtt-bootstrap-*",
      "arn:${local.partition}:iam::${local.account_id}:policy/scowtt-*",
      "arn:${local.partition}:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:GetOpenIDConnectProvider", "iam:ListOpenIDConnectProviders", "iam:ListPolicies", "iam:ListRoles"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:*", "dynamodb:*"]
    resources = [
      local.state_bucket_arn,
      "${local.state_bucket_arn}/aws/bootstrap/*",
      local.lock_table_arn,
    ]
  }
}

module "role_bootstrap_maintainer" {
  source = "../modules/github-oidc-role"

  role_name        = "scowtt-gha-bootstrap-maintainer"
  role_description = "Apply changes to infra/bootstrap/aws stacks. Gated by environment 'aws-bootstrap-maintenance'."

  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  github_owner_id   = var.github_owner_id
  github_org        = var.github_org
  github_repo       = var.github_repo

  trust_environments = ["aws-bootstrap-maintenance"]

  policy_jsons = [data.aws_iam_policy_document.bootstrap_maintainer.json]

  max_session_duration = 3600
}
