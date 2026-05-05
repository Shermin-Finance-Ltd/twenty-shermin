# sf-push Lambda

Twenty CRM → Salesforce integration. **Phase 2a scope: connection only** — proves auth round-trip works by describing Account + Contact. Write logic comes in Phase 2b/2c.

## Auth pattern

We never load the JWT secret directly. We invoke the existing shared `lambda-sf-auth-{env}` Lambda which lives in the same AWS account and is shared across `polling`, `lender-webhooks`, `ecommerce`. It returns `{access_token, instance_url, expires_at}`. Same pattern as the rest of the org.

## Local test (after deploy)

```bash
aws lambda invoke \
  --function-name twenty-crm-sf-push-dev \
  --payload '{"action":"describe","sobjects":["Account","Contact"]}' \
  --cli-binary-format raw-in-base64-out \
  --profile shermin-dev \
  /tmp/out.json && cat /tmp/out.json | python3 -m json.tool | head -50
```

Expected output (truncated):

```json
{
  "statusCode": 200,
  "body": {
    "action": "describe",
    "instance_url": "https://sherminmax--uat.sandbox.my.salesforce.com",
    "result": {
      "Account": {"fieldCount": 155, "customFieldCount": 133, "recordTypes": [...]},
      "Contact": {...}
    }
  }
}
```

## Files

- `src/main.py` — handler. Currently describes; will grow to upsert + push activity.
- `src/requirements.txt` — empty for v0a.

## Phase 2 roadmap for this Lambda

| Phase | Action | Capability |
|---|---|---|
| 2a (now) | `describe` | Smoke-test auth + read schema |
| 2b | `upsertAccount`, `upsertContact` | Push retailer + contact records on stage transition |
| 2c | `logActivity` | Push call/email/meeting from Twenty Activity object as SF Task |

## Deploy

Provisioned via Terraform in `shermin/infra/terraform/sf-integration/`. See that module's README.
