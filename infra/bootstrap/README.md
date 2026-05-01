# Bootstrap

Bootstrap stacks create the things that have to exist before any workload
stack can be applied via GitHub Actions:

* The OpenTofu state backend (per platform).
* The federation trust between GitHub Actions and each cloud (OIDC for AWS,
  Workload Identity Federation for GCP, etc.).
* The set of IAM (or equivalent) roles that GitHub Actions jobs are allowed
  to assume — one role per purpose, never one super-role.

These stacks are applied by **a human with admin credentials, exactly once
per platform**. After that, every change goes through GitHub Actions like
any other stack — but updates to bootstrap require an explicit, gated
environment (`aws-bootstrap-maintenance`, etc.) and the bootstrap-maintainer
role.

| Platform | Status | Entry point |
|---|---|---|
| AWS | implemented | [`aws/`](./aws) |
| GCP | placeholder | [`gcp/README.md`](./gcp/README.md) |
| Google Workspace | placeholder | [`google-workspace/README.md`](./google-workspace/README.md) |
| Keeper | placeholder | [`keeper/README.md`](./keeper/README.md) |
