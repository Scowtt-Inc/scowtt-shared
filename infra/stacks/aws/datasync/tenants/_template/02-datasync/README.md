# Sub-stack `02-datasync`

Apply this **after** `01-gcp-target`. It creates the AWS DataSync task and
the IAM role DataSync assumes to read the source S3 prefix.

| Resource | Notes |
|---|---|
| `data.aws_secretsmanager_secret_version.hmac` | reads the HMAC written by 01-gcp-target |
| `module.datasync` (full DataSync stack) | source role + S3 location + object-storage location + ENHANCED-mode task |

## State

`s3://<state-bucket>/aws/datasync/dev/tenants/<tenant_id>/02-datasync/terraform.tfstate`.

## Plan / apply

```bash
cd infra/stacks/aws/datasync/tenants/<TENANT_ID>/02-datasync

tofu init -backend-config=backend.hcl
tofu plan -out=tfplan
# review → if good:
tofu apply tfplan

tofu output -raw datasync_task_arn
```

Once applied, the first scheduled execution kicks off within an hour. Tail
the log group:

```bash
aws logs tail "$(tofu output -raw datasync_log_group_name)" --follow --region us-east-1
```

## Why a separate stack from 01?

* **Different blast radius.** The DataSync stack only manages AWS resources;
  the GCP-target stack touches GCP. Splitting them means re-running one is
  cheap and never risks the other.
* **Different cadence.** HMAC rotation requires `01-gcp-target apply` (mints
  a new key, updates the secret) but no `02-datasync apply` (DataSync re-reads
  the secret on the next scheduled run since the location resource references
  the secret value).
* **Cleaner least-privilege story.** 01 needs both AWS and GCP credentials;
  02 needs only AWS — fewer concerns mixed into one role per stack.
