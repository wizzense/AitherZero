#Requires -Version 7.0

<#
.SYNOPSIS
    Consolidated Infrastructure Management for AitherZero
.DESCRIPTION
    Unified infrastructure management providing OpenTofu/Terraform automation,
    security management, and system reporting capabilities.
.NOTES
    Consolidated from:
    - domains/infrastructure/Infrastructure.psm1
    - domains/security/* (if any)
    - domains/reporting/ReportingEngine.psm1
    - domains/reporting/TechDebtAnalysis.psm1
#>

# Script variables
$script:InfrastructureConfig = @{}
$script:SecuritySettings = @{}
$script:ReportingEnabled = $true

#region Infrastructure Management

function Test-OpenTofu {
    <#
    .SYNOPSIS
        Test if OpenTofu is available and functional
    #>
    [CmdletBinding()]
    param()

    try {
        $version = tofu version 2>$null
        if ($version) {
            return @{
                Available = $true
                Version = $version | Select-Object -First 1
                Tool = 'OpenTofu'
            }
        }
    }
    catch {
        # OpenTofu not available, try Terraform
    }

    try {
        $version = terraform version 2>$null
        if ($version) {
            return @{
                Available = $true
                Version = $version | Select-Object -First 1
                Tool = 'Terraform'
            }
        }
    }
    catch {
        # Neither available
    }

    return @{
        Available = $false
        Version = $null
        Tool = $null
    }
}

function Get-InfrastructureTool {
    <#
    .SYNOPSIS
        Get the available infrastructure tool (OpenTofu or Terraform)
    #>
    [CmdletBinding()]
    param()

    $toolCheck = Test-OpenTofu
    
    if ($toolCheck.Available) {
        return $toolCheck.Tool.ToLower()
    } else {
        throw "Neither OpenTofu nor Terraform is available. Please install one of them."
    }
}

function Invoke-InfrastructurePlan {
    <#
    .SYNOPSIS
        Generate and display infrastructure plan
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ConfigPath = ".",
        [hashtable]$Variables = @{},
        [string]$OutputPath,
        [switch]$Detailed
    )

    Push-Location $ConfigPath
    try {
        $tool = Get-InfrastructureTool
        
        # Prepare variable arguments
        $varArgs = @()
        foreach ($key in $Variables.Keys) {
            $varArgs += "-var"
            $varArgs += "$key=$($Variables[$key])"
        }

        if ($PSCmdlet.ShouldProcess($ConfigPath, "Generate infrastructure plan")) {
            Write-Host "🏗️  Generating infrastructure plan..." -ForegroundColor Cyan
            
            # Initialize if needed
            & $tool init -upgrade

            # Generate plan
            $planArgs = @("plan") + $varArgs
            if ($OutputPath) {
                $planArgs += "-out=$OutputPath"
            }
            if ($Detailed) {
                $planArgs += "-detailed-exitcode"
            }

            $result = & $tool @planArgs
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Infrastructure plan generated successfully" -ForegroundColor Green
            } else {
                Write-Host "❌ Failed to generate infrastructure plan" -ForegroundColor Red
            }

            return @{
                Success = ($LASTEXITCODE -eq 0)
                Output = $result
                ExitCode = $LASTEXITCODE
                Tool = $tool
            }
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-InfrastructureApply {
    <#
    .SYNOPSIS
        Apply infrastructure changes
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ConfigPath = ".",
        [string]$PlanPath,
        [hashtable]$Variables = @{},
        [switch]$AutoApprove
    )

    Push-Location $ConfigPath
    try {
        $tool = Get-InfrastructureTool
        
        if ($PSCmdlet.ShouldProcess($ConfigPath, "Apply infrastructure changes")) {
            Write-Host "🚀 Applying infrastructure changes..." -ForegroundColor Cyan
            
            $applyArgs = @("apply")
            
            if ($AutoApprove) {
                $applyArgs += "-auto-approve"
            }
            
            if ($PlanPath) {
                $applyArgs += $PlanPath
            } else {
                # Add variables if no plan file
                foreach ($key in $Variables.Keys) {
                    $applyArgs += "-var"
                    $applyArgs += "$key=$($Variables[$key])"
                }
            }

            $result = & $tool @applyArgs
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Infrastructure applied successfully" -ForegroundColor Green
            } else {
                Write-Host "❌ Failed to apply infrastructure" -ForegroundColor Red
            }

            return @{
                Success = ($LASTEXITCODE -eq 0)
                Output = $result
                ExitCode = $LASTEXITCODE
                Tool = $tool
            }
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-InfrastructureDestroy {
    <#
    .SYNOPSIS
        Destroy infrastructure resources
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ConfigPath = ".",
        [hashtable]$Variables = @{},
        [switch]$AutoApprove,
        [switch]$Force
    )

    Push-Location $ConfigPath
    try {
        $tool = Get-InfrastructureTool
        
        if ($PSCmdlet.ShouldProcess($ConfigPath, "Destroy infrastructure")) {
            Write-Host "💥 Destroying infrastructure..." -ForegroundColor Red
            
            $destroyArgs = @("destroy")
            
            if ($AutoApprove -or $Force) {
                $destroyArgs += "-auto-approve"
            }
            
            foreach ($key in $Variables.Keys) {
                $destroyArgs += "-var"
                $destroyArgs += "$key=$($Variables[$key])"
            }

            $result = & $tool @destroyArgs
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Infrastructure destroyed successfully" -ForegroundColor Green
            } else {
                Write-Host "❌ Failed to destroy infrastructure" -ForegroundColor Red
            }

            return @{
                Success = ($LASTEXITCODE -eq 0)
                Output = $result
                ExitCode = $LASTEXITCODE
                Tool = $tool
            }
        }
    }
    finally {
        Pop-Location
    }
}

#endregion

#region Security Management

function Test-SecurityRequirements {
    <#
    .SYNOPSIS
        Test that security infrastructure is properly configured
    #>
    [CmdletBinding()]
    param()

    $result = @{
        Valid = $true
        Errors = @()
        EncryptionAvailable = $false
        AuditingAvailable = $false
        AccessControls = @{}
        CertificateManagement = @{}
    }

    # Test encryption capabilities
    try {
        if ($IsWindows) {
            # Test Data Protection API availability
            $testData = "test"
            $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
                [System.Text.Encoding]::UTF8.GetBytes($testData),
                $null,
                [System.Security.Cryptography.DataProtectionScope]::CurrentUser
            )
            if ($encrypted) {
                $result.EncryptionAvailable = $true
            }
        } else {
            # Test OpenSSL availability on Unix systems
            $opensslPath = Get-Command openssl -ErrorAction SilentlyContinue
            if ($opensslPath) {
                $result.EncryptionAvailable = $true
            }
        }
    } catch {
        $result.Errors += "Encryption validation failed: $($_.Exception.Message)"
    }

    # Test audit logging capabilities
    try {
        $auditLogPath = Join-Path $env:AITHERZERO_ROOT "logs/audit"
        if (-not (Test-Path $auditLogPath)) {
            New-Item -ItemType Directory -Path $auditLogPath -Force -ErrorAction Stop | Out-Null
        }
        
        $testLogFile = Join-Path $auditLogPath "test-audit.log"
        "Test audit entry: $(Get-Date)" | Out-File -FilePath $testLogFile -Append -ErrorAction Stop
        
        if (Test-Path $testLogFile) {
            $result.AuditingAvailable = $true
            Remove-Item $testLogFile -ErrorAction SilentlyContinue
        }
    } catch {
        $result.Errors += "Audit logging validation failed: $($_.Exception.Message)"
    }

    # Initialize access controls with role-based structure
    $result.AccessControls = @{
        Roles = @{
            Administrator = @{
                Permissions = @('Read', 'Write', 'Execute', 'Manage')
                Users = @()
            }
            Developer = @{
                Permissions = @('Read', 'Write', 'Execute')
                Users = @()
            }
            ReadOnly = @{
                Permissions = @('Read')
                Users = @()
            }
        }
        CurrentUser = @{
            Name = $env:USERNAME ?? $env:USER
            Role = 'Administrator'  # Default to admin for initial setup
        }
    }

    # Initialize certificate management
    $result.CertificateManagement = @{
        Store = if ($IsWindows) { 'Cert:\CurrentUser\My' } else { "$HOME/.aitherzero/certs" }
        ValidCertificates = @()
        ExpiringCertificates = @()
        CreateSelfSignedCerts = $true
    }

    # Test certificate store access
    try {
        if ($IsWindows) {
            $certs = Get-ChildItem -Path $result.CertificateManagement.Store -ErrorAction Stop
            $result.CertificateManagement.ValidCertificates = @($certs | Where-Object { $_.NotAfter -gt (Get-Date) })
            $result.CertificateManagement.ExpiringCertificates = @($certs | Where-Object { 
                $_.NotAfter -gt (Get-Date) -and $_.NotAfter -lt (Get-Date).AddDays(30) 
            })
        } else {
            $certDir = $result.CertificateManagement.Store
            if (-not (Test-Path $certDir)) {
                New-Item -ItemType Directory -Path $certDir -Force -ErrorAction Stop | Out-Null
            }
        }
    } catch {
        $result.Errors += "Certificate store validation failed: $($_.Exception.Message)"
    }

    # Final validation
    if ($result.Errors.Count -gt 0) {
        $result.Valid = $false
    }

    return $result
}

function Initialize-SecurityConfiguration {
    <#
    .SYNOPSIS
        Initialize security settings with validated infrastructure
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{}
    )

    # Validate security requirements first
    $securityValidation = Test-SecurityRequirements
    if (-not $securityValidation.Valid) {
        throw "Security requirements not met: $($securityValidation.Errors -join '; ')"
    }

    $script:SecuritySettings = @{
        EncryptionEnabled = $securityValidation.EncryptionAvailable
        AuditLogging = $securityValidation.AuditingAvailable
        AccessControls = $securityValidation.AccessControls
        CertificateManagement = $securityValidation.CertificateManagement
    }

    # Merge with provided configuration
    foreach ($key in $Configuration.Keys) {
        $script:SecuritySettings[$key] = $Configuration[$key]
    }

    if (Get-Command Write-InfraLog -ErrorAction SilentlyContinue) {
        Write-InfraLog -Message "Security configuration initialized" -Level Information
    }
}

function Test-SecurityCompliance {
    <#
    .SYNOPSIS
        Check security compliance status
    #>
    [CmdletBinding()]
    param([string[]]$Checks = @())

    $results = @{}
    
    # Default security checks
    $defaultChecks = @{
        'PowerShellExecutionPolicy' = {
            $policy = Get-ExecutionPolicy
            @{
                Status = if ($policy -in @('Restricted', 'AllSigned', 'RemoteSigned')) { 'Pass' } else { 'Fail' }
                Value = $policy
                Recommendation = "Use Restricted, AllSigned, or RemoteSigned execution policy"
            }
        }
        'WindowsDefender' = {
            if ($IsWindows) {
                try {
                    $status = Get-MpComputerStatus -ErrorAction SilentlyContinue
                    @{
                        Status = if ($status.AntivirusEnabled) { 'Pass' } else { 'Fail' }
                        Value = $status.AntivirusEnabled
                        Recommendation = "Enable Windows Defender antivirus"
                    }
                } catch {
                    @{
                        Status = 'Unknown'
                        Value = $null
                        Recommendation = "Unable to check Windows Defender status"
                    }
                }
            } else {
                @{
                    Status = 'Skip'
                    Value = 'Not applicable on non-Windows systems'
                    Recommendation = "N/A"
                }
            }
        }
    }

    $checksToRun = if ($Checks.Count -gt 0) { $Checks } else { $defaultChecks.Keys }

    foreach ($check in $checksToRun) {
        if ($defaultChecks.ContainsKey($check)) {
            Write-Host "Checking: $check" -ForegroundColor Cyan
            $results[$check] = & $defaultChecks[$check]
        }
    }

    return $results
}

#endregion

#region Reporting Engine

function New-ExecutionDashboard {
    <#
    .SYNOPSIS
        Create an execution dashboard
    #>
    [CmdletBinding()]
    param(
        [string]$Title = "AitherZero Dashboard",
        [string]$OutputPath,
        [hashtable]$Metrics = @{}
    )

    if (-not $OutputPath) {
        $OutputPath = Join-Path $env:AITHERZERO_ROOT "reports/dashboard.html"
    }

    $dashboardData = @{
        Title = $Title
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Metrics = $Metrics
        SystemInfo = @{
            Platform = $PSVersionTable.Platform
            PSVersion = $PSVersionTable.PSVersion.ToString()
            Computer = $env:COMPUTERNAME ?? $env:HOSTNAME
            User = $env:USERNAME ?? $env:USER
        }
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>$Title</title>
    <meta charset="utf-8">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .card { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: #ecf0f1; border-radius: 5px; min-width: 150px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; color: #3498db; }
        .metric-label { color: #7f8c8d; margin-top: 5px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #bdc3c7; padding: 10px; text-align: left; }
        th { background: #34495e; color: white; }
        .status-pass { color: #27ae60; font-weight: bold; }
        .status-fail { color: #e74c3c; font-weight: bold; }
        .status-warning { color: #f39c12; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>$Title</h1>
        <p>Generated: $($dashboardData.Timestamp)</p>
    </div>
    
    <div class="card">
        <h2>System Information</h2>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Platform</td><td>$($dashboardData.SystemInfo.Platform)</td></tr>
            <tr><td>PowerShell Version</td><td>$($dashboardData.SystemInfo.PSVersion)</td></tr>
            <tr><td>Computer</td><td>$($dashboardData.SystemInfo.Computer)</td></tr>
            <tr><td>User</td><td>$($dashboardData.SystemInfo.User)</td></tr>
        </table>
    </div>
"@

    if ($Metrics.Count -gt 0) {
        $html += @"
    <div class="card">
        <h2>Metrics</h2>
        <div>
"@
        foreach ($metric in $Metrics.Keys) {
            $value = $Metrics[$metric]
            $html += @"
            <div class="metric">
                <div class="metric-value">$value</div>
                <div class="metric-label">$metric</div>
            </div>
"@
        }
        $html += "</div></div>"
    }

    $html += "</body></html>"

    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Set-Content -Path $OutputPath -Value $html -Encoding UTF8
    
    Write-Host "Dashboard created: $OutputPath" -ForegroundColor Green
    return $OutputPath
}

function Export-MetricsReport {
    <#
    .SYNOPSIS
        Export system metrics to a report
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath,
        [ValidateSet('JSON', 'HTML', 'CSV')]
        [string]$Format = 'JSON',
        [switch]$IncludeSystemInfo
    )

    if (-not $OutputPath) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd-HHmm'
        $extension = $Format.ToLower()
        $OutputPath = Join-Path $env:AITHERZERO_ROOT "reports/metrics-$timestamp.$extension"
    }

    $metrics = @{
        Timestamp = Get-Date
        InfrastructureTool = (Test-OpenTofu).Tool
        SecurityCompliance = (Test-SecurityCompliance)
    }

    if ($IncludeSystemInfo) {
        $metrics.SystemInfo = @{
            Platform = $PSVersionTable.Platform
            PSVersion = $PSVersionTable.PSVersion.ToString()
            Computer = $env:COMPUTERNAME ?? $env:HOSTNAME
            User = $env:USERNAME ?? $env:USER
            ProcessId = $PID
        }
    }

    switch ($Format) {
        'JSON' {
            $metrics | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        }
        'HTML' {
            New-ExecutionDashboard -Title "Metrics Report" -OutputPath $OutputPath -Metrics $metrics
        }
        'CSV' {
            # Flatten metrics for CSV
            $flatMetrics = @()
            foreach ($key in $metrics.Keys) {
                $value = $metrics[$key]
                if ($value -is [hashtable] -or $value -is [PSCustomObject]) {
                    $value = $value | ConvertTo-Json -Compress
                }
                $flatMetrics += [PSCustomObject]@{
                    Metric = $key
                    Value = $value
                }
            }
            $flatMetrics | Export-Csv -Path $OutputPath -NoTypeInformation
        }
    }

    Write-Host "Metrics report exported: $OutputPath" -ForegroundColor Green
    return $OutputPath
}

function Get-TechDebtAnalysis {
    <#
    .SYNOPSIS
        Analyze technical debt in the project
    #>
    [CmdletBinding()]
    param(
        [string]$ProjectPath = $env:AITHERZERO_ROOT,
        [string[]]$FileTypes = @('*.ps1', '*.psm1', '*.psd1')
    )

    $analysis = @{
        Timestamp = Get-Date
        ProjectPath = $ProjectPath
        Files = @()
        Summary = @{
            TotalFiles = 0
            TotalLines = 0
            LargeFiles = 0
            ComplexFunctions = 0
            TODOs = 0
            Duplicates = 0
        }
    }

    foreach ($pattern in $FileTypes) {
        $files = Get-ChildItem -Path $ProjectPath -Filter $pattern -Recurse -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
            $lineCount = $content.Count
            
            # Count TODOs and FIXMEs
            $todos = ($content | Select-String -Pattern 'TODO|FIXME|HACK|BUG' -AllMatches).Count
            
            # Check if file is large (>500 lines)
            $isLarge = $lineCount -gt 500
            
            $fileAnalysis = @{
                Path = $file.FullName
                Lines = $lineCount
                IsLarge = $isLarge
                TODOs = $todos
                LastModified = $file.LastWriteTime
            }
            
            $analysis.Files += $fileAnalysis
            $analysis.Summary.TotalFiles++
            $analysis.Summary.TotalLines += $lineCount
            $analysis.Summary.TODOs += $todos
            
            if ($isLarge) {
                $analysis.Summary.LargeFiles++
            }
        }
    }

    return $analysis
}

#endregion

# Initialize components
Initialize-SecurityConfiguration

if (Get-Command Write-InfraLog -ErrorAction SilentlyContinue) {
    Write-InfraLog -Message "Infrastructure module initialized" -Data @{
        OpenTofuAvailable = (Test-OpenTofu).Available
        TerraformAvailable = (Test-OpenTofu).Tool -eq 'terraform'
    }
}

# Export functions
Export-ModuleMember -Function @(
    # Infrastructure
    'Test-OpenTofu',
    'Get-InfrastructureTool',
    'Invoke-InfrastructurePlan',
    'Invoke-InfrastructureApply',
    'Invoke-InfrastructureDestroy',
    
    # Security
    'Test-SecurityRequirements',
    'Initialize-SecurityConfiguration',
    'Test-SecurityCompliance',
    
    # Reporting
    'New-ExecutionDashboard',
    'Export-MetricsReport',
    'Get-TechDebtAnalysis'
)