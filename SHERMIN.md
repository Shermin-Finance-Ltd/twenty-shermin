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

**Phase 1 — v0 deploy live.** Vanilla Twenty CRM running in the Shermin dev AWS account, single user (Barney), no Salesforce integration yet.

- **URL:** `https://twenty-shermin-v0-alb-2090009733.eu-west-2.elb.amazonaws.com` (self-signed cert, click through warning)
- **Workspace name:** Stax CRM
- **Cost:** ~£77/month while running

Phase 0 discovery docs are merged on `main` under [`shermin/docs/`](shermin/docs/).
Phase 1 v0 deploy story lives in [`shermin/docs/v0-deploy-log.md`](shermin/docs/v0-deploy-log.md).
Operational quick-reference in [`shermin/infra/README.md`](shermin/infra/README.md).

## Common operations

| What | How |
|---|---|
| Open Twenty | Visit the URL above, accept self-signed cert |
| SSO login | `aws sso login --profile shermin-dev` |
| Re-deploy Twenty | `AWS_PROFILE=shermin-dev shermin/infra/scripts/deploy-twenty.sh` |
| Tail Twenty logs | `aws logs tail /twenty-shermin-v0 --follow --profile shermin-dev` |
| Shell into the EC2 | `aws ssm start-session --target $(cd shermin/infra/terraform/v0 && terraform output -raw ec2_instance_id) --profile shermin-dev` |
| Stop the £77/month meter | `cd shermin/infra/terraform/v0 && terraform destroy -var-file=env/dev/dev.tfvars` |
| Restart it | `terraform apply -var-file=env/dev/dev.tfvars` then `./shermin/infra/scripts/deploy-twenty.sh` |

## Upstream tracking

```
git remote -v
# origin    https://github.com/Shermin-Finance-Ltd/twenty-shermin.git
# upstream  https://github.com/twentyhq/twenty.git
```

Monthly upstream bump procedure: see [shermin/docs/upstream-merge-runbook.md](shermin/docs/upstream-merge-runbook.md).

## License

Twenty is AGPL-3.0. This fork inherits that licence. See [LICENSE](LICENSE) and the AGPL note in the discovery docs.
