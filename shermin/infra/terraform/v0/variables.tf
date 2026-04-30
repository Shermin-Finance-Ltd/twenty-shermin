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
  default     = "twenty-shermin-v0"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for Twenty server + worker + Redis"
  type        = string
  default     = "t4g.medium"
}

variable "rds_instance_class" {
  description = "RDS Postgres instance class"
  type        = string
  default     = "db.t4g.small"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GiB"
  type        = number
  default     = 20
}

variable "rds_backup_retention_days" {
  description = "RDS automated backup retention in days"
  type        = number
  default     = 14
}

variable "ec2_root_volume_size" {
  description = "Size of the EC2 root EBS volume in GiB"
  type        = number
  default     = 30
}

variable "twenty_image_tag" {
  description = "Twenty Docker image tag to deploy. Pin to a specific version, do not use 'latest'."
  type        = string
  default     = "v2.1.0"
}
