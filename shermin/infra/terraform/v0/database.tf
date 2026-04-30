resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-rds"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${local.name}-rds"
  }
}

resource "aws_db_parameter_group" "postgres16" {
  name        = "${local.name}-pg16"
  family      = "postgres16"
  description = "Twenty CRM v0 Postgres parameters"

  # Twenty needs uuid-ossp / pgcrypto extensions; they ship with Postgres,
  # just ensure logging is sensible for v0 debugging.
  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log queries > 1s
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name}-pg"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "twenty"
  username = "twentyadmin"
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false
  parameter_group_name   = aws_db_parameter_group.postgres16.name

  backup_retention_period = var.rds_backup_retention_days
  backup_window           = "02:00-03:00"
  maintenance_window      = "Sun:03:30-Sun:04:30"

  copy_tags_to_snapshot     = true
  deletion_protection       = false # v0 — flip to true once promoted
  skip_final_snapshot       = true  # v0 — flip + supply final_snapshot_identifier later
  apply_immediately         = true
  auto_minor_version_upgrade = true

  performance_insights_enabled = true
  performance_insights_retention_period = 7

  tags = {
    Name = "${local.name}-pg"
  }
}
