function Set-AppLockerPolicy {
    <#
    .SYNOPSIS
        Configures AppLocker application control policies for executable whitelisting.
        
    .DESCRIPTION
        Creates and applies AppLocker policies to control which applications can run
        on Windows systems. Supports rule creation, policy templates, enforcement modes,
        and compliance reporting. Implements application whitelisting best practices.
        
    .PARAMETER ComputerName
        Target computer names for AppLocker configuration. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER PolicyTemplate
        Predefined AppLocker policy template to apply
        
    .PARAMETER RuleTypes
        Types of AppLocker rules to configure
        
    .PARAMETER EnforcementMode
        Enforcement mode for AppLocker policies
        
    .PARAMETER AllowedPaths
        File paths to explicitly allow in AppLocker policies
        
    .PARAMETER BlockedPaths
        File paths to explicitly block in AppLocker policies
        
    .PARAMETER TrustedPublishers
        Digital certificate publishers to trust
        
    .PARAMETER HashRules
        Create hash-based rules for specific executables
        
    .PARAMETER CreateDefaultRules
        Create default AppLocker rules for system files
        
    .PARAMETER TestMode
        Show what policies would be applied without enforcement
        
    .PARAMETER ReportPath
        Path to save AppLocker policy report
        
    .PARAMETER BackupExistingPolicy
        Backup existing AppLocker policy before changes
        
    .PARAMETER ValidatePolicy
        Validate policy effectiveness after application
        
    .EXAMPLE
        Set-AppLockerPolicy -PolicyTemplate Workstation -EnforcementMode Enforce -CreateDefaultRules
        
    .EXAMPLE
        Set-AppLockerPolicy -ComputerName @("PC1", "PC2") -RuleTypes @("Executable", "Script") -AllowedPaths @("C:\Program Files\", "C:\Windows\")
        
    .EXAMPLE
        Set-AppLockerPolicy -TestMode -TrustedPublishers @("Microsoft Corporation", "Adobe Systems") -ReportPath "C:\Reports\applocker.html"
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [ValidateSet('Workstation', 'Server', 'HighSecurity', 'Developer', 'Kiosk', 'Custom')]
        [string]$PolicyTemplate = 'Workstation',
        
        [Parameter()]
        [ValidateSet('Executable', 'WindowsInstaller', 'Script', 'DLL', 'PackagedApp')]
        [string[]]$RuleTypes = @('Executable', 'Script'),
        
        [Parameter()]
        [ValidateSet('NotConfigured', 'AuditOnly', 'Enforce')]
        [string]$EnforcementMode = 'AuditOnly',
        
        [Parameter()]
        [string[]]$AllowedPaths = @(),
        
        [Parameter()]
        [string[]]$BlockedPaths = @(),
        
        [Parameter()]
        [string[]]$TrustedPublishers = @(),
        
        [Parameter()]
        [hashtable[]]$HashRules = @(),
        
        [Parameter()]
        [switch]$CreateDefaultRules,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [string]$ReportPath,
        
        [Parameter()]
        [switch]$BackupExistingPolicy,
        
        [Parameter()]
        [switch]$ValidatePolicy
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting AppLocker policy configuration for $($ComputerName.Count) computer(s)"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        $AppLockerResults = @{
            PolicyTemplate = $PolicyTemplate
            EnforcementMode = $EnforcementMode
            ComputersProcessed = @()
            PoliciesApplied = 0
            RulesCreated = 0
            BackupsCreated = 0
            ValidationResults = @()
            Errors = @()
            Recommendations = @()
        }
        
        # Define policy templates
        $PolicyTemplates = @{
            'Workstation' = @{
                Description = 'Standard workstation policy with common business applications'
                DefaultPaths = @(
                    'C:\Windows\*',
                    'C:\Program Files\*',
                    'C:\Program Files (x86)\*'
                )
                TrustedPublishers = @(
                    'Microsoft Corporation',
                    'Microsoft Windows',
                    'Microsoft Windows Publisher'
                )
                BlockedPaths = @(
                    '%TEMP%\*',
                    '%USERPROFILE%\Downloads\*',
                    '%USERPROFILE%\AppData\Local\Temp\*'
                )
            }
            'Server' = @{
                Description = 'Server policy with restricted application execution'
                DefaultPaths = @(
                    'C:\Windows\*',
                    'C:\Program Files\*',
                    'C:\Program Files (x86)\*'
                )
                TrustedPublishers = @(
                    'Microsoft Corporation',
                    'Microsoft Windows',
                    'Microsoft Windows Publisher'
                )
                BlockedPaths = @(
                    '%TEMP%\*',
                    '%USERPROFILE%\*'
                )
            }
            'HighSecurity' = @{
                Description = 'High security policy with minimal allowed applications'
                DefaultPaths = @(
                    'C:\Windows\System32\*',
                    'C:\Windows\SysWOW64\*'
                )
                TrustedPublishers = @(
                    'Microsoft Corporation',
                    'Microsoft Windows'
                )
                BlockedPaths = @(
                    '%TEMP%\*',
                    '%USERPROFILE%\*',
                    'C:\Users\*'
                )
            }
            'Developer' = @{
                Description = 'Developer workstation with additional development tools'
                DefaultPaths = @(
                    'C:\Windows\*',
                    'C:\Program Files\*',
                    'C:\Program Files (x86)\*',
                    'C:\Program Files\Microsoft Visual Studio*',
                    'C:\Program Files (x86)\Microsoft Visual Studio*'
                )
                TrustedPublishers = @(
                    'Microsoft Corporation',
                    'Microsoft Windows',
                    'Microsoft Windows Publisher',
                    'JetBrains s.r.o.',
                    'GitHub, Inc.'
                )
                BlockedPaths = @(
                    '%USERPROFILE%\Downloads\*'
                )
            }
            'Kiosk' = @{
                Description = 'Kiosk mode with single application execution'
                DefaultPaths = @(
                    'C:\Windows\System32\*',
                    'C:\Windows\SysWOW64\*'
                )
                TrustedPublishers = @(
                    'Microsoft Corporation'
                )
                BlockedPaths = @(
                    '%TEMP%\*',
                    '%USERPROFILE%\*',
                    'C:\Users\*',
                    'C:\Program Files\*'
                )
            }
        }
        
        # Enforcement mode values
        $EnforcementModes = @{
            'NotConfigured' = 'NotConfigured'
            'AuditOnly' = 'AuditOnly'
            'Enforce' = 'Enforce'
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Processing AppLocker configuration for: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    ConfigurationTime = Get-Date
                    PolicyApplied = $false
                    RulesCreated = @()
                    BackupPath = $null
                    EnforcementStatus = 'Unknown'
                    ValidationResults = @()
                    Errors = @()
                }
                
                try {
                    # Execute AppLocker configuration script
                    $ScriptBlock = {
                        param($PolicyTemplate, $RuleTypes, $EnforcementMode, $AllowedPaths, $BlockedPaths, $TrustedPublishers, $HashRules, $CreateDefaultRules, $TestMode, $BackupExistingPolicy, $ValidatePolicy, $PolicyTemplates, $EnforcementModes)
                        
                        $LocalResult = @{
                            PolicyApplied = $false
                            RulesCreated = @()
                            BackupPath = $null
                            EnforcementStatus = 'Unknown'
                            ValidationResults = @()
                            Errors = @()
                        }
                        
                        try {
                            # Check if AppLocker service is available
                            $AppIDSvc = Get-Service -Name 'AppIDSvc' -ErrorAction SilentlyContinue
                            if (-not $AppIDSvc) {
                                $LocalResult.Errors += "Application Identity service not available"
                                return $LocalResult
                            }
                            
                            # Start AppLocker service if not running
                            if ($AppIDSvc.Status -ne 'Running' -and -not $TestMode) {
                                Start-Service -Name 'AppIDSvc'
                                Start-Sleep -Seconds 5
                            }
                            
                            # Backup existing policy if requested
                            if ($BackupExistingPolicy) {
                                Write-Progress -Activity "Backing Up Existing Policy" -PercentComplete 10
                                
                                try {
                                    $BackupDir = 'C:\ProgramData\AitherZero\Backups\AppLocker'
                                    if (-not (Test-Path $BackupDir)) {
                                        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
                                    }
                                    
                                    $BackupFile = Join-Path $BackupDir "AppLocker-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
                                    
                                    if (-not $TestMode) {
                                        Get-AppLockerPolicy -Effective -Xml | Out-File -FilePath $BackupFile -Encoding UTF8
                                        $LocalResult.BackupPath = $BackupFile
                                    }
                                } catch {
                                    $LocalResult.Errors += "Failed to backup existing policy: $($_.Exception.Message)"
                                }
                            }
                            
                            # Get policy template configuration
                            $PolicyConfig = if ($PolicyTemplates.ContainsKey($PolicyTemplate)) {
                                $PolicyTemplates[$PolicyTemplate]
                            } else {
                                @{
                                    Description = 'Custom policy configuration'
                                    DefaultPaths = @()
                                    TrustedPublishers = @()
                                    BlockedPaths = @()
                                }
                            }
                            
                            # Merge custom paths with template
                            $AllPathsToAllow = $PolicyConfig.DefaultPaths + $AllowedPaths | Sort-Object -Unique
                            $AllPathsToBlock = $PolicyConfig.BlockedPaths + $BlockedPaths | Sort-Object -Unique
                            $AllTrustedPublishers = $PolicyConfig.TrustedPublishers + $TrustedPublishers | Sort-Object -Unique
                            
                            # Create AppLocker policy XML
                            Write-Progress -Activity "Creating AppLocker Policy" -PercentComplete 30
                            
                            $PolicyXml = @"
<?xml version="1.0" encoding="utf-8"?>
<AppLockerPolicy Version="1">
"@
                            
                            foreach ($RuleType in $RuleTypes) {
                                $RuleCollection = switch ($RuleType) {
                                    'Executable' { 'Exe' }
                                    'WindowsInstaller' { 'Msi' }
                                    'Script' { 'Script' }
                                    'DLL' { 'Dll' }
                                    'PackagedApp' { 'AppX' }
                                }
                                
                                $PolicyXml += @"
  <RuleCollection Type="$RuleCollection" EnforcementMode="$($EnforcementModes[$EnforcementMode])">
"@
                                
                                $RuleId = 1
                                
                                # Create default rules if requested
                                if ($CreateDefaultRules) {
                                    $PolicyXml += @"
    <FilePathRule Id="$([guid]::NewGuid())" Name="Default Rule - Allow Windows" Description="Allow files in Windows folder" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="C:\Windows\*" />
      </Conditions>
    </FilePathRule>
    <FilePathRule Id="$([guid]::NewGuid())" Name="Default Rule - Allow Program Files" Description="Allow files in Program Files" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="C:\Program Files\*" />
      </Conditions>
    </FilePathRule>
"@
                                    if (Test-Path "C:\Program Files (x86)") {
                                        $PolicyXml += @"
    <FilePathRule Id="$([guid]::NewGuid())" Name="Default Rule - Allow Program Files x86" Description="Allow files in Program Files x86" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="C:\Program Files (x86)\*" />
      </Conditions>
    </FilePathRule>
"@
                                    }
                                    
                                    $LocalResult.RulesCreated += "Default rules for $RuleType"
                                }
                                
                                # Create allow path rules
                                foreach ($Path in $AllPathsToAllow) {
                                    $PolicyXml += @"
    <FilePathRule Id="$([guid]::NewGuid())" Name="Allow Path - $Path" Description="Allow files in $Path" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="$Path" />
      </Conditions>
    </FilePathRule>
"@
                                    $LocalResult.RulesCreated += "Allow path rule: $Path"
                                }
                                
                                # Create block path rules
                                foreach ($Path in $AllPathsToBlock) {
                                    $PolicyXml += @"
    <FilePathRule Id="$([guid]::NewGuid())" Name="Block Path - $Path" Description="Block files in $Path" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="$Path" />
      </Conditions>
    </FilePathRule>
"@
                                    $LocalResult.RulesCreated += "Block path rule: $Path"
                                }
                                
                                # Create publisher rules for trusted publishers
                                foreach ($Publisher in $AllTrustedPublishers) {
                                    $PolicyXml += @"
    <FilePublisherRule Id="$([guid]::NewGuid())" Name="Trust Publisher - $Publisher" Description="Allow files signed by $Publisher" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePublisherCondition PublisherName="$Publisher" ProductName="*" BinaryName="*">
          <BinaryVersionRange LowSection="*" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
"@
                                    $LocalResult.RulesCreated += "Publisher rule: $Publisher"
                                }
                                
                                # Create hash rules for specific files
                                foreach ($HashRule in $HashRules) {
                                    if ($HashRule.FilePath -and (Test-Path $HashRule.FilePath)) {
                                        try {
                                            $FileHash = Get-FileHash -Path $HashRule.FilePath -Algorithm SHA256
                                            $FileName = Split-Path $HashRule.FilePath -Leaf
                                            
                                            $PolicyXml += @"
    <FileHashRule Id="$([guid]::NewGuid())" Name="Hash Rule - $FileName" Description="Allow specific file by hash" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FileHashCondition>
          <FileHash Type="SHA256" Data="$($FileHash.Hash)" SourceFileName="$FileName" SourceFileLength="$((Get-Item $HashRule.FilePath).Length)" />
        </FileHashCondition>
      </Conditions>
    </FileHashRule>
"@
                                            $LocalResult.RulesCreated += "Hash rule: $FileName"
                                        } catch {
                                            $LocalResult.Errors += "Failed to create hash rule for $($HashRule.FilePath): $($_.Exception.Message)"
                                        }
                                    }
                                }
                                
                                $PolicyXml += @"
  </RuleCollection>
"@
                            }
                            
                            $PolicyXml += @"
</AppLockerPolicy>
"@
                            
                            # Apply policy
                            Write-Progress -Activity "Applying AppLocker Policy" -PercentComplete 60
                            
                            if (-not $TestMode) {
                                try {
                                    # Save policy to temporary file
                                    $TempPolicyFile = Join-Path $env:TEMP "AppLockerPolicy-$(Get-Date -Format 'yyyyMMddHHmmss').xml"
                                    $PolicyXml | Out-File -FilePath $TempPolicyFile -Encoding UTF8
                                    
                                    # Apply the policy
                                    Set-AppLockerPolicy -XmlPolicy $TempPolicyFile
                                    
                                    # Clean up temporary file
                                    Remove-Item -Path $TempPolicyFile -Force -ErrorAction SilentlyContinue
                                    
                                    $LocalResult.PolicyApplied = $true
                                    $LocalResult.EnforcementStatus = $EnforcementMode
                                    
                                } catch {
                                    $LocalResult.Errors += "Failed to apply AppLocker policy: $($_.Exception.Message)"
                                }
                            } else {
                                $LocalResult.PolicyApplied = $true  # Simulated for test mode
                                $LocalResult.EnforcementStatus = "Test Mode - $EnforcementMode"
                            }
                            
                            # Validate policy if requested
                            if ($ValidatePolicy) {
                                Write-Progress -Activity "Validating Policy" -PercentComplete 80
                                
                                try {
                                    # Get current AppLocker policy
                                    $CurrentPolicy = Get-AppLockerPolicy -Effective
                                    
                                    if ($CurrentPolicy) {
                                        $ValidationResult = @{
                                            PolicyExists = $true
                                            RuleCollections = @()
                                            EnforcementModes = @()
                                        }
                                        
                                        foreach ($RuleCollection in $CurrentPolicy.RuleCollections) {
                                            $ValidationResult.RuleCollections += @{
                                                Type = $RuleCollection.RuleCollectionType
                                                EnforcementMode = $RuleCollection.EnforcementMode
                                                RuleCount = $RuleCollection.Count
                                            }
                                            
                                            $ValidationResult.EnforcementModes += "$($RuleCollection.RuleCollectionType): $($RuleCollection.EnforcementMode)"
                                        }
                                        
                                        $LocalResult.ValidationResults += $ValidationResult
                                    } else {
                                        $LocalResult.ValidationResults += @{
                                            PolicyExists = $false
                                            Message = "No AppLocker policy found"
                                        }
                                    }
                                } catch {
                                    $LocalResult.Errors += "Policy validation failed: $($_.Exception.Message)"
                                }
                            }
                            
                        } catch {
                            $LocalResult.Errors += "AppLocker configuration error: $($_.Exception.Message)"
                        }
                        
                        Write-Progress -Activity "AppLocker Configuration Complete" -PercentComplete 100 -Completed
                        return $LocalResult
                    }
                    
                    # Execute configuration
                    if ($Computer -eq 'localhost') {
                        $Result = & $ScriptBlock $PolicyTemplate $RuleTypes $EnforcementMode $AllowedPaths $BlockedPaths $TrustedPublishers $HashRules $CreateDefaultRules $TestMode $BackupExistingPolicy $ValidatePolicy $PolicyTemplates $EnforcementModes
                    } else {
                        if ($Credential) {
                            $Result = Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $PolicyTemplate, $RuleTypes, $EnforcementMode, $AllowedPaths, $BlockedPaths, $TrustedPublishers, $HashRules, $CreateDefaultRules, $TestMode, $BackupExistingPolicy, $ValidatePolicy, $PolicyTemplates, $EnforcementModes
                        } else {
                            $Result = Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ArgumentList $PolicyTemplate, $RuleTypes, $EnforcementMode, $AllowedPaths, $BlockedPaths, $TrustedPublishers, $HashRules, $CreateDefaultRules, $TestMode, $BackupExistingPolicy, $ValidatePolicy, $PolicyTemplates, $EnforcementModes
                        }
                    }
                    
                    # Merge results
                    $ComputerResult.PolicyApplied = $Result.PolicyApplied
                    $ComputerResult.RulesCreated = $Result.RulesCreated
                    $ComputerResult.BackupPath = $Result.BackupPath
                    $ComputerResult.EnforcementStatus = $Result.EnforcementStatus
                    $ComputerResult.ValidationResults = $Result.ValidationResults
                    $ComputerResult.Errors = $Result.Errors
                    
                    # Update counters
                    if ($Result.PolicyApplied) {
                        $AppLockerResults.PoliciesApplied++
                    }
                    $AppLockerResults.RulesCreated += $Result.RulesCreated.Count
                    if ($Result.BackupPath) {
                        $AppLockerResults.BackupsCreated++
                    }
                    if ($Result.ValidationResults) {
                        $AppLockerResults.ValidationResults += $Result.ValidationResults
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "AppLocker configuration completed for $Computer`: $($Result.RulesCreated.Count) rules created"
                    
                } catch {
                    $Error = "Failed to configure AppLocker on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $AppLockerResults.ComputersProcessed += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during AppLocker configuration: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "AppLocker policy configuration completed"
        
        # Generate recommendations
        $AppLockerResults.Recommendations += "Start with AuditOnly mode to test policy impact before enforcement"
        $AppLockerResults.Recommendations += "Monitor AppLocker event logs for blocked applications"
        $AppLockerResults.Recommendations += "Regularly review and update AppLocker policies"
        $AppLockerResults.Recommendations += "Test application compatibility after policy deployment"
        $AppLockerResults.Recommendations += "Implement Group Policy for enterprise-wide AppLocker management"
        
        if ($EnforcementMode -eq 'AuditOnly') {
            $AppLockerResults.Recommendations += "Review audit logs and switch to Enforce mode when ready"
        }
        
        if ($AppLockerResults.BackupsCreated -gt 0) {
            $AppLockerResults.Recommendations += "Store policy backups in secure location for disaster recovery"
        }
        
        # Generate HTML report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>AppLocker Policy Configuration Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .computer { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .error { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .recommendation { background-color: #e7f3ff; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .rule-list { background-color: #f9f9f9; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class='header'>
        <h1>AppLocker Policy Configuration Report</h1>
        <p><strong>Policy Template:</strong> $($AppLockerResults.PolicyTemplate)</p>
        <p><strong>Enforcement Mode:</strong> $($AppLockerResults.EnforcementMode)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($AppLockerResults.ComputersProcessed.Count)</p>
        <p><strong>Policies Applied:</strong> <span class='success'>$($AppLockerResults.PoliciesApplied)</span></p>
        <p><strong>Rules Created:</strong> $($AppLockerResults.RulesCreated)</p>
        <p><strong>Backups Created:</strong> $($AppLockerResults.BackupsCreated)</p>
    </div>
"@
                
                foreach ($Computer in $AppLockerResults.ComputersProcessed) {
                    $StatusClass = if ($Computer.PolicyApplied) { 'success' } else { 'error' }
                    
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Policy Applied:</strong> <span class='$StatusClass'>$($Computer.PolicyApplied)</span></p>"
                    $HtmlReport += "<p><strong>Enforcement Status:</strong> $($Computer.EnforcementStatus)</p>"
                    $HtmlReport += "<p><strong>Rules Created:</strong> $($Computer.RulesCreated.Count)</p>"
                    
                    if ($Computer.BackupPath) {
                        $HtmlReport += "<p><strong>Backup Path:</strong> $($Computer.BackupPath)</p>"
                    }
                    
                    if ($Computer.RulesCreated.Count -gt 0) {
                        $HtmlReport += "<h3>Rules Created</h3>"
                        $HtmlReport += "<div class='rule-list'>"
                        foreach ($Rule in $Computer.RulesCreated) {
                            $HtmlReport += "<div>$Rule</div>"
                        }
                        $HtmlReport += "</div>"
                    }
                    
                    if ($Computer.ValidationResults.Count -gt 0) {
                        $HtmlReport += "<h3>Validation Results</h3>"
                        foreach ($Validation in $Computer.ValidationResults) {
                            if ($Validation.PolicyExists) {
                                $HtmlReport += "<p><strong>Policy Status:</strong> <span class='success'>Active</span></p>"
                                if ($Validation.RuleCollections) {
                                    $HtmlReport += "<table><tr><th>Rule Type</th><th>Enforcement Mode</th><th>Rule Count</th></tr>"
                                    foreach ($Collection in $Validation.RuleCollections) {
                                        $HtmlReport += "<tr><td>$($Collection.Type)</td><td>$($Collection.EnforcementMode)</td><td>$($Collection.RuleCount)</td></tr>"
                                    }
                                    $HtmlReport += "</table>"
                                }
                            } else {
                                $HtmlReport += "<p><strong>Policy Status:</strong> <span class='error'>$($Validation.Message)</span></p>"
                            }
                        }
                    }
                    
                    $HtmlReport += "</div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $AppLockerResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "AppLocker policy report saved to: $ReportPath"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "AppLocker Policy Configuration Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Template: $($AppLockerResults.PolicyTemplate)"
        Write-CustomLog -Level 'INFO' -Message "  Enforcement Mode: $($AppLockerResults.EnforcementMode)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($AppLockerResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Policies Applied: $($AppLockerResults.PoliciesApplied)"
        Write-CustomLog -Level 'INFO' -Message "  Rules Created: $($AppLockerResults.RulesCreated)"
        
        if ($TestMode) {
            Write-CustomLog -Level 'INFO' -Message "TEST MODE: No actual policies were applied"
        }
        
        if ($EnforcementMode -eq 'AuditOnly') {
            Write-CustomLog -Level 'WARNING' -Message "AppLocker is in Audit Only mode - review logs before enforcing"
        }
        
        return $AppLockerResults
    }
}