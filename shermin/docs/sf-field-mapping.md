# Salesforce field mapping

Maps Twenty `retailer` fields to Salesforce Account / Contact destinations for the one-way push at the `Setup in Stax` stage. Push uses the SF Composite API with `allOrNone: true`, upsert by `CRM_External_Id__c`. Account and primary Contact are created/updated atomically.

Field names below assume **standard** SF Account/Contact fields plus three new custom fields. Naming for additional custom fields needs confirming against Shermin's existing org conventions, see Workstream C output: `sf-discovery.md`.

---

## Account-bound fields

Source: Twenty `retailer`. Destination: Salesforce `Account`.

| Twenty field | SF object | SF field | SF type | Length / precision | Required in SF? | Transform notes | Sample value |
|---|---|---|---|---|---|---|---|
| `retailer.legalName` | Account | `Name` | Text | 255 | Yes | Trim whitespace. SF rejects empty. | `Acme Renewables Ltd` |
| `retailer.tradingName` | Account | `TradingName__c` (custom) | Text | 255 | No | If null, copy `Name`. | `Acme Solar` |
| `retailer.companiesHouseNumber` | Account | `CompaniesHouseNumber__c` (custom) | Text | 8 | No | Pass through. Validate against `^[A-Z0-9]{8}$` before push. | `12345678` |
| `retailer.fcaStatus` | Account | `FCA_Status__c` (custom) | Picklist | n/a | No | Map enum: Twenty `Directly authorised` → SF `Directly Authorised`; `Appointed representative` → `Appointed Representative`; `Not authorised` → `Not Authorised`; `Unknown` → blank. | `Directly Authorised` |
| `retailer.fcaReferenceNumber` | Account | `FCA_FRN__c` (custom) | Text | 7 | No | Pass through. | `123456` |
| `retailer.website` | Account | `Website` | URL | 255 | No | Pass through. | `https://acme-solar.co.uk` |
| `retailer.registeredAddress.line1` | Account | `BillingStreet` | Textarea | 255 | No | Concatenate `line1` + `\n` + `line2` if line2 present. | `12 High Street\nSuite 4` |
| `retailer.registeredAddress.city` | Account | `BillingCity` | Text | 40 | No | Pass through, truncate at 40. | `Norwich` |
| `retailer.registeredAddress.postcode` | Account | `BillingPostalCode` | Text | 20 | No | Uppercase, normalise spacing. | `NR2 1AA` |
| `retailer.registeredAddress.country` | Account | `BillingCountry` | Text | 80 | No | Default `United Kingdom` if null. | `United Kingdom` |
| `retailer.tradingAddress.*` | Account | `Shipping*` (Street/City/PostalCode/Country) | Text | as above | No | Same transforms as Billing. If `tradingAddress` null, copy `Billing*`. | `Norwich` |
| `retailer.primaryPhone` | Account | `Phone` | Phone | 40 | No | Normalise to E.164 where possible (`+44 1603 123456`). | `+441603123456` |
| `retailer.primaryEmail` | Account | `Email__c` (custom) | Email | 80 | No | Lowercase. SF Account has no standard email field, hence custom. | `info@acme-solar.co.uk` |
| `retailer.sector` | Account | `Industry` | Picklist | n/a | No | Map: `Home improvement` → `Construction`; `Renewables` → `Energy`; `Both` → `Energy`; `Other` → `Other`. Confirm with Workstream C — Shermin's org likely has a custom Sector__c picklist; if so use that instead of standard `Industry`. | `Energy` |
| `retailer.retailerProducts` | Account | `Retailer_Products__c` (custom) | Multi-select picklist | n/a | No | Join multi-select values with `;` per SF MSP convention. | `Solar PV;Battery storage` |
| `retailer.expectedMonthlyVolume` | Account | `Expected_Monthly_Volume__c` (custom) | Currency | 16,2 | No | Pass through, GBP. | `45000.00` |
| `retailer.expectedMonthlyApplications` | Account | `Expected_Monthly_Applications__c` (custom) | Number | 6,0 | No | Integer. | `25` |
| `retailer.averageTicketSize` | Account | `Average_Ticket_Size__c` (custom) | Currency | 14,2 | No | GBP. | `1800.00` |
| `retailer.contractSignedDate` | Account | `Contract_Signed_Date__c` (custom) | Date | n/a | No | ISO 8601 `YYYY-MM-DD`. | `2026-04-15` |
| `retailer.complianceOutcome` | Account | `Compliance_Outcome__c` (custom) | Picklist | n/a | No | Pass through enum value. | `Pass` |
| `retailer.complianceCheckDate` | Account | `Compliance_Check_Date__c` (custom) | Date | n/a | No | ISO 8601. | `2026-04-10` |
| `retailer.crmExternalId` | Account | `CRM_External_Id__c` (custom, External ID, Unique) | Text | 36 | Yes | The upsert key. UUID v4 stringified. | `7c1f2c0e-...-...` |
| (system) | Account | `Source__c` (custom) | Picklist | n/a | No | Hard-coded `CRM` for all pushes from this system. | `CRM` |
| (system) | Account | `Pushed_At__c` (custom) | DateTime | n/a | No | Set by Lambda to UTC now at push time. | `2026-04-29T10:15:00Z` |
| `retailer.assignedBdm` (resolved to user email) | Account | `OwnerId` | Reference (User) | 18 | Yes (SF default required) | Lookup SF User by email matching the Twenty workspaceMember's email. If no match, fall back to a configured default owner (e.g. Sales Support team queue). Confirm fallback owner. | `0051x00000Abc12AAA` |

---

## Contact-bound fields

Source: the **primary** `retailer_contact` (where `isPrimary = true and active = true`) and its linked `person`. Destination: Salesforce `Contact`.

| Twenty field | SF object | SF field | SF type | Length | Required in SF? | Transform notes | Sample value |
|---|---|---|---|---|---|---|---|
| `person.firstName` | Contact | `FirstName` | Text | 40 | No (but recommended) | Pass through. | `Sarah` |
| `person.lastName` | Contact | `LastName` | Text | 80 | Yes | Pass through. SF rejects empty. | `Patel` |
| `person.email` | Contact | `Email` | Email | 80 | No | Lowercase. | `sarah.patel@acme-solar.co.uk` |
| `person.phone` | Contact | `Phone` | Phone | 40 | No | E.164. | `+447700900000` |
| `retailer_contact.role` | Contact | `Title` | Text | 128 | No | Map enum to a free-text title: `Director` → `Director`; `Compliance Officer` → `Compliance Officer`; `Operations` → `Operations Manager`; `Finance` → `Finance Manager`; `Sales` → `Sales Manager`; `Other` → blank. Confirm whether Shermin's org has a custom `Contact_Role__c` picklist that should be used instead. | `Director` |
| `retailer.crmExternalId` (with `-contact` suffix) | Contact | `CRM_External_Id__c` (custom, External ID, Unique) | Text | 64 | Yes | Format: `{retailer.crmExternalId}-contact-{retailer_contact.id}`. Ensures contact upsert key is unique and tied to the retailer. | `7c1f...-contact-9b2...` |
| Account ref | Contact | `AccountId` | Reference (Account) | 18 | Yes (for our use) | Set in the same Composite API call: SF resolves the new Account's id from the Account upsert response and links the Contact. | `001...` |
| (system) | Contact | `Source__c` (custom) | Picklist | n/a | No | Hard-coded `CRM`. | `CRM` |
| (system) | Contact | `Pushed_At__c` (custom) | DateTime | n/a | No | UTC now. | `2026-04-29T10:15:00Z` |

---

## New custom fields to create in Salesforce

These are the system-managed integration fields. To be created on **both** Account and Contact, identically.

| Field label | API name | SF type | Length / values | Required | External ID? | Unique? | Notes |
|---|---|---|---|---|---|---|---|
| CRM External Id | `CRM_External_Id__c` | Text | 64 | Yes | Yes | Yes | The upsert key for the Composite API call. Indexed automatically by SF when External ID is set. |
| Source | `Source__c` | Picklist | values: `CRM`, `Manual`, `Stax`, `Other` | No | No | No | Identifies which system created/last-touched the record. The CRM always sets this to `CRM` on push. |
| Pushed At | `Pushed_At__c` | DateTime | n/a | No | No | No | Last successful push timestamp from the CRM. Distinct from SF's standard `LastModifiedDate`. |

There may also be other retailer-specific custom fields (the `*__c` fields referenced in the mapping tables above: `TradingName__c`, `CompaniesHouseNumber__c`, `FCA_Status__c`, etc.) that need creating. Workstream C is auditing the existing org to confirm which already exist, which need new creation, and which clash with existing field names. Treat the `*__c` names in this doc as proposed, not final.

---

## Naming convention

Field API names in this doc follow Salesforce's standard convention (PascalCase with `__c` suffix for custom). Shermin's existing SF org may have its own convention (e.g. `Shermin_*__c` prefix, or a different casing), and there may be existing fields with similar semantics we should reuse rather than duplicate.

**Action:** Workstream C is auditing this. See [`sf-discovery.md`](sf-discovery.md). Final field names confirmed there override the proposals here. Any field marked `(custom)` in the tables above should be treated as a placeholder until Workstream C signs off.

---

## Composite API request shape (reference)

```jsonc
POST /services/data/v60.0/composite
{
  "allOrNone": true,
  "compositeRequest": [
    {
      "method": "PATCH",
      "url": "/services/data/v60.0/sobjects/Account/CRM_External_Id__c/{retailer.crmExternalId}",
      "referenceId": "AccountUpsert",
      "body": { /* Account fields per the table above */ }
    },
    {
      "method": "PATCH",
      "url": "/services/data/v60.0/sobjects/Contact/CRM_External_Id__c/{retailer.crmExternalId}-contact-{retailer_contact.id}",
      "referenceId": "ContactUpsert",
      "body": {
        /* Contact fields per the table above */
        "AccountId": "@{AccountUpsert.id}"
      }
    }
  ]
}
```

`allOrNone: true` ensures atomicity: if Contact upsert fails (e.g. validation rule), the Account upsert is rolled back, the CRM never writes back `salesforceAccountId`, and the failure is recorded on `integration_log`.

---

## Open questions for Barney (and Workstream C / SF Admin)

1. **Existing field reuse.** Shermin's SF org likely already has fields covering some of these (e.g. an existing `Industry`, an existing custom Compliance status field). Workstream C confirms; until then, treat all `*__c` names as proposed.
2. **`Source__c` picklist values.** Spec'd as `CRM`, `Manual`, `Stax`, `Other`. Are there existing source values in the org we should align with? E.g. campaign sources, lead sources.
3. **`OwnerId` mapping.** SF Account requires an Owner. Mapping is by email match between Twenty workspaceMember and SF User. What's the fallback when there's no match (BDM has no SF login, ex-employee, or Sales Support is a queue)? Recommended: a dedicated SF queue `CRM_Onboarding_Queue` as the fallback owner.
4. **Industry / Sector.** Standard SF `Industry` is a picklist with fixed values. Do we map Shermin sectors to SF's standard values (`Construction`, `Energy`, etc.) or push to a custom `Sector__c` picklist that mirrors Twenty's enum? Recommend custom for analytical fidelity.
5. **Trading address vs Shipping address.** SF Account has Billing + Shipping. We've mapped registered → Billing, trading → Shipping. Confirm this matches how the Sales Ops team thinks of those fields, since some orgs use Shipping for the customer's "operational" address rather than a delivery address.
6. **`Phone` normalisation.** Push to E.164 (`+44...`) or leave in UK national format (`01603 ...`) to match what Sales Ops are used to seeing? Recommend E.164 for consistency.
7. **Do we push contact `MailingAddress`?** Spec'd as no — we don't capture per-person addresses today. Confirm Sales Ops don't need a Contact mailing address pre-populated.
8. **Multi-contact push.** v1 pushes only the primary contact. Some retailers will have a separate compliance contact, finance contact, etc. that Sales Ops want in SF too. Defer to v2, or push all `active` contacts on first sync? Recommend v2 to keep v1 atomicity simple.
9. **Reverse sync (SF → Twenty).** Out of scope per the plan, but worth confirming: if a Sales Ops user edits an Account in SF, those edits do **not** flow back to Twenty. Anyone in Sales Ops needs to know this to avoid divergence.
10. **API version pinning.** Composite API URL above uses `v60.0`. Confirm Shermin's org is on a recent enough release; pin in env config to avoid silent upgrades.
