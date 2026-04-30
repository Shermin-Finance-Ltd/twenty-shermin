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

- **Goal:** lightweight bespoke CRM for retailer onboarding, run by Sales Support with BDM input on early stages. Hands off to Salesforce as production at the "Setup in Stax" point.
- **Two pipelines on the Retailer object:**
  - **Prospecting** (BDM-owned): Prospect → Engaged → On Hold → Dead → Converted
  - **Onboarding** (Sales Support-owned): File Collection → SMT Sign Off → Sent to Lender → Lender Approved → Tech Setup → Live → Dead
- **Hosting:** AWS eu-west-2 (London), single EC2 + RDS Postgres + ALB in the dev account. ~£77/month while running.
- **Pinned to Twenty:** `v2.1.0`.

## Read first

- [`shermin/docs/PLAN.md`](shermin/docs/PLAN.md) — **single source of truth** for what's done, what's in progress, what's deferred. Read this if picking up the project.
- [`shermin/docs/v1-customisation.md`](shermin/docs/v1-customisation.md) — what's automated by `setup-shermin-crm.sh` vs what needs UI.

## Status (Phase 1 v1)

Workspace **Stax CRM** is live with all spec items in place except the conversion workflow content (3-min UI task) and full Stax brand colours (deferred to v2 — needs front-end source build).

| Live | Pending | Deferred |
|---|---|---|
| Renames (Companies → Retailers, People → Contacts) | Conversion workflow trigger + steps (UI task) | Full brand colour theme (front-end source build) |
| Staff custom object + 19 fields, restricted to HR Admin | Assigning HR Admin role to people (Settings → Members) | Per-stage prescriptive checklists ("we'll build that after") |
| Two pipeline kanbans (Prospecting + Onboarding) | Salesforce push Lambda | Multi-AZ RDS + deletion protection (before real data) |
| Stax logo uploaded | Real domain + ACM cert | CloudWatch alarms |
| 100 MB file upload cap, 7-year FCA retention | Per-user role assignments | |

**URL:** `https://twenty-shermin-v0-alb-2090009733.eu-west-2.elb.amazonaws.com` (self-signed cert, click through warning).

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
