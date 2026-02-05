variable "fleet_name" {
  description = "Name of the Windows fleet (used for resource naming)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.fleet_name))
    error_message = "Fleet name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_id" {
  description = "VPC ID where the fleet will be deployed"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid vpc-* identifier."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Auto Scaling Group"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID must be provided."
  }
}

# AMI Configuration
variable "ami_id" {
  description = "AMI ID for Windows Server 2022 (if empty, latest AWS managed AMI will be used)"
  type        = string
  default     = ""
}

# Instance Configuration
variable "instance_types" {
  description = "List of instance types for the fleet (supports multiple types for mixed instances policy)"
  type        = list(string)
  default     = ["t3.medium", "t3.large", "c5.xlarge"]

  validation {
    condition     = length(var.instance_types) > 0
    error_message = "At least one instance type must be specified."
  }
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address with instances"
  type        = bool
  default     = false
}

# Auto Scaling Configuration
variable "min_capacity" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 1

  validation {
    condition     = var.min_capacity >= 0
    error_message = "Minimum capacity must be greater than or equal to 0."
  }
}

variable "max_capacity" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 10

  validation {
    condition     = var.max_capacity > 0
    error_message = "Maximum capacity must be greater than 0."
  }
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_capacity >= 0
    error_message = "Desired capacity must be greater than or equal to 0."
  }
}

variable "health_check_grace_period" {
  description = "Time (in seconds) after instance comes into service before checking health"
  type        = number
  default     = 300
}

variable "default_cooldown" {
  description = "Amount of time (in seconds) after a scaling activity completes before another can start"
  type        = number
  default     = 300
}

variable "wait_for_capacity_timeout" {
  description = "Maximum duration to wait for all instances to be healthy (0 to disable)"
  type        = string
  default     = "10m"
}

# EBS Volume Configuration
variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.root_volume_size >= 30 && var.root_volume_size <= 16384
    error_message = "Root volume size must be between 30 GB and 16384 GB."
  }
}

variable "root_volume_type" {
  description = "Type of root EBS volume (gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "gp2", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be one of: gp3, gp2, io1, io2."
  }
}

variable "data_volumes" {
  description = "Additional data volumes to attach to instances"
  type = list(object({
    device_name           = string
    size                  = number
    type                  = string
    delete_on_termination = bool
    iops                  = optional(number)
    throughput            = optional(number)
  }))
  default = []
}

# KMS Configuration
variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

# Network Configuration
variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to access the fleet"
  type        = list(string)
  default     = []
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach to instances"
  type        = list(string)
  default     = []
}

variable "rdp_cidr_blocks" {
  description = "CIDR blocks allowed for RDP access (empty to disable)"
  type        = list(string)
  default     = []
}

variable "winrm_cidr_blocks" {
  description = "CIDR blocks allowed for WinRM access (empty to disable)"
  type        = list(string)
  default     = []
}

# Load Balancer Configuration
variable "enable_load_balancer" {
  description = "Enable ELB health checks"
  type        = bool
  default     = false
}

variable "target_group_arns" {
  description = "List of target group ARNs for load balancer integration"
  type        = list(string)
  default     = []
}

# Scaling Policy Configuration
variable "enable_cpu_target_tracking" {
  description = "Enable CPU utilization target tracking scaling policy"
  type        = bool
  default     = true
}

variable "cpu_target_value" {
  description = "Target average CPU utilization percentage for scaling"
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_target_value > 0 && var.cpu_target_value <= 100
    error_message = "CPU target value must be between 0 and 100."
  }
}

variable "enable_network_in_target_tracking" {
  description = "Enable network in target tracking scaling policy"
  type        = bool
  default     = false
}

variable "network_in_target_value" {
  description = "Target average network in bytes for scaling"
  type        = number
  default     = 10485760 # 10 MB
}

variable "enable_alb_request_count_target_tracking" {
  description = "Enable ALB request count per target tracking scaling policy"
  type        = bool
  default     = false
}

variable "alb_request_count_target_value" {
  description = "Target number of requests per instance"
  type        = number
  default     = 1000
}

variable "alb_target_group_resource_label" {
  description = "Resource label for ALB target group (required if ALB request count tracking is enabled)"
  type        = string
  default     = ""
}

# Mixed Instances Policy Configuration
variable "on_demand_base_capacity" {
  description = "Absolute minimum amount of desired capacity that must be fulfilled by on-demand instances"
  type        = number
  default     = 0
}

variable "on_demand_percentage_above_base_capacity" {
  description = "Percentage split between on-demand and spot instances above the base on-demand capacity"
  type        = number
  default     = 100

  validation {
    condition     = var.on_demand_percentage_above_base_capacity >= 0 && var.on_demand_percentage_above_base_capacity <= 100
    error_message = "On-demand percentage must be between 0 and 100."
  }
}

variable "spot_allocation_strategy" {
  description = "How to allocate capacity across Spot pools (lowest-price, capacity-optimized, capacity-optimized-prioritized)"
  type        = string
  default     = "capacity-optimized"

  validation {
    condition     = contains(["lowest-price", "capacity-optimized", "capacity-optimized-prioritized"], var.spot_allocation_strategy)
    error_message = "Spot allocation strategy must be one of: lowest-price, capacity-optimized, capacity-optimized-prioritized."
  }
}

variable "spot_instance_pools" {
  description = "Number of Spot pools per availability zone to allocate capacity (only for lowest-price strategy)"
  type        = number
  default     = 2
}

variable "spot_max_price" {
  description = "Maximum price per unit hour you are willing to pay for a Spot instance (empty for on-demand price)"
  type        = string
  default     = ""
}

# Instance Refresh Configuration
variable "instance_refresh_min_healthy_percentage" {
  description = "Minimum percentage of healthy instances during instance refresh"
  type        = number
  default     = 90

  validation {
    condition     = var.instance_refresh_min_healthy_percentage >= 0 && var.instance_refresh_min_healthy_percentage <= 100
    error_message = "Instance refresh min healthy percentage must be between 0 and 100."
  }
}

variable "instance_refresh_instance_warmup" {
  description = "Number of seconds until a newly launched instance is configured and ready to use"
  type        = number
  default     = 300
}

# Termination Policies
variable "termination_policies" {
  description = "List of policies to decide how instances are terminated (OldestInstance, NewestInstance, OldestLaunchConfiguration, etc.)"
  type        = list(string)
  default     = ["OldestInstance"]
}

# Metrics Configuration
variable "enabled_metrics" {
  description = "List of metrics to enable for the Auto Scaling Group"
  type        = list(string)
  default = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
  ]
}

# CloudWatch Alarms Configuration
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "List of alarm actions (SNS topic ARNs) to execute when alarms trigger"
  type        = list(string)
  default     = []
}

# Notifications Configuration
variable "enable_asg_notifications" {
  description = "Enable Auto Scaling Group notifications via SNS"
  type        = bool
  default     = false
}

# User Data Configuration
variable "custom_user_data_script" {
  description = "Custom PowerShell script to append to the user data"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Role        = "compute"
    ManagedBy   = "terraform"
  }

  validation {
    condition     = contains(keys(var.tags), "Environment") && contains(keys(var.tags), "Role") && contains(keys(var.tags), "ManagedBy")
    error_message = "Tags must include Environment, Role, and ManagedBy keys."
  }
}
