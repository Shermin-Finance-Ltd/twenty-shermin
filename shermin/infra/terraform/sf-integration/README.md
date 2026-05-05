# Terraform — sf-integration module

Provisions the AWS-side resources for the Twenty CRM → Salesforce integration.

## What's in here

- **`twenty-crm-sf-push-{env}` Lambda** — Python 3.13 function that talks to Salesforce. Phase 2a: read-only describe. Phase 2b/c: upsert + activity push.
- **IAM role** — minimum permissions: CloudWatch logs + invoke `lambda-sf-auth-{env}` only.
- **CloudWatch log group** — 30-day retention.

Deliberately NOT in this module (yet):

- API Gateway (will be added in Phase 2b when Twenty webhooks need an HTTP endpoint).
- The Twenty webhook receiver Lambda — separate function, separate IAM, will live alongside `sf-push` here.
- An SQS queue + DLQ — added in Phase 2b for retry / failure handling.

## Conventions

- **State backend**: same bucket as the v0 module (`stax-development-terraform-state-bucket`), separate key (`twenty-shermin/sf-integration/terraform.tfstate`). Independent state from `terraform/v0/` so applies don't risk-couple the Lambda with the EC2 / RDS infrastructure.
- **Auth pattern**: every SF call goes through the existing shared `lambda-sf-auth-{env}` Lambda. We never load the JWT secret directly. Same pattern as `polling`, `lender-webhooks`, `ecommerce`.
- **Tags**: inherits the org-wide `Service / Environment / Project / Owner` defaults, plus `Module = sf-integration`.

## Apply

```bash
cd shermin/infra/terraform/sf-integration
export AWS_PROFILE=shermin-dev

terraform init -backend-config=env/dev/backend-config.hcl
terraform plan -var-file=env/dev/dev.tfvars -out=plan.tfplan
terraform apply plan.tfplan
```

First apply: ~30 seconds. Subsequent applies (Lambda code change): ~10 seconds (Lambda update).

## Test (after apply)

```bash
aws lambda invoke \
  --function-name $(terraform output -raw sf_push_function_name) \
  --payload '{"action":"describe","sobjects":["Account","Contact"]}' \
  --cli-binary-format raw-in-base64-out \
  --profile shermin-dev \
  /tmp/sf-push-test.json && cat /tmp/sf-push-test.json | python3 -m json.tool
```

Expected: `statusCode: 200`, `result.Account.fieldCount` around 150-160 (133 custom + ~25 standard).

## Tail logs

```bash
aws logs tail $(terraform output -raw sf_push_log_group) --follow --profile shermin-dev
```

## Destroy

```bash
terraform destroy -var-file=env/dev/dev.tfvars
```

Doesn't touch the v0 EC2/RDS state. Doesn't touch the shared `lambda-sf-auth-dev` Lambda (we only consumed it via `data` source).
