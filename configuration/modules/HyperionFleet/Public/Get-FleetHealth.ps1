function Get-FleetHealth {
    <#
    .SYNOPSIS
        Retrieves health metrics for EC2 fleet instances.

    .DESCRIPTION
        Queries EC2 instances and their associated CloudWatch metrics, SSM agent status,
        and system information to provide comprehensive health reporting. Supports filtering
        by tags, instance IDs, and state.

    .PARAMETER InstanceId
        One or more EC2 instance IDs to check. If not specified, checks all managed instances.

    .PARAMETER Tag
        Filter instances by tag key-value pairs. Format: @{Environment='Production'; Role='WebServer'}

    .PARAMETER Region
        AWS region to query. Defaults to module configuration.

    .PARAMETER ProfileName
        AWS credential profile to use.

    .PARAMETER IncludeMetrics
        Include CloudWatch metrics (CPU, Memory, Disk, Network) in the health report.

    .PARAMETER MetricPeriod
        Time period for CloudWatch metrics in minutes. Default: 60 minutes.

    .PARAMETER IncludePatches
        Include patch compliance status from SSM.

    .EXAMPLE
        Get-FleetHealth
        Retrieves health status for all fleet instances.

    .EXAMPLE
        Get-FleetHealth -InstanceId 'i-1234567890abcdef0', 'i-0987654321fedcba0'
        Retrieves health for specific instances.

    .EXAMPLE
        Get-FleetHealth -Tag @{Environment='Production'} -IncludeMetrics
        Retrieves health with CloudWatch metrics for production instances.

    .EXAMPLE
        Get-FleetHealth -IncludeMetrics -IncludePatches | Where-Object {$_.Status -ne 'Healthy'}
        Retrieves comprehensive health data and filters for unhealthy instances.

    .OUTPUTS
        PSCustomObject[] with health metrics for each instance.

    .NOTES
        Requires AWS.Tools.EC2 and AWS.Tools.SimpleSystemsManagement modules.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ParameterSetName = 'ById', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidatePattern('^i-[a-f0-9]{8,17}$')]
        [string[]]$InstanceId,

        [Parameter(ParameterSetName = 'ByTag')]
        [ValidateNotNull()]
        [hashtable]$Tag,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Region = $script:ModuleConfig.DefaultRegion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [Parameter()]
        [switch]$IncludeMetrics,

        [Parameter()]
        [ValidateRange(5, 1440)]
        [int]$MetricPeriod = 60,

        [Parameter()]
        [switch]$IncludePatches
    )

    begin {
        Write-FleetLog -Message "Starting fleet health check" -Level 'Information'

        # Initialize AWS session
        $sessionParams = @{
            Region = $Region
        }
        if ($ProfileName) {
            $sessionParams['ProfileName'] = $ProfileName
        }

        try {
            $session = Get-AWSSession @sessionParams
        }
        catch {
            Write-FleetLog -Message "Failed to initialize AWS session: $_" -Level 'Error'
            throw
        }

        $healthResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        try {
            # Build EC2 filter based on parameters
            $ec2Filters = [System.Collections.Generic.List[Amazon.EC2.Model.Filter]]::new()

            # Add instance ID filter if specified
            if ($PSCmdlet.ParameterSetName -eq 'ById' -and $InstanceId) {
                $filter = [Amazon.EC2.Model.Filter]@{
                    Name = 'instance-id'
                    Values = $InstanceId
                }
                $ec2Filters.Add($filter)
            }

            # Add tag filters if specified
            if ($PSCmdlet.ParameterSetName -eq 'ByTag' -and $Tag) {
                foreach ($tagKey in $Tag.Keys) {
                    $filter = [Amazon.EC2.Model.Filter]@{
                        Name = "tag:$tagKey"
                        Values = @($Tag[$tagKey])
                    }
                    $ec2Filters.Add($filter)
                }
            }

            # Query EC2 instances
            $ec2Params = @{
                Region = $Region
            }
            if ($ProfileName) {
                $ec2Params['ProfileName'] = $ProfileName
            }
            if ($ec2Filters.Count -gt 0) {
                $ec2Params['Filter'] = $ec2Filters
            }

            Write-FleetLog -Message "Querying EC2 instances in region $Region" -Level 'Verbose'
            $instances = (Get-EC2Instance @ec2Params).Instances

            if (-not $instances -or $instances.Count -eq 0) {
                Write-FleetLog -Message "No instances found matching criteria" -Level 'Warning'
                return
            }

            Write-FleetLog -Message "Found $($instances.Count) instances" -Level 'Information'

            # Get SSM managed instance information
            $ssmParams = @{
                Region = $Region
            }
            if ($ProfileName) {
                $ssmParams['ProfileName'] = $ProfileName
            }

            try {
                $ssmInstances = Get-SSMInstanceInformation @ssmParams
                $ssmLookup = @{}
                foreach ($ssmInstance in $ssmInstances) {
                    $ssmLookup[$ssmInstance.InstanceId] = $ssmInstance
                }
            }
            catch {
                Write-FleetLog -Message "Failed to retrieve SSM instance information: $_" -Level 'Warning'
                $ssmLookup = @{}
            }

            # Process each instance
            foreach ($instance in $instances) {
                $healthData = [PSCustomObject]@{
                    PSTypeName = 'HyperionFleet.InstanceHealth'
                    InstanceId = $instance.InstanceId
                    InstanceName = ($instance.Tags | Where-Object {$_.Key -eq 'Name'}).Value
                    InstanceType = $instance.InstanceType.Value
                    State = $instance.State.Name.Value
                    AvailabilityZone = $instance.Placement.AvailabilityZone
                    LaunchTime = $instance.LaunchTime
                    PrivateIpAddress = $instance.PrivateIpAddress
                    PublicIpAddress = $instance.PublicIpAddress
                    VpcId = $instance.VpcId
                    SubnetId = $instance.SubnetId
                    Status = 'Unknown'
                    SSMAgentStatus = 'Unknown'
                    SSMPingStatus = 'Unknown'
                    SSMLastPingTime = $null
                    StatusChecks = $null
                    Metrics = $null
                    PatchCompliance = $null
                    Tags = $instance.Tags
                    Timestamp = Get-Date
                }

                # Check instance state
                if ($instance.State.Name.Value -ne 'running') {
                    $healthData.Status = 'Stopped'
                }
                else {
                    $healthData.Status = 'Running'
                }

                # Check SSM agent status
                if ($ssmLookup.ContainsKey($instance.InstanceId)) {
                    $ssmInfo = $ssmLookup[$instance.InstanceId]
                    $healthData.SSMAgentStatus = $ssmInfo.PingStatus.Value
                    $healthData.SSMPingStatus = $ssmInfo.PingStatus.Value
                    $healthData.SSMLastPingTime = $ssmInfo.LastPingDateTime

                    # Determine overall health based on SSM ping status
                    if ($ssmInfo.PingStatus.Value -eq 'Online') {
                        $healthData.Status = 'Healthy'
                    }
                    elseif ($ssmInfo.PingStatus.Value -eq 'ConnectionLost') {
                        $healthData.Status = 'Degraded'
                    }
                    else {
                        $healthData.Status = 'Unhealthy'
                    }
                }

                # Get instance status checks
                if ($instance.State.Name.Value -eq 'running') {
                    try {
                        $statusParams = @{
                            InstanceId = $instance.InstanceId
                            Region = $Region
                        }
                        if ($ProfileName) {
                            $statusParams['ProfileName'] = $ProfileName
                        }

                        $statusCheck = Get-EC2InstanceStatus @statusParams
                        if ($statusCheck) {
                            $healthData.StatusChecks = @{
                                SystemStatus = $statusCheck.SystemStatus.Status.Value
                                InstanceStatus = $statusCheck.InstanceStatus.Status.Value
                            }

                            # Update health status based on status checks
                            if ($statusCheck.SystemStatus.Status.Value -ne 'ok' -or $statusCheck.InstanceStatus.Status.Value -ne 'ok') {
                                $healthData.Status = 'Unhealthy'
                            }
                        }
                    }
                    catch {
                        Write-FleetLog -Message "Failed to retrieve status checks for $($instance.InstanceId): $_" -Level 'Warning'
                    }
                }

                # Include CloudWatch metrics if requested
                if ($IncludeMetrics -and $instance.State.Name.Value -eq 'running') {
                    $healthData.Metrics = Get-InstanceMetrics -InstanceId $instance.InstanceId -Region $Region -ProfileName $ProfileName -Period $MetricPeriod
                }

                # Include patch compliance if requested
                if ($IncludePatches -and $ssmLookup.ContainsKey($instance.InstanceId)) {
                    try {
                        $patchParams = @{
                            InstanceId = $instance.InstanceId
                            Region = $Region
                        }
                        if ($ProfileName) {
                            $patchParams['ProfileName'] = $ProfileName
                        }

                        $patchCompliance = Get-SSMInstancePatchState @patchParams
                        if ($patchCompliance) {
                            $healthData.PatchCompliance = @{
                                OperationStartTime = $patchCompliance.OperationStartTime
                                OperationEndTime = $patchCompliance.OperationEndTime
                                InstalledCount = $patchCompliance.InstalledCount
                                InstalledOtherCount = $patchCompliance.InstalledOtherCount
                                MissingCount = $patchCompliance.MissingCount
                                FailedCount = $patchCompliance.FailedCount
                                ComplianceLevel = $patchCompliance.ComplianceLevel.Value
                            }

                            # Update health if patches are missing or failed
                            if ($patchCompliance.MissingCount -gt 0 -or $patchCompliance.FailedCount -gt 0) {
                                $healthData.Status = 'Degraded'
                            }
                        }
                    }
                    catch {
                        Write-FleetLog -Message "Failed to retrieve patch compliance for $($instance.InstanceId): $_" -Level 'Warning'
                    }
                }

                $healthResults.Add($healthData)

                Write-FleetLog -Message "Health check completed for $($instance.InstanceId): $($healthData.Status)" -Level 'Verbose' -Context @{
                    InstanceId = $instance.InstanceId
                    Status = $healthData.Status
                }
            }
        }
        catch {
            Write-FleetLog -Message "Fleet health check failed: $_" -Level 'Error'
            throw
        }
    }

    end {
        Write-FleetLog -Message "Fleet health check completed. Checked $($healthResults.Count) instances" -Level 'Information'
        return $healthResults.ToArray()
    }
}

# Helper function for CloudWatch metrics (internal to this file)
function Get-InstanceMetrics {
    [CmdletBinding()]
    param(
        [string]$InstanceId,
        [string]$Region,
        [string]$ProfileName,
        [int]$Period
    )

    $endTime = Get-Date
    $startTime = $endTime.AddMinutes(-$Period)

    $metrics = @{
        CPUUtilization = $null
        NetworkIn = $null
        NetworkOut = $null
        StatusCheckFailed = $null
    }

    $metricParams = @{
        Namespace = 'AWS/EC2'
        Dimension = @([Amazon.CloudWatch.Model.Dimension]@{Name='InstanceId'; Value=$InstanceId})
        StartUtc = $startTime.ToUniversalTime()
        EndUtc = $endTime.ToUniversalTime()
        Period = 300  # 5-minute periods
        Statistic = 'Average'
        Region = $Region
    }

    if ($ProfileName) {
        $metricParams['ProfileName'] = $ProfileName
    }

    foreach ($metricName in $metrics.Keys) {
        try {
            $metricParams['MetricName'] = $metricName
            $data = Get-CWMetricStatistic @metricParams
            if ($data.Datapoints.Count -gt 0) {
                $metrics[$metricName] = ($data.Datapoints | Measure-Object -Property Average -Average).Average
            }
        }
        catch {
            Write-Verbose "Failed to retrieve $metricName for $InstanceId"
        }
    }

    return $metrics
}
