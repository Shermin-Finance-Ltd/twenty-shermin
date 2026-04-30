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

## Stax branding (v1 outcome: logo + workspace name only)

For v1 we ship light branding: Stax logo + "Stax CRM" workspace name. Twenty's default indigo accent stays. Full Stax slate blue + pink theming is **deferred to v2**.

### Why we didn't ship full theme override

We tried two approaches in PR #4 and both fell short for v1:

1. **CSS variable override.** Inject a stylesheet that overrides Twenty's `--t-accent-*` and `--t-color-blue*` scales. Verified loaded (DevTools confirmed `--t-accent-accent9: '#477085'` was the computed value). But Twenty's components don't actually consume those CSS variables — they read from a JS theme provider (emotion / styled-components context), which holds the colour values as JS literals baked at build time.
2. **JS bundle sed-patch.** Identified the bundle containing the saturated indigo P3 string `color(display-p3 0.276 0.384 0.837)` and sed-replaced the full indigo scale with Stax slate blue P3 equivalents. Worked technically (verified the patch landed in the running container) but didn't produce a clean visual change in the UI — components seem to compute colours from multiple sources and the patch only caught one. It would also need re-validating on every upstream merge, with high false-confidence risk.

### v2 path

The proper fix is a **front-end source build**: clone `twentyhq/twenty`, edit `packages/twenty-ui/src/theme/constants/MainColorsLight.ts` and `AccentLight.ts` to use Stax brand colours, run `yarn nx build twenty-front`, ship a custom server image that bundles the patched front-end. Half-day to a day of work, robust against upstream changes (just resolve any merge conflicts in those two files).

Reasonable trigger to do this: external user demos, or v2 readiness review.

### What's in the repo for branding now

- `Dockerfile.shermin` — only patches `maxFileSize` (the file-upload cap). No CSS injection, no JS theme patching.
- Logo upload via UI: Settings → General → Logo. Use `~/path-to/stax-training-platform/public/brand/stax-logo.svg`.

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

## What's automated vs UI-only

The setup script handles 95% of v1 configuration. There's one thing it can't do because Twenty's API gates it to user-session auth, and one thing that's a per-user choice.

### Automated by `setup-shermin-crm.sh`

- Companies → Retailers, People → Contacts label rename
- Adding `prospectingStage` and `onboardingStage` SELECT fields to Retailer
- Creating Staff custom object + 19 fields
- Creating HR Admin role + denying Member access to Staff
- Creating Prospecting + Onboarding Kanban views (workspace-visible)
- Creating the conversion workflow shell (in DRAFT)
- Uploading the Stax logo (if `STAX_LOGO` env var or default path resolves)

### Must be done in the UI

**1. Conversion workflow content** (3 minutes)

Twenty's `WorkflowVersionStepResolver` is gated by `UserAuthGuard`, not accessible to API keys. The shell exists in DRAFT — you fill in the trigger + steps in the UI:

1. Settings → Workflows → click "Auto-advance retailer to onboarding when converted"
2. **Add trigger**: type `Record is created or updated`, object `Retailer`, watch fields → tick `Prospecting Stage` only
3. **Add a Filter step**: condition → `{{trigger.properties.after.prospectingStage}}` IS `CONVERTED`
4. **Add an Update Record step**: object `Retailer`, record id `{{trigger.properties.after.id}}`, set field `Onboarding Stage` = `File Collection`
5. Click **Activate**

After this, when any user moves a retailer to `prospectingStage = Converted` in the Prospecting kanban, the same retailer auto-appears in the File Collection column of the Onboarding kanban.

**2. Assign HR Admin role to specific people**

Settings → Members → click member → role → HR Admin. Repeat for each person who should see Staff records (Tony, Gemma, Gareth — whoever you decide).

## Setup-script reference

The script is **idempotent**: re-runs detect existing state and skip cleanly. Safe to run after partial completions or on already-configured workspaces.

```bash
TWENTY_API_KEY=<key> shermin/infra/scripts/setup-shermin-crm.sh
```

What it does (7 steps, all idempotent):
1. Patches `Company` object label → "Retailer" / "Retailers", icon `IconBuildingStore`.
2. Patches `Person` object label → "Contact" / "Contacts", icon `IconUserCircle`.
3. Adds `prospectingStage` and `onboardingStage` SELECT fields to Retailer; creates `staffMember` custom object + 19 fields.
4. Creates `HR Admin` role; denies Member role access to Staff.
5. Configures default Kanban views (Prospecting + Onboarding) on Retailers.
6. Creates workflow shell `Auto-advance retailer to onboarding when converted` in DRAFT.
7. Uploads Stax logo via `uploadWorkspaceLogo` multipart mutation.

What the script CAN'T do (Twenty API limitations):
- Workflow trigger + step content. `WorkflowVersionStepResolver` requires `UserAuthGuard` (browser session), not accessible to API keys. The shell sits in DRAFT for the user to complete in UI.

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
