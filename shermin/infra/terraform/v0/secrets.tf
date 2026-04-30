resource "random_password" "db" {
  length      = 32
  special     = true
  min_special = 2
  override_special = "!#$%&*-_=+"
}

resource "random_password" "twenty_app_secret" {
  length  = 64
  special = false # Twenty's APP_SECRET is base64-style, keep it simple
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${local.name}/db/password"
  description = "RDS Postgres master password for Twenty CRM v0"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = random_password.db.result
}

resource "aws_secretsmanager_secret" "twenty_app_secret" {
  name        = "${local.name}/twenty/app-secret"
  description = "Twenty APP_SECRET for v0"
}

resource "aws_secretsmanager_secret_version" "twenty_app_secret" {
  secret_id     = aws_secretsmanager_secret.twenty_app_secret.id
  secret_string = random_password.twenty_app_secret.result
}
