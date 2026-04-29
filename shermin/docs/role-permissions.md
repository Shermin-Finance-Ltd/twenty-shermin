# Role permissions

Three roles: **BDM**, **Sales Support**, **Admin**. Implemented with Twenty's role-based access control on objects + fields. Twenty has no native row-level security on v2.1.0, so "see only my own retailers" for BDMs is enforced via a saved view filter plus a relation rule. See open questions.

Legend: **R** read, **C** create, **U** update, **D** delete, blank = no access.

---

## Object-level permissions

| Capability | BDM | Sales Support | Admin |
|---|---|---|---|
| `retailer` — own (where `assignedBdm = self`) | R, C, U | R, C, U | R, C, U, D |
| `retailer` — others | R (filtered, see notes) | R, C, U | R, C, U, D |
| `retailer_contact` — own retailer | R, C, U, D | R, C, U, D | R, C, U, D |
| `retailer_contact` — other retailer | R | R, C, U, D | R, C, U, D |
| `integration_log` | — | R | R, D |
| `person` | R, C, U | R, C, U | R, C, U, D |
| `company` | R | R, C, U | R, C, U, D |
| `task` (own) | R, C, U, D | R, C, U, D | R, C, U, D |
| `task` (assigned to others) | R | R, U | R, C, U, D |
| `note` (own retailer) | R, C, U, D | R, C, U, D | R, C, U, D |
| `note` (other retailer) | R | R, C, U | R, C, U, D |
| `workspaceMember` | R | R | R, C, U, D |

Notes:
- BDMs cannot delete `retailer` records. Disqualified records move to `Lost`, not deleted.
- Sales Support cannot delete `retailer` either, but can archive (Twenty's native archive action).
- Only Admin can delete `integration_log` rows; routine retention (e.g. trim payload snapshots after 90 days) is handled by a scheduled job, not user action.

---

## Field-level permissions on `retailer`

Hidden / read-only field overrides for BDM. Sales Support and Admin see and edit everything (subject to record-level rules).

| Field | BDM access |
|---|---|
| `complianceCheckCompletedBy` | hidden |
| `complianceCheckDate` | hidden |
| `complianceOutcome` | hidden |
| `complianceNotes` | hidden |
| `assignedSalesSupport` | read-only |
| `salesforceAccountId` | hidden |
| `salesforceContactId` | hidden |
| `crmExternalId` | hidden |
| `lastSfPushAt` | hidden |
| `lastSfPushStatus` | hidden |
| `expectedMonthlyVolume` | read-only after Application stage |
| `averageTicketSize` | read-only after Application stage |
| `lostReason`, `lostNotes` | read-only (only Sales Support / Admin set Lost state) |
| `previousStage` | hidden (implementation detail) |
| Everything else on `retailer` | read + edit on own records, read-only on others |

Sales Support: full access to all fields except `crmExternalId` (system-set, read-only) and `previousStage` (hidden).

Admin: full access including the implementation fields.

---

## Stage-transition rights

Who can advance a retailer between which stages.

| Transition | BDM | Sales Support | Admin |
|---|---|---|---|
| (create) → `Lead` | yes | yes | yes |
| `Lead` → `Application` | yes (own only) | yes | yes |
| `Application` → `Compliance check` | yes (own only) | yes | yes |
| `Application` → `Lost` | yes (own only) | yes | yes |
| `Compliance check` → `Contract` | no | yes | yes |
| `Compliance check` → `Lost` | no | yes (also auto on Fail) | yes |
| `Contract` → `Setup in Stax` | no | yes | yes |
| `Setup in Stax` → `Live` | no | yes | yes |
| any → `Lost` (overrides) | no | yes | yes |
| reopen `Lost` → previous | no | no | yes |
| force-set any stage (bypass) | no | no | yes |

Enforcement: Twenty's role rules cover read/edit. The stage-specific transition rights are enforced by the workflow (see `stage-requirements.md`): the workflow inspects `currentUser()` role and the transition direction; if the role isn't allowed, it reverts the stage and posts a note.

---

## Settings & system access

| Capability | BDM | Sales Support | Admin |
|---|---|---|---|
| Edit object schema (add/remove fields) | no | no | yes |
| Edit workflows | no | no | yes |
| Edit roles & permissions | no | no | yes |
| Manage workspace members (invite, deactivate) | no | no | yes |
| Edit views (saved, kanban, table) | own only | yes | yes |
| Generate API keys | no | no | yes |
| Read API keys / secrets | no | no | yes |
| Access integration_log dashboard | no | yes (read) | yes |
| Trigger manual SF re-push | no | yes | yes |
| Trigger backfill / migration scripts | no | no | yes |

API keys: only Admin can mint keys. The Lambda webhook handler authenticates with a service-account API key minted by Admin and rotated quarterly (see `disaster-runbook.md` when written).

---

## Open questions for Barney

1. **BDM row scoping.** Twenty has no native row-level security on v2.1.0. We have two workarounds:
   - **(a) View-filter only:** BDM's default view is filtered to `assignedBdm = self`, but they can still query other retailers via the API or by changing the filter. Cheap, leaks visibility.
   - **(b) Relation rule:** Twenty does support a relation-based access rule that limits read to records where a relation field matches the current user. This works for `assignedBdm` but not for "BDMs in the same region see each other's retailers".
   - **Recommended:** (b) for v1, with `assignedBdm = self` as the only constraint. Confirm BDMs do **not** need to see each other's retailers (no team-pooling); if they do, we'll need a `region` field on `retailer` and on `workspaceMember` and a custom rule.
2. **Sales Support read of own vs all.** Spec'd as "all" because the team is small and they triage centrally. Confirm there's no requirement to scope a Sales Support user to a specific BDM's retailers or a region.
3. **Two-person rule on compliance.** Currently any one Sales Support user can set `complianceOutcome = Pass`. Some FCA-regulated firms require a second-pair-of-eyes sign-off. Worth adding for v1, or defer?
4. **BDM creation of `person` records.** Spec'd as yes (they need to add new contacts). Risk: duplicate person records if the same director appears at two retailers. Mitigation: encourage searching first; if it becomes a problem, restrict person creation to Sales Support and have BDMs only link existing persons.
5. **`integration_log` visibility.** BDMs currently have no access. Argument for read-only access: when their retailer's SF push fails, they could self-serve diagnose without pinging Sales Support. Argument against: the payload snapshots may contain compliance metadata that BDMs aren't cleared to see. Recommend keeping hidden; confirm.
6. **Admin role count.** Recommend two Admins (you + Nicky) to avoid bus-factor risk. Confirm.
7. **Service account for SF push.** The webhook handler needs to call Twenty's API to write back `salesforceAccountId`, `lastSfPushAt` etc. We'll create a dedicated `service-sf-sync` workspace member with a custom "Service" role that has write access only to the SF-sync fields on `retailer` and create-only access to `integration_log`. Confirm pattern.
