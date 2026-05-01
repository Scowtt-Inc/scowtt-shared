# DataSync tenant template

A tenant deployment is two sub-stacks that run in order:

```
<TENANT_ID>/
├── 01-gcp-target/    ← apply first   (google + aws providers)
│   • GCS bucket  • write-only SA  • HMAC key  • AWS secret
│
└── 02-datasync/      ← apply second  (aws provider only)
    • reads the secret  • creates AWS DataSync task + source IAM role
```

Each sub-stack has its own state file. The deployer role's S3 IAM policy is
scoped to `aws/datasync/*`, so both fall inside the policy's blast radius
without one ever being able to mutate the other directly.

**Don't edit files in this `_template/` directory** — they're the source the
scaffolder copies from.

## Onboarding a new tenant

```bash
infra/scripts/new-aws-datasync-tenant.sh <TENANT_ID> <GCP_PROJECT_ID>
# example
infra/scripts/new-aws-datasync-tenant.sh test-deleteme3 test-deleteme3-scowtt
```

That creates `infra/stacks/aws/datasync/tenants/<TENANT_ID>/` with both
sub-stacks pre-wired (`backend.hcl` + `terraform.tfvars` populated).

Apply order:

```bash
cd infra/stacks/aws/datasync/tenants/<TENANT_ID>/01-gcp-target
tofu init -backend-config=backend.hcl
tofu apply
# captures `destination_bucket_name` and `hmac_secret_name`

cd ../02-datasync
tofu init -backend-config=backend.hcl
tofu apply
```

See each sub-stack's README for details:
* [`01-gcp-target/README.md`](./01-gcp-target/README.md)
* [`02-datasync/README.md`](./02-datasync/README.md)
