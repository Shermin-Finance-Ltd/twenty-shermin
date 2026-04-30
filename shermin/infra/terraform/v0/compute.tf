data "aws_ssm_parameter" "amzn2023_arm" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64"
}

resource "aws_iam_role" "ec2" {
  name        = "${local.name}-ec2"
  description = "Twenty EC2 instance role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "secrets_and_s3" {
  name = "${local.name}-secrets-and-s3"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = [
          aws_secretsmanager_secret.db.arn,
          aws_secretsmanager_secret.twenty_app_secret.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.attachments.arn,
          "${aws_s3_bucket.attachments.arn}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-ec2"
  role = aws_iam_role.ec2.name
}

# Minimal user_data: install Docker + Compose + CloudWatch agent + ssm-agent.
# Twenty itself is deployed via a separate SSM Run Command after Terraform finishes.
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail

    dnf update -y
    dnf install -y docker amazon-cloudwatch-agent

    systemctl enable --now docker
    usermod -aG docker ec2-user

    # Docker Compose v2 plugin
    DOCKER_CONFIG=$${DOCKER_CONFIG:-/usr/local/lib/docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-aarch64" \
      -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

    # Twenty deploy directory; populated later by SSM Run Command
    mkdir -p /opt/twenty
    chown ec2-user:ec2-user /opt/twenty

    # Marker file so the deploy script can confirm bootstrap finished
    echo "bootstrap-complete $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /opt/twenty/.bootstrap
  EOT
}

resource "aws_instance" "twenty" {
  ami                         = data.aws_ssm_parameter.amzn2023_arm.value
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true
  user_data                   = local.user_data
  user_data_replace_on_change = false

  credit_specification {
    cpu_credits = "unlimited" # T-instance unlimited mode for spiky CRM workload
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ec2_root_volume_size
    encrypted             = true
    delete_on_termination = true
    tags = {
      Name = "${local.name}-root"
    }
  }

  tags = {
    Name = "${local.name}-ec2"
  }
}

resource "aws_cloudwatch_log_group" "twenty" {
  name              = "/${local.name}"
  retention_in_days = 30
}
