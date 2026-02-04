################################################################################
# IAM Role for Windows Fleet Instances
################################################################################

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"]
    }
  }
}

resource "aws_iam_role" "windows_fleet" {
  name                 = "${var.environment}-${var.project_name}-windows-fleet-role"
  description          = "IAM role for Windows fleet instances with least privilege access"
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume_role.json
  max_session_duration = 3600

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-windows-fleet-role"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "windows_fleet" {
  name = "${var.environment}-${var.project_name}-windows-fleet-profile"
  role = aws_iam_role.windows_fleet.name

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-windows-fleet-profile"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# SSM Managed Instance Core Policy
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.windows_fleet.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent Policy
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.windows_fleet.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom S3 Access Policy (Least Privilege)
data "aws_iam_policy_document" "s3_access" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = var.fleet_s3_bucket_arns
  }

  statement {
    sid    = "GetPutObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [for bucket in var.fleet_s3_bucket_arns : "${bucket}/*"]
  }

  statement {
    sid    = "KMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [aws_kms_key.s3.arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "s3_access" {
  name        = "${var.environment}-${var.project_name}-s3-access"
  description = "Least privilege S3 access for Windows fleet instances"
  policy      = data.aws_iam_policy_document.s3_access.json

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-s3-access"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.windows_fleet.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Secrets Manager Access Policy
data "aws_iam_policy_document" "secrets_manager_access" {
  statement {
    sid    = "GetSecretValues"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_secretsmanager_secret.db_credentials.arn,
      "${aws_secretsmanager_secret.db_credentials.arn}-??????"
    ]
  }

  statement {
    sid    = "DecryptSecrets"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.secrets_manager.arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "secrets_manager_access" {
  name        = "${var.environment}-${var.project_name}-secrets-access"
  description = "Least privilege Secrets Manager access for Windows fleet instances"
  policy      = data.aws_iam_policy_document.secrets_manager_access.json

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-secrets-access"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_iam_role_policy_attachment" "secrets_manager_access" {
  role       = aws_iam_role.windows_fleet.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}

################################################################################
# KMS Keys for Encryption
################################################################################

# KMS Key for EBS Encryption
resource "aws_kms_key" "ebs" {
  description              = "KMS key for EBS volume encryption in ${var.environment}"
  deletion_window_in_days  = var.kms_deletion_window
  enable_key_rotation      = true
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage                = "ENCRYPT_DECRYPT"
  multi_region             = false

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-ebs-kms"
      Environment = var.environment
      Purpose     = "ebs-encryption"
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.environment}-${var.project_name}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

data "aws_iam_policy_document" "ebs_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow EC2 to use the key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${data.aws_region.current.name}.amazonaws.com"]
    }
  }

  statement {
    sid    = "Allow autoscaling to use the key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:CreateGrant"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key_policy" "ebs" {
  key_id = aws_kms_key.ebs.id
  policy = data.aws_iam_policy_document.ebs_kms.json
}

# KMS Key for RDS Encryption
resource "aws_kms_key" "rds" {
  description              = "KMS key for RDS encryption in ${var.environment}"
  deletion_window_in_days  = var.kms_deletion_window
  enable_key_rotation      = true
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage                = "ENCRYPT_DECRYPT"
  multi_region             = false

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-rds-kms"
      Environment = var.environment
      Purpose     = "rds-encryption"
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.environment}-${var.project_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

data "aws_iam_policy_document" "rds_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow RDS to use the key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["rds.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key_policy" "rds" {
  key_id = aws_kms_key.rds.id
  policy = data.aws_iam_policy_document.rds_kms.json
}

# KMS Key for S3 Encryption
resource "aws_kms_key" "s3" {
  description              = "KMS key for S3 bucket encryption in ${var.environment}"
  deletion_window_in_days  = var.kms_deletion_window
  enable_key_rotation      = true
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage                = "ENCRYPT_DECRYPT"
  multi_region             = false

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-s3-kms"
      Environment = var.environment
      Purpose     = "s3-encryption"
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.environment}-${var.project_name}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

data "aws_iam_policy_document" "s3_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow S3 to use the key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }
  }

  statement {
    sid    = "Allow CloudTrail to encrypt logs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:DecryptDataKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
    }
  }
}

resource "aws_kms_key_policy" "s3" {
  key_id = aws_kms_key.s3.id
  policy = data.aws_iam_policy_document.s3_kms.json
}

# KMS Key for Secrets Manager
resource "aws_kms_key" "secrets_manager" {
  description              = "KMS key for Secrets Manager encryption in ${var.environment}"
  deletion_window_in_days  = var.kms_deletion_window
  enable_key_rotation      = true
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage                = "ENCRYPT_DECRYPT"
  multi_region             = false

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-secrets-kms"
      Environment = var.environment
      Purpose     = "secrets-manager-encryption"
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_kms_alias" "secrets_manager" {
  name          = "alias/${var.environment}-${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets_manager.key_id
}

data "aws_iam_policy_document" "secrets_manager_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow Secrets Manager to use the key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["secretsmanager.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key_policy" "secrets_manager" {
  key_id = aws_kms_key.secrets_manager.id
  policy = data.aws_iam_policy_document.secrets_manager_kms.json
}

################################################################################
# Security Groups
################################################################################

# Windows Fleet Security Group
resource "aws_security_group" "windows_fleet" {
  name        = "${var.environment}-${var.project_name}-windows-fleet-sg"
  description = "Security group for Windows fleet instances with least privilege access"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-windows-fleet-sg"
      Environment = var.environment
      Purpose     = "windows-fleet"
      ManagedBy   = "terraform"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDP access from bastion only
resource "aws_vpc_security_group_ingress_rule" "windows_fleet_rdp" {
  security_group_id            = aws_security_group.windows_fleet.id
  description                  = "RDP access from bastion security group"
  from_port                    = 3389
  to_port                      = 3389
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.bastion_security_group_id

  tags = merge(
    var.tags,
    {
      Name = "rdp-from-bastion"
    }
  )
}

# HTTPS for SSM and other AWS services
resource "aws_vpc_security_group_egress_rule" "windows_fleet_https" {
  security_group_id = aws_security_group.windows_fleet.id
  description       = "HTTPS egress for SSM, CloudWatch, and AWS services"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(
    var.tags,
    {
      Name = "https-egress"
    }
  )
}

# PostgreSQL to database
resource "aws_vpc_security_group_egress_rule" "windows_fleet_postgres" {
  security_group_id            = aws_security_group.windows_fleet.id
  description                  = "PostgreSQL access to database security group"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.database.id

  tags = merge(
    var.tags,
    {
      Name = "postgres-to-db"
    }
  )
}

# Load Balancer Security Group
resource "aws_security_group" "load_balancer" {
  name        = "${var.environment}-${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer with HTTPS access"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-alb-sg"
      Environment = var.environment
      Purpose     = "load-balancer"
      ManagedBy   = "terraform"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS inbound from allowed CIDR blocks
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = length(var.alb_ingress_cidr_blocks) > 0 ? 1 : 0
  security_group_id = aws_security_group.load_balancer.id
  description       = "HTTPS inbound from allowed CIDR blocks"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.alb_ingress_cidr_blocks[0]

  tags = merge(
    var.tags,
    {
      Name = "https-inbound"
    }
  )
}

# Additional CIDR blocks for ALB
resource "aws_vpc_security_group_ingress_rule" "alb_https_additional" {
  count             = length(var.alb_ingress_cidr_blocks) > 1 ? length(var.alb_ingress_cidr_blocks) - 1 : 0
  security_group_id = aws_security_group.load_balancer.id
  description       = "HTTPS inbound from allowed CIDR blocks"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.alb_ingress_cidr_blocks[count.index + 1]

  tags = merge(
    var.tags,
    {
      Name = "https-inbound-${count.index + 1}"
    }
  )
}

# Egress to Windows fleet
resource "aws_vpc_security_group_egress_rule" "alb_to_fleet" {
  security_group_id            = aws_security_group.load_balancer.id
  description                  = "Traffic to Windows fleet instances"
  from_port                    = var.fleet_application_port
  to_port                      = var.fleet_application_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.windows_fleet.id

  tags = merge(
    var.tags,
    {
      Name = "to-windows-fleet"
    }
  )
}

# Ingress from ALB to Windows fleet
resource "aws_vpc_security_group_ingress_rule" "fleet_from_alb" {
  security_group_id            = aws_security_group.windows_fleet.id
  description                  = "Application traffic from load balancer"
  from_port                    = var.fleet_application_port
  to_port                      = var.fleet_application_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.load_balancer.id

  tags = merge(
    var.tags,
    {
      Name = "from-alb"
    }
  )
}

# Database Security Group
resource "aws_security_group" "database" {
  name        = "${var.environment}-${var.project_name}-db-sg"
  description = "Security group for PostgreSQL RDS with least privilege access"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-db-sg"
      Environment = var.environment
      Purpose     = "database"
      ManagedBy   = "terraform"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# PostgreSQL from Windows fleet only
resource "aws_vpc_security_group_ingress_rule" "db_from_fleet" {
  security_group_id            = aws_security_group.database.id
  description                  = "PostgreSQL access from Windows fleet only"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.windows_fleet.id

  tags = merge(
    var.tags,
    {
      Name = "postgres-from-fleet"
    }
  )
}

################################################################################
# Secrets Manager
################################################################################

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.environment}-${var.project_name}-db-credentials"
  description             = "PostgreSQL database credentials for ${var.environment} environment"
  kms_key_id              = aws_kms_key.secrets_manager.arn
  recovery_window_in_days = var.secret_recovery_window

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-db-credentials"
      Environment = var.environment
      Purpose     = "database-credentials"
      ManagedBy   = "terraform"
    }
  )
}

# Initial secret version (will be rotated)
resource "aws_secretsmanager_secret_version" "db_credentials_initial" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_master.result
    engine   = "postgres"
    port     = 5432
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "random_password" "db_master" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

################################################################################
# Security Hub
################################################################################

resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards  = true
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

# Enable AWS Foundational Security Best Practices
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_security_hub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# Enable CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_security_hub && var.enable_cis_benchmark ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
}

################################################################################
# GuardDuty
################################################################################

resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_frequency

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-${var.project_name}-guardduty"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
