# GCP-side setup (per tenant)

> **All GCP-side resources are codified.** You don't run `gcloud` to create
> them — running `tofu apply` in the tenant's `01-gcp-target` sub-stack does
> everything described below.
>
> This doc still exists so you can verify by hand what got created and
> understand why each piece is there.

The `01-gcp-target` sub-stack creates these in the tenant's GCP project:

| Resource | Why |
|---|---|
| GCS bucket | sync destination |
| Service account `datasync-writer-<tenant_id>@<project>.iam.gserviceaccount.com` | identity for the HMAC key |
| IAM binding: `roles/storage.objectCreator` on the bucket → SA | **only write**; no read, list, or delete (per spec A.5) |
| HMAC key for the SA | the credential AWS DataSync presents over the S3 interop endpoint |
| AWS Secrets Manager secret `datasync/<tenant_id>/gcs-hmac` | how `02-datasync` and any future consumer reach the HMAC |

The HMAC key's secret value is a `sensitive = true` Terraform output and
flows directly into Secrets Manager — it is never written to disk, tfvars,
plan output, or git.

## Auth requirements (first deploy, local)

Whoever runs `tofu apply` on the `01-gcp-target` stack from their laptop
needs the following on the GCP project (`test-deleteme3-scowtt` for the
first tenant):

* `roles/storage.admin`
* `roles/iam.serviceAccountAdmin`
* `roles/storage.hmacKeyAdmin`
* `roles/serviceusage.serviceUsageAdmin` (only on first apply, to enable APIs)

`roles/owner` covers all four. Set up local auth once:

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project test-deleteme3-scowtt
```

The Terraform google provider picks up Application Default Credentials
automatically.

Once `infra/bootstrap/gcp/` (Workload Identity Federation) is built, this
local auth step disappears and CI assumes a federated GCP service account.

## Rotating the HMAC

```bash
cd infra/stacks/aws/datasync/tenants/<tenant>/01-gcp-target

# Force a new HMAC key (Terraform replaces the resource):
tofu taint module.gcp_target.google_storage_hmac_key.this
tofu apply
```

The new key is minted, the old one is deleted, and the AWS Secrets Manager
secret value is rewritten in the same apply. The next DataSync execution
picks up the new credentials automatically (it reads from the location
resource, which Terraform updates).

## Deleting a tenant

```bash
cd infra/stacks/aws/datasync/tenants/<tenant>/02-datasync
tofu destroy

cd ../01-gcp-target
# Bucket has prevent_destroy = true — remove that block first if you really
# mean to destroy data, then:
tofu destroy
```

Order matters: kill DataSync first so it stops trying to write to a
non-existent SA, then tear down GCP-side resources.
