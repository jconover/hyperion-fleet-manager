# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Observability Module Version Constraints
# -----------------------------------------------------------------------------
# This file is kept for backwards compatibility. The actual version constraints
# are defined in main.tf. Both files specify the same requirements:
#   - Terraform >= 1.5
#   - AWS Provider >= 5.0
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
