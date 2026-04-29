# Existing Shermin infra audit

Read for: anyone provisioning AWS or building integrations for the new CRM. Goal is to align with how Shermin already does things rather than starting from scratch. The audit was done by reading READMEs, Terraform root files, GitHub Actions workflows, and example modules in the `Shermin-Finance-Ltd` GitHub org.

## Inferred AWS account structure

Shermin runs a multi-account AWS strategy in a single region:

| Environment | AWS Account ID | Region    |
|-------------|----------------|-----------|
| Development | 992914515467   | eu-west-2 |
| Test        | 302428338316   | eu-west-2 |
| Production  | 869894983688   | eu-west-2 |

These IDs are referenced consistently across `infrastructure`, `loan-application`, and `Admin-SalesForceProxy-Service` workflow files, which strongly suggests they are the canonical Shermin / Stax accounts. There is no evidence of further account splits per service, so all services live alongside each other inside the same per-environment account.

The CRM should land in these same three accounts, in eu-west-2, unless there is a reason to isolate it (e.g. a Homeserve-side account). Worth confirming with Nicky.

## Inferred IaC pattern

**Terraform, full stop.** Every infra-bearing repo I checked uses HCL:

- `infrastructure` (HCL) — core API Gateway, ECS cluster, WAF, Route53, KMS, Secrets Manager.
- `stax-admin-infrastructure` (HCL) — modules for `api_gateway`, `cloudwatch`, `dynamodb`, `ecr`, `iam`, `lambda`, `secrets`, `vpc`, `waf`.
- `loan-application` (HCL inside `infrastructure/`) — Lambda, Step Functions, API Gateway routing.
- `lender-webhooks` (HCL at repo root) — Lambdas, Step Functions, alarms.
- `polling` (HCL) — EventBridge, Lambdas, ECS Fargate, DynamoDB.
- `ecommerce` (HCL) — ECS, SQS, DynamoDB, Lambda, API Gateway.

Common conventions:

- Terraform `>= 1.13.4` is the floor (pinned to `1.13.4` in the workflows).
- AWS provider `~> 6.0`.
- A reusable `lambda` module is duplicated across repos (`infrastructure/modules/lambda`, `lender-webhooks/infra/modules/lambda`, `loan-application/infrastructure/modules/lambda`, `stax-admin-infrastructure/modules/lambda`). The contents look near-identical, so this is a copy-paste pattern, not a published module. Worth knowing if we want a single source of truth.
- Per-environment config in `env/<environment>/backend-config.hcl` and `env/<environment>/environment.tfvars`. S3 backends per env.
- `sops` is in use for KMS-encrypted secret JSON committed to the repo (see `infrastructure/sops.yaml`).

There is no CDK, no SAM, no CloudFormation, and no Pulumi. CDK / SAM patterns suggested in the brief do not match reality — the house standard is Terraform. The CRM should follow that.

## Inferred deployment pattern

GitHub Actions, manually triggered, OIDC to AWS. The pattern repeats almost verbatim across `infrastructure`, `loan-application`, `lender-webhooks`, and `polling`:

- Two workflows: `terraform-plan.yml` (PR / manual) and `terraform-apply.yml` (manual `workflow_dispatch`).
- `workflow_dispatch` input `environment` (development / test / prod).
- AWS account ID is selected via a ternary on the input.
- OIDC role: `arn:aws:iam::<ACCOUNT_ID>:role/github-actions-oidc-terraform-role`.
- `actions/checkout@v4.2.1`, `aws-actions/configure-aws-credentials@v4`, `hashicorp/setup-terraform@v3`.
- For Lambda repos: a `package-lambdas.sh` script that uses Docker / SAM build images to package functions, then `actions/cache@v4` keys on file hashes.
- `terraform init -backend-config=env/<env>/backend-config.hcl` then `terraform apply -var-file=env/<env>/environment.tfvars`.

`Admin-SalesForceProxy-Service` is the outlier: a Go / Gin Lambda container, deployed via a separate `imageDeploy.yaml` workflow that builds for ARM64, pushes to ECR (`<env-account>.dkr.ecr.eu-west-2.amazonaws.com/admin-app-<env>-proxy-service`), and updates the Lambda. Branch-driven (`development` / `test` / `main`), not `workflow_dispatch`.

There is a Checkov step commented out in several workflows ("To fix later on"). Worth uncommenting and fixing for the CRM from day one — it's cheap.

## Inferred auth / secrets pattern

- **AWS Secrets Manager** is the standard. Salesforce credentials live at `salesforce/authentication/<environment>` in `infrastructure`, and at `/webhooks/salesforce/jwt` in `lender-webhooks`. The first is the central one and is the source of truth for non-webhook services.
- **KMS CMKs** per environment, aliased `alias/<env>-app-secrets`, with `enable_key_rotation = true`. Created in `infrastructure/secrets.tf`.
- **`sops` + KMS** is used for secret JSON committed to the `infrastructure` repo (see `sops.yaml`).
- **No static IAM keys in repos.** Everything is OIDC-from-GitHub or Lambda execution roles. Good.
- IAM role policies are inlined via `jsonencode()` in Terraform (see `lender-webhooks/lambda-sf-auth.tf`), not separate JSON files. Match this style.

## Inferred logging / observability pattern

- Every Lambda / ECS service gets a CloudWatch Log Group declared explicitly in Terraform.
- **No consistent log group naming convention.** Examples in the wild:
  - `/ecs/prod-sf-event-listener` (ecommerce)
  - `<env>-stax-ecs` cluster log group (infrastructure)
  - `<lender>-step-function-logs` (loan-application)
  - `aws_cloudwatch_log_group.poll_bnp_propensio_logs` (polling)
- Retention varies: 7-day for API Gateway / ECS, 30-day for WAF.
- **CloudWatch alarms via SNS topic + email subscription.** See `lender-webhooks/alarms.tf` — a per-environment `sfn-inactivity-webhook-alerts-<env>` SNS topic, email subscriptions populated from a tfvar `alarm_email_addresses`, and one `aws_cloudwatch_metric_alarm` per Step Function watching `ExecutionsStarted < 1` over 24h. Clean and copyable.
- **Container Insights** enabled on ECS clusters.
- No evidence of structured logging libraries, no central log aggregation (Datadog / NewRelic), no APM. CloudWatch is the only game in town.

## Inferred Salesforce integration pattern (cross-ref Workstream C)

This is the biggest find. **There is already a JWT Bearer Flow Salesforce auth Lambda we can copy.** It lives at `lender-webhooks/lambdas/sf-auth/main.py` (Python 3.13). It:

- Reads a secret from Secrets Manager (`SECRET_NAME` env var, default `/webhooks/salesforce/jwt`) containing `consumer_key`, `username`, `token_url`, `private_key_pem`, optional `private_key_password`.
- Builds an RS256-signed JWT assertion using `cryptography`.
- Either returns the assertion, or exchanges it for an access token via `urn:ietf:params:oauth:grant-type:jwt-bearer`.
- Returns `{access_token, instance_url, expires_at}`.

Other services either invoke this Lambda by ARN (`SF_AUTH_FUNCTION` env var across `lender-webhooks` handlers and `polling`) or do the same JWT flow themselves (`ecommerce` calls it `SalesforceJWTAuth`).

There is a separate `Admin-SalesForceProxy-Service` (Go) which is a session-based proxy for the admin portal — it uses session cookies validated via `Admin-Auth-Service`, and forwards SOQL queries to Salesforce, working around WAF blocking SQL-like URLs by accepting POST bodies and converting to GET. Different concern from the CRM's needs (we want a server-to-server push, not a per-user proxy).

The Salesforce REST API endpoints used for writes are typically Apex REST custom endpoints, e.g. `/services/apexrest/updateApplicationStatus`. So the Salesforce-side write path is custom Apex, not standard sObject REST. Workstream C should confirm whether the CRM's "push contact / opportunity to Salesforce" should also go through a custom Apex endpoint, or use the standard sObject REST API.

## Inferred webhook pattern (relevant to our SF push Lambda)

`lender-webhooks` is the model. Architecture:

```
API Gateway → Webhook Router Lambda → Step Function → Handler Lambda → Salesforce
                                            ↑
                                       SF Auth Lambda
```

- Single API Gateway path per lender (`/webhooks/notifications/<lender>`).
- One router Lambda that picks the Step Function ARN by path.
- Per-source Step Functions defined as JSON in `step-functions/lenders/<lender>.json`.
- Step Functions provide retry logic and configurable delays.
- Handlers parse, transform, call SF Auth, then call Salesforce.
- CloudWatch alarm per Step Function on `ExecutionsStarted` to detect a webhook source going silent.

For the CRM's outbound push to Salesforce, we are *sending*, not receiving, so the architecture is closer to: Twenty webhook → API Gateway → push Lambda → SF Auth Lambda → Salesforce. We can copy the SF Auth Lambda verbatim, copy the alarm pattern, copy the Step Function pattern if we need retries, and skip the router.

## Repo-by-repo notes

### infrastructure
- **Purpose:** Core shared AWS infra for Stax — REST API Gateway (`stax-api-gw`), ECS cluster, WAF (IP whitelist), Route53, ACM, KMS, Secrets Manager.
- **IaC:** Terraform, `infrastructure/` subdir, single root, modules in `infrastructure/modules/lambda`, env folders in `infrastructure/env/{development,test,production}`.
- **Deploy:** GitHub Actions, OIDC, manual `workflow_dispatch`, `terraform apply --auto-approve`.
- **Patterns to copy:** OIDC role naming (`github-actions-oidc-terraform-role`), env-config layout, KMS-CMK-per-env for app secrets, central Secrets Manager path scheme `<service>/<purpose>/<env>`.
- **Patterns to avoid:** WAF default action is BLOCK with IP whitelist, with hardcoded path exceptions for Allium / BNP. That works for a B2B webhook receiver but won't suit an internal app — the CRM probably wants an SSO-gated approach instead, or a VPN / Tailscale front door.

### stax-admin-infrastructure
- **Purpose:** Admin portal infrastructure (auth, proxy, embedded apps, permissions). The most "modular" of the bunch.
- **IaC:** Terraform with first-class modules: `api_gateway`, `cloudwatch`, `dynamodb`, `ecr`, `iam`, `lambda`, `secrets`, `vpc`, `waf`. `environments/{dev,test,prod}` for env config.
- **Patterns to copy:** Module layout. This is the cleanest TF in the org. If we end up writing more than two or three Lambdas for the CRM, we should mirror this structure for the CRM-specific resources.
- **Patterns to avoid:** None obvious from the README.

### shared-services-infra
- **Empty repo.** Created but never populated. Worth asking if it was intended as the canonical "all shared infra" repo before getting absorbed into `infrastructure`.

### loan-application
- **Purpose:** Serverless loan submission to lender APIs via Step Functions.
- **IaC:** Terraform in `infrastructure/`, with `lambdas/` source and `step-functions/` JSON definitions.
- **Patterns to copy:** Cascading-timeout pattern (API GW 120s → Router 115s → SFN 105s → Lender 90s → API call 75s, with 5–15s buffer at each level). Worth adopting for any CRM call that touches Salesforce or external services. Also the `package-lambdas.sh` + Docker-based packaging + Actions cache on file hashes pattern.
- **Patterns to avoid:** Separate `terraform-apply-prod.yml` and `terraform-plan-prod.yml` workflows on top of the generic ones — feels like accidental duplication, probably to gate prod behind a different reviewer set. We could just use GitHub `environments` for that.

### lender-webhooks
- **Purpose:** Inbound lender webhooks, push to Salesforce.
- **IaC:** Terraform at repo root (no subdir wrapper). Modules at `infra/modules/lambda`, `infra/modules/snf_lender`.
- **Patterns to copy:** **Everything**. This is the closest analogue to what the CRM's SF push will need. Specifically: SF Auth Lambda (`lambdas/sf-auth/`), the per-domain Step Function pattern, the SNS-topic-per-env alarm pattern (`alarms.tf`), tagging convention `{ Environment = var.environment, Project = "lender-webhooks" }`.
- **Patterns to avoid:** None significant. The repo-root TF layout is fine; the wrapped `infrastructure/` style in other repos is also fine. Pick one and stay consistent.

### Admin-SalesForceProxy-Service
- **Purpose:** Per-user SOQL proxy for the admin portal. Go / Gin / Lambda container on ARM64.
- **IaC:** Implied — uses ECR per env, Lambda per env, but the Terraform for those is presumably in `stax-admin-infrastructure`.
- **Patterns to copy:** Branch-driven deploy (`development` / `test` / `main` → corresponding env) is cleaner than `workflow_dispatch` for a service with frequent code changes. ARM64 Lambda containers are cheap. Swagger auto-generated from Gin annotations.
- **Patterns to avoid:** Not relevant for the CRM — different problem (per-user session proxy vs server-to-server push). Worth being aware of as a separate hop if the CRM ever needs to query Salesforce through the same WAF.

### polling
- **Purpose:** Scheduled polling of lender APIs, comparison to Salesforce, write-back on mismatch. EventBridge → Lambda fanout, DynamoDB for batch state.
- **IaC:** Terraform in `infrastructure/`. Same patterns as the others.
- **Patterns to copy:** EventBridge schedule pattern, DynamoDB on-demand billing with TTL, `MAX_RECORDS_PER_BATCH` style env var driven config.
- **Patterns to avoid:** Lambda + ECS hybrid for one workflow (BNP Propensio polling runs on ECS Fargate while everything else is Lambda) — this looks like it grew organically and is a smell, not a model.

### ecommerce
- **Purpose:** Salesforce CDC event consumer. CometD long-polling on ECS, SQS for buffering, Lambda for retailer webhook fanout. DynamoDB for replay state.
- **IaC:** Terraform.
- **Patterns to copy:** Replay-state-in-DynamoDB pattern is good for any CDC / event-stream consumer. SQS with DLQ for inbound buffering is the right shape if we ever want to mirror SF objects into the CRM via CDC instead of polling.
- **Patterns to avoid:** ECS Fargate for what is essentially a "long-running connection holder" works but is more expensive than necessary. If we go this route, consider whether EventBridge Pipes or SF Pub/Sub API + Lambda would be a cleaner v1.

### stax-docs
- **Purpose:** Astro Starlight + Mermaid + Pagefind docs site for Stax internals. Private.
- **Useful for:** It's the canonical place to find architecture diagrams that the CRM should fit into. Worth pointing at it from `SHERMIN.md` rather than duplicating diagrams.

## Recommendations for the CRM project

1. **Use Terraform, not SAM or CDK.** The brief floated CDK/SAM. The house standard is Terraform `>= 1.13.4` with AWS provider `~> 6.0`. Match it. The marginal cost of learning is much lower than the cost of being the only repo using SAM.
2. **Start from the `lender-webhooks` repo template.** For the SF push Lambda specifically, copy the SF Auth Lambda (`lambdas/sf-auth/main.py`) verbatim, copy the alarm pattern from `alarms.tf`, and copy the GitHub Actions workflows. We will save a week.
3. **Use the existing OIDC trust pattern.** The role `github-actions-oidc-terraform-role` already exists in all three accounts. Confirm with Nicky whether we can reuse it from a new repo or whether we need a per-repo role; either way, mirror the pattern.
4. **Use Secrets Manager with the established naming `<service>/<purpose>/<env>`.** For the CRM, suggest `twenty-shermin/db/<env>`, `twenty-shermin/salesforce/<env>`, `twenty-shermin/oauth/<env>`. Wrap with a per-env KMS CMK aliased `alias/<env>-twenty-shermin-secrets`.
5. **Adopt the cascading-timeout pattern** from `loan-application` for any CRM-side call into Salesforce. Sensible defaults: API GW 30s, Lambda 25s, outbound HTTP 20s.
6. **Standardise log group naming as `/shermin/twenty-shermin/<resource>/<env>`** — this gives us a clean prefix nobody else is using and makes log search trivial. The org doesn't have a single existing convention so we can pick.
7. **Tag every resource** with `{ Environment, Project = "twenty-shermin", ManagedBy = "terraform" }`. The org is inconsistent here — the `lender-webhooks` shape (`Project = "lender-webhooks"`) is the simplest version, copy it.
8. **Turn Checkov on from day one.** Several repos have it commented out with a "to fix later" note. Cheaper to fix as we go than to retro-fit.

## Open questions for Barney

- Will the CRM live in the existing dev / test / prod accounts (992914515467 / 302428338316 / 869894983688), or is there a Homeserve-side AWS account we should land in instead?
- Can a new repo (`twenty-shermin`) reuse the existing `github-actions-oidc-terraform-role` in each account, or does each repo get its own OIDC role? Worth checking with Nicky.
- Is the `shared-services-infra` repo deprecated, or are we expected to put cross-CRM-and-Stax shared infra (e.g. a VPC peering, a shared SNS alarm topic) into it?
- For the Salesforce push direction, should we hit standard sObject REST (`/services/data/vXX.0/sobjects/Contact`) or a custom Apex endpoint like the existing `updateApplicationStatus`? Workstream C is best placed to answer.
- Is there an existing CloudWatch alarm SNS topic the wider team subscribes to, or do we set up our own per the `lender-webhooks` pattern? Per-env email distribution list would be useful.
- Does Shermin already have a budget or cost-tag policy we need to follow on AWS? Nothing in the public repos suggests one, but it would be worth knowing before we provision a new ECS cluster + RDS instance for Twenty.
