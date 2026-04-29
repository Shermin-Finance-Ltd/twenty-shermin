# sf-push Lambda

Salesforce push pipeline. Receives a webhook from Twenty when a `Retailer` reaches the "Setup in Stax" stage, and upserts the corresponding Account + Contact in Salesforce.

Phase 1 deliverable — populated after Phase 0 discovery completes the Salesforce field-mapping and sandbox audit.

## Architecture

```
Twenty webhook
    ↓
API Gateway endpoint (HMAC-validated)
    ↓
Receiver Lambda (validates signature, returns 202)
    ↓
SQS queue (14-day retention)
    ↓
Worker Lambda (consumes SQS, calls SF Composite API)
    ↓ on 5x retry failure
DLQ + CloudWatch alarm → SNS email
```

## Auth flow

OAuth 2.0 JWT Bearer Flow:
- Private key in AWS Secrets Manager (never on disk).
- Sign JWT with `iss = client_id`, `sub = integration user`, `aud = https://login.salesforce.com`, `exp = +3 min`.
- POST to `/services/oauth2/token` with `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`.
- Cache access token ~30 minutes.

## Composite request (idempotent upsert)

```
POST /services/data/v60.0/composite
{
  "allOrNone": true,
  "compositeRequest": [
    {
      "method": "PATCH",
      "url": "/services/data/v60.0/sobjects/Account/CRM_External_Id__c/{retailer_uuid}",
      "referenceId": "AccountUpsert",
      "body": { ... }
    },
    {
      "method": "PATCH",
      "url": "/services/data/v60.0/sobjects/Contact/CRM_External_Id__c/{contact_uuid}",
      "referenceId": "ContactUpsert",
      "body": { "AccountId": "@{AccountUpsert.id}", ... }
    }
  ]
}
```

## Files (to come in Phase 1)

- `template.yaml` — SAM template (Lambdas, API Gateway, SQS, DLQ, alarm).
- `src/receiver/handler.ts` — webhook receiver Lambda.
- `src/worker/handler.ts` — SF push worker Lambda.
- `src/lib/salesforce.ts` — JWT signing, token cache, composite request builder.
- `src/lib/twenty.ts` — Twenty REST client (writes `salesforce_account_id` back).
- `tests/` — unit tests with SF API mocked.

## Open questions for Phase 0

See [`shermin/docs/sf-discovery.md`](../../docs/sf-discovery.md):
- Salesforce edition confirmation
- Existing custom field naming conventions to avoid clash
- Sandbox to use for build (full / partial / dev)
- Existing integration user / Connected App pattern in the org (cf. `Admin-SalesForceProxy-Service` repo)
