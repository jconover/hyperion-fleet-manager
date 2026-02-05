function Start-MetricCollector {
    <#
    .SYNOPSIS
        Starts scheduled metric collection for Hyperion Fleet Manager.

    .DESCRIPTION
        Registers a scheduled task (Windows) or cron job (Linux) to collect
        and publish metrics at regular intervals. Supports custom metric
        definitions and multiple collection profiles.

    .PARAMETER IntervalMinutes
        The collection interval in minutes. Defaults to 5 minutes.

    .PARAMETER CollectionProfile
        The metric collection profile to use:
        - 'System': System metrics only (CPU, Memory, Disk, Network)
        - 'Compliance': Compliance metrics only
        - 'Application': Application metrics only
        - 'Full': All metrics
        Defaults to 'Full'.

    .PARAMETER ApplicationName
        The application name for application metrics.

    .PARAMETER Environment
        The deployment environment.

    .PARAMETER Role
        The server role.

    .PARAMETER Namespace
        The CloudWatch namespace.

    .PARAMETER TaskName
        The name of the scheduled task. Defaults to 'HyperionMetricCollector'.

    .PARAMETER RunAs
        The user account to run the task as. Defaults to SYSTEM on Windows.

    .PARAMETER CustomMetricScript
        Path to a custom script that returns metric objects.

    .PARAMETER Region
        The AWS region to publish metrics to.

    .PARAMETER ProfileName
        The AWS credential profile to use.

    .PARAMETER Force
        Force overwrite of existing scheduled task.

    .EXAMPLE
        Start-MetricCollector -Environment 'prod' -Role 'WebServer'

        Starts metric collection with default settings (every 5 minutes).

    .EXAMPLE
        Start-MetricCollector -IntervalMinutes 1 -CollectionProfile 'System' -Environment 'prod'

        Starts high-frequency system metrics collection.

    .EXAMPLE
        Start-MetricCollector -CustomMetricScript 'C:\Scripts\Get-CustomMetrics.ps1' -Environment 'prod'

        Starts metric collection with a custom metric script.

    .OUTPUTS
        PSCustomObject
        Returns information about the created scheduled task.

    .NOTES
        On Windows, creates a Windows Task Scheduler task.
        On Linux, creates a systemd timer or cron job.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateRange(1, 1440)]
        [int]$IntervalMinutes = 5,

        [Parameter()]
        [ValidateSet('System', 'Compliance', 'Application', 'Full')]
        [string]$CollectionProfile = 'Full',

        [Parameter()]
        [string]$ApplicationName,

        [Parameter()]
        [ValidateSet('dev', 'staging', 'prod', 'test')]
        [string]$Environment = 'dev',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Role = 'FleetServer',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace = $script:DefaultNamespace,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TaskName = $script:CollectorTaskName,

        [Parameter()]
        [string]$RunAs,

        [Parameter()]
        [ValidateScript({
            if ($_ -and -not (Test-Path -Path $_ -PathType Leaf)) {
                throw "Custom metric script not found: $_"
            }
            $true
        })]
        [string]$CustomMetricScript,

        [Parameter()]
        [string]$Region,

        [Parameter()]
        [string]$ProfileName,

        [Parameter()]
        [switch]$Force
    )

    $isWindows = $IsWindows -or ([Environment]::OSVersion.Platform -eq 'Win32NT')

    # Build the collection script path
    $collectionScript = Join-Path -Path $script:ModuleRoot -ChildPath 'Scripts\Invoke-MetricCollection.ps1'

    if (-not (Test-Path -Path $collectionScript)) {
        throw "Metric collection script not found at: $collectionScript"
    }

    # Build arguments for the collection script
    $scriptArgs = @(
        "-Environment '$Environment'",
        "-Role '$Role'",
        "-Namespace '$Namespace'",
        "-CollectionProfile '$CollectionProfile'"
    )

    if ($ApplicationName) {
        $scriptArgs += "-ApplicationName '$ApplicationName'"
    }
    if ($Region) {
        $scriptArgs += "-Region '$Region'"
    }
    if ($ProfileName) {
        $scriptArgs += "-ProfileName '$ProfileName'"
    }
    if ($CustomMetricScript) {
        $scriptArgs += "-CustomMetricScript '$CustomMetricScript'"
    }

    $argumentString = $scriptArgs -join ' '

    if ($isWindows) {
        $result = Register-WindowsMetricCollector `
            -TaskName $TaskName `
            -ScriptPath $collectionScript `
            -Arguments $argumentString `
            -IntervalMinutes $IntervalMinutes `
            -RunAs $RunAs `
            -Force:$Force `
            -WhatIf:$WhatIfPreference `
            -Confirm:$ConfirmPreference
    }
    else {
        $result = Register-LinuxMetricCollector `
            -TaskName $TaskName `
            -ScriptPath $collectionScript `
            -Arguments $argumentString `
            -IntervalMinutes $IntervalMinutes `
            -Force:$Force `
            -WhatIf:$WhatIfPreference `
            -Confirm:$ConfirmPreference
    }

    return $result
}

function Stop-MetricCollector {
    <#
    .SYNOPSIS
        Stops and removes the scheduled metric collector.

    .DESCRIPTION
        Removes the scheduled task (Windows) or cron job (Linux) that was
        created by Start-MetricCollector.

    .PARAMETER TaskName
        The name of the scheduled task to remove.

    .EXAMPLE
        Stop-MetricCollector

        Removes the default metric collector scheduled task.

    .EXAMPLE
        Stop-MetricCollector -TaskName 'CustomMetricCollector'

        Removes a custom-named metric collector.

    .OUTPUTS
        System.Boolean
        Returns $true if the collector was successfully stopped.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TaskName = $script:CollectorTaskName
    )

    $isWindows = $IsWindows -or ([Environment]::OSVersion.Platform -eq 'Win32NT')

    if ($isWindows) {
        return Unregister-WindowsMetricCollector -TaskName $TaskName -WhatIf:$WhatIfPreference
    }
    else {
        return Unregister-LinuxMetricCollector -TaskName $TaskName -WhatIf:$WhatIfPreference
    }
}

function Get-MetricCollectorStatus {
    <#
    .SYNOPSIS
        Gets the status of the metric collector scheduled task.

    .DESCRIPTION
        Returns information about the metric collector including its state,
        last run time, next run time, and any recent errors.

    .PARAMETER TaskName
        The name of the scheduled task.

    .EXAMPLE
        Get-MetricCollectorStatus

        Gets the status of the default metric collector.

    .OUTPUTS
        PSCustomObject
        Returns the collector status information.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TaskName = $script:CollectorTaskName
    )

    $isWindows = $IsWindows -or ([Environment]::OSVersion.Platform -eq 'Win32NT')

    if ($isWindows) {
        return Get-WindowsCollectorStatus -TaskName $TaskName
    }
    else {
        return Get-LinuxCollectorStatus -TaskName $TaskName
    }
}

#region Windows Task Scheduler Functions

function Register-WindowsMetricCollector {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [string]$Arguments,
        [int]$IntervalMinutes,
        [string]$RunAs,
        [switch]$Force
    )

    # Check for existing task
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($existingTask -and -not $Force) {
        throw "Scheduled task '$TaskName' already exists. Use -Force to overwrite."
    }

    if ($existingTask -and $Force) {
        if ($PSCmdlet.ShouldProcess($TaskName, 'Remove existing scheduled task')) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Verbose "Removed existing scheduled task: $TaskName"
        }
    }

    # Build the action
    $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source ??
                (Get-Command powershell -ErrorAction SilentlyContinue)?.Source

    if (-not $pwshPath) {
        throw 'PowerShell executable not found in PATH'
    }

    $actionArgs = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments"

    $action = New-ScheduledTaskAction `
        -Execute $pwshPath `
        -Argument $actionArgs

    # Build the trigger (every N minutes)
    $trigger = New-ScheduledTaskTrigger `
        -Once `
        -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
        -RepetitionDuration ([TimeSpan]::MaxValue)

    # Build the principal
    $principalParams = @{
        UserId    = $RunAs ?? 'NT AUTHORITY\SYSTEM'
        LogonType = 'ServiceAccount'
        RunLevel  = 'Highest'
    }
    $principal = New-ScheduledTaskPrincipal @principalParams

    # Task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
        -MultipleInstances IgnoreNew

    # Register the task
    $taskDescription = "Hyperion Fleet Manager metric collector. Collects and publishes metrics to CloudWatch every $IntervalMinutes minute(s)."

    if ($PSCmdlet.ShouldProcess($TaskName, 'Create scheduled task')) {
        $task = Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings `
            -Description $taskDescription `
            -Force

        Write-Verbose "Created scheduled task: $TaskName"

        # Start the task immediately
        Start-ScheduledTask -TaskName $TaskName

        return [PSCustomObject]@{
            TaskName         = $TaskName
            Status           = 'Registered'
            IntervalMinutes  = $IntervalMinutes
            ScriptPath       = $ScriptPath
            RunAs            = $principalParams.UserId
            Platform         = 'Windows'
            NextRunTime      = (Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime
            CreatedAt        = (Get-Date)
        }
    }
}

function Unregister-WindowsMetricCollector {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [string]$TaskName
    )

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if (-not $task) {
        Write-Warning "Scheduled task '$TaskName' not found."
        return $false
    }

    if ($PSCmdlet.ShouldProcess($TaskName, 'Remove scheduled task')) {
        # Stop the task if running
        if ($task.State -eq 'Running') {
            Stop-ScheduledTask -TaskName $TaskName
        }

        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Verbose "Removed scheduled task: $TaskName"
        return $true
    }

    return $false
}

function Get-WindowsCollectorStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$TaskName
    )

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if (-not $task) {
        return [PSCustomObject]@{
            TaskName  = $TaskName
            Status    = 'NotFound'
            Platform  = 'Windows'
            IsRunning = $false
        }
    }

    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName

    return [PSCustomObject]@{
        TaskName        = $TaskName
        Status          = $task.State.ToString()
        Platform        = 'Windows'
        IsRunning       = $task.State -eq 'Running'
        LastRunTime     = $taskInfo.LastRunTime
        LastTaskResult  = $taskInfo.LastTaskResult
        NextRunTime     = $taskInfo.NextRunTime
        NumberOfMissedRuns = $taskInfo.NumberOfMissedRuns
        Description     = $task.Description
    }
}

#endregion

#region Linux Systemd/Cron Functions

function Register-LinuxMetricCollector {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [string]$Arguments,
        [int]$IntervalMinutes,
        [switch]$Force
    )

    $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
    if (-not $pwshPath) {
        throw 'PowerShell (pwsh) not found in PATH'
    }

    # Determine if we can use systemd
    $useSystemd = Test-Path '/run/systemd/system'

    if ($useSystemd) {
        return Register-SystemdTimer `
            -TaskName $TaskName `
            -ScriptPath $ScriptPath `
            -Arguments $Arguments `
            -IntervalMinutes $IntervalMinutes `
            -PwshPath $pwshPath `
            -Force:$Force `
            -WhatIf:$WhatIfPreference
    }
    else {
        return Register-CronJob `
            -TaskName $TaskName `
            -ScriptPath $ScriptPath `
            -Arguments $Arguments `
            -IntervalMinutes $IntervalMinutes `
            -PwshPath $pwshPath `
            -Force:$Force `
            -WhatIf:$WhatIfPreference
    }
}

function Register-SystemdTimer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [string]$Arguments,
        [int]$IntervalMinutes,
        [string]$PwshPath,
        [switch]$Force
    )

    $serviceName = $TaskName.ToLower()
    $serviceFile = "/etc/systemd/system/$serviceName.service"
    $timerFile = "/etc/systemd/system/$serviceName.timer"

    # Check for existing
    if ((Test-Path $serviceFile) -and -not $Force) {
        throw "Systemd service '$serviceName' already exists. Use -Force to overwrite."
    }

    $serviceContent = @"
[Unit]
Description=Hyperion Fleet Manager Metric Collector
After=network.target

[Service]
Type=oneshot
ExecStart=$PwshPath -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$ScriptPath" $Arguments
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
"@

    $timerContent = @"
[Unit]
Description=Hyperion Fleet Manager Metric Collector Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=${IntervalMinutes}min
AccuracySec=1s

[Install]
WantedBy=timers.target
"@

    if ($PSCmdlet.ShouldProcess("$serviceName.service and $serviceName.timer", 'Create systemd units')) {
        $serviceContent | Set-Content -Path $serviceFile -Force
        $timerContent | Set-Content -Path $timerFile -Force

        # Reload systemd and enable the timer
        & systemctl daemon-reload
        & systemctl enable "$serviceName.timer"
        & systemctl start "$serviceName.timer"

        return [PSCustomObject]@{
            TaskName        = $TaskName
            Status          = 'Registered'
            IntervalMinutes = $IntervalMinutes
            ScriptPath      = $ScriptPath
            Platform        = 'Linux-Systemd'
            ServiceFile     = $serviceFile
            TimerFile       = $timerFile
            CreatedAt       = (Get-Date)
        }
    }
}

function Register-CronJob {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [string]$Arguments,
        [int]$IntervalMinutes,
        [string]$PwshPath,
        [switch]$Force
    )

    $cronFile = "/etc/cron.d/$($TaskName.ToLower())"

    if ((Test-Path $cronFile) -and -not $Force) {
        throw "Cron job '$TaskName' already exists. Use -Force to overwrite."
    }

    # Build cron schedule
    $cronSchedule = if ($IntervalMinutes -eq 60) {
        '0 * * * *'  # Every hour
    }
    elseif ($IntervalMinutes -ge 60) {
        $hours = [math]::Floor($IntervalMinutes / 60)
        "0 */$hours * * *"
    }
    else {
        "*/$IntervalMinutes * * * *"
    }

    $cronContent = @"
# Hyperion Fleet Manager Metric Collector
# Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

$cronSchedule root $PwshPath -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$ScriptPath" $Arguments >> /var/log/hyperion-metrics.log 2>&1
"@

    if ($PSCmdlet.ShouldProcess($cronFile, 'Create cron job')) {
        $cronContent | Set-Content -Path $cronFile -Force
        chmod 644 $cronFile

        return [PSCustomObject]@{
            TaskName        = $TaskName
            Status          = 'Registered'
            IntervalMinutes = $IntervalMinutes
            ScriptPath      = $ScriptPath
            Platform        = 'Linux-Cron'
            CronFile        = $cronFile
            CronSchedule    = $cronSchedule
            CreatedAt       = (Get-Date)
        }
    }
}

function Unregister-LinuxMetricCollector {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [string]$TaskName
    )

    $serviceName = $TaskName.ToLower()
    $serviceFile = "/etc/systemd/system/$serviceName.service"
    $timerFile = "/etc/systemd/system/$serviceName.timer"
    $cronFile = "/etc/cron.d/$serviceName"

    $removed = $false

    # Try systemd first
    if (Test-Path $timerFile) {
        if ($PSCmdlet.ShouldProcess("$serviceName.timer", 'Remove systemd timer')) {
            & systemctl stop "$serviceName.timer" 2>/dev/null
            & systemctl disable "$serviceName.timer" 2>/dev/null
            Remove-Item -Path $timerFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $serviceFile -Force -ErrorAction SilentlyContinue
            & systemctl daemon-reload
            $removed = $true
            Write-Verbose "Removed systemd timer: $serviceName"
        }
    }

    # Try cron
    if (Test-Path $cronFile) {
        if ($PSCmdlet.ShouldProcess($cronFile, 'Remove cron job')) {
            Remove-Item -Path $cronFile -Force
            $removed = $true
            Write-Verbose "Removed cron job: $cronFile"
        }
    }

    if (-not $removed) {
        Write-Warning "Metric collector '$TaskName' not found."
        return $false
    }

    return $true
}

function Get-LinuxCollectorStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$TaskName
    )

    $serviceName = $TaskName.ToLower()
    $timerFile = "/etc/systemd/system/$serviceName.timer"
    $cronFile = "/etc/cron.d/$serviceName"

    # Check systemd timer
    if (Test-Path $timerFile) {
        $status = & systemctl is-active "$serviceName.timer" 2>/dev/null
        $timerInfo = & systemctl show "$serviceName.timer" --property=LastTriggerUSec,NextElapseUSecRealtime 2>/dev/null

        $lastRun = $null
        $nextRun = $null

        foreach ($line in $timerInfo) {
            if ($line -match '^LastTriggerUSec=(.+)') {
                $lastRun = [datetime]::Parse($Matches[1]) -ErrorAction SilentlyContinue
            }
            if ($line -match '^NextElapseUSecRealtime=(.+)') {
                $nextRun = [datetime]::Parse($Matches[1]) -ErrorAction SilentlyContinue
            }
        }

        return [PSCustomObject]@{
            TaskName    = $TaskName
            Status      = $status
            Platform    = 'Linux-Systemd'
            IsRunning   = $status -eq 'active'
            LastRunTime = $lastRun
            NextRunTime = $nextRun
            TimerFile   = $timerFile
        }
    }

    # Check cron job
    if (Test-Path $cronFile) {
        return [PSCustomObject]@{
            TaskName  = $TaskName
            Status    = 'Active'
            Platform  = 'Linux-Cron'
            IsRunning = $true
            CronFile  = $cronFile
        }
    }

    return [PSCustomObject]@{
        TaskName  = $TaskName
        Status    = 'NotFound'
        Platform  = 'Linux'
        IsRunning = $false
    }
}

#endregion
