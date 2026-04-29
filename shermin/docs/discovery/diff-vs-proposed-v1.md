# Diff vs proposed v1

A list of "if interviews confirm X, the v1 design needs Y" pairs. Each one is a place where the proposed v1 might be wrong and where confirmed reality from the interviews would force a design change.

This doc is meant to be marked up live during and after the interviews. Tick off the ones that get confirmed or refuted, add new ones as they surface.

---

## 1. On-hold retailers

**If** retailers can sit in a "paused" state for weeks or months (typically because of failed compliance, gone quiet, or waiting on the retailer's own paperwork),
**then** the pipeline needs an explicit `paused` (or `on_hold`) status separate from `lost`. The proposed v1 currently conflates "not progressing" with "lost", which would mean Sales Support either lies about the status or loses the record.

**Design change:** add `paused` as a distinct stage attribute, with a required `paused_reason` and `paused_until` (or `review_on`) date. Reactivation moves them back to whichever stage they were in.

---

## 2. Compliance as multiple sub-stages

**If** Sales Support actually treats Compliance as three or four discrete checks today (e.g. KYC, FCA permission, financial fitness, director checks),
**then** v1 should either model these as separate sub-stages with their own gating, or model "Compliance check" as one stage with a structured checklist of named required documents/checks rather than a single "compliance complete" boolean.

**Design change:** define a `ComplianceCheckItem` sub-entity, each with its own `status`, `evidence_url`, `checked_by`, `checked_at`. The Compliance stage can't be cleared until all required items pass.

---

## 3. BDM doing part of Setup-in-Stax

**If** a BDM today does any of the Stax configuration (e.g. commercial terms, lender preferences, branding), even informally,
**then** the proposed role boundary "BDM owns Lead → Application; Sales Support owns Compliance check → Live" is wrong, and v1 needs to allow shared edit rights on the Setup-in-Stax stage rather than a hard handoff.

**Design change:** make stage ownership a property of the stage with a list of allowed roles, not a single owner per role. Sales Support remains primary, BDM gets read+edit on specific Setup-in-Stax fields.

---

## 4. Multiple contacts per retailer with different roles

**If** retailers regularly have more than one primary contact (e.g. a commercial contact for the BDM and a compliance contact for Sales Support),
**then** the data model needs `RetailerContact.role` as an enforced enum, and the UI needs to surface the right contact at the right stage rather than just showing "primary contact".

**Design change:** `RetailerContact { retailer_id, person_id, role: enum(commercial|compliance|operational|director), is_primary: bool }`. Stages query by role, not by primary flag.

---

## 5. Multi-BDM ownership

**If** a retailer can be worked on by more than one BDM (e.g. one sourced it, another covers the geography, or commission is split),
**then** the data model can't have `Retailer.owner_id: BDM`, it needs a join table for ownership with optional commission split.

**Design change:** `RetailerOwnership { retailer_id, bdm_id, share: decimal, role: enum(originator|account_manager) }`. Default for v1 can be a single 100% originator.

---

## 6. Self-employed vs PAYE BDMs see different things

**If** Tony's instinct is that self-employed BDMs should not see other BDMs' retailers, but PAYE BDMs should (or vice versa),
**then** v1 access rules can't be a single "BDM" role, they need to split into `BDM_PAYE` and `BDM_SelfEmployed` (or a `BDM.visibility_scope` field driving the same rules).

**Design change:** introduce a `BDM.type` field that the permissions layer reads. Default visibility scopes per type set centrally.

---

## 7. Required fields aren't enough

**If** Sales Support's actual stage gates include actions, not just data points (e.g. "phoned the retailer to confirm bank details", "Tony verbally approved commercial terms"),
**then** required-fields-per-stage will not be enough for v1, and we need a Trello-style checklist now rather than at v2.

**Design change:** bring the per-stage `Checklist` entity forward into v1, with checkboxes that can be ticked manually by the stage owner. Required fields and required checklist items both gate stage transitions.

---

## 8. Reactivation of lost retailers

**If** retailers that went "lost" come back and pick up where they left off more often than the proposed v1 assumes,
**then** v1 needs an explicit reactivation flow rather than a "create a new retailer record" workaround. Otherwise SF ends up with duplicate Accounts.

**Design change:** add a `Retailer.lifecycle_state` distinct from stage (active / dormant / lost), and a "reactivate" action that returns the record to the stage it was in when it went lost. SF push only fires once per retailer regardless of how many times they reactivate.

---

## 9. Documents stored elsewhere

**If** Sales Support keep compliance documents on a shared drive or in email and don't want to upload them into the CRM,
**then** v1 doesn't need a full document-management feature, but it does need a structured "evidence link" field per compliance item, with a verifier note ("seen on shared drive at X").

**Design change:** `ComplianceCheckItem.evidence_url` (nullable), `evidence_note` (free text). Don't build attachment upload in v1 if the team won't use it. Revisit at v2.

---

## 10. Retailer parent/child grouping

**If** Shermin onboards retailers that belong to the same parent company (group of stores, franchise network),
**then** v1 needs a `Retailer.parent_id` self-reference, otherwise reporting per-group is awkward and SF gets duplicate top-level Accounts.

**Design change:** nullable `Retailer.parent_id`. Optional in v1 UI, but the field exists in the schema from day one so we don't migrate it later.

---

## 11. Stage rejection / bounce-back

**If** Sales Support sometimes need to bounce a retailer back to the BDM (e.g. wrong information at handoff, missing fundamentals),
**then** v1 stage transitions can't be forward-only. We need an explicit "return to previous stage with reason" action that re-notifies the previous owner.

**Design change:** stage transitions support backward movement with a required `return_reason`. Audit log captures the bounce.

---

## 12. Mobile read access for BDMs

**If** BDMs are routinely out of the office and want at least to check status on a phone,
**then** the v1 UI must have a usable mobile read view for the BDM's own retailer list, even if input/edit is desktop-only.

**Design change:** invest in a responsive read-only view for `/retailers/mine` and the per-retailer detail screen. Defer mobile-friendly forms to v2.

---

## How to use this list

After each interview:

1. Mark each pair above with one of: **confirmed** (interview backed it up, design change is in for v1), **refuted** (not a real concern, drop it), **deferred** (real, but goes to v2), **needs more** (need another data point before deciding).
2. Add any new pairs the interview surfaced.
3. Once all four interviews are done, the **confirmed** list becomes the input to a v1 design amendment doc, and the **deferred** list becomes the v2 backlog seed.
