# Stage requirements

Required fields per pipeline stage, validated by the stage-gating workflow on every `pipelineStage` change. Twenty workflows can't truly block writes (no pre-save hook on v2.1.0), so this is implemented as **revert-after-update**: the stage change lands, the workflow validates, and if validation fails it writes the previous stage back and posts a note explaining why.

Stages: `Lead → Application → Compliance check → Contract → Setup in Stax → Live`. Plus the terminal `Lost` stage.

---

## Stage: `Lead`

The default state when a retailer is first created. Minimal data, BDM has just had first contact.

| Required field | Type check | Validation rule | Error message if missing |
|---|---|---|---|
| `legalName` | non-empty Text, ≤255 chars | trimmed length ≥ 2 | "Legal name is required to save a retailer." |
| `assignedBdm` | non-null Relation | resolves to an active workspaceMember | "Assign a BDM before saving." |
| `pipelineStage` | enum | always `Lead` on create | (system) |

To **enter** Lead: nothing more required (this is the initial state).

To **leave** Lead → Application: see Application requirements below.

---

## Stage: `Application`

The retailer has expressed serious interest and is being put forward for onboarding. BDM has gathered the basics.

| Required field | Type check | Validation rule | User-facing error message |
|---|---|---|---|
| `legalName` | Text | non-empty | "Legal name is required." |
| `tradingName` | Text | non-empty | "Trading name is required to progress to Application." |
| `companiesHouseNumber` | Text | matches `^[A-Z0-9]{8}$` | "A valid 8-character Companies House number is required." |
| `fcaStatus` | Select | not equal to `Unknown` | "Confirm FCA status (Directly authorised / Appointed representative / Not authorised) before progressing." |
| `fcaReferenceNumber` | Text | matches `^[0-9]{6,7}$` when `fcaStatus` is `Directly authorised` or `Appointed representative`; otherwise may be empty | "FCA reference number is required for FCA-authorised retailers." |
| `registeredAddress` | Address | line1 + city + postcode populated, postcode matches UK postcode regex | "Registered address (incl. UK postcode) is required." |
| `primaryEmail` | Email | RFC 5322 valid | "A primary email address is required." |
| `primaryPhone` | Phone | E.164 or UK national format | "A primary phone number is required." |
| `retailerProducts` | MultiSelect | at least one value | "Select at least one product the retailer sells." |
| `sector` | Select | non-null | "Select a sector before progressing to Application." |
| `expectedMonthlyVolume` | Currency | > 0 | "Provide an expected monthly volume in GBP." |
| At least one `retailer_contact` | Relation count | `count(contacts where active=true) ≥ 1` | "Add at least one active contact to the retailer." |
| At least one `retailer_contact` with `isPrimary = true` | derived | `count(contacts where isPrimary=true and active=true) = 1` | "Mark exactly one active contact as the primary contact." |

---

## Stage: `Compliance check`

Sales Support takes ownership. The application packet is being reviewed against the FCA panel-onboarding criteria. To **enter** this stage, all Application requirements must still hold (a guard against retailers regressing data) plus:

| Required field | Type check | Validation rule | User-facing error message |
|---|---|---|---|
| `assignedSalesSupport` | Relation | non-null, active workspaceMember | "Assign a Sales Support owner before progressing to Compliance check." |
| All Application-stage fields | (as above) | revalidate | "Application data is incomplete: <list of missing fields>." |

To **leave** Compliance check (to Contract or Lost):

| Required field | Type check | Validation rule | User-facing error message |
|---|---|---|---|
| `complianceOutcome` | Select | one of `Pass`, `Fail`, `Waived` | "Set a compliance outcome (Pass / Fail / Waived) before progressing." |
| `complianceCheckCompletedBy` | Relation | non-null, active workspaceMember, must have role `Sales Support` or `Admin` | "Compliance sign-off must be completed by a Sales Support or Admin user." |
| `complianceCheckDate` | Date | non-null, not in the future, within last 90 days | "Set today's compliance check date." |
| `complianceNotes` | Text | non-empty when `complianceOutcome` is `Fail` or `Waived`; optional when `Pass` | "Compliance notes are required when the outcome is Fail or Waived." |

**Edge case: failed compliance.** Recommended behaviour: when `complianceOutcome = Fail` is set, the workflow auto-transitions the retailer to `Lost`, copies `complianceNotes` into `lostNotes`, and sets `lostReason = Failed compliance`. This keeps the funnel clean (failed records are out, not stuck mid-stage) and makes lost-reason reporting accurate. Alternative: keep them on Compliance check with `complianceOutcome = Fail`, treat as a dead state. The auto-transition is cleaner; flagged as an open question for Barney to confirm.

`Waived` retailers proceed to Contract as normal (compliance has accepted a documented exception).

---

## Stage: `Contract`

Broker agreement is being prepared and signed.

| Required field | Type check | Validation rule | User-facing error message |
|---|---|---|---|
| All Compliance-check fields | (as above) | revalidate | "Compliance data is incomplete: <list>." |
| `complianceOutcome` | Select | must be `Pass` or `Waived` | "Compliance outcome must be Pass or Waived to enter Contract." |

To **leave** Contract → Setup in Stax:

| Required field | Type check | Validation rule | User-facing error message |
|---|---|---|---|
| `contractSignedDate` | Date | non-null, not in the future, within last 60 days | "Add the contract signed date before progressing to Setup in Stax." |
| `contractDoc` | Link | non-empty, resolves to a valid URL (regex), https only | "Attach the signed contract URL before progressing." |

---

## Stage: `Setup in Stax`

Operational handover. This stage triggers the one-way Salesforce push (Account + primary Contact, upsert by `crmExternalId`).

To **enter** Setup in Stax:

| Required field | Type check | Validation rule | User-facing error message |
|---|---|---|---|
| All Contract fields | (as above) | revalidate | "Contract data is incomplete: <list>." |
| `crmExternalId` | UUID | non-null (set on create, but defensive check) | "External CRM id missing. Contact an admin." |
| Primary `retailer_contact` has `email` and `firstName` + `lastName` populated on the linked `person` | derived | required for the SF Contact upsert | "Primary contact must have first name, last name and email before pushing to Salesforce." |

On entry, the workflow fires the webhook to Lambda. Push success/failure is recorded on `lastSfPushStatus`, `lastSfPushAt`, `salesforceAccountId`, and a row in `integration_log`. A failed push **does not** revert the stage (Sales Support needs the record in Setup to retry); failures surface as a note on the retailer plus an integration_log row for the Admin dashboard.

To **leave** Setup in Stax → Live:

| Required field | Type check | Validation rule | User-facing error message |
|---|---|---|---|
| `salesforceAccountId` | Text | non-null, matches SF 18-char id pattern | "Salesforce sync has not completed. Resolve the failed push before going Live." |
| `lastSfPushStatus` | Select | equal to `Success` | "Last Salesforce push did not succeed. Retry before progressing." |
| `lastSfPushAt` | DateTime | within last 30 days | "Salesforce sync is stale (> 30 days). Re-push before going Live." |

---

## Stage: `Live`

Steady state. The retailer is trading and applications are flowing through Stax. No outbound validation on entry beyond the Setup-in-Stax gates above.

Edits to a Live retailer that change SF-mapped fields (see `sf-field-mapping.md`) trigger a follow-up push, but do not change stage.

To leave Live (rare): only to `Lost` (offboarded). Lost requirements apply.

---

## Stage: `Lost`

Terminal state. Used for failed compliance, retailers who withdraw, or panel offboarding.

| Required field | Type check | Validation rule | User-facing error message |
|---|---|---|---|
| `lostReason` | Select | non-null | "Set a lost reason before marking the retailer Lost." |
| `lostNotes` | Text | non-empty when `lostReason` is `Failed compliance`, `Lender appetite` or `Other` | "Lost notes are required for this lost reason." |

Lost retailers stay in the database for reporting and FCA audit; they are filtered out of the default "active pipeline" view.

---

## Workflow design

Implements the gating logic above using Twenty's workflow engine. One workflow on `retailer.updated`, plus a small helper workflow on `retailer_contact` changes.

### Trigger

```yaml
trigger:
  type: record_updated
  object: retailer
  filter: pipelineStage_changed
  # Twenty exposes "field changed" filters; if not directly available,
  # use `record_updated` and short-circuit early in the action when
  # pipelineStage == previousStage.
```

### Actions (pseudocode)

```pseudo
on retailer.updated where pipelineStage changed:

  newStage     := record.pipelineStage
  oldStage     := record.previousStage   # written by the helper update step below
  retailerId   := record.id

  # Skip noise
  if newStage == oldStage:
    return

  # Fetch the rule set for the new stage
  rules := stageRequirements[newStage]

  # Validate
  missing := []
  for rule in rules:
    if not rule.evaluate(record):
      missing.append({field: rule.field, message: rule.errorMessage})

  if missing.isEmpty():
    # Success path
    update retailer set:
      previousStage   = newStage         # the new "previous" for next change
      stageEnteredAt  = now()
      lastModifiedBy  = currentUser()

    # Stage-specific side effects
    if newStage == 'Setup in Stax':
      enqueueWebhook(event='retailer.setup', retailerId)

    if newStage == 'Lost' and oldStage == 'Compliance check' and record.complianceOutcome == 'Fail':
      # Already covered by auto-transition below; no-op here
      pass

    return

  else:
    # Revert path
    update retailer set:
      pipelineStage  = oldStage          # this is the revert
      # do NOT bump stageEnteredAt — we're putting them back

    createNote(
      retailerId,
      title  = "Stage change reverted: missing required data",
      body   = "Cannot move to {newStage}. The following are required:\n" +
               formatList(missing)
    )

    # Optional in v1: in-app toast / email to the user who tried the change
    sendInAppNotification(currentUser(), "Stage change reverted, see retailer notes.")
    return
```

### Compliance-fail auto-transition

A second sub-rule inside the same workflow:

```pseudo
on retailer.updated where complianceOutcome changed to 'Fail':
  if record.pipelineStage == 'Compliance check':
    update retailer set:
      pipelineStage = 'Lost'
      lostReason    = 'Failed compliance'
      lostNotes     = record.complianceNotes
```

This second step relies on the main validator allowing `Compliance check → Lost`. We add `Lost` as a permitted destination from any stage in the rules table.

### Limitations and caveats

1. **Revert is observable.** Because the update happens then is reverted, there is a brief window (≤ workflow execution time, typically < 1s) where the record sits at the new stage. Subscribers watching the GraphQL stream will see two updates. Acceptable for v1; if it causes UI flicker we can wrap the revert in a debounce on the client.
2. **No transaction guarantee.** If the workflow fails between the update and the revert (e.g. Twenty restarts), the retailer is stuck at the wrong stage with no note. Mitigation: the workflow runs synchronously on a queue with retries; we add an Admin-only "stage audit" view that flags retailers whose `pipelineStage` doesn't satisfy the rules for that stage.
3. **No pre-save validation.** A determined user with API access can still set fields to invalid values; the workflow only catches stage changes, not arbitrary edits. Field-level required-ness on the schema covers the worst cases (e.g. `legalName` not empty).
4. **Concurrency.** If two users change the stage at the same time, last-writer wins. Acceptable given the Sales Support team is small.
5. **Workflow definition lives in Twenty's UI**, not in code. We will export the workflow JSON to `shermin/workflows/` once authored, so it survives database migrations.

---

## Open questions for Barney

1. **Failed-compliance auto-transition.** Recommended: auto-move `complianceOutcome = Fail` to `Lost` with `lostReason = Failed compliance`. Confirm, or would Sales Support prefer to keep failed records visible at Compliance check until a manual decision?
2. **`Waived` outcomes.** Should `Waived` require Admin sign-off (a second approver) before allowing progression to Contract, or is one Sales Support user enough? Currently spec'd as one user.
3. **SLA timers.** `stageEnteredAt` is captured but no SLA logic is defined. Do you want time-in-stage thresholds (e.g. > 14 days at Compliance check) flagged in the UI or just reported? Out of scope for v1 unless you say otherwise.
4. **Webhook on Setup-in-Stax failure.** If the SF push fails, the spec leaves the retailer at Setup in Stax with `lastSfPushStatus = Failed`. Should we instead revert them to Contract, forcing Sales Support to fix and re-progress? Recommend leaving at Setup (failure is operational, not data) but flagging for confirmation.
5. **Address validation.** UK postcode regex catches format but not deliverability. Worth integrating an address-lookup service (e.g. Loqate) at v1, or accept BDM-typed addresses?
6. **Companies House lookup.** `companiesHouseNumber` is validated for shape, not existence. Do you want a Companies House API call to confirm the number resolves to an active company? Adds a dependency but kills typos and dissolved-company errors.
