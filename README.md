# scowtt-shared

Public repo for examples and the home of all Scowtt infrastructure-as-code.

| Path | Purpose |
|---|---|
| [`infra/`](./infra) | Every piece of cloud and SaaS infrastructure — AWS, GCP, Google Workspace, Keeper. OpenTofu modules + per-stack deployments + GitHub Actions delivery. Start with [`infra/ONBOARDING.md`](./infra/ONBOARDING.md). |
| [`data/`](./data) | Sample / shared data files (pre-existing). |
| [`LICENSE`](./LICENSE) | MIT. |

> Although this repository is public, **no secret material is ever stored
> here**. All credentials live in AWS Secrets Manager / GCP Secret Manager,
> reached at apply-time via short-lived OIDC sessions. See
> [`infra/ARCHITECTURE.md`](./infra/ARCHITECTURE.md) for the full security
> model.
