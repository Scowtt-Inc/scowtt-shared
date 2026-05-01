# AWS bootstrap

Two stacks in deliberate order:

| Stack | What it creates | Where state lives |
|---|---|---|
| `01-state-backend/` | Encrypted, versioned, deletion-protected S3 bucket + DynamoDB lock table | local first, then migrated into the bucket it just created |
| `02-oidc-and-roles/` | GitHub OIDC IdP, permissions boundary, three OIDC roles | `aws/bootstrap/02-oidc-and-roles/terraform.tfstate` |

Plus the reusable [`modules/github-oidc-role`](./modules/github-oidc-role) used
by `02-oidc-and-roles/` to create one role per purpose.

## Roles created by `02-oidc-and-roles`

| Role name | Trust | What it can do |
|---|---|---|
| `scowtt-gha-readonly-pr` | `pull_request` events from `Scowtt-Inc/scowtt-shared` only | Read-only on DataSync, IAM, Logs, Secrets; read+lock on the state key prefix `aws/datasync/*` |
| `scowtt-gha-datasync-deployer-dev` | Workflow runs **inside the `aws-datasync-dev` GitHub Environment** only | Full DataSync; manage `datasync-*` IAM roles **only with the deployer permissions boundary attached**; read+write state under `aws/datasync/*` |
| `scowtt-gha-bootstrap-maintainer` | Workflow runs inside the `aws-bootstrap-maintenance` Environment only | Manage IdP, scowtt-* IAM roles/policies, state backend stack |

Trust scoping — every role's trust policy enforces:

1. `aud == sts.amazonaws.com`
2. `repository_owner_id == <numeric Scowtt-Inc id>` (prevents same-name org spoofing)
3. `sub` matches the role's specific event pattern (PR / environment / branch / tag)

So a leaked `repo:Scowtt-Inc/scowtt-shared:pull_request` token cannot assume
the deployer role even if it tried, and a leaked deployer-environment token
can't be obtained without an environment reviewer approving the apply run.

## First-time apply

```bash
cd infra/bootstrap/aws/01-state-backend
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars        # set state_bucket_name to something unique

# Authenticate locally (admin or Identity Center role)
aws sso login --profile scowtt-admin
export AWS_PROFILE=scowtt-admin

tofu init                       # local state on first apply
tofu apply
tofu output -raw state_bucket_name
tofu output -raw state_lock_table_name

# Migrate state into the bucket we just created
cp backend.hcl.example backend.hcl
$EDITOR backend.hcl             # update bucket name to match terraform.tfvars
tofu init -migrate-state -backend-config=backend.hcl
```

```bash
cd ../02-oidc-and-roles
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars        # github_owner_id, state_bucket_name

cp backend.hcl.example backend.hcl
$EDITOR backend.hcl             # match the same bucket

tofu init -backend-config=backend.hcl
tofu apply

# These are the values you paste into GitHub repo variables:
tofu output -raw readonly_pr_role_arn
tofu output -raw datasync_deployer_dev_role_arn
tofu output -raw bootstrap_maintainer_role_arn
```

## Subsequent updates

Updates to `02-oidc-and-roles/` go through GitHub Actions in the
`aws-bootstrap-maintenance` environment. **Do not run them locally.** Locally
applying bootstrap is reserved for the very first apply and unbreaking
emergencies.
