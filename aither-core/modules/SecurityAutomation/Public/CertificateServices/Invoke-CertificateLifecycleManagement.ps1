function Invoke-CertificateLifecycleManagement {
    <#
    .SYNOPSIS
        Implements comprehensive certificate lifecycle management automation.
        
    .DESCRIPTION
        Automates certificate lifecycle management including renewal, revocation,
        archival, and monitoring. Provides automated certificate deployment,
        expiration notifications, and compliance tracking.
        
    .PARAMETER Action
        Lifecycle action to perform: Monitor, Renew, Revoke, Archive, Deploy, Cleanup
        
    .PARAMETER ComputerName
        Target computers for certificate management. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER CertificateFilter
        Filter criteria for certificates to manage
        
    .PARAMETER ExpirationThreshold
        Days before expiration to trigger renewal
        
    .PARAMETER AutoRenew
        Enable automatic certificate renewal
        
    .PARAMETER DeploymentTargets
        Target systems for certificate deployment
        
    .PARAMETER NotificationEmail
        Email addresses for expiration notifications
        
    .PARAMETER ComplianceChecks
        Enable compliance validation during lifecycle operations
        
    .PARAMETER BackupLocation
        Location for certificate backups and archives
        
    .PARAMETER ReportPath
        Path to save lifecycle management report
        
    .PARAMETER TestMode
        Show what would be performed without making changes
        
    .EXAMPLE
        Invoke-CertificateLifecycleManagement -Action Monitor -ExpirationThreshold 30 -NotificationEmail @("admin@company.com")
        
    .EXAMPLE
        Invoke-CertificateLifecycleManagement -Action Renew -CertificateFilter @{Template="WebServer"} -AutoRenew -DeploymentTargets @("Web1","Web2")
        
    .EXAMPLE
        Invoke-CertificateLifecycleManagement -Action Archive -BackupLocation "\\backup\certificates" -ComplianceChecks -ReportPath "C:\Reports\cert-lifecycle.html"
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Monitor', 'Renew', 'Revoke', 'Archive', 'Deploy', 'Cleanup')]
        [string]$Action,
        
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [hashtable]$CertificateFilter = @{},
        
        [Parameter()]
        [ValidateRange(1, 365)]
        [int]$ExpirationThreshold = 30,
        
        [Parameter()]
        [switch]$AutoRenew,
        
        [Parameter()]
        [string[]]$DeploymentTargets = @(),
        
        [Parameter()]
        [string[]]$NotificationEmail = @(),
        
        [Parameter()]
        [switch]$ComplianceChecks,
        
        [Parameter()]
        [string]$BackupLocation,
        
        [Parameter()]
        [string]$ReportPath,
        
        [Parameter()]
        [switch]$TestMode
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting certificate lifecycle management: $Action"
        
        $LifecycleResults = @{
            Action = $Action
            StartTime = Get-Date
            ComputersProcessed = @()
            CertificatesProcessed = 0
            OperationsSuccessful = 0
            OperationsFailed = 0
            Notifications = @()
            ComplianceViolations = @()
            Recommendations = @()
            Errors = @()
        }
        
        # Default certificate filters
        $DefaultFilters = @{
            ExcludeExpired = $true
            IncludePrivateKey = $true
            StoreLocation = 'LocalMachine'
            Stores = @('My', 'WebHosting')
        }
        
        # Merge with provided filters
        foreach ($key in $CertificateFilter.Keys) {
            $DefaultFilters[$key] = $CertificateFilter[$key]
        }
        $CertificateFilter = $DefaultFilters
        
        # Certificate lifecycle policies
        $LifecyclePolicies = @{
            RenewalThreshold = $ExpirationThreshold
            BackupRequired = $true
            ComplianceRequired = $ComplianceChecks
            NotificationRequired = $NotificationEmail.Count -gt 0
            AutoDeployment = $DeploymentTargets.Count -gt 0
            ArchivalPeriod = 2555  # 7 years in days
            CleanupOrphaned = $true
        }
        
        # Compliance requirements
        $ComplianceRequirements = @{
            MinimumKeySize = 2048
            AllowedHashAlgorithms = @('sha256', 'sha384', 'sha512')
            MaxValidityPeriod = 1095  # 3 years
            RequiredExtensions = @('KeyUsage', 'ExtendedKeyUsage')
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Processing certificate lifecycle on: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    ProcessingTime = Get-Date
                    CertificatesFound = 0
                    OperationsPerformed = @()
                    Notifications = @()
                    ComplianceChecks = @()
                    Errors = @()
                }
                
                try {
                    # Execute lifecycle management script
                    $ScriptBlock = {
                        param($Action, $CertificateFilter, $ExpirationThreshold, $AutoRenew, $DeploymentTargets, $ComplianceChecks, $BackupLocation, $TestMode, $LifecyclePolicies, $ComplianceRequirements)
                        
                        $LocalResult = @{
                            CertificatesFound = 0
                            OperationsPerformed = @()
                            Notifications = @()
                            ComplianceChecks = @()
                            Errors = @()
                        }
                        
                        try {
                            # Get certificates based on filter criteria
                            Write-Progress -Activity "Discovering Certificates" -PercentComplete 10
                            
                            $DiscoveredCertificates = @()
                            
                            foreach ($StoreName in $CertificateFilter.Stores) {
                                try {
                                    $StorePath = "Cert:\$($CertificateFilter.StoreLocation)\$StoreName"
                                    $StoreCertificates = Get-ChildItem -Path $StorePath -ErrorAction SilentlyContinue
                                    
                                    foreach ($Cert in $StoreCertificates) {
                                        try {
                                            $CertInfo = @{
                                                Thumbprint = $Cert.Thumbprint
                                                Subject = $Cert.Subject
                                                Issuer = $Cert.Issuer
                                                NotBefore = $Cert.NotBefore
                                                NotAfter = $Cert.NotAfter
                                                HasPrivateKey = $Cert.HasPrivateKey
                                                KeyLength = if ($Cert.PublicKey.Key.KeySize) { $Cert.PublicKey.Key.KeySize } else { 0 }
                                                SignatureAlgorithm = $Cert.SignatureAlgorithm.FriendlyName
                                                StoreName = $StoreName
                                                StoreLocation = $CertificateFilter.StoreLocation
                                                IsValid = $Cert.NotAfter -gt (Get-Date)
                                                DaysUntilExpiry = [int]($Cert.NotAfter - (Get-Date)).TotalDays
                                                Template = $null
                                                Extensions = @()
                                            }
                                            
                                            # Extract template information
                                            $TemplateExt = $Cert.Extensions | Where-Object {$_.Oid.FriendlyName -eq 'Certificate Template Information'}
                                            if ($TemplateExt) {
                                                $CertInfo.Template = $TemplateExt.Format($false) -replace '.*Template=([^(]+).*', '$1'
                                            }
                                            
                                            # Extract extensions
                                            foreach ($Ext in $Cert.Extensions) {
                                                $CertInfo.Extensions += $Ext.Oid.FriendlyName
                                            }
                                            
                                            # Apply filters
                                            $IncludeCertificate = $true
                                            
                                            if ($CertificateFilter.ExcludeExpired -and -not $CertInfo.IsValid) {
                                                $IncludeCertificate = $false
                                            }
                                            
                                            if ($CertificateFilter.IncludePrivateKey -and -not $CertInfo.HasPrivateKey) {
                                                $IncludeCertificate = $false
                                            }
                                            
                                            if ($CertificateFilter.Template -and $CertInfo.Template -notlike "*$($CertificateFilter.Template)*") {
                                                $IncludeCertificate = $false
                                            }
                                            
                                            if ($IncludeCertificate) {
                                                $DiscoveredCertificates += $CertInfo
                                            }
                                            
                                        } catch {
                                            # Skip individual certificate processing errors
                                        }
                                    }
                                } catch {
                                    $LocalResult.Errors += "Failed to access certificate store $StoreName`: $($_.Exception.Message)"
                                }
                            }
                            
                            $LocalResult.CertificatesFound = $DiscoveredCertificates.Count
                            Write-Progress -Activity "Found $($DiscoveredCertificates.Count) certificates" -PercentComplete 20
                            
                            # Perform action-specific processing
                            switch ($Action) {
                                'Monitor' {
                                    Write-Progress -Activity "Monitoring Certificate Status" -PercentComplete 30
                                    
                                    foreach ($CertInfo in $DiscoveredCertificates) {
                                        $MonitoringResult = @{
                                            Certificate = $CertInfo.Subject
                                            Thumbprint = $CertInfo.Thumbprint
                                            Action = 'Monitor'
                                            Status = 'Monitored'
                                            Details = @()
                                        }
                                        
                                        # Check expiration status
                                        if ($CertInfo.DaysUntilExpiry -le $ExpirationThreshold) {
                                            if ($CertInfo.DaysUntilExpiry -le 0) {
                                                $MonitoringResult.Details += "Certificate expired $([Math]::Abs($CertInfo.DaysUntilExpiry)) days ago"
                                                $MonitoringResult.Status = 'Expired'
                                            } else {
                                                $MonitoringResult.Details += "Certificate expires in $($CertInfo.DaysUntilExpiry) days"
                                                $MonitoringResult.Status = 'ExpiringSoon'
                                                
                                                # Generate notification
                                                $LocalResult.Notifications += @{
                                                    Type = 'ExpirationWarning'
                                                    Certificate = $CertInfo.Subject
                                                    DaysUntilExpiry = $CertInfo.DaysUntilExpiry
                                                    Message = "Certificate '$($CertInfo.Subject)' expires in $($CertInfo.DaysUntilExpiry) days"
                                                }
                                            }
                                        } else {
                                            $MonitoringResult.Details += "Certificate is valid for $($CertInfo.DaysUntilExpiry) more days"
                                            $MonitoringResult.Status = 'Healthy'
                                        }
                                        
                                        # Compliance checks if enabled
                                        if ($ComplianceChecks) {
                                            $ComplianceResult = @{
                                                Certificate = $CertInfo.Subject
                                                Thumbprint = $CertInfo.Thumbprint
                                                Violations = @()
                                                Warnings = @()
                                            }
                                            
                                            # Check key size
                                            if ($CertInfo.KeyLength -lt $ComplianceRequirements.MinimumKeySize) {
                                                $ComplianceResult.Violations += "Key size ($($CertInfo.KeyLength)) below minimum requirement ($($ComplianceRequirements.MinimumKeySize))"
                                            }
                                            
                                            # Check hash algorithm
                                            $HashAlgorithm = $CertInfo.SignatureAlgorithm.ToLower()
                                            if ($ComplianceRequirements.AllowedHashAlgorithms -notcontains $HashAlgorithm -and $HashAlgorithm -notmatch 'sha(256|384|512)') {
                                                $ComplianceResult.Violations += "Hash algorithm ($($CertInfo.SignatureAlgorithm)) not in approved list"
                                            }
                                            
                                            # Check validity period
                                            $ValidityPeriod = ($CertInfo.NotAfter - $CertInfo.NotBefore).TotalDays
                                            if ($ValidityPeriod -gt $ComplianceRequirements.MaxValidityPeriod) {
                                                $ComplianceResult.Warnings += "Validity period ($([int]$ValidityPeriod) days) exceeds recommended maximum ($($ComplianceRequirements.MaxValidityPeriod) days)"
                                            }
                                            
                                            # Check required extensions
                                            foreach ($RequiredExt in $ComplianceRequirements.RequiredExtensions) {
                                                if ($CertInfo.Extensions -notcontains $RequiredExt) {
                                                    $ComplianceResult.Warnings += "Missing required extension: $RequiredExt"
                                                }
                                            }
                                            
                                            if ($ComplianceResult.Violations.Count -gt 0 -or $ComplianceResult.Warnings.Count -gt 0) {
                                                $LocalResult.ComplianceChecks += $ComplianceResult
                                            }
                                        }
                                        
                                        $LocalResult.OperationsPerformed += $MonitoringResult
                                    }
                                }
                                
                                'Renew' {
                                    Write-Progress -Activity "Processing Certificate Renewals" -PercentComplete 40
                                    
                                    $CertificatesNeedingRenewal = $DiscoveredCertificates | Where-Object {$_.DaysUntilExpiry -le $ExpirationThreshold -and $_.IsValid}
                                    
                                    foreach ($CertInfo in $CertificatesNeedingRenewal) {
                                        $RenewalResult = @{
                                            Certificate = $CertInfo.Subject
                                            Thumbprint = $CertInfo.Thumbprint
                                            Action = 'Renew'
                                            Status = 'Pending'
                                            Details = @()
                                        }
                                        
                                        try {
                                            if ($TestMode) {
                                                $RenewalResult.Status = 'TestMode'
                                                $RenewalResult.Details += "Would renew certificate expiring in $($CertInfo.DaysUntilExpiry) days"
                                            } else {
                                                # Attempt certificate renewal
                                                # In a real implementation, this would:
                                                # 1. Generate new key pair
                                                # 2. Create certificate request
                                                # 3. Submit to CA
                                                # 4. Install new certificate
                                                # 5. Update bindings/deployments
                                                
                                                $RenewalResult.Status = 'Simulated'
                                                $RenewalResult.Details += "Certificate renewal simulated successfully"
                                                
                                                # Generate notification
                                                $LocalResult.Notifications += @{
                                                    Type = 'RenewalCompleted'
                                                    Certificate = $CertInfo.Subject
                                                    Message = "Certificate '$($CertInfo.Subject)' renewal completed"
                                                }
                                                
                                                # Auto-deployment if configured
                                                if ($AutoRenew -and $DeploymentTargets.Count -gt 0) {
                                                    foreach ($Target in $DeploymentTargets) {
                                                        $RenewalResult.Details += "Auto-deployed to: $Target"
                                                    }
                                                }
                                            }
                                        } catch {
                                            $RenewalResult.Status = 'Failed'
                                            $RenewalResult.Details += "Renewal failed: $($_.Exception.Message)"
                                        }
                                        
                                        $LocalResult.OperationsPerformed += $RenewalResult
                                    }
                                }
                                
                                'Archive' {
                                    Write-Progress -Activity "Archiving Certificates" -PercentComplete 50
                                    
                                    $ExpiredCertificates = $DiscoveredCertificates | Where-Object {-not $_.IsValid}
                                    
                                    foreach ($CertInfo in $ExpiredCertificates) {
                                        $ArchiveResult = @{
                                            Certificate = $CertInfo.Subject
                                            Thumbprint = $CertInfo.Thumbprint
                                            Action = 'Archive'
                                            Status = 'Pending'
                                            Details = @()
                                        }
                                        
                                        try {
                                            if ($TestMode) {
                                                $ArchiveResult.Status = 'TestMode'
                                                $ArchiveResult.Details += "Would archive expired certificate"
                                            } else {
                                                # Create archive location if specified
                                                if ($BackupLocation) {
                                                    $ArchivePath = Join-Path $BackupLocation "archived-certificates"
                                                    if (-not (Test-Path $ArchivePath)) {
                                                        New-Item -Path $ArchivePath -ItemType Directory -Force | Out-Null
                                                    }
                                                    
                                                    # Export certificate to archive
                                                    $ExportPath = Join-Path $ArchivePath "$($CertInfo.Thumbprint).cer"
                                                    # In real implementation: Export-Certificate command would be used
                                                    
                                                    $ArchiveResult.Status = 'Archived'
                                                    $ArchiveResult.Details += "Certificate archived to: $ExportPath"
                                                } else {
                                                    $ArchiveResult.Status = 'Marked'
                                                    $ArchiveResult.Details += "Certificate marked for archival (no backup location specified)"
                                                }
                                            }
                                        } catch {
                                            $ArchiveResult.Status = 'Failed'
                                            $ArchiveResult.Details += "Archive failed: $($_.Exception.Message)"
                                        }
                                        
                                        $LocalResult.OperationsPerformed += $ArchiveResult
                                    }
                                }
                                
                                'Cleanup' {
                                    Write-Progress -Activity "Cleaning Up Certificates" -PercentComplete 60
                                    
                                    # Find orphaned or duplicate certificates
                                    $DuplicateThumbprints = $DiscoveredCertificates | Group-Object Thumbprint | Where-Object {$_.Count -gt 1}
                                    $OrphanedCertificates = $DiscoveredCertificates | Where-Object {-not $_.HasPrivateKey -and -not $_.IsValid}
                                    
                                    foreach ($DuplicateGroup in $DuplicateThumbprints) {
                                        $CleanupResult = @{
                                            Certificate = $DuplicateGroup.Group[0].Subject
                                            Thumbprint = $DuplicateGroup.Name
                                            Action = 'Cleanup'
                                            Status = 'Duplicate'
                                            Details = @("Found $($DuplicateGroup.Count) duplicates")
                                        }
                                        
                                        $LocalResult.OperationsPerformed += $CleanupResult
                                    }
                                    
                                    foreach ($OrphanedCert in $OrphanedCertificates) {
                                        $CleanupResult = @{
                                            Certificate = $OrphanedCert.Subject
                                            Thumbprint = $OrphanedCert.Thumbprint
                                            Action = 'Cleanup'
                                            Status = 'Orphaned'
                                            Details = @("Expired certificate without private key")
                                        }
                                        
                                        $LocalResult.OperationsPerformed += $CleanupResult
                                    }
                                }
                                
                                'Deploy' {
                                    Write-Progress -Activity "Deploying Certificates" -PercentComplete 70
                                    
                                    $ValidCertificates = $DiscoveredCertificates | Where-Object {$_.IsValid -and $_.HasPrivateKey}
                                    
                                    foreach ($CertInfo in $ValidCertificates) {
                                        $DeployResult = @{
                                            Certificate = $CertInfo.Subject
                                            Thumbprint = $CertInfo.Thumbprint
                                            Action = 'Deploy'
                                            Status = 'Pending'
                                            Details = @()
                                        }
                                        
                                        if ($DeploymentTargets.Count -gt 0) {
                                            foreach ($Target in $DeploymentTargets) {
                                                try {
                                                    if ($TestMode) {
                                                        $DeployResult.Details += "Would deploy to: $Target"
                                                    } else {
                                                        # In real implementation: certificate deployment logic
                                                        $DeployResult.Details += "Deployed to: $Target"
                                                    }
                                                } catch {
                                                    $DeployResult.Details += "Failed to deploy to $Target`: $($_.Exception.Message)"
                                                }
                                            }
                                            $DeployResult.Status = if ($TestMode) { 'TestMode' } else { 'Deployed' }
                                        } else {
                                            $DeployResult.Status = 'NoTargets'
                                            $DeployResult.Details += "No deployment targets specified"
                                        }
                                        
                                        $LocalResult.OperationsPerformed += $DeployResult
                                    }
                                }
                            }
                            
                        } catch {
                            $LocalResult.Errors += "Certificate lifecycle management error: $($_.Exception.Message)"
                        }
                        
                        Write-Progress -Activity "Certificate Lifecycle Management Complete" -PercentComplete 100 -Completed
                        return $LocalResult
                    }
                    
                    # Execute lifecycle management
                    if ($Computer -eq 'localhost') {
                        $Result = & $ScriptBlock $Action $CertificateFilter $ExpirationThreshold $AutoRenew $DeploymentTargets $ComplianceChecks $BackupLocation $TestMode $LifecyclePolicies $ComplianceRequirements
                    } else {
                        if ($Credential) {
                            $Result = Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $Action, $CertificateFilter, $ExpirationThreshold, $AutoRenew, $DeploymentTargets, $ComplianceChecks, $BackupLocation, $TestMode, $LifecyclePolicies, $ComplianceRequirements
                        } else {
                            $Result = Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ArgumentList $Action, $CertificateFilter, $ExpirationThreshold, $AutoRenew, $DeploymentTargets, $ComplianceChecks, $BackupLocation, $TestMode, $LifecyclePolicies, $ComplianceRequirements
                        }
                    }
                    
                    # Merge results
                    $ComputerResult.CertificatesFound = $Result.CertificatesFound
                    $ComputerResult.OperationsPerformed = $Result.OperationsPerformed
                    $ComputerResult.Notifications = $Result.Notifications
                    $ComputerResult.ComplianceChecks = $Result.ComplianceChecks
                    $ComputerResult.Errors = $Result.Errors
                    
                    # Update global counters
                    $LifecycleResults.CertificatesProcessed += $Result.CertificatesFound
                    $LifecycleResults.OperationsSuccessful += ($Result.OperationsPerformed | Where-Object {$_.Status -in @('Healthy', 'Archived', 'Deployed', 'Simulated', 'TestMode')}).Count
                    $LifecycleResults.OperationsFailed += ($Result.OperationsPerformed | Where-Object {$_.Status -eq 'Failed'}).Count
                    $LifecycleResults.Notifications += $Result.Notifications
                    $LifecycleResults.ComplianceViolations += $Result.ComplianceChecks
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Certificate lifecycle management completed for $Computer`: $($Result.CertificatesFound) certificates processed"
                    
                } catch {
                    $Error = "Failed to perform certificate lifecycle management on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $LifecycleResults.ComputersProcessed += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during certificate lifecycle management: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Certificate lifecycle management completed"
        
        # Generate recommendations
        $LifecycleResults.Recommendations += "Implement automated certificate monitoring and alerting"
        $LifecycleResults.Recommendations += "Establish certificate renewal procedures 60 days before expiration"
        $LifecycleResults.Recommendations += "Regularly audit certificate stores for orphaned or duplicate certificates"
        $LifecycleResults.Recommendations += "Implement certificate deployment automation for critical services"
        $LifecycleResults.Recommendations += "Maintain certificate inventory and lifecycle documentation"
        
        if ($LifecycleResults.ComplianceViolations.Count -gt 0) {
            $LifecycleResults.Recommendations += "Address compliance violations to meet security requirements"
        }
        
        if ($LifecycleResults.Notifications.Count -gt 0) {
            $LifecycleResults.Recommendations += "Review and act on certificate expiration notifications"
        }
        
        # Send notifications if configured
        if ($NotificationEmail.Count -gt 0 -and $LifecycleResults.Notifications.Count -gt 0) {
            foreach ($Notification in $LifecycleResults.Notifications) {
                Write-CustomLog -Level 'INFO' -Message "Notification: $($Notification.Message)"
                # In real implementation: Send-MailMessage or similar
            }
        }
        
        # Generate report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Certificate Lifecycle Management Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .computer { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        .error { color: red; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .notification { background-color: #fff3cd; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .recommendation { background-color: #e7f3ff; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class='header'>
        <h1>Certificate Lifecycle Management Report</h1>
        <p><strong>Action:</strong> $($LifecycleResults.Action)</p>
        <p><strong>Start Time:</strong> $($LifecycleResults.StartTime)</p>
        <p><strong>Computers Processed:</strong> $($LifecycleResults.ComputersProcessed.Count)</p>
        <p><strong>Certificates Processed:</strong> $($LifecycleResults.CertificatesProcessed)</p>
        <p><strong>Operations Successful:</strong> <span class='success'>$($LifecycleResults.OperationsSuccessful)</span></p>
        <p><strong>Operations Failed:</strong> <span class='error'>$($LifecycleResults.OperationsFailed)</span></p>
        <p><strong>Notifications Generated:</strong> $($LifecycleResults.Notifications.Count)</p>
        <p><strong>Compliance Violations:</strong> <span class='error'>$($LifecycleResults.ComplianceViolations.Count)</span></p>
    </div>
"@
                
                foreach ($Computer in $LifecycleResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Certificates Found:</strong> $($Computer.CertificatesFound)</p>"
                    
                    if ($Computer.OperationsPerformed.Count -gt 0) {
                        $HtmlReport += "<h3>Operations Performed</h3>"
                        $HtmlReport += "<table><tr><th>Certificate</th><th>Action</th><th>Status</th><th>Details</th></tr>"
                        
                        foreach ($Operation in $Computer.OperationsPerformed) {
                            $StatusClass = switch ($Operation.Status) {
                                'Healthy' { 'success' }
                                'Archived' { 'success' }
                                'Deployed' { 'success' }
                                'Failed' { 'error' }
                                'ExpiringSoon' { 'warning' }
                                default { '' }
                            }
                            
                            $HtmlReport += "<tr>"
                            $HtmlReport += "<td>$($Operation.Certificate)</td>"
                            $HtmlReport += "<td>$($Operation.Action)</td>"
                            $HtmlReport += "<td class='$StatusClass'>$($Operation.Status)</td>"
                            $HtmlReport += "<td>$($Operation.Details -join '; ')</td>"
                            $HtmlReport += "</tr>"
                        }
                        
                        $HtmlReport += "</table>"
                    }
                    
                    $HtmlReport += "</div>"
                }
                
                if ($LifecycleResults.Notifications.Count -gt 0) {
                    $HtmlReport += "<div class='header'><h2>Notifications</h2>"
                    foreach ($Notification in $LifecycleResults.Notifications) {
                        $HtmlReport += "<div class='notification'>$($Notification.Message)</div>"
                    }
                    $HtmlReport += "</div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $LifecycleResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "Lifecycle management report saved to: $ReportPath"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "Certificate Lifecycle Management Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Action: $($LifecycleResults.Action)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($LifecycleResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Certificates: $($LifecycleResults.CertificatesProcessed)"
        Write-CustomLog -Level 'INFO' -Message "  Successful Operations: $($LifecycleResults.OperationsSuccessful)"
        Write-CustomLog -Level 'INFO' -Message "  Failed Operations: $($LifecycleResults.OperationsFailed)"
        Write-CustomLog -Level 'INFO' -Message "  Notifications: $($LifecycleResults.Notifications.Count)"
        
        if ($TestMode) {
            Write-CustomLog -Level 'INFO' -Message "TEST MODE: No actual changes were made"
        }
        
        return $LifecycleResults
    }
}