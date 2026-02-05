#------------------------------------------------------------------------------
# CloudWatch Logs Subscription Filters
#------------------------------------------------------------------------------
# Subscription filters stream log data to destinations for archival,
# real-time processing, or cross-account sharing.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Kinesis Firehose for S3 Archival
#------------------------------------------------------------------------------

# IAM Role for CloudWatch Logs to Firehose
resource "aws_iam_role" "cloudwatch_logs_to_firehose" {
  count = var.enable_s3_archival ? 1 : 0

  name = "${var.project_name}-${var.environment}-logs-to-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringLike = {
            "aws:SourceArn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/hyperion/fleet/*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-logs-to-firehose-role"
    }
  )
}

resource "aws_iam_role_policy" "cloudwatch_logs_to_firehose" {
  count = var.enable_s3_archival ? 1 : 0

  name = "${var.project_name}-${var.environment}-logs-to-firehose-policy"
  role = aws_iam_role.cloudwatch_logs_to_firehose[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.log_archival[0].arn
      }
    ]
  })
}

# IAM Role for Kinesis Firehose to S3
resource "aws_iam_role" "firehose_to_s3" {
  count = var.enable_s3_archival ? 1 : 0

  name = "${var.project_name}-${var.environment}-firehose-to-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-firehose-to-s3-role"
    }
  )
}

resource "aws_iam_role_policy" "firehose_to_s3" {
  count = var.enable_s3_archival ? 1 : 0

  name = "${var.project_name}-${var.environment}-firehose-to-s3-policy"
  role = aws_iam_role.firehose_to_s3[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.archive_bucket_name}",
          "arn:aws:s3:::${var.archive_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.firehose_errors[0].arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.archive_kms_key_arn != null ? var.archive_kms_key_arn : "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for Firehose errors
resource "aws_cloudwatch_log_group" "firehose_errors" {
  count = var.enable_s3_archival ? 1 : 0

  name              = "/aws/firehose/${var.project_name}-${var.environment}-log-archival"
  retention_in_days = 14

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-firehose-errors"
      LogType = "firehose-errors"
    }
  )
}

resource "aws_cloudwatch_log_stream" "firehose_errors" {
  count = var.enable_s3_archival ? 1 : 0

  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose_errors[0].name
}

# Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "log_archival" {
  count = var.enable_s3_archival ? 1 : 0

  name        = "${var.project_name}-${var.environment}-log-archival"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_to_s3[0].arn
    bucket_arn = "arn:aws:s3:::${var.archive_bucket_name}"

    # Organize logs by date and log type
    prefix              = "logs/${var.environment}/!{partitionKeyFromQuery:log_type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/${var.environment}/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    buffering_size     = var.firehose_buffer_size
    buffering_interval = var.firehose_buffer_interval

    compression_format = "GZIP"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_errors[0].name
      log_stream_name = aws_cloudwatch_log_stream.firehose_errors[0].name
    }

    # Dynamic partitioning for better organization
    dynamic_partitioning_configuration {
      enabled = true
    }

    processing_configuration {
      enabled = true

      processors {
        type = "MetadataExtraction"
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          parameter_value = "{log_type: .logGroup | split(\"/\") | .[-1]}"
        }
        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }
      }

      processors {
        type = "AppendDelimiterToRecord"
        parameters {
          parameter_name  = "Delimiter"
          parameter_value = "\\n"
        }
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-log-archival"
    }
  )
}

# Subscription Filters for S3 Archival
resource "aws_cloudwatch_log_subscription_filter" "application_to_firehose" {
  count = var.enable_s3_archival ? 1 : 0

  name            = "${var.project_name}-${var.environment}-application-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.application.name
  filter_pattern  = var.archival_filter_pattern
  destination_arn = aws_kinesis_firehose_delivery_stream.log_archival[0].arn
  role_arn        = aws_iam_role.cloudwatch_logs_to_firehose[0].arn
}

resource "aws_cloudwatch_log_subscription_filter" "system_to_firehose" {
  count = var.enable_s3_archival ? 1 : 0

  name            = "${var.project_name}-${var.environment}-system-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.system.name
  filter_pattern  = var.archival_filter_pattern
  destination_arn = aws_kinesis_firehose_delivery_stream.log_archival[0].arn
  role_arn        = aws_iam_role.cloudwatch_logs_to_firehose[0].arn
}

resource "aws_cloudwatch_log_subscription_filter" "security_to_firehose" {
  count = var.enable_s3_archival ? 1 : 0

  name            = "${var.project_name}-${var.environment}-security-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.security.name
  filter_pattern  = var.archival_filter_pattern
  destination_arn = aws_kinesis_firehose_delivery_stream.log_archival[0].arn
  role_arn        = aws_iam_role.cloudwatch_logs_to_firehose[0].arn
}

resource "aws_cloudwatch_log_subscription_filter" "powershell_to_firehose" {
  count = var.enable_s3_archival ? 1 : 0

  name            = "${var.project_name}-${var.environment}-powershell-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.powershell.name
  filter_pattern  = var.archival_filter_pattern
  destination_arn = aws_kinesis_firehose_delivery_stream.log_archival[0].arn
  role_arn        = aws_iam_role.cloudwatch_logs_to_firehose[0].arn
}

resource "aws_cloudwatch_log_subscription_filter" "ssm_to_firehose" {
  count = var.enable_s3_archival ? 1 : 0

  name            = "${var.project_name}-${var.environment}-ssm-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.ssm.name
  filter_pattern  = var.archival_filter_pattern
  destination_arn = aws_kinesis_firehose_delivery_stream.log_archival[0].arn
  role_arn        = aws_iam_role.cloudwatch_logs_to_firehose[0].arn
}

resource "aws_cloudwatch_log_subscription_filter" "dsc_to_firehose" {
  count = var.enable_s3_archival ? 1 : 0

  name            = "${var.project_name}-${var.environment}-dsc-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.dsc.name
  filter_pattern  = var.archival_filter_pattern
  destination_arn = aws_kinesis_firehose_delivery_stream.log_archival[0].arn
  role_arn        = aws_iam_role.cloudwatch_logs_to_firehose[0].arn
}

#------------------------------------------------------------------------------
# Lambda Subscription for Real-Time Processing (Optional)
#------------------------------------------------------------------------------

# IAM Role for CloudWatch Logs to Lambda
resource "aws_iam_role" "cloudwatch_logs_to_lambda" {
  count = var.enable_lambda_processing ? 1 : 0

  name = "${var.project_name}-${var.environment}-logs-to-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringLike = {
            "aws:SourceArn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/hyperion/fleet/*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-logs-to-lambda-role"
    }
  )
}

# Lambda permission for CloudWatch Logs
resource "aws_lambda_permission" "allow_cloudwatch_logs" {
  count = var.enable_lambda_processing && var.lambda_processor_arn != null ? 1 : 0

  statement_id  = "AllowCloudWatchLogs-${var.project_name}-${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_processor_arn
  principal     = "logs.amazonaws.com"
  source_arn    = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/hyperion/fleet/*"
}

# Subscription Filter for Security Logs to Lambda (real-time alerting)
resource "aws_cloudwatch_log_subscription_filter" "security_to_lambda" {
  count = var.enable_lambda_processing && var.lambda_processor_arn != null ? 1 : 0

  name            = "${var.project_name}-${var.environment}-security-to-lambda"
  log_group_name  = aws_cloudwatch_log_group.security.name
  filter_pattern  = var.lambda_filter_pattern
  destination_arn = var.lambda_processor_arn

  depends_on = [aws_lambda_permission.allow_cloudwatch_logs]
}

# Subscription Filter for Application Errors to Lambda
resource "aws_cloudwatch_log_subscription_filter" "application_errors_to_lambda" {
  count = var.enable_lambda_processing && var.lambda_processor_arn != null && var.enable_application_error_lambda ? 1 : 0

  name            = "${var.project_name}-${var.environment}-app-errors-to-lambda"
  log_group_name  = aws_cloudwatch_log_group.application.name
  filter_pattern  = "?ERROR ?CRITICAL ?FATAL ?Exception"
  destination_arn = var.lambda_processor_arn

  depends_on = [aws_lambda_permission.allow_cloudwatch_logs]
}

#------------------------------------------------------------------------------
# Cross-Account Log Sharing (Optional)
#------------------------------------------------------------------------------

# Log Group Destination for cross-account sharing
resource "aws_cloudwatch_log_destination" "cross_account" {
  count = var.enable_cross_account_sharing ? 1 : 0

  name       = "${var.project_name}-${var.environment}-cross-account-destination"
  target_arn = var.cross_account_destination_arn
  role_arn   = aws_iam_role.cross_account_logs[0].arn
}

# IAM Role for cross-account log delivery
resource "aws_iam_role" "cross_account_logs" {
  count = var.enable_cross_account_sharing ? 1 : 0

  name = "${var.project_name}-${var.environment}-cross-account-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-cross-account-logs-role"
    }
  )
}

resource "aws_iam_role_policy" "cross_account_logs" {
  count = var.enable_cross_account_sharing ? 1 : 0

  name = "${var.project_name}-${var.environment}-cross-account-logs-policy"
  role = aws_iam_role.cross_account_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord"
        ]
        Resource = var.cross_account_destination_arn
      }
    ]
  })
}

# Destination policy for cross-account access
resource "aws_cloudwatch_log_destination_policy" "cross_account" {
  count = var.enable_cross_account_sharing ? 1 : 0

  destination_name = aws_cloudwatch_log_destination.cross_account[0].name
  force_update     = true

  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountSubscription"
        Effect = "Allow"
        Principal = {
          AWS = var.cross_account_principal_arns
        }
        Action   = "logs:PutSubscriptionFilter"
        Resource = aws_cloudwatch_log_destination.cross_account[0].arn
      }
    ]
  })
}

# Subscription filters for cross-account sharing (security logs)
resource "aws_cloudwatch_log_subscription_filter" "security_cross_account" {
  count = var.enable_cross_account_sharing && var.cross_account_share_security_logs ? 1 : 0

  name            = "${var.project_name}-${var.environment}-security-cross-account"
  log_group_name  = aws_cloudwatch_log_group.security.name
  filter_pattern  = var.cross_account_filter_pattern
  destination_arn = aws_cloudwatch_log_destination.cross_account[0].arn
}

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
