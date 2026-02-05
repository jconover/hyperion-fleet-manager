# Example configurations for the observability module
# These are commented out and serve as documentation

/*
# Example 1: Basic Monitoring Setup
# Minimal configuration for getting started

module "observability_basic" {
  source = "./modules/observability"

  environment = "production"

  alert_email_addresses = [
    "ops-team@example.com"
  ]

  instance_ids = [
    "i-1234567890abcdef0"
  ]

  tags = {
    Project   = "fleet-manager"
    ManagedBy = "terraform"
  }
}

# Example 2: Complete Production Setup
# Full-featured configuration with custom thresholds

module "observability_production" {
  source = "./modules/observability"

  environment = "production"

  # SNS Alerting
  alert_email_addresses = [
    "ops-team@example.com",
    "platform-team@example.com",
    "on-call@example.com"
  ]

  # Instance Monitoring
  instance_ids           = ["i-abc123", "i-def456", "i-ghi789"]
  enable_instance_alarms = true

  # Custom Alarm Thresholds
  cpu_threshold_percent     = 75
  cpu_evaluation_periods    = 4

  memory_threshold_percent  = 80
  memory_evaluation_periods = 3

  disk_free_threshold_percent = 20
  disk_evaluation_periods     = 2

  # Target Group Monitoring
  target_group_arn_suffix    = "targetgroup/fleet-tg/1234567890abcdef"
  load_balancer_arn_suffix   = "app/fleet-alb/1234567890abcdef"
  enable_target_group_alarms = true

  unhealthy_host_threshold           = 1
  unhealthy_host_evaluation_periods  = 3

  # Error Monitoring
  error_rate_threshold     = 5
  error_evaluation_periods = 3

  # Log Configuration
  log_retention_days          = 90
  security_log_retention_days = 365
  kms_key_id                  = aws_kms_key.logs.id

  # CloudWatch Configuration
  cloudwatch_namespace = "FleetManager"
  alarm_period         = 300

  # EventBridge Scheduling
  health_check_schedule          = "rate(5 minutes)"
  enable_scheduled_health_checks = true

  backup_schedule          = "cron(0 2 * * ? *)"
  enable_scheduled_backups = true

  # X-Ray Tracing
  enable_xray                  = true
  xray_sampling_priority       = 100
  xray_reservoir_size          = 5
  xray_fixed_rate              = 0.10
  xray_service_name            = "fleet-manager"
  xray_response_time_threshold = 2
  xray_insights_enabled        = true
  xray_notifications_enabled   = true

  tags = {
    Project     = "fleet-manager"
    Environment = "production"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
  }
}

# Example 3: Multi-Environment Pattern
# Separate configurations for different environments

locals {
  environments = {
    production = {
      log_retention_days       = 90
      security_log_retention   = 365
      cpu_threshold            = 80
      memory_threshold         = 85
      disk_threshold           = 15
      enable_xray              = true
      xray_sampling_rate       = 0.10
      alert_emails             = ["ops-prod@example.com"]
      health_check_interval    = "rate(5 minutes)"
    }
    staging = {
      log_retention_days       = 30
      security_log_retention   = 90
      cpu_threshold            = 85
      memory_threshold         = 90
      disk_threshold           = 10
      enable_xray              = true
      xray_sampling_rate       = 0.20
      alert_emails             = ["ops-staging@example.com"]
      health_check_interval    = "rate(10 minutes)"
    }
    dev = {
      log_retention_days       = 7
      security_log_retention   = 30
      cpu_threshold            = 90
      memory_threshold         = 95
      disk_threshold           = 10
      enable_xray              = false
      xray_sampling_rate       = 0.50
      alert_emails             = ["dev-team@example.com"]
      health_check_interval    = "rate(15 minutes)"
    }
  }
}

module "observability_multi_env" {
  for_each = local.environments

  source = "./modules/observability"

  environment = each.key

  alert_email_addresses         = each.value.alert_emails
  log_retention_days            = each.value.log_retention_days
  security_log_retention_days   = each.value.security_log_retention

  cpu_threshold_percent         = each.value.cpu_threshold
  memory_threshold_percent      = each.value.memory_threshold
  disk_free_threshold_percent   = each.value.disk_threshold

  enable_xray                   = each.value.enable_xray
  xray_fixed_rate               = each.value.xray_sampling_rate

  health_check_schedule         = each.value.health_check_interval

  instance_ids                  = lookup(var.instance_ids_by_env, each.key, [])
  target_group_arn_suffix       = lookup(var.target_group_arns_by_env, each.key, "")
  load_balancer_arn_suffix      = lookup(var.load_balancer_arns_by_env, each.key, "")

  tags = merge(
    var.common_tags,
    {
      Environment = each.key
    }
  )
}

# Example 4: High-Sensitivity Monitoring
# Aggressive thresholds for critical workloads

module "observability_critical" {
  source = "./modules/observability"

  environment = "production"

  alert_email_addresses = [
    "critical-ops@example.com",
    "cto@example.com"
  ]

  instance_ids = var.critical_instance_ids

  # Aggressive thresholds
  cpu_threshold_percent           = 70
  cpu_evaluation_periods          = 2  # 10 minutes

  memory_threshold_percent        = 75
  memory_evaluation_periods       = 2

  disk_free_threshold_percent     = 25
  disk_evaluation_periods         = 1

  unhealthy_host_threshold        = 0  # Alert on any unhealthy host
  error_rate_threshold            = 1  # Alert on any errors

  # Frequent monitoring
  alarm_period                    = 300
  health_check_schedule           = "rate(1 minute)"

  # Comprehensive logging
  log_retention_days              = 180
  security_log_retention_days     = 730

  # Full X-Ray tracing
  enable_xray                     = true
  xray_fixed_rate                 = 0.50  # 50% sampling
  xray_insights_enabled           = true
  xray_notifications_enabled      = true

  target_group_arn_suffix         = var.critical_target_group_arn
  load_balancer_arn_suffix        = var.critical_alb_arn

  tags = {
    Project     = "fleet-manager"
    Environment = "production"
    Criticality = "high"
    ManagedBy   = "terraform"
  }
}

# Example 5: Cost-Optimized Monitoring
# Minimal configuration for cost-sensitive environments

module "observability_cost_optimized" {
  source = "./modules/observability"

  environment = "dev"

  alert_email_addresses = ["dev-team@example.com"]

  # Minimal instance monitoring
  instance_ids           = var.dev_instance_ids
  enable_instance_alarms = false  # Disable per-instance alarms

  # Target group monitoring only
  enable_target_group_alarms = true
  target_group_arn_suffix    = var.dev_target_group_arn
  load_balancer_arn_suffix   = var.dev_alb_arn

  # Relaxed thresholds
  unhealthy_host_threshold = 2
  error_rate_threshold     = 50

  # Short retention
  log_retention_days          = 7
  security_log_retention_days = 30

  # Infrequent checks
  health_check_schedule          = "rate(15 minutes)"
  enable_scheduled_backups       = false

  # No X-Ray
  enable_xray = false

  tags = {
    Project     = "fleet-manager"
    Environment = "dev"
    CostProfile = "optimized"
  }
}

# Example 6: Security-Focused Monitoring
# Emphasizes security event detection and logging

module "observability_security_focused" {
  source = "./modules/observability"

  environment = "production"

  alert_email_addresses = [
    "security-team@example.com",
    "ops-team@example.com"
  ]

  instance_ids = var.instance_ids

  # Extended security log retention
  log_retention_days          = 90
  security_log_retention_days = 2555  # 7 years

  # Encrypted logs
  kms_key_id = aws_kms_key.security_logs.id

  # Standard performance thresholds
  cpu_threshold_percent    = 80
  memory_threshold_percent = 85

  # Immediate security event notification
  # (security events trigger alarm on any detection)

  # Frequent monitoring
  health_check_schedule = "rate(1 minute)"

  # Full tracing for security analysis
  enable_xray                = true
  xray_fixed_rate            = 0.25
  xray_insights_enabled      = true
  xray_notifications_enabled = true

  target_group_arn_suffix  = var.target_group_arn
  load_balancer_arn_suffix = var.alb_arn

  tags = {
    Project        = "fleet-manager"
    Environment    = "production"
    SecurityLevel  = "high"
    ComplianceType = "pci-dss"
  }
}

# Example 7: Integration with Existing Infrastructure
# Connect to resources from other modules

module "observability_integrated" {
  source = "./modules/observability"

  environment = "production"

  # Use outputs from other modules
  instance_ids             = module.compute.instance_ids
  target_group_arn_suffix  = module.networking.target_group_arn_suffix
  load_balancer_arn_suffix = module.networking.alb_arn_suffix
  kms_key_id               = module.security.kms_key_id

  alert_email_addresses = var.alert_emails

  cpu_threshold_percent    = var.cpu_threshold
  memory_threshold_percent = var.memory_threshold

  tags = merge(
    local.common_tags,
    {
      Module = "observability"
    }
  )
}

# Example outputs usage
output "monitoring_dashboard_url" {
  description = "URL to CloudWatch dashboard"
  value       = module.observability_production.dashboard_url
}

output "alert_topic_arn" {
  description = "SNS topic ARN for subscribing additional endpoints"
  value       = module.observability_production.sns_topic_arn
}

output "log_groups" {
  description = "Log group names for application configuration"
  value       = module.observability_production.log_group_names
}

output "monitoring_summary" {
  description = "Summary of monitoring configuration"
  value       = module.observability_production.monitoring_summary
}
*/
