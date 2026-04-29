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
| [discovery/README.md](discovery/README.md) | done — index of the discovery folder with one-line summaries per file | Workstream D |
| [discovery/current-state.md](discovery/current-state.md) | done — what we think we know about retailer onboarding today, with inferences flagged for confirmation | Workstream D |
| [discovery/interview-tony.md](discovery/interview-tony.md) | done — 30-min commercial interview guide covering pipeline visibility, BDM adoption, KPIs, self-employed vs PAYE | Workstream D |
| [discovery/interview-gemma.md](discovery/interview-gemma.md) | done — 30-min operational interview guide covering Sales Support workflow, compliance, Setup-in-Stax, exception cases | Workstream D |
| [discovery/interview-bdm.md](discovery/interview-bdm.md) | done — 20-min sample-BDM interview guide covering lead intake, info needs, mobile vs desktop | Workstream D |
| [discovery/interview-sales-support.md](discovery/interview-sales-support.md) | done — 30-min Sales Support interview guide covering real-onboarding walk-through, compliance, Setup-in-Stax, checklists vs required fields | Workstream D |
| [discovery/diff-vs-proposed-v1.md](discovery/diff-vs-proposed-v1.md) | done — twelve "if X then Y" pairs flagging where v1 may need to change once interviews land | Workstream D |

## Operations

- [upstream-merge-runbook.md](upstream-merge-runbook.md) — monthly Twenty upstream bump procedure.
- `disaster-runbook.md` — TODO Phase 1.
- `licensing-note.md` — TODO Phase 0 close-out (AGPL-3.0 implications memo for Tony / legal).

## How agents should add to this index

When you create a new discovery doc, update the table above with status `done` and a one-line summary in the doc itself.
