# Package the Lambda source from shermin/lambda/sf-push/src into a zip.
# Re-zips automatically when source files change (archive_file tracks content hash).
data "archive_file" "sf_push" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/sf-push/src"
  output_path = "${path.module}/.terraform/build/sf-push.zip"
}

resource "aws_cloudwatch_log_group" "sf_push" {
  name              = "/aws/lambda/${local.sf_push_function_name}"
  retention_in_days = var.lambda_log_retention_days
}

resource "aws_lambda_function" "sf_push" {
  function_name    = local.sf_push_function_name
  description      = "Twenty CRM to Salesforce push (Phase 2a: connection-only describe)"
  role             = aws_iam_role.sf_push.arn
  runtime          = var.lambda_runtime
  handler          = "main.lambda_handler"
  filename         = data.archive_file.sf_push.output_path
  source_code_hash = data.archive_file.sf_push.output_base64sha256
  timeout          = var.lambda_timeout_seconds
  memory_size      = 256

  environment {
    variables = {
      SF_AUTH_FUNCTION_NAME = var.sf_auth_function_name
      SF_API_VERSION        = var.sf_api_version
      HTTP_TIMEOUT_SECONDS  = "15"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.logs,
    aws_cloudwatch_log_group.sf_push,
  ]
}
