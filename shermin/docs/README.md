# Shermin CRM — docs index

Phase 0 discovery is in progress. Docs marked **(in progress)** are being drafted by parallel agents and will be filled in as they complete.

## Plan & decisions

- The approved v1 plan lives outside the repo (Barney's local plans dir). The headline decisions are summarised in [`SHERMIN.md`](../../SHERMIN.md).

## Phase 0 — Discovery (in progress)

| Doc | Status | Owner |
|---|---|---|
| [data-model.md](data-model.md) | done — schema for `retailer`, `retailer_contact`, `integration_log` plus reuse of standard Twenty objects | Workstream B |
| [stage-requirements.md](stage-requirements.md) | done — required-fields-per-stage tables for the six pipeline stages plus `Lost`, with revert-after-update workflow pseudocode | Workstream B |
| [role-permissions.md](role-permissions.md) | done — BDM / Sales Support / Admin matrix covering object, field, stage-transition and settings access | Workstream B |
| [sf-field-mapping.md](sf-field-mapping.md) | done — Twenty `retailer` to SF Account/Contact field map for the Setup-in-Stax push, plus the three new SF custom fields | Workstream B |
| [sf-discovery.md](sf-discovery.md) | done — audit of existing SF integration patterns, custom field naming conventions, JWT bearer auth pattern, and recommended sandbox / ECA / integration user setup for the new Twenty push | Workstream C |
| [discovery/current-state.md](discovery/current-state.md) | (in progress) | Workstream D |
| [discovery/interview-tony.md](discovery/interview-tony.md) | (in progress) | Workstream D |
| [discovery/interview-gemma.md](discovery/interview-gemma.md) | (in progress) | Workstream D |
| [discovery/interview-bdm.md](discovery/interview-bdm.md) | (in progress) | Workstream D |
| [discovery/interview-sales-support.md](discovery/interview-sales-support.md) | (in progress) | Workstream D |

## Operations

- [upstream-merge-runbook.md](upstream-merge-runbook.md) — monthly Twenty upstream bump procedure.
- `disaster-runbook.md` — TODO Phase 1.
- `licensing-note.md` — TODO Phase 0 close-out (AGPL-3.0 implications memo for Tony / legal).

## How agents should add to this index

When you create a new discovery doc, update the table above with status `done` and a one-line summary in the doc itself.
