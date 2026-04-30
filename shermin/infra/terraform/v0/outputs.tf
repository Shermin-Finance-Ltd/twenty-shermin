output "alb_url" {
  description = "URL where Twenty will be reachable once deployed (self-signed cert, expect browser warning)"
  value       = "https://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "ec2_instance_id" {
  description = "EC2 instance ID. Use for SSM Session Manager: aws ssm start-session --target <id> --profile shermin-dev"
  value       = aws_instance.twenty.id
}

output "rds_endpoint" {
  description = "RDS Postgres endpoint hostname"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS Postgres port"
  value       = aws_db_instance.main.port
}

output "rds_db_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "s3_attachments_bucket" {
  description = "S3 bucket for Twenty attachments"
  value       = aws_s3_bucket.attachments.id
}

output "secret_arn_db" {
  description = "Secrets Manager ARN for the RDS password"
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_arn_twenty_app_secret" {
  description = "Secrets Manager ARN for the Twenty APP_SECRET"
  value       = aws_secretsmanager_secret.twenty_app_secret.arn
}

output "log_group" {
  description = "CloudWatch log group for Twenty"
  value       = aws_cloudwatch_log_group.twenty.name
}
