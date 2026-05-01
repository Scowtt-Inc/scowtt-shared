# GCP bootstrap (not yet implemented)

When we start managing GCP resources from this repo, this directory will hold:

* `01-state-backend/` — GCS bucket for OpenTofu state + access controls.
* `02-wif-and-sa/` — Workload Identity Federation pool + provider trusting
  GitHub Actions OIDC tokens, plus per-stack service accounts the GH role can
  impersonate.

The pattern mirrors `infra/bootstrap/aws/`: per-stack roles/SAs, branch- and
environment-scoped trust, no static keys.

References for the implementer:
* https://cloud.google.com/iam/docs/workload-identity-federation-with-other-providers#github
* https://github.com/google-github-actions/auth (uses `workload_identity_provider` + `service_account`)
