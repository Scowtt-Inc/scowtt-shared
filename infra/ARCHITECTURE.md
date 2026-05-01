# Architecture & security model

This document explains *why* `infra/` is shaped the way it is. It's worth a
slow read before you write your first stack.

## Goals

1. **No long-lived credentials.** No engineer holds a permanent AWS key, no
   AWS user account is bound to GitHub Actions. Every cloud session is
   short-lived and minted on demand.
2. **No super-roles.** Each role can do exactly one job in one environment.
3. **No secret material in the repo.** Even though `scowtt-shared` is public,
   reading it gives an attacker zero credentials.
4. **Privilege escalation is structurally impossible.** Even if a deployer
   role is abused, anything it creates inherits a permissions boundary that
   forecloses on lateral movement.
5. **All changes are reviewed.** CODEOWNERS + branch protection + environment
   reviewers gate every apply.

## Trust model

```
                                                          ┌────────────────────┐
GitHub repo Scowtt-Inc/scowtt-shared                       │ AWS account 12345  │
  ──┐                                                      │                    │
    │ workflow run starts                                  │                    │
    ▼                                                      │                    │
┌──────────────────────────────────────────┐               │                    │
│ Runner gets a short JWT signed by GitHub │               │                    │
│   sub:    repo:Scowtt-Inc/scowtt-shared  │               │                    │
│            :environment:aws-datasync-dev │               │                    │
│   aud:    sts.amazonaws.com              │               │                    │
│   owner_id: 234455082                    │               │                    │
└─────────────────────┬────────────────────┘               │                    │
                      │ AssumeRoleWithWebIdentity          │                    │
                      ▼                                    │                    │
                  ┌──────────────────────────────────────────┐                  │
                  │ AWS STS validates JWT against IdP         │                  │
                  │ + the role's trust policy                 │                  │
                  └─────────────────────┬────────────────────┘                  │
                                        ▼                                       │
                  Returns 1-hour creds for                                       │
                  scowtt-gha-datasync-deployer-dev                               │
                                                                                │
                                                          └────────────────────┘
```

The trust policy on every OIDC role enforces three claims simultaneously:

```hcl
StringEquals  aud:                  sts.amazonaws.com
StringEquals  repository_owner_id:  234455082          # numeric Scowtt-Inc ID
StringLike    sub:                  repo:Scowtt-Inc/scowtt-shared:environment:aws-datasync-dev
```

The numeric `repository_owner_id` is the load-bearing one. GitHub org names
can be re-claimed if Scowtt-Inc is ever renamed; numeric IDs cannot. Without
this guard, a same-named impersonator could in theory obtain a token whose
`sub` matches our trust pattern.

## Role catalog

| Role | Purpose | Trust constraint | Permissions |
|---|---|---|---|
| `scowtt-gha-readonly-pr` | tofu plan on PRs | `sub:pull_request` | Read-only AWS, lock+read on state |
| `scowtt-gha-datasync-deployer-dev` | tofu apply for DataSync stacks | `sub:environment:aws-datasync-dev` | DataSync mutate, scoped IAM, scoped state |
| `scowtt-gha-bootstrap-maintainer` | rare bootstrap edits | `sub:environment:aws-bootstrap-maintenance` | IdP + scowtt-* IAM + state backend |

Adding a new workload (say, GCP storage modules) means adding a new role
with its own trust subject and its own scoped policy — never widening an
existing one.

## State isolation

Every stack writes to a unique S3 key under the shared state bucket.
Deployer roles can only read/write the prefix that belongs to their
workload. So:

* `scowtt-gha-datasync-deployer-dev` can read/write `aws/datasync/*` state.
  It **cannot** touch `aws/bootstrap/*` state.
* `scowtt-gha-bootstrap-maintainer` can read/write `aws/bootstrap/*` state.
* The lock table is shared but locks are keyed by full state path, so
  parallel applies for different stacks coexist safely.

## Permissions boundary

The deployer role's IAM permissions allow it to manage `datasync-*` named
roles, but only with the `scowtt-deployer-boundary` permissions boundary
attached. The boundary's deny block forbids `iam:CreateUser`, `organizations:*`,
`kms:ScheduleKeyDeletion`, etc. Even if a deployer were tricked into creating
a wide-open role, that wide-open role can't escape the boundary.

## Threat scenarios

### "What if the repo becomes public (or already is)?"

This repo *is* public. The threat surface that brings is:

| Asset in the repo | Risk if read | Mitigation |
|---|---|---|
| Module/stack source | None — it's intended to be public | n/a |
| Role ARNs in `02-oidc-and-roles/outputs.tf` (after apply) | Exposes account ID, but knowing the ARN doesn't grant access | OIDC trust policy is the gate |
| `terraform.tfvars` (per-tenant) | Tenant IDs and bucket names. Annoying but not a credential | n/a |
| `backend.hcl` per stack | State bucket + key. Useless without role | n/a |
| State files | **Sensitive** — never committed; live in encrypted S3 | bucket policy, no public access |
| HMAC keys, AWS keys, Workspace SA JSON | **Catastrophic** — never committed | live in Secrets Manager / Secret Manager only |

### "What if a user's GitHub PAT is compromised?"

PATs grant access to GitHub, not to AWS. The worst the attacker can do is:

* Push to a branch — but they can't push to `main` directly because of
  branch protection, and they can't merge a PR without a CODEOWNERS reviewer.
* Open a PR — `tofu-plan.yml` runs with the **read-only** PR role, so the
  worst case is the attacker gets to read what we already exposed in the
  state files (via plan output). No mutation.
* Trigger `workflow_dispatch` on apply — they need the `aws-datasync-dev`
  environment, which has required reviewers.

### "What if the readonly-pr role is compromised somehow?"

Worst case: the attacker can read state files for the AWS DataSync prefix.
They can't mutate AWS, can't pivot to other state prefixes, can't read
secrets outside the `datasync/*` Secrets Manager prefix. The blast radius
is the metadata of how DataSync is configured for tenants — which is
already public in this repo.

### "What if the deployer-dev role is compromised?"

Two layers protect against this:

1. The role is only assumable from inside the `aws-datasync-dev` environment.
   Triggering an apply requires a CODEOWNERS-approved PR merge **plus** an
   environment reviewer's explicit click. Both are recorded in audit logs.
2. Even if the role is somehow assumed, its permissions are scoped: only
   DataSync resources, only `datasync-*` IAM, only state under `aws/datasync/*`,
   only Secrets under `datasync/*`. It can't pivot to other workloads.

### "What if a Scowtt employee turns malicious?"

* They cannot apply directly — every apply needs a separate environment
  reviewer (segregation of duties).
* They cannot rewrite history — branch protection requires force-push
  permission, which only platform-admins have.
* They cannot widen the deployer role without a `infra/bootstrap/`
  PR, which is CODEOWNERS-gated to `@Scowtt-Inc/platform-admins`.
* CloudTrail records every assume-role and every API call, and is shipped
  to a separate logging account (set up alongside the prod state backend).

### "What if state is exfiltrated?"

State files contain secrets when a module reads from Secrets Manager — that
fact is the reason the state bucket is encrypted at rest, has versioning,
public access blocked, and a `Deny aws:SecureTransport=false` policy. To
exfiltrate state you need the deployer or readonly role and you need to
egress AWS — neither is invisible.

## Short-lived everything

* OIDC tokens last ~5 minutes.
* The AWS sessions minted from them last `max_session_duration` (set to 1 hour).
  You can drop this to 30 minutes if your apply runs are short — the role
  won't accept anything below 3600s in the AWS API today, but session lifetime
  in `configure-aws-credentials` action is a separate parameter
  (`role-duration-seconds`) you can tighten further.
* Secrets Manager values are read at apply-time and never persist on the runner.
* GitHub Action runners are ephemeral VMs — once the run ends, anything in
  the runner's memory is gone.

## What we deliberately don't do

* **No long-lived AWS access keys**, anywhere. If you find one, it's a bug.
* **No `terraform.tfvars` with secrets.** Secrets always come from Secrets
  Manager (AWS) or Secret Manager (GCP) via data sources at apply time.
* **No PAT-based GitHub auth from CI to AWS.** OIDC only.
* **No shared deployer roles across workloads.** Each workload gets its own.

## Future controls we should add

* **AWS CloudTrail Lake** with anomaly alerts on unusual `AssumeRoleWithWebIdentity`
  patterns.
* **AWS GuardDuty** with alerts to a security channel.
* **AWS Config** rules that flag any role created outside `infra/`.
* **Signed commits required on `main`** (Settings → Branches → "Require signed commits").
* **Dependabot** for `actions/*` updates and `aws-actions/*` updates.
