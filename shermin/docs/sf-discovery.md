# Salesforce sandbox discovery

Audit of Shermin's existing Salesforce footprint, conducted before building the Twenty CRM to Salesforce integration. Goal: confirm the v1 design works against the real org, surface naming conflicts before we ship, identify the right people to involve.

The audit was done by reading the `Shermin-Finance-Ltd` GitHub org (no live SOQL was run from this workstream). Sandbox-side verification of the items flagged "needs admin to confirm" must happen before build.

## Existing integration patterns in the org

Drawn from inspecting the following `Shermin-Finance-Ltd` repos: `Admin-SalesForceProxy-Service`, `polling`, `ecommerce`, `lender-webhooks`, `loan-application`, `infrastructure`, `stax-admin-infrastructure`, and the `stax-docs` reference site.

### Admin-SalesForceProxy-Service

- Purpose: Go/Gin Lambda that proxies SOQL queries from the Stax Admin Portal to Salesforce. Handles a WAF workaround (SOQL in POST body, converted to GET before hitting SF) and a two-query merge for rate cards.
- Auth method: not directly. The proxy validates a session cookie via a separate auth service, then forwards using the user's existing access token. Token refresh is delegated to the auth service `/auth/refresh` endpoint.
- Notable env vars: `SF_API_VERSION` defaulted to `v59.0`, `AWS_REGION_NAME=eu-west-2`, `ENVIRONMENT` (`dev` / `test` / `prod`).
- Implications for our build: confirms `eu-west-2` / Lambda / API Gateway / WAF as the house pattern. SF API version `v59.0` is the existing baseline; our Composite API call should match or exceed. Owner of this service is Danville Wilks.

### polling

- Purpose: EventBridge-driven Lambdas plus a couple of ECS Fargate tasks (BNP, Propensio) that fetch outstanding applications from Salesforce, call lender APIs, and patch SF when status changes. Reconciliation backstop for missed webhooks.
- Auth method: **JWT bearer flow** to Salesforce. `salesforce_jwt_auth.py` is reused across services. Secret name is `/webhooks/salesforce/jwt` in AWS Secrets Manager.
- Notable patterns: SOQL queries kept in dedicated `salesforce_queries.py` files per lender; PATCH back to `Application_Decision__c` uses a `Source_of_Update__c` audit field (e.g. `"Webhook_Process"`, `"Submit_Process_UWNotes"`).
- Implications for our build: JWT bearer is the proven, in-house standard. Reuse the same secret schema (`consumer_key`, `username`, `token_url`, `private_key_pem`, optional `private_key_password`) and lift `salesforce_jwt_auth.py` rather than reinventing.

### ecommerce

- Purpose: ECS Fargate CometD listener for Salesforce CDC events (replaces retired Supabase webhook), plus Lambdas for ecom retailer API and webhook fan-out to retailers.
- Auth method: JWT bearer flow, identical pattern to `polling`. `salesforce_jwt_auth.py` lives in `docker/sf-event-listener/src/`.
- Notable patterns: CDC subscriptions on `/data/ApplicationChangeEvent` and `/data/Application_DecisionChangeEvent`. Replay state stored in DynamoDB `{env}-sf-event-listener-replay-state` for no-data-loss restarts. Outbound webhook payload uses `applicationStatus`, `lenderName`, `providerName`, `eventType` keys.
- Implications for our build: if we ever flip the integration from one-way push to two-way sync, CDC is the established channel. Not needed for v1.

### lender-webhooks

- Purpose: API Gateway plus Lambdas receiving inbound lender webhooks (Allium, BNP, Propensio, This Bank, V12, Zopa, Humm) and PATCHing `Application_Decision__c` in SF.
- Auth method: JWT bearer flow. Dedicated `lambdas/sf-auth/main.py` issues access tokens or raw JWT assertions on demand. Same `/webhooks/salesforce/jwt` secret.
- Notable patterns: explicit `jti` claim in the JWT (good practice we should adopt), `lifetime_seconds=180` (the SF maximum). PATCH writes with audit fields like `Source_of_Update__c`, `Proposal_Notes__c`.
- Implications for our build: this repo's `_jwt_assertion` helper is the cleanest reusable JWT builder in the org. Copy or import it.

### loan-application

- Purpose: Outbound lender submissions via Step Functions plus Lambda. Receives an Apex callout from SF, transforms the payload per lender, calls the lender API.
- Auth method: lender side varies. SF side: this is the receiving end of an Apex callout, not an outbound caller, so no SF auth in this repo. Confirms that SF Connected Apps in the org are configured for outbound (SF to AWS) and we need a separate Connected App for inbound (AWS to SF) writes, which is what JWT bearer provides.
- Implications for our build: timeout waterfall is informative if we ever invoke Composite API from inside Step Functions (API Gateway 120s, router 115s, Step Functions 105s, lender Lambda 90s, lender call 75s). Our Twenty webhook to Lambda to SF Composite path should fit comfortably under 30s.

### infrastructure / stax-admin-infrastructure

- Purpose: Terraform IaC for the core stack (API Gateway, WAFv2, Route53, ACM, ECS, Secrets Manager, KMS, GitHub OIDC).
- Notable patterns: three AWS accounts: dev `992914515467`, test `302428338316`, prod `869894983688`. Region `eu-west-2`. Domain root `staxpayaws.co.uk` with `dev.*`, `test.*`, `ecom.*` subdomains. CloudWatch log retention 7 days (most), 30 days (WAF). Secrets Manager with KMS customer-managed keys, rotation enabled.
- Implications for our build: deploy our Twenty-to-SF Lambda into the same three accounts, region, and Terraform module conventions. New Connected App secrets go into Secrets Manager under a new path (proposed `/twenty-crm/salesforce/jwt` rather than reusing `/webhooks/salesforce/jwt`).

### stax-docs

- Reference site. Confirms org name `sherminmax` and active sandbox alias `uat` (full host `sherminmax--uat.sandbox.my.salesforce.com`). Confirms 133 custom fields on Account, including the `Retailer` record type that maps closest to a Twenty "Account" record.

## Existing custom fields / naming conventions (inferred)

| Object | Field | Source repo / doc | Notes |
|---|---|---|---|
| Account | `FRN__c` | stax-docs | FCA Firm Reference Number, audit-critical |
| Account | `Company_UUID__c` | stax-docs | **Existing external identifier on Account.** First candidate for Twenty's `crmId` mapping if we want to avoid adding `CRM_External_Id__c` |
| Account | `Company_Details__c` | stax-docs | Lookup to `Company_Detail__c` |
| Account | `Company_Type__c`, `Regulatory_Status__c`, `Retailer_Onboarding_Stage__c`, `Shermin_Region__c`, `Subscription_Level__c`, `Account_Stage__c` | stax-docs | Retailer lifecycle picklists |
| Account | `BDM__c`, `Head_BDM__c`, `Portal_User__c` | stax-docs | User lookups |
| Account | `Lender_1__c` .. `Lender_6__c` | stax-docs | Waterfall lender lookups |
| Account | `Live_Date__c`, `Go_Live_On2__c`, `Termination_Date__c` | stax-docs | Lifecycle dates |
| Account | `Is_Ecom__c`, `Finance_Products__c`, `Max_Loan_Amount__c` | stax-docs | Capability flags |
| Application_Decision__c | `Lender_Application_ID__c`, `Decision_Stage__c`, `Source_of_Update__c`, `Proposal_Notes__c`, `Lender_Key__c`, `Lender_Name__c`, `Active__c`, `Prime_Sub_Prime__c`, `Priority__c`, `Is_New_Propensio_App__c`, `BNP_Private_Key_PEM__c`, `Application_Step__c`, `Shortlisted_Lender__c` | polling, lender-webhooks | Audit pattern: every external write sets `Source_of_Update__c` to a string identifying the caller |
| Application__c (etc) | `Retailer_API_Key__c`, `Shop_Code__c`, `Customer_Name__c`, `Agreement_Number__c`, `Zopa_Agreement_Number__c`, `Retailer_Reference_Id__c`, `Provider_Name__c`, `Application_Status__c`, `Approved_Product__c`, `Nominated_Email__c`, `Record_Id__c`, `eventType__c` | polling, ecommerce | |

Naming convention: PascalCase / Title_Case with underscores, suffix `__c`. Dates are `*_Date__c` or `*_On__c`. Audit fields favour `Source_of_*`. This matches Salesforce defaults; nothing exotic.

Contact custom fields are not directly referenced anywhere in the AWS repos: every integration writes against `Application_Decision__c`, `Application__c`, or Account-derived data, never against Contact. Live SOQL on `Contact` is needed before we propose new Contact fields.

## Naming-clash check for our new fields

| Proposed new field | Already exists? | Action |
|---|---|---|
| `CRM_External_Id__c` (Account, External ID, Unique) | Not seen in any AWS repo. **`Company_UUID__c` already exists on Account and may be unused or repurposable.** Needs SF admin to verify whether `CRM_External_Id__c` already exists, and whether `Company_UUID__c` could serve instead | If `Company_UUID__c` is free or already used as an external ID, push to it instead of adding a new field. Otherwise, create `CRM_External_Id__c` (External ID, Unique, Case-insensitive). |
| `CRM_External_Id__c` (Contact, External ID, Unique) | Unknown, no AWS code touches Contact custom fields | Needs SF admin to confirm. Likely safe to create. |
| `Source__c` (Account) | Standard SF Account already has `AccountSource` (picklist). A custom `Source__c` may collide with existing automation | **Reuse `AccountSource`** if the picklist can include `Twenty CRM`, or rename our field to `CRM_Source__c` to avoid ambiguity with the standard field. |
| `Pushed_At__c` (Account, datetime) | Not seen | Likely safe. Consider `CRM_Last_Pushed_At__c` to make ownership obvious to admins reading the field list. |
| `Source_of_Update__c` (audit) | **Already used across the org** on `Application_Decision__c`, with values like `Webhook_Process`, `Submit_Process_UWNotes` | If we want to mirror the audit pattern on Account / Contact, add `Source_of_Update__c` to those objects (new field, same name) and write `Twenty_CRM_Push` so reports can group by source. Reuse the existing convention rather than inventing a new one. |

## Salesforce edition + API access

- The org uses Person Accounts, multiple record types, custom Apex with Experience Cloud LWC, scheduled Apex jobs, Salesforce CDC subscriptions, and is the target of JWT bearer auth from external services. Composite API is supported on Enterprise, Performance, Unlimited, and Developer editions, all of which support these features. The org is therefore at least Enterprise.
- API version baseline in use: `v59.0` (set in `Admin-SalesForceProxy-Service` env). Our Composite API call should target the same or newer.
- Needs SF admin to confirm: exact edition (Enterprise vs Unlimited), API call limits headroom, and whether IP relaxation is needed for the new Lambda's egress IP on the Connected App profile.

## Recommended sandbox to build in

- The active sandbox is `sherminmax--uat` (full host `sherminmax--uat.sandbox.my.salesforce.com`). All four lender integration repos point at this sandbox in their `dev` and `test` environment files. `stax-docs` calls it the "live `shermin-sandbox`".
- A second sandbox `staxdevint` appears in one Terraform var (`HUMM_REDIRECT_URL`) but seems unused for active development.
- **Recommend `uat` for the build.** It is the well-trodden path for AWS integration work and is the sandbox the existing JWT secret is already wired into, which means we can copy the connected-app pattern in place without Salesforce licence changes.
- Open question: refresh cadence of `uat`. None of the repos document it. Needs SF admin to confirm so we don't lose Twenty data on a refresh.

## Recommended integration user pattern

The repos do not name a specific Salesforce integration user inline (it lives in Secrets Manager under `username`). The pattern is one shared integration user across the AWS stack, with the JWT secret stored at `/webhooks/salesforce/jwt`.

For Twenty CRM, recommend creating a **dedicated** integration user, not reusing the existing one, so:

- API limits and audit logs are attributable to the CRM workstream specifically.
- A breach or token rotation in one workstream does not cascade into the other.
- Permission sets can be scoped to "create / update Account and Contact only", not the full surface needed by the lender stack.

Proposed naming: `twenty.crm.integration@sherminfinance.com.uat` (sandbox suffix as per Salesforce convention). User type: API Only Integration User. Profile: minimum standard profile, with a permission set granting `Create`/`Read`/`Edit` on Account and Contact and read on the lookup-target objects.

## Recommended Connected App pattern

Existing JWT bearer setup uses a single Connected App (name not visible in repos, lives in SF metadata). For Twenty:

- Create a **separate** External Client App ("ECA", the modern Salesforce equivalent of Connected App that Salesforce now defaults to) named e.g. `Twenty CRM Push`.
- OAuth scopes: `api`, `refresh_token, offline_access` (only if we ever need refresh; for pure JWT bearer, `api` alone is enough).
- "Use digital signatures" enabled, public key uploaded.
- Pre-authorise only the Twenty integration user via a permission set or profile.
- Store credentials in Secrets Manager at a new path: `/twenty-crm/salesforce/jwt`, mirroring the existing schema (`consumer_key`, `username`, `token_url`, `private_key_pem`, optional `private_key_password`).

This keeps the new app isolated from the existing AWS-Stax integration (separate consumer key, separate secret, separate audit trail) while reusing the same auth library code.

## Open questions for Barney / SF admin

1. Who is the SF admin that can create the new External Client App, the integration user, and the new custom fields? (Neethu likely; needs confirmation.)
2. Does `Company_UUID__c` on Account already serve as an external ID, or is it free for us to repurpose for Twenty? If free, we use it instead of adding `CRM_External_Id__c`.
3. Does `CRM_External_Id__c` (or anything similar) already exist on Account or Contact? A 30-second SOQL on `FieldDefinition` against both objects will answer this.
4. Which sandbox should the build target: `uat` (recommended) or `staxdevint` or a fresh Partial / Full copy? What is its refresh cadence?
5. What edition is the production org (Enterprise / Unlimited)? Drives API call limit headroom for the Composite endpoint.
6. Do you want one shared integration user across all AWS-to-SF traffic, or a dedicated `twenty.crm.integration` user? (Recommendation: dedicated.)
7. Should our PATCH writes set `Source_of_Update__c = "Twenty_CRM_Push"` on Account and Contact (mirroring the existing audit pattern from `Application_Decision__c`)?
8. The Twenty pipeline stage that triggers the push is "Setup in Stax". On the SF side, does that map to creating an Account with `Account_Stage__c` set to a specific value, or to flipping `Retailer_Onboarding_Stage__c`? (Affects the field mapping doc, not this discovery, but worth raising.)

## Recommendations

1. **Default to `Company_UUID__c` for the external ID** if a quick SOQL check shows it is unused or already serves the purpose. Only add `CRM_External_Id__c` if `Company_UUID__c` is taken or carries semantics that would clash.
2. **Lift `salesforce_jwt_auth.py` (or the cleaner `_jwt_assertion` from `lender-webhooks/lambdas/sf-auth/main.py`) into the new Lambda**. Do not write a fresh JWT builder. The existing one already handles the SF 180-second expiry, optional encrypted private keys, and is battle-tested across four production services.
3. **Stand up a separate ECA, integration user, and Secrets Manager path** for the Twenty integration. Do not piggy-back on the lender-stack credentials.
4. **Build on the `uat` sandbox** with `Source_of_Update__c = "Twenty_CRM_Push"` audit values on every PATCH, so existing reports and admins can immediately distinguish CRM-originated changes from lender / portal / Apex changes.
5. **Get a 30-second SOQL run from the SF admin** before finalising the field plan: `SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName IN ('Account','Contact') AND QualifiedApiName LIKE '%CRM%'`. Removes all naming-clash uncertainty in this doc.
