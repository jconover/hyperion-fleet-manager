# Basic test configuration for observability module
# This can be used with terraform test or as a standalone test

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # Use localstack or moto for testing without AWS credentials
  # endpoints {
  #   cloudwatch = "http://localhost:4566"
  #   sns        = "http://localhost:4566"
  #   events     = "http://localhost:4566"
  # }
}

# Test basic configuration
module "observability_basic_test" {
  source = "../"

  environment = "dev"

  alert_email_addresses = [
    "test@example.com"
  ]

  instance_ids           = ["i-test123456789abcd"]
  enable_instance_alarms = true

  target_group_arn_suffix  = "targetgroup/test-tg/1234567890abcdef"
  load_balancer_arn_suffix = "app/test-alb/1234567890abcdef"

  cpu_threshold_percent    = 80
  memory_threshold_percent = 85

  log_retention_days = 7

  enable_xray = false

  tags = {
    Test      = "true"
    ManagedBy = "terraform"
  }
}

# Test outputs are accessible
output "test_log_groups" {
  value = module.observability_basic_test.log_group_names
}

output "test_sns_topic" {
  value = module.observability_basic_test.sns_topic_arn
}

output "test_dashboard_url" {
  value = module.observability_basic_test.dashboard_url
}

# Validation checks
check "log_groups_created" {
  assert {
    condition     = length(module.observability_basic_test.log_group_names) == 3
    error_message = "Expected 3 log groups to be created"
  }
}

check "sns_topic_created" {
  assert {
    condition     = module.observability_basic_test.sns_topic_arn != ""
    error_message = "SNS topic ARN should not be empty"
  }
}

check "dashboard_created" {
  assert {
    condition     = module.observability_basic_test.dashboard_name != ""
    error_message = "Dashboard name should not be empty"
  }
}

check "monitoring_summary" {
  assert {
    condition     = module.observability_basic_test.monitoring_summary.environment == "dev"
    error_message = "Environment should be 'dev'"
  }

  assert {
    condition     = module.observability_basic_test.monitoring_summary.log_groups_count == 3
    error_message = "Should have 3 log groups"
  }
}

# Test with X-Ray enabled
module "observability_xray_test" {
  source = "../"

  environment = "dev"

  alert_email_addresses = [
    "test@example.com"
  ]

  instance_ids = []

  enable_instance_alarms       = false
  enable_target_group_alarms   = false
  enable_scheduled_health_checks = false
  enable_scheduled_backups     = false

  enable_xray           = true
  xray_sampling_priority = 100
  xray_reservoir_size   = 1
  xray_fixed_rate       = 0.05

  tags = {
    Test  = "xray"
  }
}

check "xray_resources_created" {
  assert {
    condition     = module.observability_xray_test.xray_sampling_rule_arn != null
    error_message = "X-Ray sampling rule should be created when enabled"
  }

  assert {
    condition     = module.observability_xray_test.xray_group_name != null
    error_message = "X-Ray group should be created when enabled"
  }
}

# Test variable validation
run "test_invalid_environment" {
  command = plan

  variables {
    environment = "invalid"
    alert_email_addresses = ["test@example.com"]
  }

  expect_failures = [
    var.environment
  ]
}

run "test_invalid_email" {
  command = plan

  variables {
    environment = "dev"
    alert_email_addresses = ["not-an-email"]
  }

  expect_failures = [
    var.alert_email_addresses
  ]
}

run "test_invalid_cpu_threshold" {
  command = plan

  variables {
    environment = "dev"
    alert_email_addresses = ["test@example.com"]
    cpu_threshold_percent = 150
  }

  expect_failures = [
    var.cpu_threshold_percent
  ]
}

run "test_invalid_log_retention" {
  command = plan

  variables {
    environment = "dev"
    alert_email_addresses = ["test@example.com"]
    log_retention_days = 15  # Invalid value
  }

  expect_failures = [
    var.log_retention_days
  ]
}

run "test_valid_configuration" {
  command = plan

  variables {
    environment = "production"
    alert_email_addresses = [
      "ops@example.com",
      "platform@example.com"
    ]
    instance_ids = [
      "i-1234567890abcdef0",
      "i-0987654321fedcba0"
    ]
    cpu_threshold_percent = 75
    memory_threshold_percent = 80
    log_retention_days = 90
    enable_xray = true
  }

  assert {
    condition     = module.observability_basic_test.monitoring_summary.log_groups_count == 3
    error_message = "Should create 3 log groups"
  }
}
