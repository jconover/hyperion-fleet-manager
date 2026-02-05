# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Dashboards Module Version Constraints
# -----------------------------------------------------------------------------
# This file defines the required Terraform and provider versions for the
# observability dashboards sub-module.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
