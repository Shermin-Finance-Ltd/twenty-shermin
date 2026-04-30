# v1 customisation

The Shermin-specific configuration on top of vanilla Twenty: object renames, the Staff object, pipeline stages, role-based access, and the Stax brand patch. Read this if you're rebuilding the workspace from scratch or wondering why something looks the way it does.

## What changed in v1

| Change | Where it lives | How to reproduce |
|---|---|---|
| Companies → Retailers (label only) | Twenty workspace metadata | `setup-shermin-crm.sh` |
| People → Contacts (label only) | Twenty workspace metadata | `setup-shermin-crm.sh` |
| `Retailer.prospectingStage` SELECT field | Twenty workspace metadata | `setup-shermin-crm.sh` |
| `Retailer.onboardingStage` SELECT field | Twenty workspace metadata | `setup-shermin-crm.sh` |
| `staffMember` custom object + 19 fields | Twenty workspace metadata | `setup-shermin-crm.sh` |
| `HR Admin` role | Twenty workspace metadata | `setup-shermin-crm.sh` |
| Member role denied access to Staff | Twenty workspace metadata | `setup-shermin-crm.sh` |
| Per-file upload cap lifted to 100 MB | Patched front-end / server image | `Dockerfile.shermin` (sed of compiled JS) |
| Stax slate blue + pink + white branding | Patched front-end image | `shermin-overrides.css` injected into `index.html` |

## Pipeline shape

One `Retailer` (formerly Company) record per company. Two SELECT fields drive the two kanban pipelines:

| Field | Stages | Owner | View |
|---|---|---|---|
| `prospectingStage` | Prospect → Engaged → On Hold → Dead → **Converted** | BDM | "Prospecting" kanban |
| `onboardingStage` | File Collection → SMT Sign Off → Sent to Lender → Lender Approved → Tech Setup → Live → Dead | Sales Support | "Onboarding" kanban |

When a BDM moves a retailer to `prospectingStage = Converted`, the Onboarding kanban should auto-set `onboardingStage = File Collection` (workflow built in UI — see "Things you do in the UI" below).

## Roles

Three roles, one access boundary:

| Role | Built by | Default object access | Staff object |
|---|---|---|---|
| `Admin` | Twenty (built-in, uneditable) | Read/write all | Yes |
| `HR Admin` | Our setup script | Read/write all | Yes |
| `Member` | Twenty (built-in) | Read/write all | **No** (explicit deny) |

Visibility model: by default new users land on Member and cannot see Staff. Move someone to HR Admin (Settings → Members → assign role) to give them access. Admin sees everything.

## Stax branding

Twenty's UI is Linaria CSS-in-JS with a generated CSS-variables file shipped in the front-end build. We don't fork the CSS; we inject an override.

**Architecture:**

```
shermin-overrides.css  (this repo, shermin/infra/docker/)
        ↓
Dockerfile.shermin copies it into the container at /app/.../dist/front/
        ↓
Dockerfile.shermin sed-injects <link rel="stylesheet" href="/shermin-overrides.css"/> into index.html, BEFORE </head>
        ↓
Browser loads index.html, then Twenty's compiled CSS, then OUR override (last-wins)
        ↓
Stax slate blue + pink palette
```

**What the override does:** replaces Twenty's `--t-color-blue*` (1–12) with a Stax slate blue scale (step 9 = `#477085`), and replaces `--t-color-pink*` with the documented Stax pink scale (step 9 = `#d884b6`). Surfaces (`gray0` = white, `gray1` = `#f5f7fa`) match the Stax design system.

**Verifying it's live:**
```bash
curl -ks https://<alb-dns>/shermin-overrides.css | head -5    # should return Stax CSS
curl -ks https://<alb-dns>/ | grep shermin-overrides.css      # should show the injected <link>
```

**When upstream changes the index.html template** (rare), the Dockerfile sed will fail loudly with `grep -q "</head>"` exiting non-zero. Inspect the new index, fix the sed, re-deploy.

**When upstream renames CSS variables** (more likely over time), our override stops working but doesn't error. Visual check on every upstream bump — confirm the Stax blue is still the primary action colour.

## Reproducing v1 from scratch

```bash
# 1. Bring up infrastructure (fresh AWS)
cd shermin/infra/terraform/v0
export AWS_PROFILE=shermin-dev
terraform init -backend-config=env/dev/backend-config.hcl
terraform apply -var-file=env/dev/dev.tfvars

# 2. Deploy Twenty (builds the patched image with maxFileSize + brand override)
../scripts/deploy-twenty.sh

# 3. Sign up as workspace admin in browser
open "$(terraform output -raw alb_url)"

# 4. Generate an API key in Settings → API & Webhooks

# 5. Configure the data model
TWENTY_API_KEY=<paste-key> ../scripts/setup-shermin-crm.sh
```

Steps 1–2 are infrastructure + image. Step 5 is workspace-internal data model + roles.

## Things you do in the UI (not scripted)

The setup script doesn't (yet) configure these because they're either trivial in the UI or require a workflow-version API the script avoids:

- **Logo upload.** Settings → General → Logo — drop the Stax PNG/SVG.
- **Default Kanban views.** On Retailers list page, click the view dropdown → New view → Kanban → group by `prospectingStage`. Save as workspace view "Prospecting". Repeat with `onboardingStage` filtered to `prospectingStage = Converted`, save as "Onboarding".
- **Conversion workflow.** Settings → Workflows → New → trigger: `Record updated on Retailer` where `prospectingStage` field changed → action: Update Record → set `onboardingStage = File Collection`. Activate.
- **Assign HR Admin role.** Settings → Members → Edit your own role → HR Admin. Add other people (Tony, Gemma, Gareth) as needed.

## Setup-script reference

The script is **idempotent**: re-runs detect existing state and skip cleanly. Safe to run after partial completions or on already-configured workspaces.

```bash
TWENTY_API_KEY=<key> shermin/infra/scripts/setup-shermin-crm.sh
```

What it does (in order, with idempotent skip-if-exists):
1. Patches `Company` object label → "Retailer" / "Retailers", icon `IconBuildingStore`.
2. Patches `Person` object label → "Contact" / "Contacts", icon `IconUserCircle`.
3. Adds `prospectingStage` and `onboardingStage` SELECT fields to Retailer.
4. Creates `staffMember` custom object with 19 fields.
5. Creates `HR Admin` role.
6. Upserts `staffMember` permissions on Member role to deny read/edit/destroy.

What the script avoids:
- Workflow creation (Twenty's `workflowVersion` API is awkward; UI is faster).
- View creation (per-user view state, scriptable but high churn).
- Logo upload (single drag-and-drop in UI, not worth scripting).

## Files in this v1 PR

- `shermin/infra/docker/Dockerfile.shermin` — extended with brand CSS injection.
- `shermin/infra/docker/shermin-overrides.css` — Stax brand override stylesheet.
- `shermin/infra/scripts/deploy-twenty.sh` — extended to send the brand CSS in the Docker build context, image tag bumped to `-shermin2`.
- `shermin/infra/scripts/setup-shermin-crm.sh` — new, idempotent data-model + roles bootstrap.
- `shermin/docs/v1-customisation.md` — this file.
- `shermin/docs/v0-deploy-log.md` — extended with v1 changes.

## Known issues / v2 work

- **API key in setup script** is passed via env var. Not in the repo, but the user has to handle it carefully. Eventually add a "fetch from Secrets Manager" path.
- **Workflow not scripted.** When Twenty's workflow API stabilises, automate.
- **Brand CSS may drift on upstream bumps.** Manual visual check on each upgrade.
- **No automated test of brand patch.** A visual regression test (Playwright + a couple of screenshots compared against baselines) would catch CSS-variable rename damage before users see it.
