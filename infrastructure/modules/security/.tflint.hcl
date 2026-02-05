# TFLint configuration for security module

config {
  module     = true
  force      = false
  disabled_by_default = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Rule configurations
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

# AWS-specific rules
rule "aws_resource_missing_tags" {
  enabled = true
  tags = ["Environment", "ManagedBy"]
}

rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = true
}

rule "aws_iam_role_policy_too_long" {
  enabled = true
}

rule "aws_security_group_rule_undesired_cidrs" {
  enabled = true
  cidrs = [
    "0.0.0.0/0"  # Flag overly permissive rules
  ]
}
