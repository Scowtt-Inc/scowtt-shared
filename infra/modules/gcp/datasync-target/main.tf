locals {
  base_labels = merge(
    {
      tenant_id  = var.tenant_id
      managed_by = "opentofu"
      module     = "gcp-datasync-target"
    },
    var.labels,
  )

  # GCP service account IDs are 6-30 chars, lowercase alphanumeric + hyphens.
  # "datasync-writer-" is 16 chars, leaving 14 for the tenant id.
  sa_account_id = "datasync-writer-${substr(var.tenant_id, 0, 14)}"
}

# ---------------------------------------------------------------------------
# Required project APIs (storage, iam). Idempotent: enabled-if-not-already.
# ---------------------------------------------------------------------------

resource "google_project_service" "required" {
  for_each = var.enable_apis ? toset([
    "storage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
  ]) : toset([])

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Bucket — created if create_bucket=true; otherwise referenced via data source.
#
# If the bucket already exists in GCP and you want this module to manage it
# instead, run BEFORE the first apply:
#   tofu import 'module.gcp_target.google_storage_bucket.this[0]' '<project>/<bucket>'
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "this" {
  count = var.create_bucket ? 1 : 0

  project       = var.gcp_project_id
  name          = var.destination_bucket_name
  location      = var.gcp_region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false
  }

  labels = local.base_labels

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.required]
}

data "google_storage_bucket" "existing" {
  count = var.create_bucket ? 0 : 1
  name  = var.destination_bucket_name
}

locals {
  bucket_name = var.create_bucket ? google_storage_bucket.this[0].name : data.google_storage_bucket.existing[0].name
}

# ---------------------------------------------------------------------------
# Write-only service account.
# Holds ONLY storage.objectCreator on the destination bucket — it cannot read,
# list, or delete objects. The HMAC key minted from this SA inherits that
# limit (per spec item A.5: "data-storage: only write permissions").
# ---------------------------------------------------------------------------

resource "google_service_account" "writer" {
  project      = var.gcp_project_id
  account_id   = local.sa_account_id
  display_name = "DataSync writer for ${var.tenant_id}"
  description  = "Used by AWS DataSync to write to gs://${var.destination_bucket_name} via S3 interop"

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket_iam_member" "writer" {
  bucket = local.bucket_name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.writer.email}"
}

# ---------------------------------------------------------------------------
# HMAC key — what AWS DataSync presents to GCS over the S3 interop endpoint.
# ---------------------------------------------------------------------------

resource "google_storage_hmac_key" "this" {
  service_account_email = google_service_account.writer.email
  project               = var.gcp_project_id
  state                 = "ACTIVE"
}
