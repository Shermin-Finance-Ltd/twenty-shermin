# twenty-shermin

Shermin Finance's fork of [Twenty CRM](https://github.com/twentyhq/twenty), used as a bespoke retailer-onboarding CRM that hands off to Salesforce when a retailer goes live on Stax.

This file is the **start here** for everything Shermin-specific. Upstream Twenty docs (`README.md`, `CLAUDE.md`) are kept untouched to minimise merge conflicts on upstream bumps.

## Where Shermin-specific work lives

```
shermin/                         All Shermin-specific docs, infra, runbooks
  docs/                          Discovery, design, runbooks
  infra/                         AWS provisioning notes
  lambda/sf-push/                Salesforce push Lambda
packages/shermin-crm-app/        Twenty App package (custom objects, workflows, UI)
.github/workflows/shermin-ci.yaml  CI workflow scoped to our paths
.github/CODEOWNERS               Default reviewers
SHERMIN.md                       This file
```

Upstream files we never modify:
- `README.md`, `CLAUDE.md`, `LICENSE`
- Anything under `packages/twenty-*/` (Twenty's own packages)
- Existing `.github/workflows/` files (we add a new one)

## Project context

- **Goal:** lightweight bespoke CRM for retailer onboarding, run by Sales Support with BDM input on early stages.
- **Pipeline:** Lead → Application → Compliance check → Contract → Setup in Stax → Live.
- **Salesforce integration:** one-way push at "Setup in Stax" stage — creates Account + Contact via Composite API upsert.
- **Hosting:** AWS eu-west-2 (London), single EC2 + RDS Postgres + ALB. ~£85/month.
- **Pinned to Twenty:** `v2.1.0` (latest stable as of fork date 2026-04-29).

## Status

**Phase 0 — Discovery.** Four parallel workstreams producing committed documentation before any AWS spend or build.

See [shermin/docs/README.md](shermin/docs/README.md) for the discovery index.

## Upstream tracking

```
git remote -v
# origin    https://github.com/Shermin-Finance-Ltd/twenty-shermin.git
# upstream  https://github.com/twentyhq/twenty.git
```

Monthly upstream bump procedure: see [shermin/docs/upstream-merge-runbook.md](shermin/docs/upstream-merge-runbook.md).

## License

Twenty is AGPL-3.0. This fork inherits that licence. See [LICENSE](LICENSE) and the AGPL note in the discovery docs.
