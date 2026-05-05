output "sf_push_function_name" {
  description = "Lambda function name. Use with `aws lambda invoke --function-name <this>` to test."
  value       = aws_lambda_function.sf_push.function_name
}

output "sf_push_function_arn" {
  description = "Lambda ARN. Will be referenced by the Twenty webhook receiver in Phase 2b."
  value       = aws_lambda_function.sf_push.arn
}

output "sf_push_role_arn" {
  description = "IAM role ARN used by the Lambda."
  value       = aws_iam_role.sf_push.arn
}

output "sf_push_log_group" {
  description = "CloudWatch log group. Tail with `aws logs tail <this> --follow`."
  value       = aws_cloudwatch_log_group.sf_push.name
}

output "sf_auth_function_resolved" {
  description = "ARN of the shared SF auth Lambda we resolved and bound to."
  value       = data.aws_lambda_function.sf_auth.arn
}
