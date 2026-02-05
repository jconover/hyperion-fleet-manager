# Example 1: Basic Windows Fleet
# Minimal configuration for a simple Windows Server fleet

module "basic_windows_fleet" {
  source = "./modules/compute"

  fleet_name = "basic-app-fleet"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1"
  ]

  instance_types   = ["t3.medium"]
  min_capacity     = 1
  max_capacity     = 5
  desired_capacity = 2

  tags = {
    Environment = "development"
    Role        = "application-server"
    ManagedBy   = "terraform"
  }
}

# Example 2: Production Fleet with Load Balancer
# Full-featured configuration with ALB integration and advanced scaling

module "production_web_fleet" {
  source = "./modules/compute"

  fleet_name = "prod-web-fleet"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1",
    "subnet-0123456789abcdef2"
  ]

  # Multiple instance types for flexibility
  instance_types   = ["t3.large", "t3.xlarge", "c5.xlarge"]
  min_capacity     = 3
  max_capacity     = 20
  desired_capacity = 5

  # Enhanced storage configuration
  root_volume_size = 100
  root_volume_type = "gp3"

  data_volumes = [
    {
      device_name           = "xvdf"
      size                  = 500
      type                  = "gp3"
      delete_on_termination = false
      iops                  = 3000
      throughput            = 125
    }
  ]

  # Load balancer integration
  enable_load_balancer = true
  target_group_arns    = ["arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web/0123456789abcdef"]

  # Multiple scaling policies
  enable_cpu_target_tracking = true
  cpu_target_value           = 70

  enable_alb_request_count_target_tracking = true
  alb_request_count_target_value           = 1000
  alb_target_group_resource_label          = "app/prod-alb/0123456789abcdef/targetgroup/web/0123456789abcdef"

  # Security configuration
  allowed_security_group_ids = ["sg-0123456789abcdef0"]
  associate_public_ip        = false

  # Monitoring and alerting
  enable_cloudwatch_alarms = true
  alarm_actions            = ["arn:aws:sns:us-east-1:123456789012:ops-alerts"]

  enable_asg_notifications = true

  # Custom bootstrap
  custom_user_data_script = <<-EOT
    Write-Output "Installing IIS..."
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools

    Write-Output "Configuring application..."
    New-Item -ItemType Directory -Path "C:\inetpub\wwwroot\app" -Force

    Write-Output "Application setup complete"
  EOT

  tags = {
    Environment = "production"
    Role        = "web-server"
    ManagedBy   = "terraform"
    Application = "customer-portal"
    CostCenter  = "engineering"
  }
}

# Example 3: Spot Instance Fleet for Batch Processing
# Cost-optimized configuration using Spot instances

module "batch_processing_fleet" {
  source = "./modules/compute"

  fleet_name = "batch-processor-fleet"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1"
  ]

  # Multiple compute-optimized instance types
  instance_types   = ["c5.xlarge", "c5.2xlarge", "c5a.xlarge", "c5n.xlarge"]
  min_capacity     = 0
  max_capacity     = 100
  desired_capacity = 20

  # Spot instance configuration
  on_demand_base_capacity                  = 2  # Keep 2 on-demand for stability
  on_demand_percentage_above_base_capacity = 10 # 10% on-demand, 90% spot
  spot_allocation_strategy                 = "capacity-optimized"
  spot_max_price                           = "" # Use on-demand price as max

  # Optimize for rapid scaling
  health_check_grace_period = 180
  default_cooldown          = 60

  # Aggressive scaling for batch workloads
  enable_cpu_target_tracking = true
  cpu_target_value           = 80

  # No load balancer needed for batch processing
  enable_load_balancer = false

  # Minimal monitoring
  enable_cloudwatch_alarms = false
  enable_asg_notifications = false

  tags = {
    Environment = "production"
    Role        = "batch-processor"
    ManagedBy   = "terraform"
    Workload    = "interruptible"
  }
}

# Example 4: High-Security Fleet with Custom AMI
# Enterprise security configuration with hardened AMI

module "secure_app_fleet" {
  source = "./modules/compute"

  fleet_name = "secure-app-fleet"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = [
    "subnet-0123456789abcdef0", # Private subnets only
    "subnet-0123456789abcdef1"
  ]

  # Use custom hardened AMI
  ami_id = "ami-custom123456789"

  instance_types   = ["t3.large"]
  min_capacity     = 2
  max_capacity     = 8
  desired_capacity = 4

  # Enhanced security
  associate_public_ip = false # Private IPs only
  rdp_cidr_blocks     = []    # No RDP access
  winrm_cidr_blocks   = []    # No WinRM access

  # Restrict access to specific security groups only
  allowed_security_group_ids = [
    "sg-app-tier",
    "sg-monitoring"
  ]

  # Encrypted storage with custom KMS settings
  root_volume_size    = 100
  root_volume_type    = "gp3"
  kms_deletion_window = 30

  # Conservative scaling
  enable_cpu_target_tracking = true
  cpu_target_value           = 60

  # Enhanced monitoring
  enable_cloudwatch_alarms = true
  alarm_actions = [
    "arn:aws:sns:us-east-1:123456789012:security-alerts",
    "arn:aws:sns:us-east-1:123456789012:ops-alerts"
  ]

  enable_asg_notifications = true

  # Minimal user data for security
  custom_user_data_script = <<-EOT
    # Apply additional security hardening
    Write-Output "Applying security policies..."

    # Disable guest account
    net user guest /active:no

    # Configure audit policies
    auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
    auditpol /set /category:"Account Logon" /success:enable /failure:enable

    Write-Output "Security hardening complete"
  EOT

  tags = {
    Environment    = "production"
    Role           = "application-server"
    ManagedBy      = "terraform"
    SecurityLevel  = "high"
    ComplianceType = "pci-dss"
  }
}

# Example 5: Development Fleet with RDP Access
# Development environment with direct access enabled

module "dev_fleet" {
  source = "./modules/compute"

  fleet_name = "dev-test-fleet"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-0123456789abcdef0"]

  instance_types   = ["t3.medium"]
  min_capacity     = 1
  max_capacity     = 3
  desired_capacity = 1

  # Enable public access for development
  associate_public_ip = true

  # Allow RDP from office network
  rdp_cidr_blocks = [
    "203.0.113.0/24" # Office network
  ]

  # Smaller volumes for dev
  root_volume_size = 50

  # Minimal scaling
  enable_cpu_target_tracking = false

  # Basic monitoring
  enable_cloudwatch_alarms = false
  enable_asg_notifications = false

  # Development tools installation
  custom_user_data_script = <<-EOT
    Write-Output "Installing development tools..."

    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    # Install common dev tools
    choco install -y git vscode notepadplusplus 7zip

    Write-Output "Development environment ready"
  EOT

  tags = {
    Environment  = "development"
    Role         = "test-server"
    ManagedBy    = "terraform"
    AutoShutdown = "enabled"
  }
}

# Example 6: Multi-Volume Database Server Fleet
# Configuration for data-intensive applications

module "database_server_fleet" {
  source = "./modules/compute"

  fleet_name = "sql-server-fleet"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1"
  ]

  # Memory-optimized instances for database workloads
  instance_types   = ["r5.xlarge", "r5.2xlarge"]
  min_capacity     = 2
  max_capacity     = 6
  desired_capacity = 2

  # OS volume
  root_volume_size = 100
  root_volume_type = "gp3"

  # Multiple data volumes
  data_volumes = [
    {
      # Database data files
      device_name           = "xvdf"
      size                  = 1000
      type                  = "io2"
      delete_on_termination = false
      iops                  = 10000
      throughput            = null
    },
    {
      # Database log files
      device_name           = "xvdg"
      size                  = 500
      type                  = "io2"
      delete_on_termination = false
      iops                  = 5000
      throughput            = null
    },
    {
      # TempDB
      device_name           = "xvdh"
      size                  = 200
      type                  = "gp3"
      delete_on_termination = true
      iops                  = 3000
      throughput            = 125
    },
    {
      # Backup volume
      device_name           = "xvdi"
      size                  = 2000
      type                  = "st1"
      delete_on_termination = false
      iops                  = null
      throughput            = null
    }
  ]

  # Database-specific scaling
  enable_cpu_target_tracking = true
  cpu_target_value           = 75

  # High availability
  health_check_grace_period = 600
  enable_load_balancer      = true
  target_group_arns         = ["arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/sql/0123456789abcdef"]

  # SQL Server installation
  custom_user_data_script = <<-EOT
    Write-Output "Preparing SQL Server installation..."

    # Configure SQL Server data directories
    New-Item -ItemType Directory -Path "D:\SQLData" -Force
    New-Item -ItemType Directory -Path "E:\SQLLogs" -Force
    New-Item -ItemType Directory -Path "F:\TempDB" -Force
    New-Item -ItemType Directory -Path "G:\Backups" -Force

    # Set SQL Server service account permissions
    icacls "D:\SQLData" /grant "NT SERVICE\MSSQLSERVER:(OI)(CI)F" /T
    icacls "E:\SQLLogs" /grant "NT SERVICE\MSSQLSERVER:(OI)(CI)F" /T
    icacls "F:\TempDB" /grant "NT SERVICE\MSSQLSERVER:(OI)(CI)F" /T

    Write-Output "SQL Server directories prepared"
  EOT

  tags = {
    Environment = "production"
    Role        = "database-server"
    ManagedBy   = "terraform"
    Database    = "sql-server"
    Backup      = "enabled"
  }
}
