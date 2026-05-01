# infra

All Scowtt infrastructure-as-code lives here. Per-platform (AWS / GCP /
Google Workspace / Keeper), per-lifecycle (bootstrap / modules / stacks),
delivered through GitHub Actions with short-lived OIDC credentials.

## Layout

```
infra/
├── bootstrap/                 # one-off setup per platform (state backend, OIDC trust)
│   ├── aws/
│   │   ├── 01-state-backend/  # S3 + DynamoDB lock
│   │   ├── 02-oidc-and-roles/ # OIDC IdP + per-role trust + policies
│   │   └── modules/github-oidc-role/   # reusable role+trust factory
│   ├── gcp/                   # placeholder (WIF + state)
│   ├── google-workspace/      # placeholder
│   └── keeper/                # placeholder
├── modules/                   # the TF Catalog — reusable modules
│   └── aws/datasync-s3-to-gcs/
├── stacks/                    # actual deployments
│   └── aws/datasync/tenants/
│       └── _template/         # scaffolded by infra/scripts/new-aws-datasync-tenant.sh
├── catalog/catalog-info.yaml  # Backstage descriptor for the modules
├── scripts/                   # automation helpers
├── docs/                      # operational docs
├── ARCHITECTURE.md            # security & topology — start here
└── ONBOARDING.md              # first-time deploy walkthrough
```

## What to read first

1. [`ARCHITECTURE.md`](./ARCHITECTURE.md) — the security model, threat scenarios, and trust topology.
2. [`ONBOARDING.md`](./ONBOARDING.md) — the chronological steps to bring this up from a brand-new AWS account.
3. The README of whichever stack you're touching.

## State key convention

Every stack writes to `s3://<state-bucket>/<platform>/<workload>/<env>/<scope>/terraform.tfstate`.

Examples in use today:

| Stack | State key |
|---|---|
| AWS bootstrap (state backend) | `aws/bootstrap/01-state-backend/terraform.tfstate` |
| AWS bootstrap (OIDC + roles) | `aws/bootstrap/02-oidc-and-roles/terraform.tfstate` |
| AWS DataSync tenant `tenant-a` | `aws/datasync/dev/tenants/tenant-a/terraform.tfstate` |

This convention is what makes per-stack IAM scoping work — each role's S3
permission is restricted to its own prefix.

< OIDC bootstrap verified 2026-05-01 -->
