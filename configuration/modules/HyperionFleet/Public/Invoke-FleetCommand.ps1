function Invoke-FleetCommand {
    <#
    .SYNOPSIS
        Executes SSM Run Command across fleet instances.

    .DESCRIPTION
        Sends AWS Systems Manager Run Command to one or more EC2 instances with support
        for command tracking, output retrieval, and error handling. Supports both
        predefined SSM documents and custom shell/PowerShell scripts.

    .PARAMETER InstanceId
        One or more EC2 instance IDs to target. Cannot be used with -Tag.

    .PARAMETER Tag
        Filter target instances by tag key-value pairs. Cannot be used with -InstanceId.

    .PARAMETER DocumentName
        SSM document name to execute. Default: AWS-RunShellScript (Linux) or AWS-RunPowerShellScript (Windows).

    .PARAMETER Command
        Command(s) to execute on target instances. Required for shell/PowerShell documents.

    .PARAMETER Parameter
        Hashtable of parameters to pass to the SSM document.

    .PARAMETER Comment
        Comment/description for the command execution.

    .PARAMETER TimeoutSeconds
        Command timeout in seconds. Default: 3600 (1 hour).

    .PARAMETER MaxConcurrency
        Maximum number of instances to execute on concurrently. Default: 50.

    .PARAMETER MaxErrors
        Maximum number of errors before stopping execution. Default: 0 (no limit).

    .PARAMETER Region
        AWS region to execute command in. Defaults to module configuration.

    .PARAMETER ProfileName
        AWS credential profile to use.

    .PARAMETER Wait
        Wait for command completion and return output.

    .PARAMETER WhatIf
        Shows what would happen if the command runs without actually executing.

    .PARAMETER Confirm
        Prompts for confirmation before executing the command.

    .EXAMPLE
        Invoke-FleetCommand -InstanceId 'i-1234567890' -Command 'uptime'
        Executes uptime command on a single instance.

    .EXAMPLE
        Invoke-FleetCommand -Tag @{Environment='Production'} -Command 'sudo yum update -y' -Wait
        Updates all production instances and waits for completion.

    .EXAMPLE
        Invoke-FleetCommand -InstanceId 'i-1234567890' -DocumentName 'AWS-ConfigureAWSPackage' -Parameter @{action='Install'; name='AmazonCloudWatchAgent'}
        Installs CloudWatch agent using SSM document.

    .EXAMPLE
        $commands = @('df -h', 'free -m', 'uptime')
        Invoke-FleetCommand -Tag @{Role='WebServer'} -Command $commands -Comment 'Health check commands'
        Executes multiple commands on web servers.

    .OUTPUTS
        PSCustomObject with CommandId, Status, and output details.

    .NOTES
        Requires AWS.Tools.SimpleSystemsManagement module.
        Target instances must have SSM agent installed and running.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidatePattern('^i-[a-f0-9]{8,17}$')]
        [string[]]$InstanceId,

        [Parameter(ParameterSetName = 'ByTag', Mandatory)]
        [ValidateNotNull()]
        [hashtable]$Tag,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DocumentName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Command,

        [Parameter()]
        [ValidateNotNull()]
        [hashtable]$Parameter = @{},

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Comment = "Executed via HyperionFleet module",

        [Parameter()]
        [ValidateRange(1, 28800)]
        [int]$TimeoutSeconds = 3600,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$MaxConcurrency = 50,

        [Parameter()]
        [ValidateRange(0, 1000)]
        [int]$MaxErrors = 0,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Region = $script:ModuleConfig.DefaultRegion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [Parameter()]
        [switch]$Wait
    )

    begin {
        Write-FleetLog -Message "Preparing fleet command execution" -Level 'Information'

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

        $commandResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        try {
            # Determine target instances
            $targetInstances = @()

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $targetInstances = $InstanceId
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByTag') {
                # Query instances by tag
                Write-FleetLog -Message "Resolving target instances by tags" -Level 'Verbose'

                $ec2Filters = [System.Collections.Generic.List[Amazon.EC2.Model.Filter]]::new()
                $stateFilter = [Amazon.EC2.Model.Filter]@{
                    Name = 'instance-state-name'
                    Values = @('running')
                }
                $ec2Filters.Add($stateFilter)

                foreach ($tagKey in $Tag.Keys) {
                    $tagFilter = [Amazon.EC2.Model.Filter]@{
                        Name = "tag:$tagKey"
                        Values = @($Tag[$tagKey])
                    }
                    $ec2Filters.Add($tagFilter)
                }

                $ec2Params = @{
                    Filter = $ec2Filters
                    Region = $Region
                }
                if ($ProfileName) {
                    $ec2Params['ProfileName'] = $ProfileName
                }

                $instances = (Get-EC2Instance @ec2Params).Instances
                if (-not $instances -or $instances.Count -eq 0) {
                    Write-FleetLog -Message "No running instances found matching tags" -Level 'Warning'
                    return
                }

                $targetInstances = $instances.InstanceId
                Write-FleetLog -Message "Resolved $($targetInstances.Count) target instances" -Level 'Information'
            }

            # Validate target instances have SSM agent
            $ssmParams = @{
                Region = $Region
            }
            if ($ProfileName) {
                $ssmParams['ProfileName'] = $ProfileName
            }

            $ssmInstances = Get-SSMInstanceInformation @ssmParams | Where-Object {
                $targetInstances -contains $_.InstanceId -and $_.PingStatus -eq 'Online'
            }

            if (-not $ssmInstances -or $ssmInstances.Count -eq 0) {
                Write-FleetLog -Message "No target instances have SSM agent online" -Level 'Error'
                throw "No valid SSM-managed instances found in target set"
            }

            $validTargets = @($ssmInstances.InstanceId)
            Write-FleetLog -Message "Validated $($validTargets.Count) instances with online SSM agent" -Level 'Information'

            # Determine document name and parameters
            if (-not $DocumentName) {
                # Auto-detect based on platform (assume Linux/shell by default)
                $DocumentName = 'AWS-RunShellScript'
                Write-FleetLog -Message "Auto-selected document: $DocumentName" -Level 'Verbose'
            }

            # Build parameters
            $documentParameters = $Parameter.Clone()

            if ($Command -and -not $documentParameters.ContainsKey('commands')) {
                $documentParameters['commands'] = $Command
            }

            # Build WhatIf/Confirm message
            $targetSummary = if ($validTargets.Count -le 5) {
                $validTargets -join ', '
            }
            else {
                "$($validTargets.Count) instances"
            }

            $actionMessage = "Execute SSM command on $targetSummary"
            $actionDetail = @"
Document: $DocumentName
Targets: $($validTargets.Count) instances
Command: $($Command -join '; ')
Region: $Region
"@

            if ($PSCmdlet.ShouldProcess($actionMessage, $actionDetail, 'Invoke-FleetCommand')) {
                Write-FleetLog -Message "Executing SSM command on $($validTargets.Count) instances" -Level 'Information' -Context @{
                    DocumentName = $DocumentName
                    TargetCount = $validTargets.Count
                }

                # Build Send-SSMCommand parameters
                $ssmCommandParams = @{
                    DocumentName = $DocumentName
                    InstanceId = $validTargets
                    Parameter = $documentParameters
                    Comment = $Comment
                    TimeoutSecond = $TimeoutSeconds
                    MaxConcurrency = [string]$MaxConcurrency
                    Region = $Region
                }

                if ($MaxErrors -gt 0) {
                    $ssmCommandParams['MaxError'] = [string]$MaxErrors
                }

                if ($ProfileName) {
                    $ssmCommandParams['ProfileName'] = $ProfileName
                }

                # Execute command
                try {
                    $ssmCommand = Send-SSMCommand @ssmCommandParams

                    Write-FleetLog -Message "SSM command sent successfully: $($ssmCommand.CommandId)" -Level 'Information' -Context @{
                        CommandId = $ssmCommand.CommandId
                        Status = $ssmCommand.Status.Value
                    }

                    $result = [PSCustomObject]@{
                        PSTypeName = 'HyperionFleet.CommandResult'
                        CommandId = $ssmCommand.CommandId
                        DocumentName = $ssmCommand.DocumentName
                        Status = $ssmCommand.Status.Value
                        RequestedDateTime = $ssmCommand.RequestedDateTime
                        TargetCount = $ssmCommand.TargetCount
                        CompletedCount = $ssmCommand.CompletedCount
                        ErrorCount = $ssmCommand.ErrorCount
                        Comment = $ssmCommand.Comment
                        Outputs = $null
                        Timestamp = Get-Date
                    }

                    # Wait for completion if requested
                    if ($Wait) {
                        Write-FleetLog -Message "Waiting for command completion..." -Level 'Information'

                        $waitParams = @{
                            CommandId = $ssmCommand.CommandId
                            Region = $Region
                        }
                        if ($ProfileName) {
                            $waitParams['ProfileName'] = $ProfileName
                        }

                        $timeout = [datetime]::Now.AddSeconds($TimeoutSeconds + 60)
                        do {
                            Start-Sleep -Seconds 5

                            $commandStatus = Get-SSMCommand @waitParams

                            $result.Status = $commandStatus.Status.Value
                            $result.CompletedCount = $commandStatus.CompletedCount
                            $result.ErrorCount = $commandStatus.ErrorCount

                            Write-Progress -Activity "Waiting for SSM command" -Status "$($commandStatus.Status) - Completed: $($commandStatus.CompletedCount)/$($commandStatus.TargetCount)"

                            if ([datetime]::Now -gt $timeout) {
                                Write-FleetLog -Message "Wait timeout exceeded" -Level 'Warning'
                                break
                            }
                        } while ($commandStatus.Status.Value -in @('Pending', 'InProgress'))

                        Write-Progress -Activity "Waiting for SSM command" -Completed

                        # Retrieve command outputs
                        Write-FleetLog -Message "Retrieving command outputs" -Level 'Verbose'

                        $outputs = @{}
                        foreach ($instanceId in $validTargets) {
                            try {
                                $invocationParams = @{
                                    CommandId = $ssmCommand.CommandId
                                    InstanceId = $instanceId
                                    Region = $Region
                                }
                                if ($ProfileName) {
                                    $invocationParams['ProfileName'] = $ProfileName
                                }

                                $invocation = Get-SSMCommandInvocation @invocationParams

                                $outputs[$instanceId] = @{
                                    Status = $invocation.Status.Value
                                    StatusDetails = $invocation.StatusDetails
                                    StandardOutputContent = $invocation.StandardOutputContent
                                    StandardErrorContent = $invocation.StandardErrorContent
                                    ResponseCode = $invocation.ResponseCode
                                }
                            }
                            catch {
                                Write-FleetLog -Message "Failed to retrieve output for $instanceId : $_" -Level 'Warning'
                                $outputs[$instanceId] = @{
                                    Status = 'Failed'
                                    Error = $_.Exception.Message
                                }
                            }
                        }

                        $result.Outputs = $outputs

                        Write-FleetLog -Message "Command completed: $($result.Status)" -Level 'Information' -Context @{
                            CommandId = $result.CommandId
                            Status = $result.Status
                            CompletedCount = $result.CompletedCount
                            ErrorCount = $result.ErrorCount
                        }
                    }

                    $commandResults.Add($result)
                }
                catch {
                    Write-FleetLog -Message "Failed to execute SSM command: $_" -Level 'Error'
                    throw
                }
            }
            else {
                Write-FleetLog -Message "Command execution cancelled by user" -Level 'Information'
            }
        }
        catch {
            Write-FleetLog -Message "Fleet command execution failed: $_" -Level 'Error'
            throw
        }
    }

    end {
        if ($commandResults.Count -gt 0) {
            Write-FleetLog -Message "Fleet command execution completed. Executed $($commandResults.Count) command(s)" -Level 'Information'
            return $commandResults.ToArray()
        }
    }
}
