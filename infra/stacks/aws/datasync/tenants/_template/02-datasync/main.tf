provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      managed-by  = "opentofu"
      stack       = "datasync-target/${var.tenant_id}/02-datasync"
      environment = var.environment
      repo        = "Scowtt-Inc/scowtt-shared"
    }
  }
}

# ---------------------------------------------------------------------------
# Read the HMAC out of the secret created by 01-gcp-target. Reads happen at
# every plan/apply through OIDC — the value never lands on disk.
# ---------------------------------------------------------------------------

data "aws_secretsmanager_secret" "hmac" {
  name = var.hmac_secret_name
}

data "aws_secretsmanager_secret_version" "hmac" {
  secret_id = data.aws_secretsmanager_secret.hmac.id
}

locals {
  hmac = jsondecode(data.aws_secretsmanager_secret_version.hmac.secret_string)
}

# ---------------------------------------------------------------------------
# DataSync — consume the AWS catalog module.
# ---------------------------------------------------------------------------

module "datasync" {
  source = "../../../../../../modules/aws/datasync-s3-to-gcs"

  tenant_id            = var.tenant_id
  source_s3_bucket_arn = var.source_s3_bucket_arn

  destination_bucket_name    = var.destination_bucket_name
  gcs_hmac_access_key_id     = local.hmac["access_key_id"]
  gcs_hmac_secret_access_key = local.hmac["secret_access_key"]

  # Defaults already match the spec (ENHANCED, rate(1 hour), agentless).

  tags = {
    environment = var.environment
  }
}
