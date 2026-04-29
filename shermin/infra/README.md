# shermin/infra

AWS infrastructure for the Shermin Twenty deployment. Phase 1 work — populated after Phase 0 discovery completes.

## Target architecture (planned)

- **Region:** eu-west-2 (London)
- **VPC:** 10.0.0.0/16, 2 AZs
- **Compute:** EC2 `t4g.medium` running Twenty server + worker + Redis + Caddy via docker-compose
- **Database:** RDS Postgres 16 `db.t4g.small`, Single-AZ, 14-day PITR
- **Storage:** S3 `shermin-crm-attachments-prod` with Twenty's `STORAGE_TYPE=s3`
- **Edge:** ALB + ACM + Route 53 (`crm.shermin.co.uk`)
- **Secrets:** Secrets Manager (DB creds, Twenty `APP_SECRET`, SF JWT key, SF client ID)
- **Access:** SSM Session Manager only — no SSH

Estimated cost: ~£77/month (£85 with buffer).

## Files (to come in Phase 1)

- `aws-cli-snippets.sh` — non-secret CLI commands used during provisioning, for reproducibility.
- `docker-compose.yml` — Twenty stack on EC2 (Postgres + Redis externalised).
- `.env.production.template` — env var template (real values from Secrets Manager).
- `disaster-runbook.md` — RDS restore, EC2 rebuild, region failure procedures.

## Provisioning order (Phase 1)

1. AWS account hardening (CloudTrail, GuardDuty, billing alarms, IAM SSO)
2. VPC + subnets + security groups
3. RDS Postgres
4. S3 bucket
5. Route 53 hosted zone + ACM cert
6. ALB
7. EC2 + IAM role + SSM access
8. Twenty docker-compose deploy
9. CloudWatch alarms + AMI snapshot schedule
