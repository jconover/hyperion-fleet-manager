function Get-SystemMetrics {
    <#
    .SYNOPSIS
        Collects system performance metrics from the local machine.

    .DESCRIPTION
        Gathers CPU, Memory, Disk, and Network metrics using WMI/CIM for Windows
        and platform-specific methods for Linux. Returns structured metric objects
        ready for publishing to CloudWatch.

    .PARAMETER IncludeCPU
        Include CPU utilization metrics. Defaults to $true.

    .PARAMETER IncludeMemory
        Include memory usage metrics. Defaults to $true.

    .PARAMETER IncludeDisk
        Include disk space metrics. Defaults to $true.

    .PARAMETER IncludeNetwork
        Include network throughput metrics. Defaults to $true.

    .PARAMETER DiskDrives
        Specific disk drives to monitor. Defaults to all fixed drives.
        On Windows: 'C:', 'D:', etc.
        On Linux: '/', '/home', etc.

    .PARAMETER NetworkInterfaces
        Specific network interfaces to monitor. Defaults to all active interfaces.

    .PARAMETER SampleInterval
        The interval in seconds for CPU sampling. Defaults to 1 second.

    .EXAMPLE
        Get-SystemMetrics

        Collects all system metrics with default settings.

    .EXAMPLE
        Get-SystemMetrics -IncludeCPU -IncludeMemory -DiskDrives @('C:', 'D:')

        Collects CPU, memory, and specific disk metrics.

    .EXAMPLE
        Get-SystemMetrics | Publish-FleetMetric -Environment 'prod'

        Collects system metrics and publishes them to CloudWatch.

    .OUTPUTS
        PSCustomObject[]
        An array of metric objects with MetricName, Value, Unit, and Dimensions properties.

    .NOTES
        Windows metrics are collected via CIM/WMI.
        Linux metrics are collected via /proc filesystem.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [switch]$IncludeCPU = $true,

        [Parameter()]
        [switch]$IncludeMemory = $true,

        [Parameter()]
        [switch]$IncludeDisk = $true,

        [Parameter()]
        [switch]$IncludeNetwork = $true,

        [Parameter()]
        [string[]]$DiskDrives,

        [Parameter()]
        [string[]]$NetworkInterfaces,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$SampleInterval = 1
    )

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()
    $timestamp = (Get-Date).ToUniversalTime()
    $isWindows = $IsWindows -or ([Environment]::OSVersion.Platform -eq 'Win32NT')

    # CPU Metrics
    if ($IncludeCPU) {
        Write-Verbose 'Collecting CPU metrics...'
        $cpuMetrics = if ($isWindows) {
            Get-WindowsCPUMetrics -SampleInterval $SampleInterval
        }
        else {
            Get-LinuxCPUMetrics
        }

        foreach ($metric in $cpuMetrics) {
            $metric.Timestamp = $timestamp
            $metrics.Add($metric)
        }
    }

    # Memory Metrics
    if ($IncludeMemory) {
        Write-Verbose 'Collecting memory metrics...'
        $memoryMetrics = if ($isWindows) {
            Get-WindowsMemoryMetrics
        }
        else {
            Get-LinuxMemoryMetrics
        }

        foreach ($metric in $memoryMetrics) {
            $metric.Timestamp = $timestamp
            $metrics.Add($metric)
        }
    }

    # Disk Metrics
    if ($IncludeDisk) {
        Write-Verbose 'Collecting disk metrics...'
        $diskMetrics = if ($isWindows) {
            Get-WindowsDiskMetrics -DiskDrives $DiskDrives
        }
        else {
            Get-LinuxDiskMetrics -MountPoints $DiskDrives
        }

        foreach ($metric in $diskMetrics) {
            $metric.Timestamp = $timestamp
            $metrics.Add($metric)
        }
    }

    # Network Metrics
    if ($IncludeNetwork) {
        Write-Verbose 'Collecting network metrics...'
        $networkMetrics = if ($isWindows) {
            Get-WindowsNetworkMetrics -Interfaces $NetworkInterfaces
        }
        else {
            Get-LinuxNetworkMetrics -Interfaces $NetworkInterfaces
        }

        foreach ($metric in $networkMetrics) {
            $metric.Timestamp = $timestamp
            $metrics.Add($metric)
        }
    }

    return $metrics.ToArray()
}

#region Windows Metric Collection Functions

function Get-WindowsCPUMetrics {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [int]$SampleInterval = 1
    )

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        # Get CPU utilization using CIM
        $cpuLoad = Get-CimInstance -ClassName Win32_Processor |
            Measure-Object -Property LoadPercentage -Average |
            Select-Object -ExpandProperty Average

        $metrics.Add([PSCustomObject]@{
            MetricName = 'CPUUtilization'
            Value      = [math]::Round($cpuLoad, 2)
            Unit       = 'Percent'
            Dimensions = @{ MetricType = 'System' }
        })

        # Get per-processor metrics
        $processors = Get-CimInstance -ClassName Win32_Processor
        $processorIndex = 0
        foreach ($proc in $processors) {
            $metrics.Add([PSCustomObject]@{
                MetricName = 'CPUUtilization'
                Value      = [math]::Round($proc.LoadPercentage, 2)
                Unit       = 'Percent'
                Dimensions = @{
                    MetricType = 'System'
                    Processor  = "CPU$processorIndex"
                }
            })
            $processorIndex++
        }

        # Get processor queue length (system load indicator)
        $perfOS = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_System
        if ($perfOS) {
            $metrics.Add([PSCustomObject]@{
                MetricName = 'ProcessorQueueLength'
                Value      = $perfOS.ProcessorQueueLength
                Unit       = 'Count'
                Dimensions = @{ MetricType = 'System' }
            })
        }
    }
    catch {
        Write-Warning "Failed to collect CPU metrics: $_"
    }

    return $metrics.ToArray()
}

function Get-WindowsMemoryMetrics {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem

        $totalMemoryMB = [math]::Round($cs.TotalPhysicalMemory / 1MB, 2)
        $freeMemoryMB = [math]::Round($os.FreePhysicalMemory / 1KB, 2)
        $usedMemoryMB = $totalMemoryMB - $freeMemoryMB
        $memoryUsedPercent = [math]::Round(($usedMemoryMB / $totalMemoryMB) * 100, 2)

        $metrics.Add([PSCustomObject]@{
            MetricName = 'MemoryUsed'
            Value      = $usedMemoryMB
            Unit       = 'Megabytes'
            Dimensions = @{ MetricType = 'System' }
        })

        $metrics.Add([PSCustomObject]@{
            MetricName = 'MemoryAvailable'
            Value      = $freeMemoryMB
            Unit       = 'Megabytes'
            Dimensions = @{ MetricType = 'System' }
        })

        $metrics.Add([PSCustomObject]@{
            MetricName = 'MemoryUtilization'
            Value      = $memoryUsedPercent
            Unit       = 'Percent'
            Dimensions = @{ MetricType = 'System' }
        })

        $metrics.Add([PSCustomObject]@{
            MetricName = 'MemoryTotal'
            Value      = $totalMemoryMB
            Unit       = 'Megabytes'
            Dimensions = @{ MetricType = 'System' }
        })

        # Page file metrics
        $pageFile = Get-CimInstance -ClassName Win32_PageFileUsage | Select-Object -First 1
        if ($pageFile) {
            $pageFileUsedPercent = [math]::Round(($pageFile.CurrentUsage / $pageFile.AllocatedBaseSize) * 100, 2)
            $metrics.Add([PSCustomObject]@{
                MetricName = 'PageFileUtilization'
                Value      = $pageFileUsedPercent
                Unit       = 'Percent'
                Dimensions = @{ MetricType = 'System' }
            })
        }
    }
    catch {
        Write-Warning "Failed to collect memory metrics: $_"
    }

    return $metrics.ToArray()
}

function Get-WindowsDiskMetrics {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string[]]$DiskDrives
    )

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        $drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"

        if ($DiskDrives) {
            $drives = $drives | Where-Object { $_.DeviceID -in $DiskDrives }
        }

        foreach ($drive in $drives) {
            $totalGB = [math]::Round($drive.Size / 1GB, 2)
            $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
            $usedGB = $totalGB - $freeGB
            $usedPercent = if ($totalGB -gt 0) {
                [math]::Round(($usedGB / $totalGB) * 100, 2)
            }
            else { 0 }

            $driveLetter = $drive.DeviceID.TrimEnd(':')

            $metrics.Add([PSCustomObject]@{
                MetricName = 'DiskSpaceUsed'
                Value      = $usedGB
                Unit       = 'Gigabytes'
                Dimensions = @{
                    MetricType = 'System'
                    Drive      = $driveLetter
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'DiskSpaceAvailable'
                Value      = $freeGB
                Unit       = 'Gigabytes'
                Dimensions = @{
                    MetricType = 'System'
                    Drive      = $driveLetter
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'DiskSpaceUtilization'
                Value      = $usedPercent
                Unit       = 'Percent'
                Dimensions = @{
                    MetricType = 'System'
                    Drive      = $driveLetter
                }
            })
        }

        # Disk I/O metrics
        $diskPerf = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_PhysicalDisk |
            Where-Object { $_.Name -ne '_Total' }

        foreach ($disk in $diskPerf) {
            $diskName = $disk.Name -replace '\s+', '_'

            $metrics.Add([PSCustomObject]@{
                MetricName = 'DiskReadBytesPerSecond'
                Value      = [math]::Round($disk.DiskReadBytesPerSec / 1MB, 2)
                Unit       = 'Megabytes/Second'
                Dimensions = @{
                    MetricType = 'System'
                    Disk       = $diskName
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'DiskWriteBytesPerSecond'
                Value      = [math]::Round($disk.DiskWriteBytesPerSec / 1MB, 2)
                Unit       = 'Megabytes/Second'
                Dimensions = @{
                    MetricType = 'System'
                    Disk       = $diskName
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'DiskQueueLength'
                Value      = $disk.CurrentDiskQueueLength
                Unit       = 'Count'
                Dimensions = @{
                    MetricType = 'System'
                    Disk       = $diskName
                }
            })
        }
    }
    catch {
        Write-Warning "Failed to collect disk metrics: $_"
    }

    return $metrics.ToArray()
}

function Get-WindowsNetworkMetrics {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string[]]$Interfaces
    )

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        $netAdapters = Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_NetworkInterface |
            Where-Object { $_.BytesTotalPersec -gt 0 }

        if ($Interfaces) {
            $netAdapters = $netAdapters | Where-Object { $_.Name -in $Interfaces }
        }

        foreach ($adapter in $netAdapters) {
            $interfaceName = $adapter.Name -replace '[^\w\-]', '_'

            $metrics.Add([PSCustomObject]@{
                MetricName = 'NetworkBytesIn'
                Value      = [math]::Round($adapter.BytesReceivedPersec / 1KB, 2)
                Unit       = 'Kilobytes/Second'
                Dimensions = @{
                    MetricType = 'System'
                    Interface  = $interfaceName
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'NetworkBytesOut'
                Value      = [math]::Round($adapter.BytesSentPersec / 1KB, 2)
                Unit       = 'Kilobytes/Second'
                Dimensions = @{
                    MetricType = 'System'
                    Interface  = $interfaceName
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'NetworkPacketsIn'
                Value      = $adapter.PacketsReceivedPersec
                Unit       = 'Count/Second'
                Dimensions = @{
                    MetricType = 'System'
                    Interface  = $interfaceName
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'NetworkPacketsOut'
                Value      = $adapter.PacketsSentPersec
                Unit       = 'Count/Second'
                Dimensions = @{
                    MetricType = 'System'
                    Interface  = $interfaceName
                }
            })
        }

        # TCP connection metrics
        $tcpStats = Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_TCPv4
        if ($tcpStats) {
            $metrics.Add([PSCustomObject]@{
                MetricName = 'TCPConnectionsEstablished'
                Value      = $tcpStats.ConnectionsEstablished
                Unit       = 'Count'
                Dimensions = @{ MetricType = 'System' }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'TCPConnectionFailures'
                Value      = $tcpStats.ConnectionFailures
                Unit       = 'Count'
                Dimensions = @{ MetricType = 'System' }
            })
        }
    }
    catch {
        Write-Warning "Failed to collect network metrics: $_"
    }

    return $metrics.ToArray()
}

#endregion

#region Linux Metric Collection Functions

function Get-LinuxCPUMetrics {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        # Read /proc/stat for CPU metrics
        $statContent = Get-Content -Path '/proc/stat' -ErrorAction Stop
        $cpuLine = $statContent | Where-Object { $_ -match '^cpu\s' } | Select-Object -First 1

        if ($cpuLine) {
            $values = ($cpuLine -split '\s+')[1..10]
            $user = [long]$values[0]
            $nice = [long]$values[1]
            $system = [long]$values[2]
            $idle = [long]$values[3]
            $iowait = [long]$values[4]

            $total = $user + $nice + $system + $idle + $iowait
            $cpuUsage = if ($total -gt 0) {
                [math]::Round((($total - $idle - $iowait) / $total) * 100, 2)
            }
            else { 0 }

            $metrics.Add([PSCustomObject]@{
                MetricName = 'CPUUtilization'
                Value      = $cpuUsage
                Unit       = 'Percent'
                Dimensions = @{ MetricType = 'System' }
            })
        }

        # Load average
        $loadAvg = Get-Content -Path '/proc/loadavg' -ErrorAction Stop
        if ($loadAvg) {
            $loads = $loadAvg -split '\s+'
            $metrics.Add([PSCustomObject]@{
                MetricName = 'LoadAverage1Min'
                Value      = [double]$loads[0]
                Unit       = 'None'
                Dimensions = @{ MetricType = 'System' }
            })
            $metrics.Add([PSCustomObject]@{
                MetricName = 'LoadAverage5Min'
                Value      = [double]$loads[1]
                Unit       = 'None'
                Dimensions = @{ MetricType = 'System' }
            })
        }
    }
    catch {
        Write-Warning "Failed to collect Linux CPU metrics: $_"
    }

    return $metrics.ToArray()
}

function Get-LinuxMemoryMetrics {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        $memInfo = Get-Content -Path '/proc/meminfo' -ErrorAction Stop

        $memTotal = ($memInfo | Where-Object { $_ -match '^MemTotal:' }) -replace '[^\d]', ''
        $memFree = ($memInfo | Where-Object { $_ -match '^MemFree:' }) -replace '[^\d]', ''
        $memAvailable = ($memInfo | Where-Object { $_ -match '^MemAvailable:' }) -replace '[^\d]', ''
        $buffers = ($memInfo | Where-Object { $_ -match '^Buffers:' }) -replace '[^\d]', ''
        $cached = ($memInfo | Where-Object { $_ -match '^Cached:' }) -replace '[^\d]', ''

        $totalMB = [math]::Round([long]$memTotal / 1024, 2)
        $availableMB = [math]::Round([long]$memAvailable / 1024, 2)
        $usedMB = $totalMB - $availableMB
        $usedPercent = [math]::Round(($usedMB / $totalMB) * 100, 2)

        $metrics.Add([PSCustomObject]@{
            MetricName = 'MemoryUsed'
            Value      = $usedMB
            Unit       = 'Megabytes'
            Dimensions = @{ MetricType = 'System' }
        })

        $metrics.Add([PSCustomObject]@{
            MetricName = 'MemoryAvailable'
            Value      = $availableMB
            Unit       = 'Megabytes'
            Dimensions = @{ MetricType = 'System' }
        })

        $metrics.Add([PSCustomObject]@{
            MetricName = 'MemoryUtilization'
            Value      = $usedPercent
            Unit       = 'Percent'
            Dimensions = @{ MetricType = 'System' }
        })

        $metrics.Add([PSCustomObject]@{
            MetricName = 'MemoryTotal'
            Value      = $totalMB
            Unit       = 'Megabytes'
            Dimensions = @{ MetricType = 'System' }
        })
    }
    catch {
        Write-Warning "Failed to collect Linux memory metrics: $_"
    }

    return $metrics.ToArray()
}

function Get-LinuxDiskMetrics {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string[]]$MountPoints
    )

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        $dfOutput = & df -BM --output=target,size,used,avail,pcent 2>/dev/null |
            Select-Object -Skip 1

        foreach ($line in $dfOutput) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            $parts = $line -split '\s+' | Where-Object { $_ }
            if ($parts.Count -lt 5) { continue }

            $mountPoint = $parts[0]

            # Filter to specified mount points or common ones
            if ($MountPoints) {
                if ($mountPoint -notin $MountPoints) { continue }
            }
            elseif ($mountPoint -notmatch '^(/|/home|/var|/tmp|/opt)$') {
                continue
            }

            $totalMB = [int]($parts[1] -replace 'M', '')
            $usedMB = [int]($parts[2] -replace 'M', '')
            $availMB = [int]($parts[3] -replace 'M', '')
            $usedPercent = [int]($parts[4] -replace '%', '')

            $mountLabel = $mountPoint -replace '/', '_' -replace '^_', 'root'
            if ($mountLabel -eq '') { $mountLabel = 'root' }

            $metrics.Add([PSCustomObject]@{
                MetricName = 'DiskSpaceUsed'
                Value      = [math]::Round($usedMB / 1024, 2)
                Unit       = 'Gigabytes'
                Dimensions = @{
                    MetricType = 'System'
                    MountPoint = $mountLabel
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'DiskSpaceAvailable'
                Value      = [math]::Round($availMB / 1024, 2)
                Unit       = 'Gigabytes'
                Dimensions = @{
                    MetricType = 'System'
                    MountPoint = $mountLabel
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'DiskSpaceUtilization'
                Value      = $usedPercent
                Unit       = 'Percent'
                Dimensions = @{
                    MetricType = 'System'
                    MountPoint = $mountLabel
                }
            })
        }
    }
    catch {
        Write-Warning "Failed to collect Linux disk metrics: $_"
    }

    return $metrics.ToArray()
}

function Get-LinuxNetworkMetrics {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string[]]$Interfaces
    )

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        $netDev = Get-Content -Path '/proc/net/dev' -ErrorAction Stop | Select-Object -Skip 2

        foreach ($line in $netDev) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            $parts = $line -split '[\s:]+' | Where-Object { $_ }
            if ($parts.Count -lt 10) { continue }

            $interface = $parts[0]

            # Skip loopback
            if ($interface -eq 'lo') { continue }

            # Filter to specified interfaces
            if ($Interfaces -and $interface -notin $Interfaces) { continue }

            $rxBytes = [long]$parts[1]
            $rxPackets = [long]$parts[2]
            $txBytes = [long]$parts[9]
            $txPackets = [long]$parts[10]

            $metrics.Add([PSCustomObject]@{
                MetricName = 'NetworkBytesIn'
                Value      = [math]::Round($rxBytes / 1KB, 2)
                Unit       = 'Kilobytes'
                Dimensions = @{
                    MetricType = 'System'
                    Interface  = $interface
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'NetworkBytesOut'
                Value      = [math]::Round($txBytes / 1KB, 2)
                Unit       = 'Kilobytes'
                Dimensions = @{
                    MetricType = 'System'
                    Interface  = $interface
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'NetworkPacketsIn'
                Value      = $rxPackets
                Unit       = 'Count'
                Dimensions = @{
                    MetricType = 'System'
                    Interface  = $interface
                }
            })

            $metrics.Add([PSCustomObject]@{
                MetricName = 'NetworkPacketsOut'
                Value      = $txPackets
                Unit       = 'Count'
                Dimensions = @{
                    MetricType = 'System'
                    Interface  = $interface
                }
            })
        }
    }
    catch {
        Write-Warning "Failed to collect Linux network metrics: $_"
    }

    return $metrics.ToArray()
}

#endregion
