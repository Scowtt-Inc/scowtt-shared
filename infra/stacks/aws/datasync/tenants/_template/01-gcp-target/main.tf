provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      managed-by  = "opentofu"
      stack       = "datasync-target/${var.tenant_id}/01-gcp-target"
      environment = var.environment
      repo        = "Scowtt-Inc/scowtt-shared"
    }
  }
}

# GCP provider auth on first run = local Application Default Credentials
# (`gcloud auth application-default login`). Once Workload Identity Federation
# is in place under infra/bootstrap/gcp/, this stack will assume a federated SA
# instead — no code change required, just the environment.
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ---------------------------------------------------------------------------
# 1. GCP target — bucket (if needed) + write-only SA + HMAC key.
# ---------------------------------------------------------------------------

module "gcp_target" {
  source = "../../../../../../modules/gcp/datasync-target"

  tenant_id               = var.tenant_id
  gcp_project_id          = var.gcp_project_id
  gcp_region              = var.gcp_region
  destination_bucket_name = var.destination_bucket_name
  create_bucket           = var.create_bucket

  labels = {
    environment = var.environment
  }
}

# ---------------------------------------------------------------------------
# 2. Mirror HMAC into AWS Secrets Manager.
#
# Why mirror? DataSync's location_object_storage takes access_key / secret_key
# as direct inputs — it cannot read from Secrets Manager itself. Putting the
# HMAC in Secrets Manager lets the 02-datasync stack (and any future consumer
# such as a rotation script) read the credentials over OIDC, without ever
# writing them to a tfvars file or a runner's disk.
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "hmac" {
  name        = "datasync/${var.tenant_id}/gcs-hmac"
  description = "GCS HMAC for ${var.tenant_id} → ${module.gcp_target.bucket_url} (write-only SA)"

  # Dev: immediate delete. Set to >=7 in prod for accidental-delete protection.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "hmac" {
  secret_id = aws_secretsmanager_secret.hmac.id
  secret_string = jsonencode({
    access_key_id     = module.gcp_target.hmac_access_key_id
    secret_access_key = module.gcp_target.hmac_secret_access_key
  })
}
