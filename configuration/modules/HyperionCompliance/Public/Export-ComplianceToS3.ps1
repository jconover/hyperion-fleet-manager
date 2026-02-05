function Export-ComplianceToS3 {
    <#
    .SYNOPSIS
        Uploads compliance reports to an S3 bucket.

    .DESCRIPTION
        Exports compliance reports and results to AWS S3 for centralized storage,
        audit trails, and integration with other AWS services. Includes metadata
        tags for easy organization and querying.

    .PARAMETER BucketName
        The name of the S3 bucket to upload to.

    .PARAMETER ReportData
        The compliance report data to upload. Can be a file path, PSCustomObject,
        or output from Get-ComplianceReport.

    .PARAMETER ReportType
        The type of report being uploaded. Used for S3 key organization.
        Valid values: Compliance, Remediation, Audit, Summary

    .PARAMETER KeyPrefix
        Optional prefix for the S3 key (folder path). Defaults to 'compliance-reports'.

    .PARAMETER Region
        AWS region for the S3 bucket. Defaults to module configuration.

    .PARAMETER ProfileName
        AWS credential profile to use.

    .PARAMETER Tags
        Additional tags to apply to the S3 object.

    .PARAMETER ServerSideEncryption
        Enable server-side encryption. Valid values: None, AES256, aws:kms
        Default: AES256

    .PARAMETER KmsKeyId
        KMS key ID for server-side encryption (when using aws:kms).

    .PARAMETER Metadata
        Additional metadata to attach to the S3 object.

    .PARAMETER Force
        Overwrite existing objects without prompting.

    .EXAMPLE
        Export-ComplianceToS3 -BucketName 'my-compliance-bucket' -ReportData $report -ReportType 'Compliance'
        Uploads compliance report to S3.

    .EXAMPLE
        Get-ComplianceReport -Format JSON | Export-ComplianceToS3 -BucketName 'audit-bucket' -ReportType 'Audit'
        Generates a report and uploads it to S3.

    .EXAMPLE
        Export-ComplianceToS3 -BucketName 'secure-bucket' -ReportData './report.json' -ServerSideEncryption 'aws:kms' -KmsKeyId 'alias/my-key'
        Uploads an existing report file with KMS encryption.

    .OUTPUTS
        PSCustomObject with upload details including S3 URI and ETag.

    .NOTES
        Requires AWS.Tools.S3 module and appropriate IAM permissions:
        - s3:PutObject
        - s3:PutObjectTagging
        - kms:GenerateDataKey (if using KMS encryption)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BucketName,

        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        $ReportData,

        [Parameter(Mandatory)]
        [ValidateSet('Compliance', 'Remediation', 'Audit', 'Summary')]
        [string]$ReportType,

        [Parameter()]
        [string]$KeyPrefix = 'compliance-reports',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Region = $script:ModuleConfig.DefaultRegion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [Parameter()]
        [hashtable]$Tags = @{},

        [Parameter()]
        [ValidateSet('None', 'AES256', 'aws:kms')]
        [string]$ServerSideEncryption = 'AES256',

        [Parameter()]
        [string]$KmsKeyId,

        [Parameter()]
        [hashtable]$Metadata = @{},

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-ComplianceLog -Message "Starting S3 export" -Level 'Information' -Operation 'Export' -Context @{
            BucketName = $BucketName
            ReportType = $ReportType
        }

        # Verify AWS module is available
        if (-not (Get-Module -Name 'AWS.Tools.S3' -ListAvailable)) {
            throw "AWS.Tools.S3 module is required. Install with: Install-Module AWS.Tools.S3 -Scope CurrentUser"
        }

        Import-Module AWS.Tools.S3 -ErrorAction Stop
    }

    process {
        try {
            # Determine the content to upload
            $content = $null
            $contentType = 'application/json'
            $sourceType = 'Object'

            if ($ReportData -is [string] -and (Test-Path -Path $ReportData)) {
                # File path provided
                $content = Get-Content -Path $ReportData -Raw -Encoding UTF8
                $sourceType = 'File'

                # Determine content type from file extension
                $extension = [System.IO.Path]::GetExtension($ReportData).ToLower()
                $contentType = switch ($extension) {
                    '.json' { 'application/json' }
                    '.html' { 'text/html' }
                    '.csv'  { 'text/csv' }
                    '.xml'  { 'application/xml' }
                    default { 'application/octet-stream' }
                }
            }
            elseif ($ReportData -is [PSCustomObject] -or $ReportData -is [hashtable]) {
                # Object provided - convert to JSON
                $content = $ReportData | ConvertTo-Json -Depth 20
                $contentType = 'application/json'
                $sourceType = 'Object'
            }
            elseif ($ReportData -is [string]) {
                # Raw string content
                $content = $ReportData
                $contentType = 'application/json'
                $sourceType = 'String'
            }
            else {
                throw "Unsupported ReportData type: $($ReportData.GetType().FullName)"
            }

            # Generate S3 key
            $timestamp = Get-Date -Format 'yyyy/MM/dd/HHmmss'
            $hostname = $env:HOSTNAME ?? $env:COMPUTERNAME ?? 'unknown'
            $fileExtension = switch ($contentType) {
                'application/json' { 'json' }
                'text/html'        { 'html' }
                'text/csv'         { 'csv' }
                default            { 'dat' }
            }

            $s3Key = "$KeyPrefix/$ReportType/$timestamp-$hostname-$ReportType.$fileExtension"
            $s3Key = $s3Key -replace '//', '/'  # Clean up any double slashes

            # Build common parameters
            $s3Params = @{
                BucketName  = $BucketName
                Key         = $s3Key
                Content     = $content
                ContentType = $contentType
                Region      = $Region
            }

            if ($ProfileName) {
                $s3Params['ProfileName'] = $ProfileName
            }

            # Add server-side encryption
            if ($ServerSideEncryption -ne 'None') {
                $s3Params['ServerSideEncryption'] = $ServerSideEncryption
                if ($ServerSideEncryption -eq 'aws:kms' -and $KmsKeyId) {
                    $s3Params['ServerSideEncryptionKeyManagementServiceKeyId'] = $KmsKeyId
                }
            }

            # Build metadata
            $objectMetadata = @{
                'x-amz-meta-report-type'    = $ReportType
                'x-amz-meta-generated-at'   = (Get-Date -Format 'o')
                'x-amz-meta-hostname'       = $hostname
                'x-amz-meta-module-version' = '1.0.0'
                'x-amz-meta-source-type'    = $sourceType
            }

            foreach ($key in $Metadata.Keys) {
                $objectMetadata["x-amz-meta-$key"] = $Metadata[$key]
            }

            $s3Params['Metadata'] = $objectMetadata

            # Build tags
            $objectTags = @{
                'Environment' = $env:ENVIRONMENT ?? 'Unknown'
                'Project'     = 'hyperion-fleet-manager'
                'ReportType'  = $ReportType
                'Hostname'    = $hostname
                'ManagedBy'   = 'HyperionCompliance'
            }

            foreach ($key in $Tags.Keys) {
                $objectTags[$key] = $Tags[$key]
            }

            # Convert tags to AWS format
            $tagSet = $objectTags.GetEnumerator() | ForEach-Object {
                [Amazon.S3.Model.Tag]@{
                    Key   = $_.Key
                    Value = $_.Value
                }
            }

            # Check if object exists
            if (-not $Force) {
                try {
                    $existingObject = Get-S3ObjectMetadata -BucketName $BucketName -Key $s3Key -Region $Region -ErrorAction SilentlyContinue
                    if ($existingObject) {
                        Write-Warning "Object already exists at s3://$BucketName/$s3Key"
                        if (-not $PSCmdlet.ShouldContinue("Object already exists. Overwrite?", "Confirm Overwrite")) {
                            return
                        }
                    }
                }
                catch {
                    # Object doesn't exist, continue
                }
            }

            # Upload to S3
            $targetDescription = "s3://$BucketName/$s3Key"

            if ($PSCmdlet.ShouldProcess($targetDescription, 'Upload compliance report')) {
                Write-Information "Uploading to $targetDescription..." -InformationAction Continue

                # Write content to S3
                $uploadResult = Write-S3Object @s3Params

                # Apply tags
                try {
                    $null = Set-S3ObjectTagSet -BucketName $BucketName -Key $s3Key -Tagging_TagSet $tagSet -Region $Region
                }
                catch {
                    Write-ComplianceLog -Message "Failed to apply tags: $_" -Level 'Warning' -Operation 'Export'
                }

                # Get object details
                $objectInfo = Get-S3ObjectMetadata -BucketName $BucketName -Key $s3Key -Region $Region

                $result = [PSCustomObject]@{
                    PSTypeName          = 'HyperionCompliance.S3ExportResult'
                    BucketName          = $BucketName
                    Key                 = $s3Key
                    S3Uri               = "s3://$BucketName/$s3Key"
                    HttpsUrl            = "https://$BucketName.s3.$Region.amazonaws.com/$s3Key"
                    ETag                = $objectInfo.ETag
                    ContentLength       = $objectInfo.ContentLength
                    ContentType         = $contentType
                    ServerSideEncryption = $objectInfo.ServerSideEncryptionMethod
                    UploadedAt          = Get-Date
                    ReportType          = $ReportType
                    SourceType          = $sourceType
                }

                Write-ComplianceLog -Message "Successfully uploaded to S3" -Level 'Information' -Operation 'Export' -Context @{
                    S3Uri = $result.S3Uri
                    Size  = $result.ContentLength
                }

                Write-Information "Successfully uploaded to: $($result.S3Uri)" -InformationAction Continue
                Write-Information "Size: $($result.ContentLength) bytes" -InformationAction Continue

                return $result
            }
        }
        catch {
            Write-ComplianceLog -Message "S3 export failed: $_" -Level 'Error' -Operation 'Export' -Context @{
                BucketName = $BucketName
            }
            throw
        }
    }
}
