#Requires -Version 7.0

<#
.SYNOPSIS
    Run security vulnerability scanning
.DESCRIPTION
    Performs comprehensive security scanning including dependency checks,
    code vulnerability detection, and sensitive data exposure checks.
    
    Exit Codes:
    0 - No critical vulnerabilities found
    1 - Critical vulnerabilities detected
    2 - Error during scanning
    
.NOTES
    Stage: Security
    Order: 0523
    Dependencies: None
    Tags: security, vulnerability, scanning, compliance
#>

[CmdletBinding()]
param(
    [ValidateSet('Quick', 'Standard', 'Comprehensive')]
    [string]$ScanLevel = 'Standard',
    
    [string[]]$ExcludePaths = @('tests', 'examples', '.git'),
    
    [switch]$GenerateReport,
    
    [switch]$CI,
    
    [switch]$FailOnWarning
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Security'
    Order = 0523
    Dependencies = @()
    Tags = @('security', 'vulnerability', 'scanning', 'compliance')
    RequiresAdmin = $false
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = @{
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Information' = 'White'
        'Success' = 'Green'
    }[$Level]
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message "[Security] $Message"
    }
}

try {
    Write-ScriptLog -Message "Starting security vulnerability scanning (Level: $ScanLevel)"
    
    $findings = @{
        Critical = @()
        High = @()
        Medium = @()
        Low = @()
        Info = @()
    }
    
    # === 1. Check for hardcoded secrets and sensitive data ===
    Write-ScriptLog -Message "Scanning for hardcoded secrets..."
    
    $secretPatterns = @{
        'API Key' = @(
            "api[_-]?key\s*[:=]\s*[`"'][^`"']+[`"']"
            "apikey\s*[:=]\s*[`"'][^`"']+[`"']"
        )
        'Password' = @(
            "password\s*[:=]\s*[`"'][^`"']+[`"']"
            "pwd\s*[:=]\s*[`"'][^`"']+[`"']"
            "ConvertTo-SecureString\s+[`"'][^`"']+[`"']\s+-AsPlainText"
        )
        'Token' = @(
            "token\s*[:=]\s*[`"'][^`"']+[`"']"
            "bearer\s+[`"'][^`"']+[`"']"
            "auth.*token\s*[:=]\s*[`"'][^`"']+[`"']"
        )
        'Connection String' = @(
            'Data Source=.*;.*Password='
            'Server=.*;.*Pwd='
            'mongodb://[^@]+@'
        )
        'Private Key' = @(
            '-----BEGIN (RSA |EC )?PRIVATE KEY-----'
            '-----BEGIN OPENSSH PRIVATE KEY-----'
        )
    }
    
    $filesToScan = Get-ChildItem -Path . -Recurse -Include "*.ps1","*.psm1","*.psd1","*.json","*.xml","*.yml","*.yaml","*.config" |
        Where-Object { 
            $file = $_
            -not ($ExcludePaths | Where-Object { $file.FullName -like "*$_*" })
        }
    
    foreach ($category in $secretPatterns.Keys) {
        foreach ($pattern in $secretPatterns[$category]) {
            $matches = $filesToScan | Select-String -Pattern $pattern
            
            foreach ($match in $matches) {
                # Check if it's a false positive (commented out, in test file, etc.)
                $line = $match.Line.Trim()
                if ($line -match '^\s*#' -or $line -match '^\s*//') {
                    continue
                }
                
                $finding = @{
                    Type = $category
                    File = $match.Path
                    Line = $match.LineNumber
                    Pattern = $pattern
                    Content = if ($line.Length -gt 80) { $line.Substring(0, 77) + "..." } else { $line }
                }
                
                $findings.Critical += $finding
                Write-ScriptLog -Level Warning -Message "Found potential $category in $($match.Path):$($match.LineNumber)"
            }
        }
    }
    
    # === 2. Check for dangerous PowerShell patterns ===
    Write-ScriptLog -Message "Scanning for dangerous code patterns..."
    
    $dangerousPatterns = @{
        'Code Injection' = @{
            Patterns = @('Invoke-Expression', 'iex\s+', '\[System\.CodeDom\.Compiler')
            Severity = 'High'
        }
        'Unrestricted Execution' = @{
            Patterns = @('Set-ExecutionPolicy\s+Unrestricted', 'Set-ExecutionPolicy\s+Bypass')
            Severity = 'High'
        }
        'Credential Exposure' = @{
            Patterns = @('Get-Credential.*\$null', '\$cred\.GetNetworkCredential\(\)\.Password')
            Severity = 'High'
        }
        'Unsafe Web Request' = @{
            Patterns = @('ServerCertificateValidationCallback.*\$true', 'SkipCertificateCheck')
            Severity = 'Medium'
        }
        'Weak Cryptography' = @{
            Patterns = @('MD5CryptoServiceProvider', 'SHA1CryptoServiceProvider', 'DESCryptoServiceProvider')
            Severity = 'Medium'
        }
    }
    
    foreach ($category in $dangerousPatterns.Keys) {
        $config = $dangerousPatterns[$category]
        
        foreach ($pattern in $config.Patterns) {
            $matches = $filesToScan | Select-String -Pattern $pattern
            
            foreach ($match in $matches) {
                $finding = @{
                    Type = $category
                    File = $match.Path
                    Line = $match.LineNumber
                    Pattern = $pattern
                    Content = $match.Line.Trim()
                }
                
                $findings[$config.Severity] += $finding
                Write-ScriptLog -Level Warning -Message "Found $category pattern in $($match.Path):$($match.LineNumber)"
            }
        }
    }
    
    # === 3. Check file permissions (if not Windows) ===
    if (-not $IsWindows) {
        Write-ScriptLog -Message "Checking file permissions..."
        
        $executableScripts = Get-ChildItem -Path . -Recurse -Include "*.ps1","*.sh" |
            Where-Object { 
                $file = $_
                -not ($ExcludePaths | Where-Object { $file.FullName -like "*$_*" })
            }
        
        foreach ($script in $executableScripts) {
            $permissions = (stat -c "%a" $script.FullName 2>$null) -as [int]
            if ($permissions -and ($permissions -band 0002)) {
                # World-writable
                $findings.High += @{
                    Type = 'World-Writable File'
                    File = $script.FullName
                    Permissions = $permissions
                }
                Write-ScriptLog -Level Warning -Message "World-writable file: $($script.FullName)"
            }
        }
    }
    
    # === 4. Check for outdated dependencies ===
    if ($ScanLevel -in @('Standard', 'Comprehensive')) {
        Write-ScriptLog -Message "Checking for outdated dependencies..."
        
        # Check PowerShell modules
        if (Test-Path "./requirements.psd1") {
            $requirements = Import-PowerShellDataFile "./requirements.psd1"
            foreach ($module in $requirements.Modules) {
                $installed = Get-Module -ListAvailable -Name $module.Name | Select-Object -First 1
                if ($installed) {
                    $latest = Find-Module -Name $module.Name -ErrorAction SilentlyContinue
                    if ($latest -and $latest.Version -gt $installed.Version) {
                        $findings.Low += @{
                            Type = 'Outdated Module'
                            Module = $module.Name
                            Current = $installed.Version
                            Latest = $latest.Version
                        }
                    }
                }
            }
        }
    }
    
    # === 5. Check for missing security headers in web configs ===
    $webConfigs = Get-ChildItem -Path . -Recurse -Include "web.config","*.json" |
        Where-Object { $_.Name -match 'appsettings|config' }
    
    foreach ($config in $webConfigs) {
        $content = Get-Content $config.FullName -Raw
        
        # Check for missing HTTPS enforcement
        if ($content -notmatch 'requireHttps|RequireSSL|https:\/\/') {
            $findings.Medium += @{
                Type = 'Missing HTTPS Enforcement'
                File = $config.FullName
            }
        }
    }
    
    # === 6. Generate Summary ===
    Write-Host "`n════════════════════════════════════════" -ForegroundColor Blue
    Write-Host " Security Scan Results" -ForegroundColor White
    Write-Host "════════════════════════════════════════" -ForegroundColor Blue
    
    $totalFindings = 0
    foreach ($severity in @('Critical', 'High', 'Medium', 'Low', 'Info')) {
        $count = @($findings[$severity]).Count
        $totalFindings += $count
        
        $color = switch($severity) {
            'Critical' { 'Red' }
            'High' { 'DarkRed' }
            'Medium' { 'Yellow' }
            'Low' { 'DarkYellow' }
            'Info' { 'Gray' }
        }
        
        if ($count -gt 0) {
            Write-Host "  $severity : $count finding(s)" -ForegroundColor $color
        }
    }
    
    if ($totalFindings -eq 0) {
        Write-Host "`n✅ No security vulnerabilities detected!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  Total findings: $totalFindings" -ForegroundColor Yellow
    }
    
    # === 7. Generate Report ===
    if ($GenerateReport) {
        $reportPath = "./tests/security"
        if (-not (Test-Path $reportPath)) {
            New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $reportFile = "$reportPath/SecurityScan-$timestamp.json"
        
        $report = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ScanLevel = $ScanLevel
            TotalFindings = $totalFindings
            Findings = $findings
            Summary = @{
                Critical = @($findings.Critical).Count
                High = @($findings.High).Count
                Medium = @($findings.Medium).Count
                Low = @($findings.Low).Count
                Info = @($findings.Info).Count
            }
        }
        
        $report | ConvertTo-Json -Depth 10 | Set-Content $reportFile
        Write-ScriptLog -Message "Security report saved to: $reportFile"
        
        # Generate SARIF for GitHub if in CI
        if ($CI) {
            $sarif = @{
                version = "2.1.0"
                runs = @(@{
                    tool = @{
                        driver = @{
                            name = "AitherZero Security Scanner"
                            version = "1.0.0"
                        }
                    }
                    results = @()
                })
            }
            
            foreach ($severity in $findings.Keys) {
                foreach ($finding in $findings[$severity]) {
                    if ($finding.File) {
                        $sarif.runs[0].results += @{
                            ruleId = $finding.Type -replace ' ', '-'
                            level = if ($severity -eq 'Critical') { 'error' } 
                                   elseif ($severity -eq 'High') { 'error' }
                                   elseif ($severity -eq 'Medium') { 'warning' }
                                   else { 'note' }
                            message = @{ 
                                text = "$($finding.Type): $($finding.Content ?? 'Security vulnerability detected')"
                            }
                            locations = @(@{
                                physicalLocation = @{
                                    artifactLocation = @{ 
                                        uri = $finding.File -replace '\\', '/' -replace '^\./', ''
                                    }
                                    region = @{
                                        startLine = $finding.Line ?? 1
                                    }
                                }
                            })
                        }
                    }
                }
            }
            
            $sarifFile = "$reportPath/security-scan.sarif"
            $sarif | ConvertTo-Json -Depth 10 | Set-Content $sarifFile
            Write-ScriptLog -Message "SARIF report saved to: $sarifFile"
        }
    }
    
    # === 8. Exit based on findings ===
    if (@($findings.Critical).Count -gt 0) {
        Write-ScriptLog -Level Error -Message "Critical security vulnerabilities found!"
        exit 1
    }
    
    if (@($findings.High).Count -gt 0 -and $FailOnWarning) {
        Write-ScriptLog -Level Error -Message "High severity vulnerabilities found with FailOnWarning enabled"
        exit 1
    }
    
    Write-ScriptLog -Level Success -Message "Security scan completed successfully"
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Security scan failed: $_"
    exit 2
}