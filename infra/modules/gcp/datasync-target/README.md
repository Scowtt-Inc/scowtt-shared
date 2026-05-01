# Module: `gcp/datasync-target`

Provisions everything on the GCP side that AWS DataSync needs to sync into:

* **GCS bucket** — created if missing, or referenced if it already exists
  (`create_bucket = false`). Uniform bucket-level access, public access
  prevention enforced, `prevent_destroy = true` on the resource.
* **Service account** — `datasync-writer-<tenant_id>@<project>.iam.gserviceaccount.com`,
  bound to **`roles/storage.objectCreator` only** on this bucket. No read,
  no list, no delete.
* **HMAC key** — what AWS DataSync presents to GCS over the S3
  interoperability endpoint. The secret is exposed as a sensitive output;
  pipe it straight into AWS Secrets Manager.
* **Required APIs** — `storage`, `iam`, `iamcredentials` are enabled on the
  project (`enable_apis = true` by default).

## Usage

```hcl
module "gcp_target" {
  source = "../../../modules/gcp/datasync-target"

  tenant_id               = "test-deleteme3"
  gcp_project_id          = "test-deleteme3-scowtt"
  gcp_region              = "US"                   # multi-region
  destination_bucket_name = "test-deleteme3-scowtt-crm-sync"
}

# Pipe the HMAC into AWS Secrets Manager so DataSync (or any other consumer)
# can read it through OIDC, without it ever touching disk.
resource "aws_secretsmanager_secret" "hmac" {
  name = "datasync/${var.tenant_id}/gcs-hmac"
}

resource "aws_secretsmanager_secret_version" "hmac" {
  secret_id = aws_secretsmanager_secret.hmac.id
  secret_string = jsonencode({
    access_key_id     = module.gcp_target.hmac_access_key_id
    secret_access_key = module.gcp_target.hmac_secret_access_key
  })
}
```

## Importing an existing bucket

If the bucket already exists in GCP and you want this module to manage it,
run before `tofu apply`:

```bash
tofu import 'module.gcp_target.google_storage_bucket.this[0]' \
  '<project>/<bucket-name>'
```

Alternatively set `create_bucket = false` to **read** an existing bucket
without managing it — the module will still bind the SA and mint the HMAC
key, but won't change bucket-level settings.

## Inputs

| Name | Default | Required |
|---|---|---|
| `tenant_id` | — | yes |
| `gcp_project_id` | — | yes |
| `destination_bucket_name` | — | yes |
| `gcp_region` | `"US"` | no |
| `create_bucket` | `true` | no |
| `enable_apis` | `true` | no |
| `labels` | `{}` | no |

## Outputs

| Name | Sensitive | Notes |
|---|---|---|
| `bucket_name` | no | resolved name (created or existing) |
| `bucket_url` | no | `gs://<bucket_name>` |
| `service_account_email` | no | for IAM audits |
| `hmac_access_key_id` | no | safe to log; analogous to `AWS_ACCESS_KEY_ID` |
| `hmac_secret_access_key` | **yes** | feed into Secrets Manager only |

## Required permissions on the GCP project

Whoever runs `tofu apply` (your laptop today; a federated SA later) needs:

* `roles/storage.admin` — bucket lifecycle + IAM bindings
* `roles/iam.serviceAccountAdmin` — create/delete the writer SA
* `roles/storage.hmacKeyAdmin` — create the HMAC key
* `roles/serviceusage.serviceUsageAdmin` — enable APIs (only on first apply)

`roles/owner` covers all four.
