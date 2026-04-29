# shermin-crm-app

Twenty App package for Shermin Finance's bespoke CRM. This is where all custom objects, workflows, role configurations, and UI extensions live.

## Why this package exists

We chose to fork Twenty for full source control. To keep `git merge upstream/main` mostly painless, **all customisations go through Twenty's Apps SDK** rather than touching `twenty-server/` or `twenty-front/` core source.

This package is monorepo-native — it sits inside Twenty's Nx workspace so it can use the App SDK build tooling.

## Status

Phase 0 — not built yet. The schema, workflows, and roles will be defined here once discovery completes:

- Custom objects: `Retailer`, `RetailerContact`, `IntegrationLog`
- Workflow rules: stage-transition validation (revert pattern), Salesforce push trigger
- Role configurations: BDM, Sales Support, Admin
- UI extensions (Phase 2): Trello-style checklist primitive

See [`shermin/docs/data-model.md`](../../shermin/docs/data-model.md) for the spec (when discovery completes).

## Files (to come in Phase 1)

- `package.json` — App package manifest
- `app.config.ts` — Twenty App registration
- `src/objects/` — custom object definitions
- `src/workflows/` — workflow rule definitions
- `src/roles/` — role + permission definitions
- `src/ui/` — React components (Phase 2)
