# Module: `datasync-s3-to-gcs`

Reusable OpenTofu module that provisions a single AWS DataSync task for one
tenant. Source is an S3 bucket prefix; destination is a Google Cloud Storage
bucket reached via the GCS S3-interoperability endpoint with HMAC credentials.

This module is the **TF Catalog item** advertised by the repo's
`catalog-info.yaml`.

## Usage

```hcl
module "tenant_a" {
  source = "git::https://github.com/<org>/datasync-s3-to-gcs.git//modules/datasync-s3-to-gcs?ref=v1.0.0"

  tenant_id            = "tenant-a"
  source_s3_bucket_arn = "arn:aws:s3:::scowtt-crm-data-bucket-dev"

  destination_bucket_name    = "tenant-a-crm-sync"
  gcs_hmac_access_key_id     = data.aws_secretsmanager_secret_version.hmac.secret_string["access_key_id"]
  gcs_hmac_secret_access_key = data.aws_secretsmanager_secret_version.hmac.secret_string["secret_access_key"]

  tags = { env = "dev" }
}
```

## What it creates

| Resource | Purpose |
|---|---|
| `aws_iam_role.source` | DataSync assumes this to list/read the tenant prefix in source S3 |
| `aws_iam_role_policy.source` | Read-only on `<bucket>/<tenant_id>/*`, list scoped to the prefix |
| `aws_datasync_location_s3.source` | Source location pointing at `<bucket>/<tenant_id>` |
| `aws_datasync_location_object_storage.destination` | GCS via `storage.googleapis.com` + HMAC |
| `aws_cloudwatch_log_group.task` + log resource policy | Transfer logs |
| `aws_datasync_task.this` | Task: `task_mode=ENHANCED`, `schedule=rate(1 hour)` |

## Spec mapping

| Spec | Implementation |
|---|---|
| A.1 us-east-1 | Set in calling stack's `provider "aws"` |
| A.2 Enhanced mode | `task_mode = "ENHANCED"` |
| A.3 60-min schedule | `schedule_expression = "rate(1 hour)"` |
| A.4 SA HMAC interop | `aws_datasync_location_object_storage` with GCS endpoint + HMAC keys |
| A.5 Write-only on data-storage | Enforced **on the GCP side** by binding only `roles/storage.objectCreator` to the HMAC service account. See `docs/gcp-setup.md`. |
| A.6 Auto-generated source role | `aws_iam_role.source` named `datasync-<tenant_id>-source-role` |

## Inputs

See [`variables.tf`](./variables.tf). Key inputs:

| Name | Required | Default |
|---|---|---|
| `tenant_id` | yes | — |
| `source_s3_bucket_arn` | yes | — |
| `destination_bucket_name` | yes | — |
| `gcs_hmac_access_key_id` | yes (sensitive) | — |
| `gcs_hmac_secret_access_key` | yes (sensitive) | — |
| `task_mode` | no | `ENHANCED` |
| `schedule_expression` | no | `rate(1 hour)` |
| `agent_arns` | no | `[]` (empty for ENHANCED-mode S3↔object-storage) |

## Notes

* HMAC credentials should be sourced from AWS Secrets Manager — never put them
  in `terraform.tfvars`. The tenant stack template demonstrates this.
* `task_mode = "ENHANCED"` requires AWS provider `>= 5.60.0`.
* Enhanced-mode tasks transferring between S3 and object storage are
  **agentless**, so `agent_arns` defaults to `[]`. If you set
  `task_mode = "BASIC"`, supply at least one DataSync agent ARN.
