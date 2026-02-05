terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for latest Windows Server 2022 AMI if not provided
data "aws_ami" "windows_2022" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# KMS key for EBS encryption
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS volume encryption - ${var.fleet_name}"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.fleet_name}-ebs-key"
    }
  )
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.fleet_name}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

# IAM role for EC2 instances
resource "aws_iam_role" "instance" {
  name               = "${var.fleet_name}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.fleet_name}-instance-role"
    }
  )
}

data "aws_iam_policy_document" "instance_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Attach SSM managed policy for Systems Manager
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch agent policy
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom policy for KMS encryption access
resource "aws_iam_role_policy" "kms_access" {
  name = "${var.fleet_name}-kms-access"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = aws_kms_key.ebs.arn
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "instance" {
  name = "${var.fleet_name}-instance-profile"
  role = aws_iam_role.instance.name

  tags = merge(
    var.tags,
    {
      Name = "${var.fleet_name}-instance-profile"
    }
  )
}

# Security group for the fleet
resource "aws_security_group" "fleet" {
  name        = "${var.fleet_name}-sg"
  description = "Security group for ${var.fleet_name} Windows fleet"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.fleet_name}-sg"
    }
  )
}

# Egress rule - allow all outbound traffic
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.fleet.id
  description       = "Allow all outbound traffic"
}

# Optional ingress rules from allowed security groups
resource "aws_security_group_rule" "ingress_from_sg" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.fleet.id
  description              = "Allow traffic from security group ${var.allowed_security_group_ids[count.index]}"
}

# Optional RDP access
resource "aws_security_group_rule" "rdp" {
  count             = length(var.rdp_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = var.rdp_cidr_blocks
  security_group_id = aws_security_group.fleet.id
  description       = "Allow RDP access"
}

# Optional WinRM access
resource "aws_security_group_rule" "winrm_https" {
  count             = length(var.winrm_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 5986
  to_port           = 5986
  protocol          = "tcp"
  cidr_blocks       = var.winrm_cidr_blocks
  security_group_id = aws_security_group.fleet.id
  description       = "Allow WinRM HTTPS access"
}

# Launch template for the Auto Scaling Group
resource "aws_launch_template" "fleet" {
  name_prefix   = "${var.fleet_name}-"
  description   = "Launch template for ${var.fleet_name} Windows fleet"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.windows_2022[0].id
  instance_type = var.instance_types[0]

  # Enable IMDSv2 (required)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # IAM instance profile
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  # Network interfaces configuration
  network_interfaces {
    associate_public_ip_address = var.associate_public_ip
    delete_on_termination       = true
    security_groups             = concat([aws_security_group.fleet.id], var.additional_security_group_ids)
  }

  # Root EBS volume with encryption
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = true
      kms_key_id            = aws_kms_key.ebs.arn
      delete_on_termination = true
    }
  }

  # Additional data volumes
  dynamic "block_device_mappings" {
    for_each = var.data_volumes

    content {
      device_name = block_device_mappings.value.device_name

      ebs {
        volume_size           = block_device_mappings.value.size
        volume_type           = block_device_mappings.value.type
        encrypted             = true
        kms_key_id            = aws_kms_key.ebs.arn
        delete_on_termination = block_device_mappings.value.delete_on_termination
        iops                  = lookup(block_device_mappings.value, "iops", null)
        throughput            = lookup(block_device_mappings.value, "throughput", null)
      }
    }
  }

  # User data script
  user_data = base64encode(templatefile("${path.module}/user_data.ps1", {
    fleet_name    = var.fleet_name
    environment   = var.tags["Environment"]
    custom_script = var.custom_user_data_script
  }))

  # Tag specifications
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      {
        Name = "${var.fleet_name}-instance"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = "${var.fleet_name}-volume"
      }
    )
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.fleet_name}-launch-template"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "fleet" {
  name                = "${var.fleet_name}-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_capacity
  max_size            = var.max_capacity
  desired_capacity    = var.desired_capacity

  health_check_type         = var.enable_load_balancer ? "ELB" : "EC2"
  health_check_grace_period = var.health_check_grace_period
  default_cooldown          = var.default_cooldown

  target_group_arns         = var.target_group_arns
  termination_policies      = var.termination_policies
  enabled_metrics           = var.enabled_metrics
  wait_for_capacity_timeout = var.wait_for_capacity_timeout

  # Mixed instances policy for multiple instance types
  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = var.on_demand_base_capacity
      on_demand_percentage_above_base_capacity = var.on_demand_percentage_above_base_capacity
      spot_allocation_strategy                 = var.spot_allocation_strategy
      spot_instance_pools                      = var.spot_instance_pools
      spot_max_price                           = var.spot_max_price
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.fleet.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.instance_types

        content {
          instance_type = override.value
        }
      }
    }
  }

  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = var.instance_refresh_min_healthy_percentage
      instance_warmup        = var.instance_refresh_instance_warmup
    }
  }

  # Tags
  dynamic "tag" {
    for_each = merge(
      var.tags,
      {
        Name = "${var.fleet_name}-instance"
      }
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy_attachment.cloudwatch
  ]
}

# Target tracking scaling policy - CPU utilization
resource "aws_autoscaling_policy" "cpu_target" {
  count                  = var.enable_cpu_target_tracking ? 1 : 0
  name                   = "${var.fleet_name}-cpu-target-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.fleet.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}

# Target tracking scaling policy - Network in
resource "aws_autoscaling_policy" "network_in_target" {
  count                  = var.enable_network_in_target_tracking ? 1 : 0
  name                   = "${var.fleet_name}-network-in-target-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.fleet.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageNetworkIn"
    }
    target_value = var.network_in_target_value
  }
}

# Target tracking scaling policy - ALB request count per target
resource "aws_autoscaling_policy" "alb_request_count_target" {
  count                  = var.enable_alb_request_count_target_tracking ? 1 : 0
  name                   = "${var.fleet_name}-alb-request-count-target-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.fleet.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_target_group_resource_label
    }
    target_value = var.alb_request_count_target_value
  }
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.fleet_name}-high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors high CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.fleet.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count               = var.enable_cloudwatch_alarms && var.enable_load_balancer ? 1 : 0
  alarm_name          = "${var.fleet_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy hosts in target group"
  alarm_actions       = var.alarm_actions

  tags = var.tags
}

# SNS topic for ASG notifications
resource "aws_sns_topic" "asg_notifications" {
  count = var.enable_asg_notifications ? 1 : 0
  name  = "${var.fleet_name}-asg-notifications"

  tags = merge(
    var.tags,
    {
      Name = "${var.fleet_name}-asg-notifications"
    }
  )
}

resource "aws_autoscaling_notification" "notifications" {
  count = var.enable_asg_notifications ? 1 : 0

  group_names = [aws_autoscaling_group.fleet.name]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.asg_notifications[0].arn
}
