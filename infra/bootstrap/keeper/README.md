# Keeper bootstrap (not yet implemented)

Keeper Secrets Manager is the planned home for any secret that must be shared
between humans (e.g. break-glass admin credentials) rather than between
services. Service-to-service secrets stay in AWS Secrets Manager / GCP Secret
Manager, fetched via OIDC at apply-time.

When implemented:

* This directory will document the per-environment Keeper Vault and the
  Secrets Manager Application bound to it (with a hard cap on which secret
  records the application can access).
* The Keeper API token / one-time access token is stored in AWS Secrets Manager,
  read by GitHub Actions via OIDC — there is no static Keeper credential
  anywhere in the repo.
* Modules in `infra/modules/keeper/` will create folders and shared records
  through the Keeper Terraform provider.
