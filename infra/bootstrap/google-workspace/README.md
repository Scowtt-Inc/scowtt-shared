# Google Workspace bootstrap (not yet implemented)

Google Workspace is administered through the Admin SDK. Auth happens via a
dedicated service account in a GCP project (with **domain-wide delegation**
enabled and a small set of explicit OAuth scopes). The SA is impersonated
from GitHub Actions through the same Workload Identity Federation pool as
`bootstrap/gcp/`.

When implemented this directory will:

* Create the dedicated `workspace-admin@<gcp-project>.iam.gserviceaccount.com`
  service account.
* Document the very narrow OAuth scopes needed
  (e.g. `https://www.googleapis.com/auth/admin.directory.group` only).
* Hold an outputs file with the SA's `client_id`, used to register
  domain-wide delegation in the Workspace Admin Console (manual one-time step).

The Terraform `googleworkspace` provider is the typical entrypoint for the
modules under `infra/modules/google-workspace/`.
