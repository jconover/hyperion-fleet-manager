################################################################################
# IAM Outputs
################################################################################

output "windows_fleet_role_arn" {
  description = "ARN of the IAM role for Windows fleet instances"
  value       = aws_iam_role.windows_fleet.arn
}

output "windows_fleet_role_name" {
  description = "Name of the IAM role for Windows fleet instances"
  value       = aws_iam_role.windows_fleet.name
}

output "windows_fleet_instance_profile_arn" {
  description = "ARN of the instance profile for Windows fleet instances"
  value       = aws_iam_instance_profile.windows_fleet.arn
}

output "windows_fleet_instance_profile_name" {
  description = "Name of the instance profile for Windows fleet instances"
  value       = aws_iam_instance_profile.windows_fleet.name
}

################################################################################
# KMS Key Outputs
################################################################################

output "kms_key_ebs_arn" {
  description = "ARN of the KMS key for EBS encryption"
  value       = aws_kms_key.ebs.arn
}

output "kms_key_ebs_id" {
  description = "ID of the KMS key for EBS encryption"
  value       = aws_kms_key.ebs.key_id
}

output "kms_key_ebs_alias" {
  description = "Alias of the KMS key for EBS encryption"
  value       = aws_kms_alias.ebs.name
}

output "kms_key_rds_arn" {
  description = "ARN of the KMS key for RDS encryption"
  value       = aws_kms_key.rds.arn
}

output "kms_key_rds_id" {
  description = "ID of the KMS key for RDS encryption"
  value       = aws_kms_key.rds.key_id
}

output "kms_key_rds_alias" {
  description = "Alias of the KMS key for RDS encryption"
  value       = aws_kms_alias.rds.name
}

output "kms_key_s3_arn" {
  description = "ARN of the KMS key for S3 encryption"
  value       = aws_kms_key.s3.arn
}

output "kms_key_s3_id" {
  description = "ID of the KMS key for S3 encryption"
  value       = aws_kms_key.s3.key_id
}

output "kms_key_s3_alias" {
  description = "Alias of the KMS key for S3 encryption"
  value       = aws_kms_alias.s3.name
}

output "kms_key_secrets_manager_arn" {
  description = "ARN of the KMS key for Secrets Manager encryption"
  value       = aws_kms_key.secrets_manager.arn
}

output "kms_key_secrets_manager_id" {
  description = "ID of the KMS key for Secrets Manager encryption"
  value       = aws_kms_key.secrets_manager.key_id
}

output "kms_key_secrets_manager_alias" {
  description = "Alias of the KMS key for Secrets Manager encryption"
  value       = aws_kms_alias.secrets_manager.name
}

################################################################################
# Security Group Outputs
################################################################################

output "windows_fleet_security_group_id" {
  description = "ID of the security group for Windows fleet instances"
  value       = aws_security_group.windows_fleet.id
}

output "windows_fleet_security_group_arn" {
  description = "ARN of the security group for Windows fleet instances"
  value       = aws_security_group.windows_fleet.arn
}

output "load_balancer_security_group_id" {
  description = "ID of the security group for the Application Load Balancer"
  value       = aws_security_group.load_balancer.id
}

output "load_balancer_security_group_arn" {
  description = "ARN of the security group for the Application Load Balancer"
  value       = aws_security_group.load_balancer.arn
}

output "database_security_group_id" {
  description = "ID of the security group for the PostgreSQL database"
  value       = aws_security_group.database.id
}

output "database_security_group_arn" {
  description = "ARN of the security group for the PostgreSQL database"
  value       = aws_security_group.database.arn
}

################################################################################
# Secrets Manager Outputs
################################################################################

output "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Name of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "db_master_password" {
  description = "Master password for RDS database (sensitive)"
  value       = random_password.db_master.result
  sensitive   = true
}

################################################################################
# Security Hub Outputs
################################################################################

output "security_hub_account_id" {
  description = "Security Hub account ID"
  value       = var.enable_security_hub ? aws_securityhub_account.main[0].id : null
}

output "security_hub_enabled" {
  description = "Whether Security Hub is enabled"
  value       = var.enable_security_hub
}

################################################################################
# GuardDuty Outputs
################################################################################

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "guardduty_enabled" {
  description = "Whether GuardDuty is enabled"
  value       = var.enable_guardduty
}

################################################################################
# Consolidated Outputs for Convenience
################################################################################

output "security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    windows_fleet = aws_security_group.windows_fleet.id
    load_balancer = aws_security_group.load_balancer.id
    database      = aws_security_group.database.id
  }
}

output "kms_key_arns" {
  description = "Map of all KMS key ARNs"
  value = {
    ebs             = aws_kms_key.ebs.arn
    rds             = aws_kms_key.rds.arn
    s3              = aws_kms_key.s3.arn
    secrets_manager = aws_kms_key.secrets_manager.arn
  }
}

output "kms_key_ids" {
  description = "Map of all KMS key IDs"
  value = {
    ebs             = aws_kms_key.ebs.key_id
    rds             = aws_kms_key.rds.key_id
    s3              = aws_kms_key.s3.key_id
    secrets_manager = aws_kms_key.secrets_manager.key_id
  }
}
