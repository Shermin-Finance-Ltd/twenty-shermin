# Data model

Phase 0 schema for Shermin CRM, built on Twenty v2.1.0. Three custom objects (`retailer`, `retailer_contact`, `integration_log`) plus reuse of Twenty's standard objects (`person`, `company`, `note`, `task`).

All apiNames are snake_case (Twenty convention). Twenty auto-generates `id` (UUID), `createdAt`, `updatedAt`, `createdBy` and `position` on every custom object, so they are not repeated below unless overridden.

---

## 1. `retailer`

**Purpose:** the central pipeline object. One record per UK retailer (or prospective retailer) being onboarded onto Shermin's broker panel. This is the spine of the CRM: every BDM activity, compliance check, contract and Salesforce push hangs off it.

### Fields

| Name | apiName | Type | Required? | Description | Notes |
|---|---|---|---|---|---|
| Legal name | `legalName` | Text | Yes | Registered company name as it appears on Companies House. | Max 255. Used as the record's display label. |
| Trading name | `tradingName` | Text | No | Brand or trading name if different from legal name. | Max 255. Often the name BDMs know the retailer by. |
| Companies House number | `companiesHouseNumber` | Text | No | 8-character CRN. | Pattern: `^[A-Z0-9]{8}$`. Unique constraint; index. Optional because sole traders have no CRN. |
| FCA status | `fcaStatus` | Select | Yes | Authorisation status with the FCA. | Values: `Directly authorised`, `Appointed representative`, `Not authorised`, `Unknown`. Default `Unknown`. |
| FCA reference number | `fcaReferenceNumber` | Text | No | FRN if FCA-regulated. | Pattern `^[0-9]{6,7}$`. Compliance check requires this when `fcaStatus != Not authorised`. |
| Website | `website` | Link | No | Retailer's primary website. | |
| Registered address | `registeredAddress` | Address | No | Companies House registered office. | Twenty's structured Address type (line1, line2, city, postcode, country). |
| Trading address | `tradingAddress` | Address | No | Operational address if different. | |
| Primary phone | `primaryPhone` | Phone | No | Main switchboard number. | |
| Primary email | `primaryEmail` | Email | No | Generic inbox (e.g. `info@`). Personal contacts live on `retailer_contact`. | |
| Sector | `sector` | Select | No | Trade vertical. | Values: `Home improvement`, `Renewables`, `Both`, `Other`. |
| Retailer products | `retailerProducts` | MultiSelect | No | Products the retailer sells, drives downstream lender suitability. | Values: `Solar PV`, `Battery storage`, `Heat pump`, `Boiler`, `Windows & doors`, `Kitchens`, `Bathrooms`, `Roofing`, `Insulation`, `EV charging`, `Other`. |
| Expected monthly volume | `expectedMonthlyVolume` | Currency | No | BDM's forecast monthly funded value, GBP. | Currency type stores ISO code; default GBP. |
| Expected monthly applications | `expectedMonthlyApplications` | Number | No | BDM's forecast application count per month. | Integer. |
| Average ticket size | `averageTicketSize` | Currency | No | Mean loan size in GBP. | |
| Pipeline stage | `pipelineStage` | Select | Yes | Where the retailer sits in the onboarding funnel. | Values: `Lead`, `Application`, `Compliance check`, `Contract`, `Setup in Stax`, `Live`, `Lost`. Default `Lead`. Index. |
| Stage entered at | `stageEnteredAt` | DateTime | No | Timestamp the retailer entered its current `pipelineStage`. Set by workflow on stage change. | Used to compute time-in-stage SLAs. |
| Previous stage | `previousStage` | Select | No | Holds the prior stage value, written by the stage-change workflow before validation runs. | Same enum as `pipelineStage`. Used by the revert pattern (see `stage-requirements.md`). |
| Lost reason | `lostReason` | Select | No | Why the retailer was disqualified or walked away. | Values: `Failed compliance`, `Withdrew`, `Pricing`, `Lender appetite`, `No response`, `Other`. Required when `pipelineStage = Lost`. |
| Lost notes | `lostNotes` | Text | No | Free-text context for `lostReason`. | |
| Assigned BDM | `assignedBdm` | Relation | No | Workspace member who owns the retailer. | Many-to-one to `workspaceMember`. Drives row-level filtering for BDM role. |
| Assigned Sales Support | `assignedSalesSupport` | Relation | No | Sales Support owner from Compliance check stage onwards. | Many-to-one to `workspaceMember`. |
| Compliance check completed by | `complianceCheckCompletedBy` | Relation | No | Sales Support member who signed off compliance. | Many-to-one to `workspaceMember`. Hidden from BDMs. |
| Compliance check date | `complianceCheckDate` | Date | No | Date compliance was completed. | Hidden from BDMs. |
| Compliance outcome | `complianceOutcome` | Select | No | Result of compliance review. | Values: `Pass`, `Fail`, `Waived`. Hidden from BDMs. Required to leave Compliance check stage. |
| Compliance notes | `complianceNotes` | Text | No | Long-form rationale, evidence references, conditions. | Hidden from BDMs. Multiline. |
| Contract signed date | `contractSignedDate` | Date | No | Date the broker agreement was countersigned. | Required to leave Contract stage. |
| Contract document | `contractDoc` | Link | No | URL to the signed contract in document storage. | Twenty Apps don't yet expose a first-class file field for custom objects on v2.1.0; using Link to an external object store (S3 / DocuSign envelope URL) until the Files API is GA. See open question. |
| Salesforce Account ID | `salesforceAccountId` | Text | No | Salesforce 18-character Account ID, written back after first successful push. | Read-only in UI. Set by webhook handler. |
| Salesforce Contact ID (primary) | `salesforceContactId` | Text | No | Salesforce 18-character Contact ID for the primary contact pushed alongside the Account. | Read-only in UI. |
| CRM external id | `crmExternalId` | UUID | Yes | Stable external identifier used as the upsert key in Salesforce (`CRM_External_Id__c`). | Auto-generated on create. Immutable. Unique. Index. |
| Last SF push at | `lastSfPushAt` | DateTime | No | Last time a webhook push to Salesforce succeeded. | Read-only in UI. |
| Last SF push status | `lastSfPushStatus` | Select | No | Outcome of the most recent push. | Values: `Success`, `Failed`, `Pending`, `Skipped`. |
| Last modified by | `lastModifiedBy` | Relation | No | Workspace member who last edited the record. | Many-to-one to `workspaceMember`. Twenty doesn't populate this automatically for custom objects, set by workflow on update. |

Field count: 32 custom (excluding system-generated id/createdAt/updatedAt/createdBy/position). Sits in the 25–35 target.

### Relations

| From | To | Cardinality | Inverse name | Notes |
|---|---|---|---|---|
| `retailer.assignedBdm` | `workspaceMember` | many-to-one | `workspaceMember.retailersAsBdm` | |
| `retailer.assignedSalesSupport` | `workspaceMember` | many-to-one | `workspaceMember.retailersAsSalesSupport` | |
| `retailer.complianceCheckCompletedBy` | `workspaceMember` | many-to-one | `workspaceMember.retailersComplianceSignedOff` | |
| `retailer.lastModifiedBy` | `workspaceMember` | many-to-one | `workspaceMember.retailersLastModified` | |
| `retailer` | `retailer_contact` | one-to-many | `retailer.contacts` | Contacts join records. |
| `retailer` | `integration_log` | one-to-many | `retailer.integrationLogs` | All push attempts for this retailer. |
| `retailer` | `note` | one-to-many | `retailer.notes` | Standard Twenty note attachment. |
| `retailer` | `task` | one-to-many | `retailer.tasks` | Standard Twenty task attachment. |

---

## 2. `retailer_contact`

**Purpose:** join object connecting `retailer` to Twenty's standard `person`. Many-to-many: a person can be a contact at multiple retailers (rare but real, e.g. a director of two trading companies), and a retailer has multiple contacts (director, compliance officer, ops lead). Also carries role and primary-contact metadata that don't belong on `person`.

### Fields

| Name | apiName | Type | Required? | Description | Notes |
|---|---|---|---|---|---|
| Retailer | `retailer` | Relation | Yes | Parent retailer. | Many-to-one. |
| Person | `person` | Relation | Yes | Standard Twenty Person record. | Many-to-one. |
| Role | `role` | Select | Yes | Functional role at this retailer. | Values: `Director`, `Compliance Officer`, `Operations`, `Finance`, `Sales`, `Other`. |
| Is primary | `isPrimary` | Boolean | Yes | Marks the primary commercial contact pushed to Salesforce as the related Contact. | Default `false`. Only one `isPrimary = true` per retailer enforced by workflow (Twenty has no native partial unique index). |
| Notes | `notes` | Text | No | Free-text context (e.g. "lead negotiator", "evenings only"). | Multiline. |
| Active | `active` | Boolean | Yes | Soft-delete flag for when a contact leaves the retailer. | Default `true`. Inactive contacts are excluded from SF push. |

### Relations

| From | To | Cardinality | Inverse name | Notes |
|---|---|---|---|---|
| `retailer_contact.retailer` | `retailer` | many-to-one | `retailer.contacts` | |
| `retailer_contact.person` | `person` | many-to-one | `person.retailerContacts` | |

---

## 3. `integration_log`

**Purpose:** audit trail of every outbound push (and, in future, inbound webhook receipt) between the CRM and external systems. Primary consumer today is the Salesforce sync; designed generically so we can add Stax, Companies House lookups etc. without schema change. Used for replay on failure, debugging, and demonstrating sync health to Tony / Compliance.

### Fields

| Name | apiName | Type | Required? | Description | Notes |
|---|---|---|---|---|---|
| Retailer | `retailer` | Relation | No | Source retailer that triggered the push, if applicable. | Nullable to allow logs that are not retailer-scoped (e.g. health pings). |
| Target system | `targetSystem` | Select | Yes | Which downstream system. | Values: `Salesforce`, `Stax`, `Other`. |
| Target record id | `targetRecordId` | Text | No | The id assigned by the target system once the push lands (e.g. SF Account Id). | Populated on success. |
| Direction | `direction` | Select | Yes | Outbound or inbound. | Values: `Outbound`, `Inbound`. Default `Outbound`. |
| Operation | `operation` | Select | Yes | What kind of call. | Values: `Create`, `Update`, `Upsert`, `Delete`, `Read`. Default `Upsert`. |
| Payload hash | `payloadHash` | Text | Yes | SHA-256 hex of the JSON payload sent. | 64-char. Used to detect duplicate pushes; webhook handler skips push if the latest log for this retailer + target has the same hash and `status = Success`. |
| Payload snapshot | `payloadSnapshot` | Text | No | Full JSON payload, stored only on failure for debugging. | Multiline, max ~32KB. Never store on success (compliance + size). |
| Status | `status` | Select | Yes | Outcome. | Values: `Pending`, `Success`, `Failed`, `Skipped`. Default `Pending`. Index. |
| Attempts | `attempts` | Number | Yes | Retry count for this logical push. | Default 1. Integer. |
| Last error | `lastError` | Text | No | Error message from the target system. | Multiline. Truncate at 4000 chars. |
| Pushed at | `pushedAt` | DateTime | Yes | When the push was attempted. | |
| Completed at | `completedAt` | DateTime | No | When the final status was set. | |
| Correlation id | `correlationId` | UUID | Yes | Cross-system trace id, also written to CloudWatch log entries from the Lambda handler. | Auto-generated on create if not supplied. Unique. Index. Used to join CRM logs with Lambda logs. |
| HTTP status | `httpStatus` | Number | No | Raw HTTP code from target (e.g. 200, 401, 500). | Integer. |

### Relations

| From | To | Cardinality | Inverse name | Notes |
|---|---|---|---|---|
| `integration_log.retailer` | `retailer` | many-to-one | `retailer.integrationLogs` | Nullable. |

---

## Standard Twenty objects we use

We rely on Twenty's built-in objects rather than recreating them:

- **`person`** — every individual we deal with (retailer directors, compliance officers, internal staff). Linked to `retailer` via `retailer_contact`. We do not currently extend the standard person fields; if we need retailer-specific attributes (e.g. role) they go on `retailer_contact`.
- **`company`** — NOT used as the retailer record. We chose a custom `retailer` object instead because the sales-funnel semantics (pipeline_stage, compliance_outcome, SF sync metadata) clutter `company` and would conflict with Twenty's intended use of company as a generic CRM company. `company` remains available for non-retailer organisations (e.g. lender references, group parents) but is not central to the workflow.
- **`note`** — attached to `retailer` for free-form notes (call notes, ad-hoc context). Standard Twenty notes UI is good enough; no custom fields needed.
- **`task`** — attached to `retailer` for follow-ups, callbacks, document chases. Standard Twenty due-date and assignee fields cover what BDMs need at v1. Trello-style stage checklists are deferred to v2 (see plan); when we build them we will likely add a `stage` Select on `task` to scope tasks to a pipeline stage.
- **`workspaceMember`** — Twenty's user object. Targeted by all `assigned*` and `*By` relations on `retailer`.

---

## Open questions for Barney

1. **Contract document storage.** Twenty v2.1.0 doesn't expose a first-class file/attachment field on custom objects via the public API. We've spec'd `contractDoc` as a `Link` to an external store (S3 bucket, or the DocuSign envelope URL). Acceptable for v1, or do you want to wait for the Twenty Files API and accept a later schema migration?
2. **`tradingName` vs `legalName` as display label.** Twenty uses one field as the record label in tables and dropdowns. BDMs talk in trading names; compliance and contracts use legal names. Spec'd `legalName` because it's the FCA-true identity and avoids ambiguity; do you want trading name front-and-centre instead, with legal name as a secondary field?
3. **`expectedMonthlyVolume` precision.** Currency type stores 2dp. Confirm GBP-only, or do we need to support EUR / multi-currency now to avoid a migration when Shermin expands?
4. **`previousStage` field.** Added to support the revert-after-update workflow pattern. It's an implementation detail that pollutes the schema. Alternative: store previous stage in workflow context or in `integration_log`. Happy with it on the object, or prefer it hidden / on a side table?
5. **`Sector` vs `retailerProducts`.** There's overlap (a retailer with `Solar PV` is implicitly Renewables). Worth keeping both for reporting flexibility, or collapse to just `retailerProducts` and derive sector?
6. **Soft delete.** Twenty supports record archival natively. No custom `deletedAt` or `active` field on `retailer`. Confirm we use Twenty's native archive, or do you want an explicit `status` field separating archived-but-kept-for-history from genuinely-active?
