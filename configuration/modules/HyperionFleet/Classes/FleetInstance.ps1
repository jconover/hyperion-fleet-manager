#Requires -Version 7.4

<#
.SYNOPSIS
    PowerShell class definitions for HyperionFleet module.

.DESCRIPTION
    Defines strongly-typed classes for fleet management operations including
    instance representations, health status, and command results.
#>

# FleetInstance class - Represents an EC2 instance with fleet metadata
class FleetInstance {
    [string]$InstanceId
    [string]$Name
    [string]$InstanceType
    [string]$State
    [string]$Region
    [string]$AvailabilityZone
    [string]$PrivateIpAddress
    [string]$PublicIpAddress
    [hashtable]$Tags
    [datetime]$LaunchTime
    [string]$Platform

    # Constructor with instance ID
    FleetInstance([string]$instanceId) {
        $this.InstanceId = $instanceId
        $this.Tags = @{}
    }

    # Constructor with full details
    FleetInstance(
        [string]$instanceId,
        [string]$name,
        [string]$instanceType,
        [string]$state
    ) {
        $this.InstanceId = $instanceId
        $this.Name = $name
        $this.InstanceType = $instanceType
        $this.State = $state
        $this.Tags = @{}
    }

    # Method to check if instance is running
    [bool] IsRunning() {
        return $this.State -eq 'running'
    }

    # Method to get tag value
    [string] GetTag([string]$key) {
        if ($this.Tags.ContainsKey($key)) {
            return $this.Tags[$key]
        }
        return $null
    }

    # Method to set tag
    [void] SetTag([string]$key, [string]$value) {
        $this.Tags[$key] = $value
    }

    # Method to get instance age
    [timespan] GetAge() {
        if ($this.LaunchTime) {
            return (Get-Date) - $this.LaunchTime
        }
        return [timespan]::Zero
    }

    # String representation
    [string] ToString() {
        return "$($this.InstanceId) ($($this.Name)) - $($this.State)"
    }
}

# HealthStatus class - Represents instance health metrics
class HealthStatus {
    [string]$InstanceId
    [ValidateSet('Healthy', 'Degraded', 'Unhealthy', 'Stopped', 'Unknown')]
    [string]$Status
    [string]$SSMAgentStatus
    [datetime]$LastCheckTime
    [hashtable]$Metrics
    [hashtable]$StatusChecks
    [string[]]$Issues

    # Constructor
    HealthStatus([string]$instanceId) {
        $this.InstanceId = $instanceId
        $this.Status = 'Unknown'
        $this.LastCheckTime = Get-Date
        $this.Metrics = @{}
        $this.StatusChecks = @{}
        $this.Issues = @()
    }

    # Method to add issue
    [void] AddIssue([string]$issue) {
        $this.Issues += $issue
    }

    # Method to check if healthy
    [bool] IsHealthy() {
        return $this.Status -eq 'Healthy'
    }

    # Method to get issue count
    [int] GetIssueCount() {
        return $this.Issues.Count
    }

    # String representation
    [string] ToString() {
        return "$($this.InstanceId): $($this.Status) ($($this.Issues.Count) issues)"
    }
}

# CommandResult class - Represents SSM command execution result
class CommandResult {
    [string]$CommandId
    [string]$DocumentName
    [ValidateSet('Pending', 'InProgress', 'Success', 'Failed', 'Cancelled', 'TimedOut')]
    [string]$Status
    [datetime]$RequestedDateTime
    [datetime]$CompletedDateTime
    [int]$TargetCount
    [int]$CompletedCount
    [int]$ErrorCount
    [hashtable]$Outputs

    # Constructor
    CommandResult([string]$commandId, [string]$documentName) {
        $this.CommandId = $commandId
        $this.DocumentName = $documentName
        $this.Status = 'Pending'
        $this.RequestedDateTime = Get-Date
        $this.Outputs = @{}
    }

    # Method to check if complete
    [bool] IsComplete() {
        return $this.Status -in @('Success', 'Failed', 'Cancelled', 'TimedOut')
    }

    # Method to check if successful
    [bool] IsSuccessful() {
        return $this.Status -eq 'Success' -and $this.ErrorCount -eq 0
    }

    # Method to get execution duration
    [timespan] GetDuration() {
        if ($this.CompletedDateTime) {
            return $this.CompletedDateTime - $this.RequestedDateTime
        }
        return (Get-Date) - $this.RequestedDateTime
    }

    # Method to get success rate
    [double] GetSuccessRate() {
        if ($this.TargetCount -eq 0) {
            return 0.0
        }
        return [math]::Round(($this.CompletedCount - $this.ErrorCount) / $this.TargetCount * 100, 2)
    }

    # String representation
    [string] ToString() {
        return "$($this.CommandId): $($this.Status) ($($this.CompletedCount)/$($this.TargetCount) completed)"
    }
}

# PatchCompliance class - Represents patch compliance status
class PatchCompliance {
    [string]$InstanceId
    [datetime]$AssessmentTime
    [int]$InstalledCount
    [int]$InstalledOtherCount
    [int]$MissingCount
    [int]$FailedCount
    [int]$NotApplicableCount
    [ValidateSet('Compliant', 'NonCompliant', 'Unspecified')]
    [string]$ComplianceLevel

    # Constructor
    PatchCompliance([string]$instanceId) {
        $this.InstanceId = $instanceId
        $this.AssessmentTime = Get-Date
        $this.ComplianceLevel = 'Unspecified'
    }

    # Method to check if compliant
    [bool] IsCompliant() {
        return $this.ComplianceLevel -eq 'Compliant' -and $this.MissingCount -eq 0 -and $this.FailedCount -eq 0
    }

    # Method to get total patch count
    [int] GetTotalPatches() {
        return $this.InstalledCount + $this.MissingCount + $this.FailedCount + $this.NotApplicableCount
    }

    # Method to get compliance percentage
    [double] GetCompliancePercentage() {
        $total = $this.GetTotalPatches()
        if ($total -eq 0) {
            return 100.0
        }
        return [math]::Round($this.InstalledCount / $total * 100, 2)
    }

    # String representation
    [string] ToString() {
        return "$($this.InstanceId): $($this.ComplianceLevel) (Missing: $($this.MissingCount), Failed: $($this.FailedCount))"
    }
}

# Export classes (PowerShell 7+)
# Classes are automatically available when the file is dot-sourced
