resource "aws_iam_role" "sf_push" {
  name        = "${local.sf_push_function_name}-role"
  description = "Execution role for the Twenty CRM to Salesforce push Lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# CloudWatch logs.
resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.sf_push.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow invoking ONLY the shared SF auth Lambda (least-privilege).
resource "aws_iam_role_policy" "invoke_sf_auth" {
  name = "${local.sf_push_function_name}-invoke-sf-auth"
  role = aws_iam_role.sf_push.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = data.aws_lambda_function.sf_auth.arn
    }]
  })
}
