# v0 deploy log

Chronicle of the v0 deploy, including the gotchas hit and the fixes applied. Read this if you're reproducing the deploy from scratch, or if a future upgrade reintroduces one of these issues.

## What v0 is

Vanilla Twenty CRM (image `twentycrm/twenty:v2.1.0`) running in the Shermin dev AWS account on a single EC2 with RDS Postgres and S3 attachments. No Salesforce integration, no custom objects, no SSO — just a working Twenty workspace where Barney can poke around and decide what to build next.

## What's running

| Resource | Identifier |
|---|---|
| AWS account | `992914515467` (dev) |
| Region | `eu-west-2` |
| Workspace URL | `https://twenty-shermin-v0-alb-2090009733.eu-west-2.elb.amazonaws.com` |
| EC2 | `i-0b201d521fdde2a5b` (`t4g.medium`, AL2023 ARM64) |
| RDS | `twenty-shermin-v0-pg.cb6gcqc0041o.eu-west-2.rds.amazonaws.com` (Postgres 16, `db.t4g.small`) |
| S3 attachments | `twenty-shermin-v0-attachments-992914515467` |
| ALB | `twenty-shermin-v0-alb` |
| Secrets | `twenty-shermin-v0/db/password`, `twenty-shermin-v0/twenty/app-secret` |
| CloudWatch logs | `/twenty-shermin-v0` |
| Terraform state | `s3://stax-development-terraform-state-bucket/twenty-shermin/v0/terraform.tfstate` |

## Deploy story (chronological)

### 1. AWS profile setup

Barney's existing AWS CLI was configured for the prod account via static IAM keys. Set up a separate `shermin-dev` profile using AWS IAM Identity Center / SSO:

```bash
aws configure sso
# session name: shermin
# start URL:    https://staxpay.awsapps.com/start
# region:       eu-west-2
# account:      992914515467 (dev)
# role:         AdministratorAccess
# profile name: shermin-dev
```

### 2. Terraform install

Brewed Hashicorp's tap; Terraform `1.15.0` installed.

### 3. Existing-infra audit

Discovered Shermin's house Terraform conventions before writing anything new:
- House provider: `aws ~> 6.0`
- House state backend: `s3://stax-development-terraform-state-bucket/<service>/terraform.tfstate`
- Per-env config in `env/<env>/backend-config.hcl` and `env/<env>/<env>.tfvars`
- Existing OIDC role: `github-actions-oidc-terraform-role` (we'll need to add this repo to its trust list when we set up CI; deferred)

We use the existing dev state bucket under key `twenty-shermin/v0/terraform.tfstate`.

### 4. Terraform apply

40 resources, ~8 minutes (RDS dominated). One application, no manual fixups. State pushed cleanly to S3 backend.

### 5. SSM deploy of Twenty (with two TLS gotchas)

EC2 user_data installs Docker + Compose + SSM agent. Twenty is then deployed by `shermin/infra/scripts/deploy-twenty.sh`, which runs an inline script over SSM that:
1. Reads secrets from Secrets Manager via the EC2 IAM role.
2. Writes `/opt/twenty/.env` and `/opt/twenty/docker-compose.yml`.
3. `docker compose pull && docker compose up -d`.
4. Polls `localhost:3000/healthz` until ready (or fails after 5 min).

**Gotcha 1 — RDS rejects non-SSL connections.** Default for Postgres 16 RDS is `rds.force_ssl = 1`. First deploy attempt failed with `no pg_hba.conf entry for host "10.20.1.239", user "twentyadmin", database "twenty", no encryption`.

Fix: append `?sslmode=require` to the `PG_DATABASE_URL`.

**Gotcha 2 — Node's pg client rejects RDS's CA.** With SSL enabled, Twenty's TypeORM/pg client tries to verify the cert chain, but Amazon's CA isn't in the Node container's trust store. Failed with `Error: self-signed certificate in certificate chain`.

Fix for v0: `NODE_TLS_REJECT_UNAUTHORIZED=0` on both `server` and `worker` containers. Encrypts but skips CA verification. Limited blast radius (only those containers).

**Proper fix for v1**: bake the [RDS global CA bundle](https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem) into the Twenty container or mount it as a Docker secret, then drop the `NODE_TLS_REJECT_UNAUTHORIZED` env var. Tracked as a v1 task.

### 6. End-to-end verification

After fixes, deploy completed in 23×5s = ~2 minutes. ALB target took another ~60s to flip to healthy after Twenty came up (2 consecutive checks at 30s intervals). End-to-end HTTPS through the ALB returns 200 on `/healthz`. Self-signed cert warning in browser, click-through expected.

## Storage configuration

### File attachments (where they live)

Files attached to Twenty records — Companies, People, Notes — go to S3 bucket `twenty-shermin-v0-attachments-992914515467` under `<workspace-uuid>/<file-uuid>/<filename>`. Configured at deploy time via the `STORAGE_TYPE=s3` family of env vars. Versioning on, SSE-S3 encryption.

**Custom objects don't get native attachments in Twenty v2.1.0.** When we build the `Retailer` custom object in Phase 1, we attach contract / compliance / KYC documents as `Note` records related to the Retailer. Note is a standard Twenty object with full attachment support. See [`data-model.md`](data-model.md) for the spec.

### 100 MB upload cap

Twenty's upstream image hardcodes a 10 MB per-file upload cap in `packages/twenty-server/src/engine/constants/settings/index.ts:maxFileSize`. No env-var override exists upstream. Most contract / FCA / KYC PDFs sit between 5 and 30 MB, so 10 MB is too tight.

We build a derivative image `twenty-shermin:<upstream>-shermin1` from `twentycrm/twenty:<upstream>` that sed-patches the compiled constant on build:

- Dockerfile: [`shermin/infra/docker/Dockerfile.shermin`](../infra/docker/Dockerfile.shermin)
- Build trigger: every run of [`shermin/infra/scripts/deploy-twenty.sh`](../infra/scripts/deploy-twenty.sh) builds the image on the EC2 itself (no registry needed) before `docker compose up`.
- Build-arg: `MAX_FILE_SIZE` (default 100MB). Override via `MAX_FILE_SIZE=250MB ./deploy-twenty.sh`.
- Verification: the build asserts that the substitution actually happened (greps for the new value after sed). If a future Twenty version restructures the compiled constant, the build fails loudly rather than silently shipping a 10 MB cap.

**v1 work:** submit an upstream PR adding `STORAGE_MAX_FILE_SIZE` env var to Twenty. When merged, drop our Dockerfile.

**Upstream-merge note:** when bumping to a new Twenty tag, the first deploy after may fail at the build assertion if the compiled output structure changed. Inspect the new dist file, regenerate the sed pattern, retry.

### S3 lifecycle (FCA retention)

Aligned to FCA CONC retention requirements (6 years for credit records — we use 7 as a safety margin). Nothing is ever permanently deleted.

| Layer | Path |
|---|---|
| Current versions | Standard → GIR after 90 days → Deep Archive after 7 years |
| Non-current versions | Standard → GIR after 30 days → Deep Archive after 7 years |
| Incomplete multipart uploads | Aborted after 7 days (housekeeping only) |

Cost impact at expected v1 volumes (~25 GiB total): negligible. Without the GIR transitions, S3 Standard would charge ~£0.45/month. With them, that drops to ~£0.30/month over time. The win isn't cost — it's that we explicitly don't lose anything.

If the GIR / Deep Archive scheme proves wrong (e.g. compliance asks for hot-tier retention longer), the lifecycle is one Terraform edit + apply away.

## Cost

About £77/month while running. `terraform destroy` at any time to stop the meter.

| Service | Monthly £ |
|---|---|
| EC2 t4g.medium | 22 |
| EBS root | 2 |
| RDS db.t4g.small | 24 |
| ALB | 18 |
| S3 attachments (small) | 1 |
| CloudWatch | 5 |
| Secrets Manager | 1 |
| Data transfer + misc | 4 |

## Known issues / v1 work

| Item | Severity | Fix |
|---|---|---|
| `NODE_TLS_REJECT_UNAUTHORIZED=0` on Twenty containers | Medium | Bake RDS CA bundle into image or mount as secret |
| Self-signed ACM cert | Low (v0 single-user only) | Real ACM cert + Route 53 record on real domain |
| ALB SG ingress 0.0.0.0/0 on 443 | Low (v0, no real data) | Restrict to office CIDRs, or put behind Cloudflare/WAF |
| RDS `deletion_protection = false`, `skip_final_snapshot = true` | High before any real data | Flip both before promoting |
| Single-AZ RDS | Low for v0 | Multi-AZ before any real data |
| No CloudWatch alarms | Medium | Wire up after first real users |
| No EC2 AMI snapshot schedule | Medium | AWS Backup or DLM |
| GitHub Actions OIDC trust list excludes this repo | Low | Add `Shermin-Finance-Ltd/twenty-shermin` to the OIDC trust list in the existing infrastructure repo when we want CI/CD |

## Repro from scratch

```bash
# 1. SSO login
aws sso login --profile shermin-dev

# 2. Terraform
cd shermin/infra/terraform/v0
export AWS_PROFILE=shermin-dev
terraform init -backend-config=env/dev/backend-config.hcl
terraform plan -var-file=env/dev/dev.tfvars -out=v0.tfplan
terraform apply v0.tfplan

# 3. Deploy Twenty
../../scripts/deploy-twenty.sh

# 4. Visit ALB URL, sign up as workspace admin
echo "https://$(terraform output -raw alb_dns_name)"
```

Tear-down:

```bash
cd shermin/infra/terraform/v0
export AWS_PROFILE=shermin-dev
terraform destroy -var-file=env/dev/dev.tfvars
```
