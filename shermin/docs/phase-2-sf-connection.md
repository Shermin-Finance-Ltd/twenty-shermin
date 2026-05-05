# Phase 2 — Salesforce connection architecture

How the Twenty CRM authenticates to and talks with Salesforce. Read this if you're picking up Phase 2 work or wondering why we don't have our own JWT key.

## Pattern: reuse the existing shared auth Lambda

Every existing AWS-to-Salesforce integration in the org (`polling`, `lender-webhooks`, `ecommerce`) shares a single auth Lambda named `lambda-sf-auth-{env}`. It loads a JWT private key from Secrets Manager, signs a JWT bearer assertion, exchanges it for an OAuth access token at the Salesforce token endpoint, and returns `{access_token, instance_url, expires_at}` to whoever called it.

Twenty CRM joins as the fifth caller of that helper.

```
┌─────────────────────────────────────────────────────┐
│ Twenty CRM workspace (Stax CRM)                     │
│   Phase 2b: webhook on Retailer stage transition    │
│   Phase 2c: webhook on Activity record create       │
└─────────────────────────────────────────────────────┘
                       │ HTTPS POST (Phase 2b+)
                       ▼
┌─────────────────────────────────────────────────────┐
│ API Gateway + WAF (Phase 2b+)                       │
└─────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ twenty-crm-sf-push-{env} Lambda      OUR LAMBDA      │
│   Phase 2a: action=describe (smoke test)            │
│   Phase 2b: action=upsertAccount, upsertContact     │
│   Phase 2c: action=logActivity                      │
└─────────────────────────────────────────────────────┘
                       │ lambda:Invoke (RequestResponse)
                       ▼
┌─────────────────────────────────────────────────────┐
│ lambda-sf-auth-{env}  EXISTING SHARED LAMBDA        │
│   Loads /webhooks/salesforce/jwt from SM            │
│   Signs JWT, exchanges for SF access token          │
│   Returns {access_token, instance_url, expires_at}  │
└─────────────────────────────────────────────────────┘
                       │ OAuth 2.0 JWT bearer flow
                       ▼
┌─────────────────────────────────────────────────────┐
│ Salesforce sherminmax--uat (sandbox)                │
│   Account, Contact, (Phase 2c) Task                 │
└─────────────────────────────────────────────────────┘
```

## Why we share the auth Lambda

| Reason | Detail |
|---|---|
| One JWT key to rotate | Secret rotation playbook already covers all five callers |
| One Connected App in SF | No proliferation of integration users / consumer keys / private keys |
| One audit identity | All integration writes appear as `integration.user@shermin.com.uat` in SF audit |
| Distinguish writers via `Source_of_Update__c` | Existing audit pattern. Twenty writes `Twenty_CRM_Push`; polling writes `Polling_Process`; etc. |

Operational dependency: if `lambda-sf-auth-dev` is down or its IAM resource policy changes, every SF integration in the org stops working including Twenty's. Acceptable trade-off given that's a critical shared resource that's already monitored.

## Why NOT reuse via proxy through `polling`

Considered and rejected. `polling`'s Lambdas are EventBridge-scheduled; they don't expose a synchronous HTTP surface. Adding one would entangle Twenty's reliability with `polling`'s release cadence. Direct invocation of the shared auth Lambda gives identical reuse benefit with cleaner separation.

## Salesforce-side facts (verified by Phase 2a A1 describe)

Captured from a successful `aws lambda invoke twenty-crm-sf-push-dev` at apply time:

| Object | Total fields | Standard | Custom | Record types |
|---|---|---|---|---|
| Account | 221 | 81 | **140** | 8 (incl. PersonAccount, Lender, Retailer, Retailer_Branch, Retailer_IAR, Retailer_IAR_Branch) |
| Contact | 87 | 46 | **41** | 2 (Contacts, Master) |

When we write retailer records from Twenty in Phase 2b we'll target the `Retailer` Account record type (and possibly `Retailer_IAR` for IAR retailers — TBD when Barney annotates the schema CSV).

## Permissions: what the integration user can do today vs needs to do

**Today** (per repo evidence — polling, lender-webhooks):
- Read Application__c, Application_Decision__c
- Update Application_Decision__c
- (Inferred but unverified) Read Account, Contact

**Needs to do** for Twenty CRM Phase 2:
- Create + Update Account
- Create + Update Contact
- Create Task (Phase 2c, for activity push)

This requires a new permission set `Twenty_CRM_Account_Contact_Write` — see `discovery/neethu-asks.md` ask #2.

## Audit pattern

Every record Twenty writes to Salesforce will set:
- `Source_of_Update__c = "Twenty_CRM_Push"` (new field, ask #3 in `neethu-asks.md`)

Lets the Salesforce team filter out Twenty-originated writes from manual or other integration writes when investigating data lineage.

## Files

- `shermin/lambda/sf-push/src/main.py` — Lambda handler
- `shermin/lambda/sf-push/README.md` — usage / test
- `shermin/infra/terraform/sf-integration/` — Terraform module
- `shermin/infra/terraform/sf-integration/README.md` — apply / destroy

## v2 deferred items (relevant to this connection layer)

| Item | Rationale for deferral |
|---|---|
| Production SF writes | Would need a separate Connected App + integration user + secret in the prod org. Phase 2 ships against sandbox only. |
| Direct JWT (not via shared auth Lambda) | We could load the secret ourselves and skip the cross-Lambda invoke. ~50 ms latency saving per call. Not worth the duplicated rotation complexity. |
| API Gateway in front of `sf-push` Lambda | Phase 2a runs against `aws lambda invoke` only. API Gateway gets added in Phase 2b when we wire Twenty webhooks. |
