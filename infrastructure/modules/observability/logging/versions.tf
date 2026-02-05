#------------------------------------------------------------------------------
# Terraform and Provider Version Constraints
#------------------------------------------------------------------------------
# This file specifies the required Terraform and provider versions for
# the CloudWatch logging module.
#------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
