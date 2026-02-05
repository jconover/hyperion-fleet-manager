# Production Environment Backend Configuration
# This file configures remote state storage for the production environment

terraform {
  backend "s3" {
    bucket         = "hyperion-fleet-terraform-state"
    key            = "environments/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "hyperion-fleet-terraform-lock"
    encrypt        = true

    # Optional: Use KMS key for additional encryption
    # kms_key_id = "arn:aws:kms:us-east-1:ACCOUNT_ID:key/KEY_ID"
  }
}
