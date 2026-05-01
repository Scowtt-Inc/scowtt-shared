locals {
  # Build the list of allowed sub claims from the configurable trust flags.
  sub_branches     = [for b in var.trust_branches : "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${b}"]
  sub_tags         = [for t in var.trust_tags : "repo:${var.github_org}/${var.github_repo}:ref:refs/tags/${t}"]
  sub_environments = [for e in var.trust_environments : "repo:${var.github_org}/${var.github_repo}:environment:${e}"]
  sub_pull_request = var.trust_pull_request ? ["repo:${var.github_org}/${var.github_repo}:pull_request"] : []

  trusted_subs = concat(local.sub_branches, local.sub_tags, local.sub_environments, local.sub_pull_request)
}

# Refuse to create a role with no trust at all — that would be a bug.
resource "terraform_data" "trust_guard" {
  triggers_replace = {
    n = length(local.trusted_subs)
  }

  lifecycle {
    precondition {
      condition     = length(local.trusted_subs) > 0
      error_message = "github-oidc-role: at least one of trust_pull_request / trust_branches / trust_environments / trust_tags must be set."
    }
  }
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Standard audience check.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Hard-pin the GitHub owner numeric ID. Prevents another GitHub org with
    # the same name from impersonating us if our org ever changes name.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository_owner_id"
      values   = [var.github_owner_id]
    }

    # Allowed sub patterns — branch, environment, tag, or pull_request.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.trusted_subs
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.role_description
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(
    {
      "managed-by" = "opentofu"
      "module"     = "github-oidc-role"
    },
    var.tags,
  )

  depends_on = [terraform_data.trust_guard]
}

resource "aws_iam_role_policy" "this" {
  count  = length(var.policy_jsons)
  name   = "${var.role_name}-policy-${count.index}"
  role   = aws_iam_role.this.id
  policy = var.policy_jsons[count.index]
}
