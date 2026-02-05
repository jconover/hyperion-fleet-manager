<powershell>
# Windows Server 2022 Bootstrap Script
# Fleet: ${fleet_name}
# Environment: ${environment}

# Set error handling
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Configure logging
$LogFile = "C:\ProgramData\Bootstrap\bootstrap.log"
$LogDir = Split-Path $LogFile -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-BootstrapLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Output $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

Write-BootstrapLog "=== Starting Windows Fleet Bootstrap ==="
Write-BootstrapLog "Fleet Name: ${fleet_name}"
Write-BootstrapLog "Environment: ${environment}"
Write-BootstrapLog "Computer Name: $env:COMPUTERNAME"

# Configure PowerShell execution policy
Write-BootstrapLog "Configuring PowerShell execution policy..."
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    Write-BootstrapLog "PowerShell execution policy set to RemoteSigned"
} catch {
    Write-BootstrapLog "ERROR: Failed to set execution policy: $_"
}

# Configure Windows Time Service
Write-BootstrapLog "Configuring Windows Time Service..."
try {
    w32tm /config /manualpeerlist:"169.254.169.123" /syncfromflags:manual /reliable:yes /update
    Restart-Service w32time
    w32tm /resync /force
    Write-BootstrapLog "Windows Time Service configured successfully"
} catch {
    Write-BootstrapLog "ERROR: Failed to configure time service: $_"
}

# Set timezone to UTC
Write-BootstrapLog "Setting timezone to UTC..."
try {
    Set-TimeZone -Id "UTC"
    Write-BootstrapLog "Timezone set to UTC"
} catch {
    Write-BootstrapLog "ERROR: Failed to set timezone: $_"
}

# Configure Windows Firewall for SSM
Write-BootstrapLog "Configuring Windows Firewall..."
try {
    # Allow outbound HTTPS for SSM
    New-NetFirewallRule -DisplayName "Allow HTTPS Outbound for SSM" -Direction Outbound -Protocol TCP -RemotePort 443 -Action Allow -ErrorAction SilentlyContinue
    Write-BootstrapLog "Firewall rules configured"
} catch {
    Write-BootstrapLog "ERROR: Failed to configure firewall: $_"
}

# Verify and configure SSM Agent
Write-BootstrapLog "Checking SSM Agent status..."
try {
    $ssmService = Get-Service -Name "AmazonSSMAgent" -ErrorAction SilentlyContinue
    if ($ssmService) {
        if ($ssmService.Status -ne "Running") {
            Start-Service -Name "AmazonSSMAgent"
            Write-BootstrapLog "SSM Agent started"
        }
        Set-Service -Name "AmazonSSMAgent" -StartupType Automatic
        Write-BootstrapLog "SSM Agent is running and set to automatic startup"
    } else {
        Write-BootstrapLog "WARNING: SSM Agent service not found"
    }
} catch {
    Write-BootstrapLog "ERROR: Failed to configure SSM Agent: $_"
}

# Install and configure CloudWatch Agent
Write-BootstrapLog "Checking CloudWatch Agent..."
try {
    $cwAgentPath = "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.exe"
    if (Test-Path $cwAgentPath) {
        Write-BootstrapLog "CloudWatch Agent is installed"

        # Create basic CloudWatch config
        $cwConfig = @{
            "agent" = @{
                "metrics_collection_interval" = 60
                "run_as_user" = "cwagent"
            }
            "logs" = @{
                "logs_collected" = @{
                    "windows_events" = @{
                        "collect_list" = @(
                            @{
                                "event_name" = "System"
                                "event_levels" = @("ERROR", "WARNING", "CRITICAL")
                                "log_group_name" = "/aws/ec2/windows/${fleet_name}/system"
                                "log_stream_name" = "{instance_id}"
                            },
                            @{
                                "event_name" = "Application"
                                "event_levels" = @("ERROR", "WARNING", "CRITICAL")
                                "log_group_name" = "/aws/ec2/windows/${fleet_name}/application"
                                "log_stream_name" = "{instance_id}"
                            }
                        )
                    }
                    "files" = @{
                        "collect_list" = @(
                            @{
                                "file_path" = "C:\ProgramData\Bootstrap\bootstrap.log"
                                "log_group_name" = "/aws/ec2/windows/${fleet_name}/bootstrap"
                                "log_stream_name" = "{instance_id}"
                            }
                        )
                    }
                }
            }
            "metrics" = @{
                "namespace" = "Windows/${fleet_name}"
                "metrics_collected" = @{
                    "LogicalDisk" = @{
                        "measurement" = @(
                            @{
                                "name" = "% Free Space"
                                "unit" = "Percent"
                            }
                        )
                        "metrics_collection_interval" = 60
                        "resources" = @("*")
                    }
                    "Memory" = @{
                        "measurement" = @(
                            @{
                                "name" = "% Committed Bytes In Use"
                                "unit" = "Percent"
                            }
                        )
                        "metrics_collection_interval" = 60
                    }
                    "Processor" = @{
                        "measurement" = @(
                            @{
                                "name" = "% Processor Time"
                                "unit" = "Percent"
                            }
                        )
                        "metrics_collection_interval" = 60
                        "resources" = @("_Total")
                    }
                }
            }
        }

        $cwConfigPath = "C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json"
        $cwConfigDir = Split-Path $cwConfigPath -Parent
        if (-not (Test-Path $cwConfigDir)) {
            New-Item -ItemType Directory -Path $cwConfigDir -Force | Out-Null
        }

        $cwConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $cwConfigPath
        Write-BootstrapLog "CloudWatch Agent configuration created"

        # Start CloudWatch Agent
        & $cwAgentPath -a fetch-config -m ec2 -s -c "file:$cwConfigPath"
        Write-BootstrapLog "CloudWatch Agent configured and started"
    } else {
        Write-BootstrapLog "WARNING: CloudWatch Agent not installed"
    }
} catch {
    Write-BootstrapLog "ERROR: Failed to configure CloudWatch Agent: $_"
}

# Configure instance metadata service
Write-BootstrapLog "Configuring instance metadata..."
try {
    # Test IMDSv2 access
    $token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} -Method PUT -Uri http://169.254.169.254/latest/api/token
    $instanceId = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
    $availabilityZone = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/placement/availability-zone
    $instanceType = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-type

    Write-BootstrapLog "Instance ID: $instanceId"
    Write-BootstrapLog "Availability Zone: $availabilityZone"
    Write-BootstrapLog "Instance Type: $instanceType"

    # Store instance metadata in registry for future reference
    $registryPath = "HKLM:\SOFTWARE\FleetManager"
    if (-not (Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $registryPath -Name "InstanceId" -Value $instanceId
    Set-ItemProperty -Path $registryPath -Name "FleetName" -Value "${fleet_name}"
    Set-ItemProperty -Path $registryPath -Name "Environment" -Value "${environment}"
    Set-ItemProperty -Path $registryPath -Name "BootstrapTime" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

    Write-BootstrapLog "Instance metadata stored in registry"
} catch {
    Write-BootstrapLog "ERROR: Failed to retrieve instance metadata: $_"
}

# Configure Windows updates
Write-BootstrapLog "Configuring Windows Update settings..."
try {
    # Set Windows Update to download but not install automatically
    $AutoUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $AutoUpdatePath)) {
        New-Item -Path $AutoUpdatePath -Force | Out-Null
    }
    Set-ItemProperty -Path $AutoUpdatePath -Name "NoAutoUpdate" -Value 0 -Type DWord
    Set-ItemProperty -Path $AutoUpdatePath -Name "AUOptions" -Value 3 -Type DWord
    Set-ItemProperty -Path $AutoUpdatePath -Name "ScheduledInstallDay" -Value 0 -Type DWord
    Set-ItemProperty -Path $AutoUpdatePath -Name "ScheduledInstallTime" -Value 3 -Type DWord

    Write-BootstrapLog "Windows Update configured"
} catch {
    Write-BootstrapLog "ERROR: Failed to configure Windows Update: $_"
}

# Optimize system performance
Write-BootstrapLog "Optimizing system performance..."
try {
    # Disable unnecessary services
    $servicesToDisable = @(
        "WSearch"  # Windows Search
    )

    foreach ($service in $servicesToDisable) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc -and $svc.StartType -ne "Disabled") {
            Set-Service -Name $service -StartupType Disabled
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Write-BootstrapLog "Disabled service: $service"
        }
    }

    # Configure power plan to High Performance
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    Write-BootstrapLog "Power plan set to High Performance"
} catch {
    Write-BootstrapLog "ERROR: Failed to optimize system: $_"
}

# Configure disk settings
Write-BootstrapLog "Configuring disk settings..."
try {
    # Initialize and format any additional disks
    $rawDisks = Get-Disk | Where-Object PartitionStyle -eq "RAW"
    if ($rawDisks) {
        foreach ($disk in $rawDisks) {
            $diskNumber = $disk.Number
            Initialize-Disk -Number $diskNumber -PartitionStyle GPT -PassThru |
                New-Partition -AssignDriveLetter -UseMaximumSize |
                Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data$diskNumber" -Confirm:$false
            Write-BootstrapLog "Initialized and formatted disk $diskNumber"
        }
    } else {
        Write-BootstrapLog "No additional raw disks found"
    }
} catch {
    Write-BootstrapLog "ERROR: Failed to configure disks: $_"
}

# Configure event log retention
Write-BootstrapLog "Configuring event log retention..."
try {
    $logs = @("Application", "System", "Security")
    foreach ($log in $logs) {
        Limit-EventLog -LogName $log -MaximumSize 512MB -OverflowAction OverwriteAsNeeded
    }
    Write-BootstrapLog "Event log retention configured"
} catch {
    Write-BootstrapLog "ERROR: Failed to configure event logs: $_"
}

# Set computer description
Write-BootstrapLog "Setting computer description..."
try {
    $description = "${fleet_name} - ${environment} - Managed by Terraform"
    $computerSystem = Get-WmiObject -Class Win32_OperatingSystem
    $computerSystem.Description = $description
    $computerSystem.Put() | Out-Null
    Write-BootstrapLog "Computer description set"
} catch {
    Write-BootstrapLog "ERROR: Failed to set computer description: $_"
}

# Run custom user data script if provided
$customScript = @"
${custom_script}
"@

if ($customScript.Trim() -ne "") {
    Write-BootstrapLog "Executing custom user data script..."
    try {
        Invoke-Expression $customScript
        Write-BootstrapLog "Custom script executed successfully"
    } catch {
        Write-BootstrapLog "ERROR: Custom script execution failed: $_"
    }
}

# Final system information
Write-BootstrapLog "=== System Information ==="
Write-BootstrapLog "OS Version: $([System.Environment]::OSVersion.VersionString)"
Write-BootstrapLog "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-BootstrapLog "Computer Name: $env:COMPUTERNAME"
Write-BootstrapLog "Domain: $env:USERDOMAIN"

# Signal completion
Write-BootstrapLog "=== Bootstrap completed successfully ==="
Write-BootstrapLog "Bootstrap log available at: $LogFile"

# Create completion marker
$completionMarker = "C:\ProgramData\Bootstrap\bootstrap.complete"
Set-Content -Path $completionMarker -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Write-Output "Windows Fleet Bootstrap completed successfully!"
</powershell>
