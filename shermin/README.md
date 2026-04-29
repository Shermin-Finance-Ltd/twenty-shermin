# shermin/

All Shermin-specific work that isn't a Twenty App package. Kept under one folder so upstream bumps never touch it.

## Layout

```
docs/                    Discovery, design, runbooks
  README.md              Index of discovery docs
  upstream-merge-runbook.md
  data-model.md          (Phase 0 output)
  stage-requirements.md  (Phase 0 output)
  role-permissions.md    (Phase 0 output)
  sf-field-mapping.md    (Phase 0 output)
  sf-discovery.md        (Phase 0 output)
  discovery/             Interview prep + current-state
infra/                   AWS provisioning notes, CLI snippets, runbooks
lambda/                  Lambdas (sf-push live here)
  sf-push/               Receiver + worker Lambdas for Salesforce sync
```

The Twenty App package lives at [`/packages/shermin-crm-app/`](../packages/shermin-crm-app/), not here, because it has to live inside the Nx monorepo to use Twenty's build tooling.
