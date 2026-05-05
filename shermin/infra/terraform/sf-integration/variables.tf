variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name (dev | test | prod)"
  type        = string
}

variable "name_prefix" {
  description = "Prefix applied to all resource names"
  type        = string
  default     = "twenty-crm"
}

variable "sf_auth_function_name" {
  description = "Name of the existing shared SF auth Lambda (e.g. lambda-sf-auth-dev) we invoke for JWT-bearer access tokens"
  type        = string
}

variable "sf_api_version" {
  description = "Salesforce REST API version. Match or exceed the version polling uses (currently v60.0)."
  type        = string
  default     = "v60.0"
}

variable "lambda_runtime" {
  description = "Python runtime version for the Lambda. Match the rest of the org's Python lambdas."
  type        = string
  default     = "python3.13"
}

variable "lambda_timeout_seconds" {
  description = "Lambda execution timeout. Describe is fast; pad for cold start + auth round-trip."
  type        = number
  default     = 30
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log group retention"
  type        = number
  default     = 30
}
