#!/usr/bin/env bash
# Deploy Twenty to the v0 EC2 via SSM.
#
# Reads Terraform outputs from the v0 module, sends an inline bootstrap script
# to the EC2 via SSM, and waits for the app to come up healthy.
#
# Usage:
#   AWS_PROFILE=shermin-dev ./deploy-twenty.sh
#
# Idempotent: re-run safely; it will pull the latest pinned image and rolling-restart.

set -euo pipefail

cd "$(dirname "$0")/../terraform/v0"

REGION=$(terraform output -raw aws_region 2>/dev/null || echo "eu-west-2")
EC2_ID=$(terraform output -raw ec2_instance_id)
ALB_DNS=$(terraform output -raw alb_dns_name)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_PORT=$(terraform output -raw rds_port)
S3_BUCKET=$(terraform output -raw s3_attachments_bucket)
SECRET_DB=$(terraform output -raw secret_arn_db)
SECRET_APP=$(terraform output -raw secret_arn_twenty_app_secret)
TWENTY_TAG=$(terraform output -json | jq -r '.twenty_image_tag.value // "v2.1.0"' 2>/dev/null || echo "v2.1.0")

# Shermin image config — derives a custom image with maxFileSize lifted to 100MB
SHERMIN_IMAGE_TAG="${TWENTY_TAG}-shermin1"
MAX_FILE_SIZE="${MAX_FILE_SIZE:-100MB}"

# Encode the Dockerfile so we can transmit it inside the SSM payload
DOCKERFILE_PATH="$(dirname "$0")/../docker/Dockerfile.shermin"
DOCKERFILE_B64=$(base64 < "$DOCKERFILE_PATH" | tr -d '\n')

echo "EC2:           $EC2_ID"
echo "ALB DNS:       $ALB_DNS"
echo "RDS:           $RDS_ENDPOINT:$RDS_PORT"
echo "S3:            $S3_BUCKET"
echo "Upstream tag:  $TWENTY_TAG"
echo "Shermin image: twenty-shermin:$SHERMIN_IMAGE_TAG (max file size $MAX_FILE_SIZE)"
echo ""

REMOTE_SCRIPT=$(cat <<'REMOTE_EOF'
#!/bin/bash
set -euo pipefail

REGION="__REGION__"
ALB_DNS="__ALB_DNS__"
RDS_ENDPOINT="__RDS_ENDPOINT__"
RDS_PORT="__RDS_PORT__"
S3_BUCKET="__S3_BUCKET__"
SECRET_DB_ARN="__SECRET_DB__"
SECRET_APP_ARN="__SECRET_APP__"
TWENTY_TAG="__TWENTY_TAG__"
SHERMIN_IMAGE_TAG="__SHERMIN_IMAGE_TAG__"
MAX_FILE_SIZE="__MAX_FILE_SIZE__"
DOCKERFILE_B64="__DOCKERFILE_B64__"

cd /opt/twenty

echo "[deploy] writing Dockerfile.shermin"
mkdir -p /opt/twenty/docker
echo "$DOCKERFILE_B64" | base64 -d > /opt/twenty/docker/Dockerfile.shermin

echo "[deploy] building patched Twenty image (twenty-shermin:$SHERMIN_IMAGE_TAG)"
# Pull upstream first so docker build can use it as the FROM
docker pull "twentycrm/twenty:$TWENTY_TAG"
docker build \
  --build-arg "TWENTY_TAG=$TWENTY_TAG" \
  --build-arg "MAX_FILE_SIZE=$MAX_FILE_SIZE" \
  -t "twenty-shermin:$SHERMIN_IMAGE_TAG" \
  -f /opt/twenty/docker/Dockerfile.shermin \
  /opt/twenty/docker

echo "[deploy] fetching secrets"
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$SECRET_DB_ARN" --region "$REGION" --query SecretString --output text)
APP_SECRET_VAL=$(aws secretsmanager get-secret-value --secret-id "$SECRET_APP_ARN" --region "$REGION" --query SecretString --output text)

echo "[deploy] writing .env"
umask 077
cat > /opt/twenty/.env <<ENV_EOF
TAG=$TWENTY_TAG
SHERMIN_IMAGE_TAG=$SHERMIN_IMAGE_TAG
SERVER_URL=https://$ALB_DNS
PG_DATABASE_HOST=$RDS_ENDPOINT
PG_DATABASE_PORT=$RDS_PORT
PG_DATABASE_USER=twentyadmin
PG_DATABASE_PASSWORD=$DB_PASSWORD
PG_DATABASE_NAME=twenty
APP_SECRET=$APP_SECRET_VAL
STORAGE_TYPE=s3
STORAGE_S3_REGION=$REGION
STORAGE_S3_NAME=$S3_BUCKET
ENV_EOF

echo "[deploy] writing docker-compose.yml"
cat > /opt/twenty/docker-compose.yml <<'COMPOSE_EOF'
name: twenty

services:
  server:
    image: twenty-shermin:${SHERMIN_IMAGE_TAG}
    pull_policy: never
    volumes:
      - server-local-data:/app/packages/twenty-server/.local-storage
    ports:
      - "3000:3000"
    environment:
      NODE_PORT: 3000
      PG_DATABASE_URL: postgres://${PG_DATABASE_USER}:${PG_DATABASE_PASSWORD}@${PG_DATABASE_HOST}:${PG_DATABASE_PORT}/${PG_DATABASE_NAME}?sslmode=require
      SERVER_URL: ${SERVER_URL}
      REDIS_URL: redis://redis:6379
      STORAGE_TYPE: ${STORAGE_TYPE}
      STORAGE_S3_REGION: ${STORAGE_S3_REGION}
      STORAGE_S3_NAME: ${STORAGE_S3_NAME}
      APP_SECRET: ${APP_SECRET}
      # v0: skip CA verification on RDS connection (encrypted but unverified).
      # Promote to RDS CA bundle in v1.
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
    depends_on:
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl --fail http://localhost:3000/healthz || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 30
      start_period: 60s
    restart: always

  worker:
    image: twenty-shermin:${SHERMIN_IMAGE_TAG}
    pull_policy: never
    volumes:
      - server-local-data:/app/packages/twenty-server/.local-storage
    command: ["yarn", "worker:prod"]
    environment:
      PG_DATABASE_URL: postgres://${PG_DATABASE_USER}:${PG_DATABASE_PASSWORD}@${PG_DATABASE_HOST}:${PG_DATABASE_PORT}/${PG_DATABASE_NAME}?sslmode=require
      SERVER_URL: ${SERVER_URL}
      REDIS_URL: redis://redis:6379
      DISABLE_DB_MIGRATIONS: "true"
      DISABLE_CRON_JOBS_REGISTRATION: "true"
      STORAGE_TYPE: ${STORAGE_TYPE}
      STORAGE_S3_REGION: ${STORAGE_S3_REGION}
      STORAGE_S3_NAME: ${STORAGE_S3_NAME}
      APP_SECRET: ${APP_SECRET}
      # v0: skip CA verification on RDS connection (encrypted but unverified).
      # Promote to RDS CA bundle in v1.
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
    depends_on:
      server:
        condition: service_healthy
    restart: always

  redis:
    image: redis:7-alpine
    command: ["redis-server", "--maxmemory-policy", "noeviction", "--appendonly", "yes"]
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: always

volumes:
  server-local-data:
  redis-data:
COMPOSE_EOF

chown -R ec2-user:ec2-user /opt/twenty

echo "[deploy] pulling redis (server/worker use locally-built image)"
cd /opt/twenty
docker compose pull redis

echo "[deploy] starting stack"
docker compose up -d

echo "[deploy] waiting up to 5 min for /healthz"
for i in $(seq 1 60); do
  if curl -sf http://localhost:3000/healthz > /dev/null 2>&1; then
    echo "[deploy] healthy after ${i}*5s"
    docker compose ps
    exit 0
  fi
  sleep 5
done

echo "[deploy] FAILED to become healthy in 5 min"
docker compose ps
docker compose logs --tail=50 server
exit 1
REMOTE_EOF
)

# Substitute placeholders into the remote script
REMOTE_SCRIPT=${REMOTE_SCRIPT//__REGION__/$REGION}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__ALB_DNS__/$ALB_DNS}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__RDS_ENDPOINT__/$RDS_ENDPOINT}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__RDS_PORT__/$RDS_PORT}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__S3_BUCKET__/$S3_BUCKET}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__SECRET_DB__/$SECRET_DB}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__SECRET_APP__/$SECRET_APP}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__TWENTY_TAG__/$TWENTY_TAG}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__SHERMIN_IMAGE_TAG__/$SHERMIN_IMAGE_TAG}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__MAX_FILE_SIZE__/$MAX_FILE_SIZE}
REMOTE_SCRIPT=${REMOTE_SCRIPT//__DOCKERFILE_B64__/$DOCKERFILE_B64}

PARAMS_FILE=$(mktemp)
trap 'rm -f "$PARAMS_FILE"' EXIT
jq -n --arg cmd "$REMOTE_SCRIPT" '{commands: [$cmd]}' > "$PARAMS_FILE"

echo "[local] sending SSM Run Command"
CMD_ID=$(aws ssm send-command \
  --instance-ids "$EC2_ID" \
  --document-name "AWS-RunShellScript" \
  --comment "twenty-shermin v0 deploy" \
  --parameters "file://$PARAMS_FILE" \
  --cloud-watch-output-config CloudWatchOutputEnabled=true,CloudWatchLogGroupName=/twenty-shermin-v0 \
  --region "$REGION" \
  --query 'Command.CommandId' --output text)

echo "[local] command-id: $CMD_ID"
echo "[local] waiting for completion (up to 10 min)..."

for i in $(seq 1 120); do
  STATUS=$(aws ssm get-command-invocation \
    --command-id "$CMD_ID" \
    --instance-id "$EC2_ID" \
    --region "$REGION" \
    --query 'Status' --output text 2>/dev/null || echo "Pending")

  case "$STATUS" in
    Success)
      echo "[local] SSM command succeeded"
      aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$EC2_ID" --region "$REGION" --query 'StandardOutputContent' --output text | tail -30
      echo ""
      echo "Twenty is up. Visit: https://$ALB_DNS"
      echo "(Browser will warn about self-signed cert; Advanced > Proceed.)"
      exit 0
      ;;
    Failed|Cancelled|TimedOut)
      echo "[local] SSM command $STATUS"
      aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$EC2_ID" --region "$REGION" \
        --query '{stdout:StandardOutputContent,stderr:StandardErrorContent}' --output json
      exit 1
      ;;
    *)
      printf "."
      sleep 5
      ;;
  esac
done

echo ""
echo "[local] timed out waiting for SSM command"
exit 1
