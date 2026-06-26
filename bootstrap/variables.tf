variable "aws_region" {
  description = "AWS region for the state bucket and lock table."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for state bucket and DynamoDB table names."
  type        = string
  default     = "data-platform"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "state_bucket_name" {
  description = "Optional fixed S3 bucket name. Defaults to {project}-{env}-tfstate-{account_id}."
  type        = string
  default     = ""
}
