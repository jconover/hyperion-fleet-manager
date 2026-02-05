function Get-FleetInventory {
    <#
    .SYNOPSIS
        Lists all EC2 instances with comprehensive tag and configuration information.

    .DESCRIPTION
        Retrieves a complete inventory of EC2 instances across specified regions with
        detailed tag information, network configuration, and instance metadata. Supports
        filtering, grouping, and export capabilities.

    .PARAMETER Region
        AWS region(s) to query. Defaults to module configuration. Accepts multiple regions.

    .PARAMETER ProfileName
        AWS credential profile to use.

    .PARAMETER Tag
        Filter instances by tag key-value pairs. Format: @{Environment='Production'}

    .PARAMETER State
        Filter by instance state (running, stopped, terminated, etc). Default: all non-terminated.

    .PARAMETER InstanceType
        Filter by instance type pattern (e.g., 't3.*', 'm5.large').

    .PARAMETER GroupBy
        Group results by tag key (e.g., 'Environment', 'Application').

    .PARAMETER IncludeTerminated
        Include terminated instances in results. Default: false.

    .PARAMETER ExportPath
        Export inventory to CSV file at specified path.

    .EXAMPLE
        Get-FleetInventory
        Retrieves inventory of all running instances.

    .EXAMPLE
        Get-FleetInventory -Tag @{Environment='Production'} -State 'running'
        Lists all running production instances.

    .EXAMPLE
        Get-FleetInventory -Region 'us-east-1','us-west-2' -GroupBy 'Environment'
        Gets inventory from multiple regions grouped by environment.

    .EXAMPLE
        Get-FleetInventory -ExportPath '/tmp/fleet-inventory.csv'
        Exports complete inventory to CSV file.

    .OUTPUTS
        PSCustomObject[] with instance inventory data.

    .NOTES
        Requires AWS.Tools.EC2 module.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Region = @($script:ModuleConfig.DefaultRegion),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [Parameter()]
        [ValidateNotNull()]
        [hashtable]$Tag,

        [Parameter()]
        [ValidateSet('pending', 'running', 'shutting-down', 'terminated', 'stopping', 'stopped')]
        [string[]]$State,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$InstanceType,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$GroupBy,

        [Parameter()]
        [switch]$IncludeTerminated,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ExportPath
    )

    begin {
        Write-FleetLog -Message "Starting fleet inventory" -Level 'Information' -Context @{
            Regions = ($Region -join ', ')
        }

        $inventoryResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        try {
            # Process each region
            foreach ($currentRegion in $Region) {
                Write-FleetLog -Message "Querying instances in region: $currentRegion" -Level 'Verbose'

                # Build EC2 filters
                $ec2Filters = [System.Collections.Generic.List[Amazon.EC2.Model.Filter]]::new()

                # Filter by state (exclude terminated by default)
                if ($State) {
                    $stateFilter = [Amazon.EC2.Model.Filter]@{
                        Name = 'instance-state-name'
                        Values = $State
                    }
                    $ec2Filters.Add($stateFilter)
                }
                elseif (-not $IncludeTerminated) {
                    $stateFilter = [Amazon.EC2.Model.Filter]@{
                        Name = 'instance-state-name'
                        Values = @('pending', 'running', 'shutting-down', 'stopping', 'stopped')
                    }
                    $ec2Filters.Add($stateFilter)
                }

                # Filter by instance type
                if ($InstanceType) {
                    $typeFilter = [Amazon.EC2.Model.Filter]@{
                        Name = 'instance-type'
                        Values = @($InstanceType)
                    }
                    $ec2Filters.Add($typeFilter)
                }

                # Filter by tags
                if ($Tag) {
                    foreach ($tagKey in $Tag.Keys) {
                        $tagFilter = [Amazon.EC2.Model.Filter]@{
                            Name = "tag:$tagKey"
                            Values = @($Tag[$tagKey])
                        }
                        $ec2Filters.Add($tagFilter)
                    }
                }

                # Query EC2 instances
                $ec2Params = @{
                    Region = $currentRegion
                }
                if ($ProfileName) {
                    $ec2Params['ProfileName'] = $ProfileName
                }
                if ($ec2Filters.Count -gt 0) {
                    $ec2Params['Filter'] = $ec2Filters
                }

                $reservations = Get-EC2Instance @ec2Params

                if (-not $reservations) {
                    Write-FleetLog -Message "No instances found in region: $currentRegion" -Level 'Verbose'
                    continue
                }

                $instances = $reservations.Instances
                Write-FleetLog -Message "Found $($instances.Count) instances in $currentRegion" -Level 'Information'

                # Process each instance
                foreach ($instance in $instances) {
                    # Convert tags to hashtable for easier access
                    $tagHash = @{}
                    foreach ($tag in $instance.Tags) {
                        $tagHash[$tag.Key] = $tag.Value
                    }

                    # Build inventory record
                    $inventoryItem = [PSCustomObject]@{
                        PSTypeName = 'HyperionFleet.InventoryItem'
                        InstanceId = $instance.InstanceId
                        Name = $tagHash['Name']
                        State = $instance.State.Name.Value
                        InstanceType = $instance.InstanceType.Value
                        Platform = $instance.Platform.Value ?? 'Linux'
                        Architecture = $instance.Architecture.Value
                        VirtualizationType = $instance.VirtualizationType.Value
                        Region = $currentRegion
                        AvailabilityZone = $instance.Placement.AvailabilityZone
                        VpcId = $instance.VpcId
                        SubnetId = $instance.SubnetId
                        PrivateIpAddress = $instance.PrivateIpAddress
                        PublicIpAddress = $instance.PublicIpAddress
                        PrivateDnsName = $instance.PrivateDnsName
                        PublicDnsName = $instance.PublicDnsName
                        SecurityGroups = ($instance.SecurityGroups | ForEach-Object { "$($_.GroupName) ($($_.GroupId))" }) -join '; '
                        KeyName = $instance.KeyName
                        IamInstanceProfile = $instance.IamInstanceProfile.Arn
                        LaunchTime = $instance.LaunchTime
                        ImageId = $instance.ImageId
                        RootDeviceType = $instance.RootDeviceType.Value
                        RootDeviceName = $instance.RootDeviceName
                        Monitoring = $instance.Monitoring.State.Value
                        Tenancy = $instance.Placement.Tenancy.Value
                        EbsOptimized = $instance.EbsOptimized
                        Tags = $tagHash
                        Environment = $tagHash['Environment']
                        Application = $tagHash['Application']
                        Owner = $tagHash['Owner']
                        CostCenter = $tagHash['CostCenter']
                        Timestamp = Get-Date
                    }

                    # Add GroupBy field if specified
                    if ($GroupBy -and $tagHash.ContainsKey($GroupBy)) {
                        $inventoryItem | Add-Member -NotePropertyName 'GroupByValue' -NotePropertyValue $tagHash[$GroupBy]
                    }

                    $inventoryResults.Add($inventoryItem)
                }
            }
        }
        catch {
            Write-FleetLog -Message "Fleet inventory failed: $_" -Level 'Error'
            throw
        }
    }

    end {
        $totalCount = $inventoryResults.Count
        Write-FleetLog -Message "Fleet inventory completed. Total instances: $totalCount" -Level 'Information'

        # Group results if requested
        if ($GroupBy -and $inventoryResults.Count -gt 0) {
            Write-FleetLog -Message "Grouping results by: $GroupBy" -Level 'Verbose'

            $grouped = $inventoryResults | Group-Object -Property GroupByValue
            foreach ($group in $grouped) {
                Write-FleetLog -Message "$GroupBy '$($group.Name)': $($group.Count) instances" -Level 'Information'
            }
        }

        # Export to CSV if requested
        if ($ExportPath) {
            try {
                # Flatten tags for CSV export
                $exportData = $inventoryResults | Select-Object -Property * -ExcludeProperty Tags, PSTypeName

                # Add common tag columns
                foreach ($item in $exportData) {
                    $originalItem = $inventoryResults | Where-Object { $_.InstanceId -eq $item.InstanceId } | Select-Object -First 1
                    foreach ($tagKey in @('Name', 'Environment', 'Application', 'Owner', 'CostCenter')) {
                        if (-not (Get-Member -InputObject $item -Name "Tag_$tagKey" -MemberType NoteProperty)) {
                            $item | Add-Member -NotePropertyName "Tag_$tagKey" -NotePropertyValue $originalItem.Tags[$tagKey]
                        }
                    }
                }

                $exportData | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                Write-FleetLog -Message "Inventory exported to: $ExportPath" -Level 'Information'
            }
            catch {
                Write-FleetLog -Message "Failed to export inventory: $_" -Level 'Error'
                throw
            }
        }

        return $inventoryResults.ToArray()
    }
}
