#------------------------------------------------------------------------------
# CloudWatch Logs Insights Query Definitions
#------------------------------------------------------------------------------
# Saved queries for common log analysis tasks. These queries can be used
# directly in the CloudWatch Logs Insights console or invoked via API.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Error Analysis Queries
#------------------------------------------------------------------------------

# Top Errors by Count - Find the most frequent errors
resource "aws_cloudwatch_query_definition" "top_errors_by_count" {
  name = "${var.project_name}/${var.environment}/TopErrorsByCount"

  log_group_names = [
    aws_cloudwatch_log_group.application.name,
    aws_cloudwatch_log_group.system.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(error|critical|fatal)/
    | parse @message /(?<error_type>Error|Exception|Critical|Fatal).*?(?<error_message>[^\\n]+)/
    | stats count(*) as error_count by error_type, error_message
    | sort error_count desc
    | limit 50
  EOT
}

# Errors by Instance - Group errors by source instance
resource "aws_cloudwatch_query_definition" "errors_by_instance" {
  name = "${var.project_name}/${var.environment}/ErrorsByInstance"

  log_group_names = [
    aws_cloudwatch_log_group.application.name,
    aws_cloudwatch_log_group.system.name,
    aws_cloudwatch_log_group.security.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(error|critical|exception|failed)/
    | parse @logStream /(?<instance_id>i-[a-z0-9]+)/
    | stats count(*) as error_count by instance_id
    | sort error_count desc
    | limit 25
  EOT
}

# Error Rate Over Time - Track error trends
resource "aws_cloudwatch_query_definition" "error_trends_over_time" {
  name = "${var.project_name}/${var.environment}/ErrorTrendsOverTime"

  log_group_names = [
    aws_cloudwatch_log_group.application.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message
    | filter @message like /(?i)(error|critical|exception)/
    | stats count(*) as error_count by bin(5m) as time_bucket
    | sort time_bucket asc
  EOT
}

# Recent Critical Errors - Latest critical issues
resource "aws_cloudwatch_query_definition" "recent_critical_errors" {
  name = "${var.project_name}/${var.environment}/RecentCriticalErrors"

  log_group_names = [
    aws_cloudwatch_log_group.application.name,
    aws_cloudwatch_log_group.system.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(critical|fatal|unhandled)/
    | sort @timestamp desc
    | limit 100
  EOT
}

#------------------------------------------------------------------------------
# Performance Analysis Queries
#------------------------------------------------------------------------------

# Slow Operations - Find operations taking longer than threshold
resource "aws_cloudwatch_query_definition" "slow_operations" {
  name = "${var.project_name}/${var.environment}/SlowOperations"

  log_group_names = [
    aws_cloudwatch_log_group.application.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | parse @message /[Dd]uration[:\s]+(?<duration_ms>\d+)(\s*ms)?/
    | filter duration_ms > 5000
    | stats count(*) as occurrence_count, avg(duration_ms) as avg_duration_ms, max(duration_ms) as max_duration_ms by @logStream
    | sort max_duration_ms desc
    | limit 50
  EOT
}

# Operation Duration Percentiles
resource "aws_cloudwatch_query_definition" "operation_duration_percentiles" {
  name = "${var.project_name}/${var.environment}/OperationDurationPercentiles"

  log_group_names = [
    aws_cloudwatch_log_group.application.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message
    | parse @message /[Dd]uration[:\s]+(?<duration_ms>\d+)/
    | filter ispresent(duration_ms)
    | stats
        count(*) as total_count,
        avg(duration_ms) as avg_duration,
        pct(duration_ms, 50) as p50,
        pct(duration_ms, 90) as p90,
        pct(duration_ms, 95) as p95,
        pct(duration_ms, 99) as p99
      by bin(1h) as time_bucket
    | sort time_bucket desc
  EOT
}

# Request Throughput Analysis
resource "aws_cloudwatch_query_definition" "request_throughput" {
  name = "${var.project_name}/${var.environment}/RequestThroughput"

  log_group_names = [
    aws_cloudwatch_log_group.application.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message
    | filter @message like /(?i)(request|operation|transaction)/
    | stats count(*) as request_count by bin(1m) as time_bucket
    | sort time_bucket desc
  EOT
}

#------------------------------------------------------------------------------
# Security Analysis Queries
#------------------------------------------------------------------------------

# Failed Authentication Attempts - Security monitoring
resource "aws_cloudwatch_query_definition" "failed_authentication_attempts" {
  name = "${var.project_name}/${var.environment}/FailedAuthenticationAttempts"

  log_group_names = [
    aws_cloudwatch_log_group.security.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(4625|4771|4776|failed|failure|denied|unauthorized)/
    | parse @message /[Uu]ser[:\s]+(?<username>[^\s,]+)/
    | parse @message /[Ss]ource[:\s]+(?<source_ip>\d+\.\d+\.\d+\.\d+)/
    | stats count(*) as failure_count by username, source_ip
    | sort failure_count desc
    | limit 50
  EOT
}

# Account Lockout Events
resource "aws_cloudwatch_query_definition" "account_lockout_events" {
  name = "${var.project_name}/${var.environment}/AccountLockoutEvents"

  log_group_names = [
    aws_cloudwatch_log_group.security.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(4740|lockout|locked)/
    | parse @message /[Aa]ccount[:\s]+(?<account_name>[^\s,]+)/
    | sort @timestamp desc
    | limit 100
  EOT
}

# Privilege Escalation Analysis
resource "aws_cloudwatch_query_definition" "privilege_escalation_analysis" {
  name = "${var.project_name}/${var.environment}/PrivilegeEscalationAnalysis"

  log_group_names = [
    aws_cloudwatch_log_group.security.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(4672|4673|4674|privilege|elevated|administrator)/
    | parse @message /[Uu]ser[:\s]+(?<username>[^\s,]+)/
    | parse @message /[Pp]rivilege[:\s]+(?<privilege>[^\s,]+)/
    | stats count(*) as event_count by username, privilege
    | sort event_count desc
    | limit 50
  EOT
}

# Suspicious Security Events
resource "aws_cloudwatch_query_definition" "suspicious_security_events" {
  name = "${var.project_name}/${var.environment}/SuspiciousSecurityEvents"

  log_group_names = [
    aws_cloudwatch_log_group.security.name,
    aws_cloudwatch_log_group.powershell.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(mimikatz|credential.*dump|pass.*hash|golden.*ticket|silver.*ticket|kerberoast|invoke-expression|downloadstring|encoded.*command)/
    | sort @timestamp desc
    | limit 100
  EOT
}

#------------------------------------------------------------------------------
# Correlation and Tracing Queries
#------------------------------------------------------------------------------

# Correlation ID Trace - Follow a request across logs
resource "aws_cloudwatch_query_definition" "correlation_id_trace" {
  name = "${var.project_name}/${var.environment}/CorrelationIDTrace"

  log_group_names = [
    aws_cloudwatch_log_group.application.name,
    aws_cloudwatch_log_group.system.name,
    aws_cloudwatch_log_group.ssm.name
  ]

  # Note: Replace {correlation_id} with actual ID when running
  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /correlation[_-]?id|request[_-]?id|trace[_-]?id|transaction[_-]?id/
    | parse @message /(?i)(correlation[_-]?id|request[_-]?id|trace[_-]?id|transaction[_-]?id)[:\s="]+(?<correlation_id>[a-zA-Z0-9-]+)/
    | filter ispresent(correlation_id)
    | sort @timestamp asc
    | limit 500
  EOT
}

# Request Flow Analysis
resource "aws_cloudwatch_query_definition" "request_flow_analysis" {
  name = "${var.project_name}/${var.environment}/RequestFlowAnalysis"

  log_group_names = [
    aws_cloudwatch_log_group.application.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | parse @message /(?<request_id>[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})/
    | filter ispresent(request_id)
    | stats earliest(@timestamp) as start_time, latest(@timestamp) as end_time, count(*) as log_entries by request_id
    | sort start_time desc
    | limit 100
  EOT
}

# Cross-Service Error Correlation
resource "aws_cloudwatch_query_definition" "cross_service_error_correlation" {
  name = "${var.project_name}/${var.environment}/CrossServiceErrorCorrelation"

  log_group_names = [
    aws_cloudwatch_log_group.application.name,
    aws_cloudwatch_log_group.system.name,
    aws_cloudwatch_log_group.ssm.name,
    aws_cloudwatch_log_group.dsc.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream, @log
    | filter @message like /(?i)(error|failed|exception)/
    | parse @logStream /(?<instance_id>i-[a-z0-9]+)/
    | stats count(*) as error_count by instance_id, @log
    | sort error_count desc
    | limit 100
  EOT
}

#------------------------------------------------------------------------------
# SSM and Configuration Management Queries
#------------------------------------------------------------------------------

# SSM Command Execution History
resource "aws_cloudwatch_query_definition" "ssm_command_execution_history" {
  name = "${var.project_name}/${var.environment}/SSMCommandExecutionHistory"

  log_group_names = [
    aws_cloudwatch_log_group.ssm.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | parse @message /[Cc]ommand[_-]?[Ii]d[:\s]+(?<command_id>[a-zA-Z0-9-]+)/
    | parse @message /[Ss]tatus[:\s]+(?<status>\w+)/
    | filter ispresent(command_id)
    | stats count(*) as execution_count, latest(@timestamp) as last_execution by command_id, status
    | sort last_execution desc
    | limit 100
  EOT
}

# SSM Failure Analysis
resource "aws_cloudwatch_query_definition" "ssm_failure_analysis" {
  name = "${var.project_name}/${var.environment}/SSMFailureAnalysis"

  log_group_names = [
    aws_cloudwatch_log_group.ssm.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(failed|error|timeout|cancelled)/
    | parse @logStream /(?<instance_id>i-[a-z0-9]+)/
    | parse @message /[Cc]ommand[:\s]+(?<command_name>[^\s,]+)/
    | stats count(*) as failure_count by instance_id, command_name
    | sort failure_count desc
    | limit 50
  EOT
}

# DSC Compliance Status
resource "aws_cloudwatch_query_definition" "dsc_compliance_status" {
  name = "${var.project_name}/${var.environment}/DSCComplianceStatus"

  log_group_names = [
    aws_cloudwatch_log_group.dsc.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | parse @message /[Ss]tatus[:\s]+(?<compliance_status>\w+)/
    | parse @logStream /(?<instance_id>i-[a-z0-9]+)/
    | stats latest(compliance_status) as current_status, count(*) as check_count by instance_id
    | sort instance_id asc
  EOT
}

# DSC Configuration Drift Details
resource "aws_cloudwatch_query_definition" "dsc_configuration_drift_details" {
  name = "${var.project_name}/${var.environment}/DSCConfigurationDriftDetails"

  log_group_names = [
    aws_cloudwatch_log_group.dsc.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(not.*compliant|drift|out.*of.*desired.*state)/
    | parse @message /[Rr]esource[:\s]+(?<resource_name>[^\s,]+)/
    | parse @logStream /(?<instance_id>i-[a-z0-9]+)/
    | stats count(*) as drift_count by instance_id, resource_name
    | sort drift_count desc
    | limit 50
  EOT
}

#------------------------------------------------------------------------------
# PowerShell Analysis Queries
#------------------------------------------------------------------------------

# PowerShell Script Execution Analysis
resource "aws_cloudwatch_query_definition" "powershell_script_execution" {
  name = "${var.project_name}/${var.environment}/PowerShellScriptExecution"

  log_group_names = [
    aws_cloudwatch_log_group.powershell.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | parse @message /[Ss]cript[Nn]ame[:\s]+(?<script_name>[^\s,]+)/
    | filter ispresent(script_name)
    | stats count(*) as execution_count by script_name
    | sort execution_count desc
    | limit 50
  EOT
}

# PowerShell Suspicious Commands
resource "aws_cloudwatch_query_definition" "powershell_suspicious_commands" {
  name = "${var.project_name}/${var.environment}/PowerShellSuspiciousCommands"

  log_group_names = [
    aws_cloudwatch_log_group.powershell.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(-enc|-encodedcommand|invoke-expression|iex|downloadstring|webclient|invoke-webrequest|bypass|hidden|-w hidden|-nop|-noprofile)/
    | sort @timestamp desc
    | limit 100
  EOT
}

#------------------------------------------------------------------------------
# Operational Health Queries
#------------------------------------------------------------------------------

# Overall Log Volume by Type
resource "aws_cloudwatch_query_definition" "log_volume_by_type" {
  name = "${var.project_name}/${var.environment}/LogVolumeByType"

  log_group_names = [
    aws_cloudwatch_log_group.application.name,
    aws_cloudwatch_log_group.system.name,
    aws_cloudwatch_log_group.security.name,
    aws_cloudwatch_log_group.powershell.name,
    aws_cloudwatch_log_group.ssm.name,
    aws_cloudwatch_log_group.dsc.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @log
    | stats count(*) as log_count by @log, bin(1h) as time_bucket
    | sort time_bucket desc
  EOT
}

# Instance Health Summary
resource "aws_cloudwatch_query_definition" "instance_health_summary" {
  name = "${var.project_name}/${var.environment}/InstanceHealthSummary"

  log_group_names = [
    aws_cloudwatch_log_group.application.name,
    aws_cloudwatch_log_group.system.name
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | parse @logStream /(?<instance_id>i-[a-z0-9]+)/
    | filter ispresent(instance_id)
    | stats
        count(*) as total_logs,
        sum(strcontains(@message, "ERROR") or strcontains(@message, "error")) as error_count,
        sum(strcontains(@message, "WARNING") or strcontains(@message, "warning")) as warning_count,
        latest(@timestamp) as last_activity
      by instance_id
    | sort error_count desc
  EOT
}
