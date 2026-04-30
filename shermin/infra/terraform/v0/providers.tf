provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Service     = "twenty-crm"
      Environment = var.environment
      Project     = "twenty-shermin"
      ManagedBy   = "terraform"
      Owner       = "bgood11"
      Repo        = "Shermin-Finance-Ltd/twenty-shermin"
    }
  }
}
