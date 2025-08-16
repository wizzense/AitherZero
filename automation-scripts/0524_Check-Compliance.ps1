#Requires -Version 7.0

<#
.SYNOPSIS
    Run compliance checks for policies, licenses, and standards
.DESCRIPTION
    Performs comprehensive compliance checking including:
    - License compatibility
    - Security policy compliance
    - Code of conduct presence
    - Dependency vulnerabilities
    - Signed commits verification
    - Regulatory compliance checks
    
    Exit Codes:
    0 - All compliance checks passed
    1 - Compliance violations found
    2 - Error during compliance check
    
.NOTES
    Stage: Compliance
    Order: 0524
    Dependencies: None
    Tags: compliance, audit, governance, security
#>

[CmdletBinding()]
param(
    [ValidateSet('Quick', 'Standard', 'Full')]
    [string]$AuditLevel = 'Standard',
    
    [switch]$CheckLicenses,
    
    [switch]$CheckDependencies,
    
    [switch]$CheckSecurityPolicies,
    
    [switch]$CheckSignedCommits,
    
    [switch]$GenerateReport,
    
    [switch]$CI,
    
    [switch]$FailOnWarning
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Compliance'
    Order = 0524
    Dependencies = @()
    Tags = @('compliance', 'audit', 'governance', 'security')
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
        Write-CustomLog -Level $Level -Message "[Compliance] $Message"
    }
}

try {
    Write-ScriptLog -Message "Starting compliance check (Level: $AuditLevel)"
    
    $complianceResults = @{
        Passed = @()
        Failed = @()
        Warnings = @()
        Info = @()
    }
    
    # === 1. Check Required Policy Documents ===
    Write-ScriptLog -Message "Checking required policy documents..."
    
    $requiredDocs = @{
        'LICENSE' = 'License file'
        'README.md' = 'Project documentation'
        'SECURITY.md' = 'Security policy'
        'CODE_OF_CONDUCT.md' = 'Code of conduct'
        'CONTRIBUTING.md' = 'Contribution guidelines'
        '.github/CODEOWNERS' = 'Code ownership'
    }
    
    foreach ($doc in $requiredDocs.Keys) {
        $docPath = Join-Path $PSScriptRoot ".." $doc
        if (Test-Path $docPath) {
            $complianceResults.Passed += @{
                Type = 'Policy Document'
                Item = $doc
                Status = 'Present'
            }
            Write-ScriptLog -Level Success -Message "✓ Found $($requiredDocs[$doc]): $doc"
        } else {
            if ($doc -in @('LICENSE', 'README.md')) {
                # Critical documents
                $complianceResults.Failed += @{
                    Type = 'Policy Document'
                    Item = $doc
                    Status = 'Missing'
                    Severity = 'High'
                }
                Write-ScriptLog -Level Error -Message "✗ Missing required document: $doc"
            } else {
                # Recommended documents
                $complianceResults.Warnings += @{
                    Type = 'Policy Document'
                    Item = $doc
                    Status = 'Missing'
                    Severity = 'Medium'
                }
                Write-ScriptLog -Level Warning -Message "⚠ Missing recommended document: $doc"
            }
        }
    }
    
    # === 2. Check License Compliance ===
    if ($CheckLicenses -or $AuditLevel -in @('Standard', 'Full')) {
        Write-ScriptLog -Message "Checking license compliance..."
        
        # Check main LICENSE file
        $licensePath = Join-Path $PSScriptRoot ".." "LICENSE"
        if (Test-Path $licensePath) {
            $licenseContent = Get-Content $licensePath -Raw
            
            # Detect license type
            $licenseType = switch -Regex ($licenseContent) {
                'MIT License' { 'MIT' }
                'Apache License.*2\.0' { 'Apache-2.0' }
                'GNU GENERAL PUBLIC LICENSE.*Version 3' { 'GPL-3.0' }
                'BSD 3-Clause' { 'BSD-3-Clause' }
                'Mozilla Public License 2\.0' { 'MPL-2.0' }
                default { 'Unknown' }
            }
            
            $complianceResults.Passed += @{
                Type = 'License'
                Item = 'Project License'
                Value = $licenseType
            }
            Write-ScriptLog -Level Success -Message "✓ Project license: $licenseType"
            
            # Check for license headers in source files
            if ($AuditLevel -eq 'Full') {
                $sourceFiles = Get-ChildItem -Path . -Recurse -Include "*.ps1","*.psm1" |
                    Where-Object { $_.FullName -notlike "*tests*" -and $_.FullName -notlike "*node_modules*" }
                
                $filesWithoutHeaders = @()
                foreach ($file in $sourceFiles) {
                    $content = Get-Content $file.FullName -First 10 -Raw
                    if ($content -notmatch 'Copyright|License|MIT|Apache|GPL|BSD|MPL') {
                        $filesWithoutHeaders += $file.Name
                    }
                }
                
                if ($filesWithoutHeaders.Count -gt 0) {
                    $complianceResults.Warnings += @{
                        Type = 'License Headers'
                        Count = $filesWithoutHeaders.Count
                        Files = $filesWithoutHeaders | Select-Object -First 5
                    }
                    Write-ScriptLog -Level Warning -Message "⚠ $($filesWithoutHeaders.Count) files missing license headers"
                }
            }
        } else {
            $complianceResults.Failed += @{
                Type = 'License'
                Item = 'LICENSE file'
                Status = 'Missing'
                Severity = 'Critical'
            }
            Write-ScriptLog -Level Error -Message "✗ LICENSE file not found"
        }
    }
    
    # === 3. Check Dependency Compliance ===
    if ($CheckDependencies -or $AuditLevel -in @('Standard', 'Full')) {
        Write-ScriptLog -Message "Checking dependency compliance..."
        
        # Check PowerShell module dependencies
        if (Test-Path "./requirements.psd1") {
            $requirements = Import-PowerShellDataFile "./requirements.psd1"
            
            foreach ($module in $requirements.Modules) {
                # Check if module is from trusted source
                $moduleInfo = Find-Module -Name $module.Name -ErrorAction SilentlyContinue
                if ($moduleInfo) {
                    if ($moduleInfo.CompanyName -in @('Microsoft Corporation', 'Microsoft', 'PowerShell Team')) {
                        $complianceResults.Passed += @{
                            Type = 'Dependency'
                            Module = $module.Name
                            Publisher = $moduleInfo.CompanyName
                            Status = 'Trusted'
                        }
                    } else {
                        $complianceResults.Warnings += @{
                            Type = 'Dependency'
                            Module = $module.Name
                            Publisher = $moduleInfo.CompanyName
                            Status = 'Third-party'
                        }
                        Write-ScriptLog -Level Warning -Message "⚠ Third-party dependency: $($module.Name) by $($moduleInfo.CompanyName)"
                    }
                }
            }
        }
        
        # Check for known vulnerable dependencies
        $vulnerableDependencies = @{
            'Log4j' = '< 2.17.0'
            'jQuery' = '< 3.6.0'
            'Bootstrap' = '< 4.6.0'
        }
        
        foreach ($dep in $vulnerableDependencies.Keys) {
            $found = Get-ChildItem -Path . -Recurse -Filter "*$dep*" -ErrorAction SilentlyContinue
            if ($found) {
                $complianceResults.Warnings += @{
                    Type = 'Vulnerable Dependency'
                    Dependency = $dep
                    Criteria = $vulnerableDependencies[$dep]
                }
                Write-ScriptLog -Level Warning -Message "⚠ Potentially vulnerable dependency found: $dep"
            }
        }
    }
    
    # === 4. Check Security Policies ===
    if ($CheckSecurityPolicies -or $AuditLevel -eq 'Full') {
        Write-ScriptLog -Message "Checking security policy compliance..."
        
        # Check for security.txt
        $securityTxtPath = "./.well-known/security.txt"
        if (Test-Path $securityTxtPath) {
            $complianceResults.Passed += @{
                Type = 'Security'
                Item = 'security.txt'
                Status = 'Present'
            }
        } else {
            $complianceResults.Info += @{
                Type = 'Security'
                Item = 'security.txt'
                Status = 'Missing'
                Recommendation = 'Consider adding .well-known/security.txt for vulnerability disclosure'
            }
        }
        
        # Check branch protection (if git repo)
        if (Test-Path ".git") {
            $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null | ForEach-Object { $_ -replace '.*/', '' }
            if ($defaultBranch) {
                # Check if main/master branch exists
                $complianceResults.Passed += @{
                    Type = 'Git'
                    Item = 'Default Branch'
                    Value = $defaultBranch
                }
                Write-ScriptLog -Level Success -Message "✓ Default branch: $defaultBranch"
            }
        }
    }
    
    # === 5. Check Signed Commits (if requested) ===
    if ($CheckSignedCommits -and (Test-Path ".git")) {
        Write-ScriptLog -Message "Checking commit signatures..."
        
        $unsignedCommits = git log --format="%H %G? %s" -n 20 2>$null | Where-Object { $_ -match '^[a-f0-9]+ N' }
        
        if ($unsignedCommits) {
            $complianceResults.Warnings += @{
                Type = 'Git Security'
                Item = 'Unsigned Commits'
                Count = @($unsignedCommits).Count
                Recent = @($unsignedCommits | Select-Object -First 3)
            }
            Write-ScriptLog -Level Warning -Message "⚠ Found $(@($unsignedCommits).Count) unsigned commits in recent history"
        } else {
            $complianceResults.Passed += @{
                Type = 'Git Security'
                Item = 'Commit Signatures'
                Status = 'All signed'
            }
            Write-ScriptLog -Level Success -Message "✓ All recent commits are signed"
        }
    }
    
    # === 6. Check Data Privacy Compliance ===
    if ($AuditLevel -eq 'Full') {
        Write-ScriptLog -Message "Checking data privacy compliance..."
        
        # Check for GDPR/Privacy policy
        $privacyDocs = @('PRIVACY.md', 'PRIVACY_POLICY.md', 'docs/privacy.md')
        $hasPrivacyDoc = $false
        
        foreach ($doc in $privacyDocs) {
            if (Test-Path $doc) {
                $hasPrivacyDoc = $true
                $complianceResults.Passed += @{
                    Type = 'Privacy'
                    Item = 'Privacy Policy'
                    Location = $doc
                }
                break
            }
        }
        
        if (-not $hasPrivacyDoc) {
            $complianceResults.Info += @{
                Type = 'Privacy'
                Item = 'Privacy Policy'
                Status = 'Not found'
                Note = 'Consider adding if handling personal data'
            }
        }
        
        # Check for PII in code
        Write-ScriptLog -Message "Scanning for potential PII exposure..."
        $piiPatterns = @(
            '\b\d{3}-\d{2}-\d{4}\b'  # SSN
            '\b[A-Z]{2}\d{6}\b'       # Passport
            '\b\d{16}\b'              # Credit card
            '\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'  # Email (in code)
        )
        
        $sourceFiles = Get-ChildItem -Path . -Recurse -Include "*.ps1","*.psm1","*.json" |
            Where-Object { $_.FullName -notlike "*tests*" }
        
        $piiFindings = @()
        foreach ($pattern in $piiPatterns) {
            $matches = $sourceFiles | Select-String -Pattern $pattern
            if ($matches) {
                $piiFindings += $matches
            }
        }
        
        if ($piiFindings.Count -gt 0) {
            $complianceResults.Warnings += @{
                Type = 'Privacy'
                Item = 'Potential PII'
                Count = $piiFindings.Count
                Note = 'Review for false positives'
            }
            Write-ScriptLog -Level Warning -Message "⚠ Found $($piiFindings.Count) potential PII patterns"
        }
    }
    
    # === 7. Generate Summary ===
    Write-Host "`n════════════════════════════════════════" -ForegroundColor Blue
    Write-Host " Compliance Check Results" -ForegroundColor White
    Write-Host "════════════════════════════════════════" -ForegroundColor Blue
    
    Write-Host "`n✅ Passed: $(@($complianceResults.Passed).Count)" -ForegroundColor Green
    Write-Host "❌ Failed: $(@($complianceResults.Failed).Count)" -ForegroundColor Red
    Write-Host "⚠️  Warnings: $(@($complianceResults.Warnings).Count)" -ForegroundColor Yellow
    Write-Host "ℹ️  Info: $(@($complianceResults.Info).Count)" -ForegroundColor Cyan
    
    $totalIssues = @($complianceResults.Failed).Count + @($complianceResults.Warnings).Count
    
    if (@($complianceResults.Failed).Count -eq 0) {
        if (@($complianceResults.Warnings).Count -eq 0) {
            Write-Host "`n🎉 All compliance checks passed!" -ForegroundColor Green
        } else {
            Write-Host "`n✅ No critical compliance issues, but $(@($complianceResults.Warnings).Count) warning(s) found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n❌ Critical compliance issues found!" -ForegroundColor Red
    }
    
    # === 8. Generate Report ===
    if ($GenerateReport) {
        $reportPath = "./tests/compliance"
        if (-not (Test-Path $reportPath)) {
            New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $reportFile = "$reportPath/ComplianceReport-$timestamp.json"
        
        $report = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            AuditLevel = $AuditLevel
            Summary = @{
                Passed = @($complianceResults.Passed).Count
                Failed = @($complianceResults.Failed).Count
                Warnings = @($complianceResults.Warnings).Count
                Info = @($complianceResults.Info).Count
            }
            Results = $complianceResults
            Compliant = @($complianceResults.Failed).Count -eq 0
        }
        
        $report | ConvertTo-Json -Depth 10 | Set-Content $reportFile
        Write-ScriptLog -Message "Compliance report saved to: $reportFile"
        
        # Generate HTML report for better readability
        $htmlFile = "$reportPath/ComplianceReport-$timestamp.html"
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Compliance Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
               margin: 2rem; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; 
                    padding: 2rem; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007acc; padding-bottom: 1rem; }
        .summary { display: flex; gap: 2rem; margin: 2rem 0; }
        .stat { flex: 1; padding: 1rem; border-radius: 8px; text-align: center; }
        .stat.passed { background: #d4edda; color: #155724; }
        .stat.failed { background: #f8d7da; color: #721c24; }
        .stat.warning { background: #fff3cd; color: #856404; }
        .stat.info { background: #d1ecf1; color: #0c5460; }
        .stat-number { font-size: 2rem; font-weight: bold; }
        .stat-label { font-size: 0.9rem; margin-top: 0.5rem; }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.75rem; text-align: left; border-bottom: 1px solid #dee2e6; }
        th { background: #f8f9fa; font-weight: 600; }
        .badge { padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.875rem; }
        .badge.passed { background: #28a745; color: white; }
        .badge.failed { background: #dc3545; color: white; }
        .badge.warning { background: #ffc107; color: #333; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Compliance Audit Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Level: $AuditLevel</p>
        
        <div class="summary">
            <div class="stat passed">
                <div class="stat-number">$(@($complianceResults.Passed).Count)</div>
                <div class="stat-label">Passed</div>
            </div>
            <div class="stat failed">
                <div class="stat-number">$(@($complianceResults.Failed).Count)</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat warning">
                <div class="stat-number">$(@($complianceResults.Warnings).Count)</div>
                <div class="stat-label">Warnings</div>
            </div>
            <div class="stat info">
                <div class="stat-number">$(@($complianceResults.Info).Count)</div>
                <div class="stat-label">Info</div>
            </div>
        </div>
        
        <h2>Compliance Status: $(if (@($complianceResults.Failed).Count -eq 0) { '✅ COMPLIANT' } else { '❌ NON-COMPLIANT' })</h2>
        
        $(if (@($complianceResults.Failed).Count -gt 0) {
            '<h3>❌ Failed Checks</h3><table><tr><th>Type</th><th>Item</th><th>Details</th></tr>'
            foreach ($item in $complianceResults.Failed) {
                "<tr><td>$($item.Type)</td><td>$($item.Item)</td><td>$($item.Status)</td></tr>"
            }
            '</table>'
        })
        
        $(if (@($complianceResults.Warnings).Count -gt 0) {
            '<h3>⚠️ Warnings</h3><table><tr><th>Type</th><th>Item</th><th>Details</th></tr>'
            foreach ($item in $complianceResults.Warnings) {
                "<tr><td>$($item.Type)</td><td>$($item.Item ?? $item.Module ?? 'N/A')</td><td>$($item.Status ?? $item.Publisher ?? 'See details')</td></tr>"
            }
            '</table>'
        })
        
        <h3>✅ Passed Checks</h3>
        <p>$(@($complianceResults.Passed).Count) checks passed successfully.</p>
    </div>
</body>
</html>
"@
        $html | Set-Content $htmlFile
        Write-ScriptLog -Message "HTML report saved to: $htmlFile"
    }
    
    # === 9. Exit based on results ===
    if (@($complianceResults.Failed).Count -gt 0) {
        Write-ScriptLog -Level Error -Message "Compliance check failed with $(@($complianceResults.Failed).Count) critical issue(s)"
        exit 1
    }
    
    if (@($complianceResults.Warnings).Count -gt 0 -and $FailOnWarning) {
        Write-ScriptLog -Level Error -Message "Compliance check failed with $(@($complianceResults.Warnings).Count) warning(s) (FailOnWarning enabled)"
        exit 1
    }
    
    Write-ScriptLog -Level Success -Message "Compliance check completed successfully"
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Compliance check failed: $_"
    exit 2
}