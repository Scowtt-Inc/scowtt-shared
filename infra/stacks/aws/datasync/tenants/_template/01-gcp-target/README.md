# Sub-stack `01-gcp-target`

Apply this **before** `02-datasync`. It creates everything on the GCP side
plus the AWS Secrets Manager record that holds the HMAC key.

| Resource | Provider | Notes |
|---|---|---|
| `google_storage_bucket.this` | google | created if `create_bucket = true`; `prevent_destroy` |
| `google_service_account.writer` | google | one per tenant |
| `google_storage_bucket_iam_member.writer` | google | only `roles/storage.objectCreator` |
| `google_storage_hmac_key.this` | google | mints the HMAC the AWS side uses |
| `aws_secretsmanager_secret.hmac` | aws | `datasync/<tenant_id>/gcs-hmac` |
| `aws_secretsmanager_secret_version.hmac` | aws | JSON `{access_key_id, secret_access_key}` |

## State

This sub-stack writes to
`s3://<state-bucket>/aws/datasync/dev/tenants/<tenant_id>/01-gcp-target/terraform.tfstate`.

## Auth (first apply)

Run from your laptop:

```bash
# AWS — same as any apply, via SSO
aws sso login --profile scowtt-admin
export AWS_PROFILE=scowtt-admin

# GCP — Application Default Credentials
gcloud auth application-default login
gcloud auth application-default set-quota-project test-deleteme3-scowtt
```

Once `infra/bootstrap/gcp/` is built out, this step disappears — CI assumes
a federated GCP service account through Workload Identity Federation.

## Plan / apply

```bash
cd infra/stacks/aws/datasync/tenants/<TENANT_ID>/01-gcp-target

# After scaffolder, both files already exist:
ls backend.hcl terraform.tfvars

tofu init -backend-config=backend.hcl
tofu plan -out=tfplan
# review → if good:
tofu apply tfplan

# Capture outputs you'll need for 02-datasync:
tofu output -raw destination_bucket_name
tofu output -raw hmac_secret_name
```

## What can go wrong

| Symptom | Cause |
|---|---|
| `googleapi: Error 409: Bucket already exists` | A bucket with the same name exists in some other GCP project. Pick a different name (GCS bucket names are globally unique). |
| `googleapi: ... permission denied` | Your `gcloud` identity lacks one of `storage.admin`, `iam.serviceAccountAdmin`, `storage.hmacKeyAdmin` on the project. |
| `Error 403: ... API has not been used` | First apply enables the APIs; expect a 30-60s lag before Terraform can use them. Re-run `tofu apply` once. |
