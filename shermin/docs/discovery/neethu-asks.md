# Neethu — Salesforce asks for Stax CRM Phase 2

Six things needed from Salesforce admin to unblock Phase 2 of the Stax CRM build. Send as one consolidated email or Slack message; Neethu can work through them in any order.

---

## Email-ready draft

> Subject: Stax CRM (Twenty) — six small Salesforce asks
>
> Hi Neethu,
>
> We're building a bespoke CRM (forked Twenty, hosted in our dev AWS) that will replace Salesforce as the day-to-day system for BDMs and Sales Support. They'll work in the new CRM; Salesforce stays as the back-office system of record.
>
> The CRM needs to push Account + Contact records to SF when retailers reach the "live" stage and pull schema + status data for display. To avoid building a parallel Connected App, I'd like to reuse the existing JWT integration setup at `/webhooks/salesforce/jwt` (the one polling, lender-webhooks, ecommerce all share). Six small asks to make this work:
>
> **1. Confirm the existing Connected App can be used for our writes.**
> The secret references a Consumer Key. Can you tell me which Connected App in `sherminmax--uat` that's tied to, what OAuth scopes it grants, and which permission set pre-authorises `integration.user@shermin.com.uat`? If that user only has CRUD on `Application_Decision__c`, we'll need a new perm set (point 2).
>
> **2. Create permission set `Twenty_CRM_Account_Contact_Write`.**
> Grants Create + Edit on Account and Contact (no Delete). Assign to `integration.user@shermin.com.uat`. Field-level perms: all standard fields editable; on custom fields, edit access for any field marked "Twenty mirrored" in the schema audit (point 4) — for now, full edit is fine, we'll lock it down once we know which fields we're touching.
>
> **3. Add custom field `Source_of_Update__c` to Account and Contact.**
> Text (50 chars). We'll write `Twenty_CRM_Push` to it on every CRM-originated write so it's distinguishable from your existing `Polling_Process` / `Webhook_Process` audit values. Lets you build clean reports later filtering by integration source.
>
> **4. Run two SOQL queries against `sherminmax` (production).**
> So we know what fields exist before we decide which to mirror. Outputs as CSV please:
>
> ```
> SELECT QualifiedApiName, Label, DataType, Length, ReferenceTo, IsCustom,
>        IsNillable, IsUnique, InlineHelpText, Description
> FROM   FieldDefinition
> WHERE  EntityDefinition.QualifiedApiName = 'Account'
> ORDER  BY IsCustom DESC, QualifiedApiName
> ```
> ```
> SELECT QualifiedApiName, Label, DataType, Length, ReferenceTo, IsCustom,
>        IsNillable, IsUnique, InlineHelpText, Description
> FROM   FieldDefinition
> WHERE  EntityDefinition.QualifiedApiName = 'Contact'
> ORDER  BY IsCustom DESC, QualifiedApiName
> ```
>
> Picklist values too where present (one query per relevant field, or a bulk dump from `PicklistValueInfo` — your call).
>
> **5. What's the dev sandbox refresh cadence for `sherminmax--uat`?**
> Affects how often we'll need to re-seed any Twenty test data and re-apply the perm set after refreshes.
>
> **6. Should Twenty's external ID use the existing `Company_UUID__c` or a new field?**
> Quick check: `SELECT Id, Company_UUID__c FROM Account LIMIT 100`. If it's mostly null we can repurpose; if it's populated with values you're using (Stax Portal IDs, etc.) we'll add `CRM_External_Id__c` instead.
>
> ---
>
> No rush on any of this individually but item 1 unblocks the most. If you'd rather I write the queries up as something Apex / Workbench-runnable, happy to.
>
> Cheers,
> Barney

---

## Why we're asking each thing (background, in case Neethu queries it)

| Ask | Why it matters |
|---|---|
| 1 | Avoids creating a parallel Connected App + new keys; keeps audit trails for SF↔AWS integration in one place |
| 2 | The integration user currently writes only `Application_Decision__c` (per polling + lender-webhooks). Our writes are different scope; need explicit allow |
| 3 | Mirrors the existing audit pattern on `Application_Decision__c`. Without it, our writes look identical to manual ones in the audit log |
| 4 | We don't have schema visibility from the AWS side; need the dump to plan field mirroring. ~133 custom Account fields documented elsewhere; only ~22 in `stax-docs` |
| 5 | If sandbox refreshes wipe data + perm sets weekly, we need to script our re-apply procedure; if it's once-a-quarter, manual is fine |
| 6 | Idempotency on our writes. Twenty needs a stable external ID per Account so re-pushes don't create duplicates |

## Status tracking

Once Neethu replies, fill in:

- [ ] 1. Connected App identified: `_______`. Scopes: `_______`. Pre-auth perm set: `_______`
- [ ] 2. Permission set `Twenty_CRM_Account_Contact_Write` created and assigned
- [ ] 3. `Source_of_Update__c` field added to Account and Contact
- [ ] 4. SOQL CSVs landed at `sf-account-fields.csv` and `sf-contact-fields.csv`
- [ ] 5. Sandbox refresh cadence: `_______`
- [ ] 6. External ID strategy: `Company_UUID__c` reused / new `CRM_External_Id__c`
