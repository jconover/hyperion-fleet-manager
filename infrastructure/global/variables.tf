variable "aws_region" {
  description = "AWS region for global backend resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state storage"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.state_bucket_name))
    error_message = "Bucket name must be lowercase alphanumeric with hyphens only."
  }
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-lock"
}

variable "state_version_retention_days" {
  description = "Number of days to retain old state file versions"
  type        = number
  default     = 90
  validation {
    condition     = var.state_version_retention_days >= 30
    error_message = "State version retention must be at least 30 days."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain access logs"
  type        = number
  default     = 365
  validation {
    condition     = var.log_retention_days >= 90
    error_message = "Log retention must be at least 90 days."
  }
}
