# Stax CRM — master plan

The single source of truth for what Stax CRM is, what it should do, and where each piece of work currently sits. Read this first if you're picking up the project after a break.

## What we're building

A bespoke CRM for Shermin Finance, branded as "Stax CRM", forked from open-source [Twenty](https://github.com/twentyhq/twenty), self-hosted on AWS in the dev account. Replaces today's spreadsheet + Slack approach to retailer onboarding. Hands off to Salesforce as the production system for live retailers.

## Original requirements (from Barney, captured verbatim)

These are the requirements as Barney stated them. Every piece of work in this repo traces back to one of these.

1. **Renames.** Companies → Retailers. People → Contacts. Staff is a new object.

2. **Staff section.** Visible only to super admin and other nominated users. Holds confidential detail like personal details, start dates, employment contracts, salary details, holiday allowances and dates.

3. **Branding.** Apply full Stax branding including logo and colourways.

4. **Prospecting pipeline.** BDMs should have a default Kanban view. They can create a retailer prospect. Kanban columns: **prospect, engaged, on hold, dead, converted**.

5. **Onboarding pipeline.** Should pick up on `converted` from the previous pipeline. Default Kanban view. Stages: **File Collection, SMT sign off, Sent to lender, Lender approved, Tech setup, Live, dead**.

6. **Each stage will have multiple required steps and statuses.** ("We can build that after.")

## Earlier discovery / context

Phase 0 produced a substantial discovery package on `main` already:

- [`data-model.md`](data-model.md) — full Retailer / Contact / Staff / IntegrationLog schema spec
- [`stage-requirements.md`](stage-requirements.md) — required-fields-per-stage matrix (pre-Trello-checklist v1)
- [`role-permissions.md`](role-permissions.md) — BDM / Sales Support / Admin matrix
- [`sf-discovery.md`](sf-discovery.md) — audit of existing Shermin Salesforce footprint and integration patterns
- [`sf-field-mapping.md`](sf-field-mapping.md) — Twenty → Salesforce field map for the Setup-in-Stax push
- [`existing-shermin-infra.md`](existing-shermin-infra.md) — house Terraform / OIDC / SF auth conventions
- [`licensing-note.md`](licensing-note.md) — AGPL-3.0 plain-English memo for Tony / legal
- [`discovery/`](discovery/) — current-state map + four interview guides + diff-vs-proposed-v1 doc

## Status today

### ✅ Live in the workspace (Stax CRM, dev AWS)

| Requirement | What's live | Pointer |
|---|---|---|
| Renames | Companies → Retailers (apiName `company` preserved). People → Contacts (apiName `person` preserved). | `setup-shermin-crm.sh` |
| Staff custom object | Created with 19 fields covering personal, employment, compensation, holiday, contracts. | `setup-shermin-crm.sh` |
| Staff visibility | HR Admin role created. Member role explicitly denied read/edit/delete on Staff. Workspace Admin sees all. | `setup-shermin-crm.sh` |
| Prospecting pipeline kanban | Default workspace view "Prospecting" on Retailers, groups by `prospectingStage` (Prospect, Engaged, On Hold, Dead, Converted). | API |
| Onboarding pipeline kanban | Default workspace view "Onboarding" on Retailers, groups by `onboardingStage` (File Collection, SMT Sign Off, Sent to Lender, Lender Approved, Tech Setup, Live, Dead). | API |
| Logo | Stax SVG uploaded to workspace logo via `uploadWorkspaceLogo`. | API |
| Workspace name | "Stax CRM" | UI |
| File upload cap | Lifted from 10 MB (upstream default) to 100 MB. | `Dockerfile.shermin` |
| File retention (FCA) | S3 lifecycle: Standard → Glacier IR @ 90d → Deep Archive @ 7y, never deleted. | `terraform/v0/storage.tf` |

### ⚠️ Partially done

| Requirement | What's missing | Why | Plan |
|---|---|---|---|
| Conversion auto-step (prospectingStage = Converted → onboardingStage = File Collection) | Workflow shell created in DRAFT; trigger + filter + update step content not configured | Twenty's workflow content APIs (`createWorkflowVersionStep`, etc.) require user-session auth; API keys can't reach them | **Barney completes in UI**: Settings → Workflows → "Auto-advance retailer to onboarding when converted" → Add trigger + filter + update step. ~3 min. Walkthrough in [`v1-customisation.md`](v1-customisation.md). |
| Branding colourways | Twenty's default indigo accent is still in place; #477085 slate blue + #d884b6 pink not applied | Twenty consumes brand colours from a JS theme provider, not CSS variables. Two patch attempts (CSS override + sed-patched compiled JS) didn't produce a clean visual change. | **Deferred to v2**: a proper front-end source build (clone twentyhq/twenty, edit `MainColorsLight.ts` + `AccentLight.ts`, run `yarn nx build twenty-front`, ship a custom server image). ~half-day of work. Trigger when polish matters: external user demos, or v2 readiness review. Documented in [`v1-customisation.md`](v1-customisation.md). |

### 🔮 Explicitly deferred (per Barney's spec)

> "Each of these stages will have multiple required steps and statuses but we can build that after."

The per-stage required steps + statuses (the Trello-style prescriptive checklist Barney described in earlier sessions) are intentionally **not in v1**. Path forward when we pick this up:

- Add a `ChecklistTemplate` and `ChecklistItem` custom object pair, related to Retailer + Stage.
- Add a workflow that auto-creates a `ChecklistItem` set when a record enters a new stage.
- Add a stage-advance gate: workflow that checks all required ChecklistItems are completed before allowing stage progression.
- Side-panel React component for the checklist UI (would need a Twenty App package or front-end fork).

This is a v2 scope item, sized at ~5-7 days.

### 🔮 Not yet started but important

| Item | Why | Effort | Trigger |
|---|---|---|---|
| **Salesforce push stub Lambda** | Wire the trigger flow end-to-end without real SF config (validates the architecture) | ~1 day | Next session |
| **Salesforce push real integration** | Push Account + Contact at Setup-in-Stax stage, JWT bearer auth, idempotent upsert | ~2-3 days | After Neethu confirms the SF discovery questions in [`sf-discovery.md`](sf-discovery.md) |
| **Real domain + ACM cert** | Drop the self-signed cert warning, host on `crm-dev.staxpayaws.co.uk` or similar | ~1 hour | Before any non-Barney user gets the URL |
| **CloudWatch alarms** | Catch outages without monitoring the deploy manually | ~half-day | Before any non-Barney user is on the workspace |
| **Multi-AZ RDS + deletion protection** | Stop being able to lose data | ~10 min Terraform change + ~30 min apply | Before any real (non-test) data goes in |
| **Front-end source build for full Stax branding** | Make it look like Stax | ~half-day | External user demo, or v2 readiness review |
| **Per-stage prescriptive checklist** | The "we can build after" item from the spec | ~5-7 days | When Sales Support has used v1 for a few weeks and we know what stages actually need |

## Architecture summary

```
                 Barney's browser (Cmd+Shift+R)
                            ↓ HTTPS (self-signed cert for v0)
             ALB twenty-shermin-v0-alb-2090009733.elb
                            ↓
            EC2 t4g.medium (eu-west-2a, public subnet)
            ├─ Twenty server (NestJS, port 3000)
            ├─ Twenty worker (BullMQ jobs)
            ├─ Redis (queue + cache)
            └─ Caddy reverse proxy
                ↓                       ↓
       RDS Postgres 16             S3 attachments
       db.t4g.small               twenty-shermin-v0-attachments-...
       (private subnets)          (Stax slate blue / FCA-aligned lifecycle)

Image: twenty-shermin:v2.1.0-shermin6 (locally built on the EC2 from
       Dockerfile.shermin, lifts maxFileSize 10MB → 100MB)

Coming: SF push Lambda + API Gateway + SQS + DLQ for Twenty webhook → SF Composite API
```

## How to do things

### How to make changes to the running workspace

Two layers:

1. **Data model + roles + views + logo + workflow shell** — via API, all in [`shermin/infra/scripts/setup-shermin-crm.sh`](../infra/scripts/setup-shermin-crm.sh). Idempotent. Re-runnable on a fresh workspace to recreate everything. Requires `TWENTY_API_KEY` env var (generate via Settings → API & Webhooks).

2. **Workflow content (trigger + steps)** — via UI only. API is gated by `UserAuthGuard`. Walkthrough in [`v1-customisation.md`](v1-customisation.md).

### How to deploy infrastructure changes

```bash
cd shermin/infra/terraform/v0
export AWS_PROFILE=shermin-dev
terraform plan -var-file=env/dev/dev.tfvars
terraform apply -var-file=env/dev/dev.tfvars
```

Then redeploy Twenty if the image needs rebuilding:
```bash
shermin/infra/scripts/deploy-twenty.sh
```

### How to throw it all away (and bring it back)

Throw away:
```bash
cd shermin/infra/terraform/v0
terraform destroy -var-file=env/dev/dev.tfvars
```
Stops the £77/month meter immediately. RDS data is lost (`skip_final_snapshot = true` in v0 — flip that before any real data lives there).

Bring back:
```bash
terraform apply -var-file=env/dev/dev.tfvars
shermin/infra/scripts/deploy-twenty.sh
TWENTY_API_KEY=<new-key> shermin/infra/scripts/setup-shermin-crm.sh
```

Reproducible from zero in about 30 minutes including the manual workflow + role-assignment UI steps.

## Open questions outstanding

(These are the ones from earlier in the project that haven't been actioned yet — re-listed here so they don't get lost.)

| For | Question | Reference |
|---|---|---|
| Tony / legal | AGPL-3.0 sign-off for internal Shermin use | [`licensing-note.md`](licensing-note.md) |
| Neethu (SF admin) | 6 SF questions blocking the full SF integration | [`sf-discovery.md`](sf-discovery.md) |
| Tony / Gemma / BDM / Sales Support | Four interview guides ready to run | [`discovery/`](discovery/) |
| Nicky | What is `shared-services-infra` for? Repo is empty | [`existing-shermin-infra.md`](existing-shermin-infra.md) |
| Barney | Promote v0 to test/prod once we know the data model is settled | this doc |

## Suggested next sessions

In rough priority order:

1. **Finish the conversion workflow in UI** (3 min). Validates the auto-handoff. Documented in [`v1-customisation.md`](v1-customisation.md).

2. **Build the SF push stub Lambda** (~1 day). Trigger flow end-to-end without real SF — proves the architecture, gives us a target for when Neethu's answers come in. Includes API Gateway + SQS + DLQ + alarm.

3. **Run one or two of the discovery interviews** with Tony / Gemma / a BDM. Output: amend the Retailer object's stage + field requirements based on real-world feedback before we put any non-test data in.

4. **Real domain + ACM cert** (~1 hour). Drop the self-signed cert warning. Pre-requisite for showing this to anyone other than Barney.

5. **Front-end source build for full Stax branding** (~half-day). Required before external user demos.

6. **Per-stage prescriptive checklist** (~5-7 days). The deferred "we can build after" piece. Most usefully built once Sales Support has been using v1 for a few weeks and tells us what stages actually need.

## Pull requests so far

| PR | Title | Status |
|---|---|---|
| [#1](https://github.com/Shermin-Finance-Ltd/twenty-shermin/pull/1) | Phase 0 — Discovery and planning docs | merged |
| [#2](https://github.com/Shermin-Finance-Ltd/twenty-shermin/pull/2) | Phase 1 v0 — Twenty deployed to dev AWS | merged |
| [#3](https://github.com/Shermin-Finance-Ltd/twenty-shermin/pull/3) | Phase 1 v1 — Retailers / Contacts / Staff, pipelines, HR Admin role, Stax branding | merged |
| [#4](https://github.com/Shermin-Finance-Ltd/twenty-shermin/pull/4) | Branding patches (CSS + JS theme attempts) | closed without merge |
| [#5](https://github.com/Shermin-Finance-Ltd/twenty-shermin/pull/5) | Revert branding patches; v1 = logo + workspace name only | merged |
