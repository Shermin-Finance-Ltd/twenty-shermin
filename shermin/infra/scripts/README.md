# shermin/infra/scripts

Operational scripts for the Twenty deployment. Each script is self-contained and idempotent — re-run safely.

## Scripts

### `deploy-twenty.sh`

Deploys (or redeploys) Twenty onto the v0 EC2 via SSM Run Command. Reads Terraform outputs from `../terraform/v0/`, sends an inline bootstrap script that fetches secrets from Secrets Manager, writes the docker-compose stack, pulls images, and starts the containers.

**Usage:**

```bash
AWS_PROFILE=shermin-dev ./deploy-twenty.sh
```

**What it does, step by step:**

1. Reads Terraform outputs (EC2 ID, ALB DNS, RDS endpoint, S3 bucket, secret ARNs, Twenty image tag).
2. Constructs a bash script that, on the EC2:
   - Pulls DB password and `APP_SECRET` from Secrets Manager via the EC2's IAM role.
   - Writes `/opt/twenty/.env` (mode 600).
   - Writes `/opt/twenty/docker-compose.yml` — a customised version of upstream Twenty's compose with the local `db` service removed (we use RDS) and `?sslmode=require` plus `NODE_TLS_REJECT_UNAUTHORIZED=0` for the RDS connection.
   - Runs `docker compose pull && docker compose up -d`.
   - Polls `localhost:3000/healthz` until ready.
3. Sends the script via `aws ssm send-command` with CloudWatch logging enabled.
4. Polls SSM for completion and tails the output.

**When to re-run:**

- After bumping `twenty_image_tag` in `variables.tf` (or env tfvars) — pulls the new image, recreates containers.
- After changing the docker-compose.yml in this script — same.
- After Twenty appears stuck — recreates the containers.

It does NOT recreate volumes, so Redis state (queue contents) persists across redeploys.

**When NOT to use this:**

- If you've changed Terraform infra (RDS endpoint, S3 bucket, secret ARN). Apply Terraform first; then run this — it'll pick up the new outputs.
- If you've broken the EC2 itself (failed bootstrap). Re-launch via Terraform first.

### Future scripts

- `destroy-v0.sh` — wraps `terraform destroy` with safety prompts. Not yet built.
- `backup-rds.sh` — manual on-demand RDS snapshot. Not yet built.
- `add-user.sh` — invites a workspace user via Twenty's API. Not yet built.

## Conventions

- All scripts assume `AWS_PROFILE=shermin-dev` is set (or CLI args provide one).
- All scripts must be idempotent. Re-running should not break anything.
- Errors propagate (`set -euo pipefail`).
- Output is human-readable, with `[deploy]` / `[local]` prefixes for who's speaking (the EC2 vs your laptop).
