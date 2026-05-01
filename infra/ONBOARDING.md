# Onboarding — first deployment

This is the chronological path from "fresh AWS account, empty `infra/` tree"
to "first DataSync tenant syncing every hour." Steps are strictly ordered;
each one's outputs are inputs to the next.

If you just want to add a new tenant to an already-bootstrapped repo, jump
to **Phase 4**.

> Read [`ARCHITECTURE.md`](./ARCHITECTURE.md) first if you haven't.

---

## Prerequisites

Run once, before phase 1. Everything else can be done after.

* **AWS account** with admin (or admin-equivalent) access for the human doing
  the bootstrap. AWS Identity Center / SSO is recommended over IAM users.
* **OpenTofu** ≥ 1.6 installed locally (`brew install opentofu` or
  https://opentofu.org/docs/intro/install/).
* **GitHub CLI** (`gh`) installed and logged into Scowtt-Inc.
* **GitHub teams** created in the org:
  * `@Scowtt-Inc/platform-admins`
  * `@Scowtt-Inc/aws-leads`
  * `@Scowtt-Inc/gcp-leads` (placeholder — fine to create empty)
  * `@Scowtt-Inc/workspace-admins`
  * `@Scowtt-Inc/security-leads`
  These are the names referenced by `.github/CODEOWNERS`. Without them, the
  CODEOWNERS file evaluates to "no owners" and any contributor can self-merge.
* **Branch protection on `main`** (Settings → Branches → Add rule):
  * Require pull request before merging
  * Require approvals: 1
  * Require review from Code Owners
  * Require status checks: `tofu-plan`, `gitleaks`, `tfsec`, `tflint`
  * Require linear history (recommended)
  * Restrict who can push to matching branches: `@Scowtt-Inc/platform-admins`
* **GitHub org numeric ID:** `gh api orgs/Scowtt-Inc -q .id` — keep this
  for phase 2.

---

## Phase 1 — Provision the AWS state backend (one-time, manual)

```bash
cd infra/bootstrap/aws/01-state-backend

cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars                  # set state_bucket_name (must be globally unique)

# Authenticate as a human admin
aws sso login --profile scowtt-admin
export AWS_PROFILE=scowtt-admin

tofu init                                  # local state for first apply
tofu apply                                  # review carefully, type 'yes'

# Capture for phase 2
tofu output -raw state_bucket_name         # → e.g. scowtt-tfstate-prod
tofu output -raw state_lock_table_name     # → scowtt-tfstate-locks
```

Then push this stack's own state into the bucket it just created:

```bash
cp backend.hcl.example backend.hcl
$EDITOR backend.hcl                        # bucket name must match
tofu init -migrate-state -backend-config=backend.hcl
# Confirm 'yes'. Local terraform.tfstate is now redundant — delete it.
rm terraform.tfstate*
```

---

## Phase 2 — Provision OIDC + the three roles (one-time, manual)

```bash
cd ../02-oidc-and-roles

cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
# Required values:
#   github_owner_id   = "<gh api orgs/Scowtt-Inc -q .id>"
#   state_bucket_name = "<from phase 1>"

cp backend.hcl.example backend.hcl
$EDITOR backend.hcl                        # bucket name must match phase 1

tofu init -backend-config=backend.hcl
tofu apply

# These three values go into GitHub repo variables in phase 3
tofu output -raw readonly_pr_role_arn
tofu output -raw datasync_deployer_dev_role_arn
tofu output -raw bootstrap_maintainer_role_arn
```

---

## Phase 3 — Wire GitHub (one-time, manual, in the GitHub UI)

### 3a. Repository variables

**Settings → Secrets and variables → Actions → Variables → New repository variable**

| Variable | Value |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `AWS_ROLE_PR_PLAN` | `readonly_pr_role_arn` from phase 2 |
| `AWS_ROLE_DATASYNC_DEPLOYER_DEV` | `datasync_deployer_dev_role_arn` from phase 2 |
| `AWS_ROLE_BOOTSTRAP_MAINTAINER` | `bootstrap_maintainer_role_arn` from phase 2 |

These are *variables*, not secrets — they're not sensitive (the trust policy
on the role is what gates access).

### 3b. Environments

**Settings → Environments → New environment**

| Environment | Required reviewers | Why |
|---|---|---|
| `aws-datasync-dev` | `@Scowtt-Inc/aws-leads` | Pause every apply for human approval |
| `aws-bootstrap-maintenance` | `@Scowtt-Inc/platform-admins` | Even tighter — bootstrap edits |

You can also restrict which branches can deploy to each environment under
"Deployment branches" — pin to `main` only.

### 3c. Branch protection

Already in prereqs. Verify it's actually on by trying to push to `main`
directly — it should fail.

---

## Phase 4 — Onboard your first tenant

### 4a. GCP side (per tenant)

Follow [`docs/gcp-tenant-setup.md`](./docs/gcp-tenant-setup.md). The end
state is an HMAC `access_key_id` + `secret_access_key` for a service
account that holds **only** `roles/storage.objectCreator` on the
destination bucket.

### 4b. Store the HMAC pair in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --region us-east-1 \
  --name datasync/tenant-a/gcs-hmac \
  --description "GCS HMAC for tenant-a (write-only)" \
  --secret-string '{"access_key_id":"GOOG1E...","secret_access_key":"..."}'
```

### 4c. Scaffold the stack

```bash
cd <repo-root>
infra/scripts/new-aws-datasync-tenant.sh tenant-a tenant-a-crm-sync

git checkout -b onboard-tenant-a
git add infra/stacks/aws/datasync/tenants/tenant-a
git commit -m "Onboard tenant tenant-a"
git push -u origin onboard-tenant-a
gh pr create --fill
```

### 4d. Watch the workflow

Open the PR's **Checks** tab — `tofu-plan` runs. Review the plan in the
job summary. Get an `@Scowtt-Inc/aws-leads` reviewer on the PR.

### 4e. Merge and apply

Merge the PR. `tofu-apply` triggers but pauses on the
`aws-datasync-dev` environment gate. An `@Scowtt-Inc/aws-leads` reviewer
clicks **Approve and deploy**. Apply runs.

After ~30s the DataSync task exists. First scheduled run kicks off within
the hour.

---

## Phase 5 — Verify

```bash
# From your laptop, with read access to the dev account:
aws datasync list-tasks --region us-east-1
aws datasync describe-task --task-arn <arn-from-output> --region us-east-1
aws logs tail /aws/datasync/datasync-tenant-a --region us-east-1 --follow
```

Or in the AWS Console: DataSync → Tasks → tenant task → Execution history.

---

## Adding a second tenant

You don't need phases 1–3 again. Just:

1. Phase 4a — GCP setup for the new tenant.
2. Phase 4b — store the new HMAC pair in Secrets Manager.
3. Phase 4c — `infra/scripts/new-aws-datasync-tenant.sh tenant-b tenant-b-crm-sync`.
4. PR + review + merge + environment approval.

---

## Adding a new workload (not just a tenant)

Example: you want to start managing GCP resources, or a new AWS service.

1. PR `infra/bootstrap/aws/02-oidc-and-roles/main.tf` to add a new role
   (e.g. `scowtt-gha-gcp-deployer-dev`). Use the `github-oidc-role` module —
   one new `module` block plus a tightly scoped policy.
2. Get a `@Scowtt-Inc/platform-admins` review (CODEOWNERS enforces this).
3. Apply via the `aws-bootstrap-maintenance` environment.
4. Add a new GitHub repo variable for the new role ARN.
5. Add a new workflow (or extend an existing one) that uses
   `aws-actions/configure-aws-credentials` with the new role.

This pattern — one role per workload, never a wider existing one — keeps
each blast radius small as the repo grows.
