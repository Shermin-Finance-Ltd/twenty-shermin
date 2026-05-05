locals {
  # The Lambda function name itself becomes part of the deployable surface — used
  # by the Twenty webhook (Phase 2b+) and by ad-hoc invocations during testing.
  sf_push_function_name = "${var.name_prefix}-sf-push-${var.environment}"
}

data "aws_caller_identity" "current" {}

# We invoke the existing shared SF auth Lambda. Resolve its ARN at apply time
# so we can grant a least-privilege invoke permission.
data "aws_lambda_function" "sf_auth" {
  function_name = var.sf_auth_function_name
}
