# shermin/infra

AWS infrastructure for the Shermin Twenty deployment. **v0 is live in the dev account** — see [`v0-deploy-log.md`](../docs/v0-deploy-log.md) for the full chronological story.

## Layout

```
infra/
  terraform/
    v0/                  # Live: VPC, RDS, EC2, ALB, S3, Secrets, IAM
      env/dev/           # Per-env backend + tfvars
      *.tf
      README.md
  scripts/
    deploy-twenty.sh     # Deploys Twenty onto the v0 EC2 via SSM
    README.md
```

## Live architecture (v0)

- **Region:** eu-west-2 (London)
- **VPC:** 10.0.0.0/16, 2 AZs
- **Compute:** EC2 `t4g.medium` running Twenty server + worker + Redis + Caddy via docker-compose
- **Database:** RDS Postgres 16 `db.t4g.small`, Single-AZ, 14-day PITR
- **Storage:** S3 `shermin-crm-attachments-prod` with Twenty's `STORAGE_TYPE=s3`
- **Edge:** ALB + ACM + Route 53 (`crm.shermin.co.uk`)
- **Secrets:** Secrets Manager (DB creds, Twenty `APP_SECRET`, SF JWT key, SF client ID)
- **Access:** SSM Session Manager only — no SSH

Cost: ~£77/month while running. `terraform destroy` to stop the meter.

## Quick reference

| Action | Command |
|---|---|
| SSO login | `aws sso login --profile shermin-dev` |
| Check what's deployed | `cd terraform/v0 && AWS_PROFILE=shermin-dev terraform output` |
| Plan changes | `terraform plan -var-file=env/dev/dev.tfvars` |
| Apply changes | `terraform apply -var-file=env/dev/dev.tfvars` |
| (Re)deploy Twenty | `AWS_PROFILE=shermin-dev ./scripts/deploy-twenty.sh` |
| Tail Twenty logs | `aws logs tail /twenty-shermin-v0 --follow --profile shermin-dev` |
| Shell into EC2 | `aws ssm start-session --target $(cd terraform/v0 && terraform output -raw ec2_instance_id) --profile shermin-dev` |
| Tear down | `terraform destroy -var-file=env/dev/dev.tfvars` |

## Documentation

- [`terraform/v0/README.md`](terraform/v0/README.md) — Terraform module specifics, what's created, prerequisites.
- [`scripts/README.md`](scripts/README.md) — Deploy script details and runbook.
- [`../docs/v0-deploy-log.md`](../docs/v0-deploy-log.md) — Chronological deploy log including gotchas hit (RDS SSL, Node TLS verify) and v1 fix list.

## Deferred to v1+

- Real ACM cert + Route 53 record on a real domain (currently self-signed)
- Customer-managed KMS keys
- WAF, GuardDuty (org-level)
- CloudWatch alarms + synthetic canary
- AMI snapshot schedule via AWS Backup or DLM
- Multi-AZ RDS, deletion protection, final snapshots
- RDS CA bundle baked into Twenty image (drop `NODE_TLS_REJECT_UNAUTHORIZED=0`)
- GitHub Actions OIDC trust list extension to include this repo
