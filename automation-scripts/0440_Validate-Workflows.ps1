#Requires -Version 7.0

<#
.SYNOPSIS
    Validates GitHub Actions workflow files for syntax, schema compliance, and best practices
.DESCRIPTION
    Comprehensive validation of GitHub Actions workflows including:
    - YAML syntax validation
    - GitHub Actions schema compliance
    - Secret and variable references
    - Action version checks
    - Deprecated feature detection
    - Best practice analysis
.PARAMETER Path
    Path to workflow file or directory containing workflows
.PARAMETER Strict
    Enable strict validation mode (fails on warnings)
.PARAMETER AutoFix
    Attempt to auto-fix common issues
.PARAMETER OutputFormat
    Output format for validation results
.PARAMETER CI
    Running in CI environment
.PARAMETER WhatIf
    Preview what validation would be performed without executing
.EXAMPLE
    ./0440_Validate-Workflows.ps1 -Path .github/workflows
.EXAMPLE
    ./0440_Validate-Workflows.ps1 -Path .github/workflows/ci.yml -Strict -AutoFix
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string]$Path = ".github/workflows",
    
    [switch]$Strict,
    
    [switch]$AutoFix,
    
    [ValidateSet('Console', 'JSON', 'HTML', 'Markdown')]
    [string]$OutputFormat = 'Console',
    
    [string]$OutputPath = "./tests/results",
    
    [switch]$CI,
    
    [switch]$CheckDependencies,
    
    [switch]$CheckSecrets,
    
    [switch]$CheckDeprecated,
    
    [switch]$CheckBestPractices,
    
    [switch]$All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
if (Test-Path $script:LoggingModule) {
    Import-Module $script:LoggingModule -Force -ErrorAction SilentlyContinue
}

# Import Configuration module for auto-install settings
$script:ConfigModule = Join-Path $script:ProjectRoot "domains/configuration/Configuration.psm1"
if (Test-Path $script:ConfigModule) {
    Import-Module $script:ConfigModule -Force -ErrorAction SilentlyContinue
}

# Logging helper
function Write-ValidationLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "WorkflowValidation"
    } else {
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Success' { 'Green' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Initialize validation results
$script:ValidationResults = @{
    Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    TotalFiles = 0
    ValidFiles = 0
    InvalidFiles = 0
    Errors = @()
    Warnings = @()
    Info = @()
    FileResults = @{}
}

# GitHub Actions schema elements
$script:GitHubActionsSchema = @{
    RequiredKeys = @('name', 'on')
    ValidTriggers = @(
        'branch_protection_rule', 'check_run', 'check_suite', 'create', 'delete',
        'deployment', 'deployment_status', 'discussion', 'discussion_comment',
        'fork', 'gollum', 'issue_comment', 'issues', 'label', 'merge_group',
        'milestone', 'page_build', 'project', 'project_card', 'project_column',
        'public', 'pull_request', 'pull_request_comment', 'pull_request_review',
        'pull_request_review_comment', 'pull_request_target', 'push', 'registry_package',
        'release', 'repository_dispatch', 'schedule', 'status', 'watch',
        'workflow_call', 'workflow_dispatch', 'workflow_run'
    )
    ValidPermissions = @(
        'actions', 'checks', 'contents', 'deployments', 'discussions',
        'id-token', 'issues', 'packages', 'pages', 'pull-requests',
        'repository-projects', 'security-events', 'statuses'
    )
    DeprecatedActions = @{
        'actions/setup-node@v1' = 'Use actions/setup-node@v4 or later'
        'actions/checkout@v1' = 'Use actions/checkout@v4 or later'
        'actions/checkout@v2' = 'Use actions/checkout@v4 or later'
        'actions/upload-artifact@v1' = 'Use actions/upload-artifact@v4 or later'
        'actions/upload-artifact@v2' = 'Use actions/upload-artifact@v4 or later'
        'actions/download-artifact@v1' = 'Use actions/download-artifact@v4 or later'
        'actions/download-artifact@v2' = 'Use actions/download-artifact@v4 or later'
        'actions/cache@v1' = 'Use actions/cache@v4 or later'
        'actions/cache@v2' = 'Use actions/cache@v4 or later'
        'actions/github-script@v5' = 'Use actions/github-script@v7 or later'
        'actions/github-script@v6' = 'Use actions/github-script@v7 or later'
    }
    RequiredSecrets = @(
        'GITHUB_TOKEN', 'GITHUB_PAT'
    )
}

function Test-YamlSyntax {
    param(
        [string]$FilePath
    )
    
    try {
        # Try to use PowerShell-Yaml if available
        if (Get-Module -ListAvailable -Name powershell-yaml -ErrorAction SilentlyContinue) {
            Import-Module powershell-yaml -ErrorAction SilentlyContinue
            $content = Get-Content $FilePath -Raw
            $yaml = ConvertFrom-Yaml $content
            return @{
                Valid = $true
                Data = $yaml
            }
        }
        
        # Fallback to basic validation
        $content = Get-Content $FilePath -Raw
        
        # Check for basic YAML structure
        if ($content -match '^\s*$' -or -not $content) {
            throw "File is empty"
        }
        
        # Check for tab characters (YAML doesn't allow tabs for indentation)
        if ($content -match '\t') {
            throw "YAML files must use spaces for indentation, not tabs"
        }
        
        # Basic structure validation
        if ($content -notmatch '(?m)^name:' -and $content -notmatch '(?m)^on:') {
            throw "Missing required top-level keys (name, on)"
        }
        
        return @{
            Valid = $true
            Data = $null
            Warning = "Full YAML parsing not available. Install powershell-yaml module for complete validation"
        }
    }
    catch {
        return @{
            Valid = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-WorkflowSchema {
    param(
        [string]$FilePath,
        [object]$YamlData
    )
    
    $errors = @()
    $warnings = @()
    
    # If we couldn't parse YAML, do basic text validation
    if (-not $YamlData) {
        $content = Get-Content $FilePath -Raw
        
        # Check for required keys
        foreach ($key in $script:GitHubActionsSchema.RequiredKeys) {
            if ($content -notmatch "(?m)^${key}:") {
                $errors += "Missing required key: $key"
            }
        }
        
        # Check for common issues
        if ($content -match 'actions/[^@]+@master') {
            $warnings += "Using @master is not recommended. Pin to a specific version or SHA"
        }
        
        if ($content -match '\$\{\{.*github\.token.*\}\}') {
            $warnings += "Consider using secrets.GITHUB_TOKEN instead of github.token"
        }
    }
    else {
        # Full schema validation with parsed YAML
        foreach ($key in $script:GitHubActionsSchema.RequiredKeys) {
            if (-not $YamlData.ContainsKey($key)) {
                $errors += "Missing required key: $key"
            }
        }
        
        # Validate triggers
        if ($YamlData.on) {
            $triggers = if ($YamlData.on -is [string]) { @($YamlData.on) } else { $YamlData.on.Keys }
            foreach ($trigger in $triggers) {
                if ($trigger -notin $script:GitHubActionsSchema.ValidTriggers) {
                    $warnings += "Unknown trigger: $trigger"
                }
            }
        }
        
        # Validate permissions
        if ($YamlData.permissions) {
            $permissions = if ($YamlData.permissions -is [string]) { 
                @($YamlData.permissions) 
            } else { 
                $YamlData.permissions.Keys 
            }
            
            foreach ($perm in $permissions) {
                if ($perm -ne 'write-all' -and $perm -ne 'read-all' -and 
                    $perm -notin $script:GitHubActionsSchema.ValidPermissions) {
                    $warnings += "Unknown permission: $perm"
                }
            }
        }
        
        # Validate jobs
        if ($YamlData.jobs) {
            foreach ($jobName in $YamlData.jobs.Keys) {
                $job = $YamlData.jobs[$jobName]
                
                # Check runs-on
                if (-not $job.'runs-on') {
                    $errors += "Job '$jobName' missing 'runs-on'"
                }
                
                # Check for matrix strategy issues
                if ($job.PSObject.Properties.Name -contains 'strategy') {
                    if ($job.strategy -and $job.strategy.PSObject.Properties.Name -contains 'matrix') {
                        if ($job.'runs-on' -match '\$\{\{.*matrix.*\}\}') {
                            # This is fine, using matrix in runs-on
                        } elseif ($job.'runs-on' -is [array]) {
                            $warnings += "Job '$jobName' uses array for runs-on without matrix reference"
                        }
                    }
                }
            }
        }
    }
    
    return @{
        Errors = $errors
        Warnings = $warnings
    }
}

function Test-DeprecatedFeatures {
    param(
        [string]$FilePath
    )
    
    $content = Get-Content $FilePath -Raw
    $warnings = @()
    
    # Check for deprecated actions
    foreach ($deprecated in $script:GitHubActionsSchema.DeprecatedActions.GetEnumerator()) {
        if ($content -match [regex]::Escape($deprecated.Key)) {
            $warnings += "Deprecated action: $($deprecated.Key). $($deprecated.Value)"
        }
    }
    
    # Check for deprecated syntax
    if ($content -match 'set-output') {
        $warnings += "set-output is deprecated. Use >> \$env:GITHUB_OUTPUT instead"
    }
    
    if ($content -match 'set-state') {
        $warnings += "set-state is deprecated. Use >> \$env:GITHUB_STATE instead"
    }
    
    if ($content -match 'add-path') {
        $warnings += "add-path is deprecated. Use >> \$env:GITHUB_PATH instead"
    }
    
    if ($content -match 'set-env') {
        $warnings += "set-env is deprecated. Use >> \$env:GITHUB_ENV instead"
    }
    
    return $warnings
}

function Test-SecretReferences {
    param(
        [string]$FilePath
    )
    
    $content = Get-Content $FilePath -Raw
    $errors = @()
    $warnings = @()
    
    # Find all secret references
    $secretRefs = [regex]::Matches($content, '\$\{\{\s*secrets\.([A-Z_]+)\s*\}\}')
    
    foreach ($ref in $secretRefs) {
        $secretName = $ref.Groups[1].Value
        
        # Check for common required secrets
        if ($secretName -eq 'GITHUB_TOKEN') {
            # This is automatically provided
            continue
        }
        
        # Flag potentially missing secrets
        if ($secretName -match '^(AZURE|AWS|GCP)_') {
            $warnings += "Cloud provider secret referenced: $secretName - ensure it's configured in repository settings"
        }
        
        if ($secretName -match 'PASSWORD|KEY|TOKEN|SECRET') {
            $warnings += "Sensitive secret referenced: $secretName - ensure it's properly secured"
        }
    }
    
    # Check for hardcoded secrets
    if ($content -match '(api[_-]?key|password|token|secret)\s*[:=]\s*["''][^"'']+["'']' -and 
        $content -notmatch '\$\{\{') {
        $errors += "Potential hardcoded secret detected. Use GitHub secrets instead"
    }
    
    return @{
        Errors = $errors
        Warnings = $warnings
    }
}

function Test-BestPractices {
    param(
        [string]$FilePath
    )
    
    $content = Get-Content $FilePath -Raw
    $warnings = @()
    
    # Check for timeout-minutes
    if ($content -notmatch 'timeout-minutes:') {
        $warnings += "Consider setting timeout-minutes for jobs to prevent hanging workflows"
    }
    
    # Check for concurrency control
    if ($content -notmatch 'concurrency:') {
        $warnings += "Consider using concurrency to prevent duplicate workflow runs"
    }
    
    # Check for conditional steps
    if ($content -match 'if:\s*always\(\)' -and $content -notmatch 'if:\s*always\(\)\s*&&') {
        $warnings += "Using 'if: always()' without additional conditions can be dangerous"
    }
    
    # Check for artifact retention
    if ($content -match 'upload-artifact' -and $content -notmatch 'retention-days') {
        $warnings += "Consider setting retention-days for uploaded artifacts to manage storage"
    }
    
    # Check for checkout depth
    if ($content -match 'actions/checkout' -and $content -notmatch 'fetch-depth') {
        $warnings += "Consider setting fetch-depth for checkout to improve performance"
    }
    
    # Check for caching
    if ($content -match 'npm install|pip install|bundle install' -and $content -notmatch 'actions/cache') {
        $warnings += "Consider using actions/cache to speed up dependency installation"
    }
    
    return $warnings
}

function Invoke-WorkflowValidation {
    param(
        [string]$FilePath
    )
    
    Write-ValidationLog "Validating: $FilePath" -Level Information
    
    $fileResult = @{
        File = $FilePath
        Valid = $true
        Errors = @()
        Warnings = @()
        Info = @()
    }
    
    # 1. YAML Syntax validation
    $yamlResult = Test-YamlSyntax -FilePath $FilePath
    if (-not $yamlResult.Valid) {
        $fileResult.Valid = $false
        $fileResult.Errors += "YAML Syntax Error: $($yamlResult.Error)"
    } elseif ($yamlResult.ContainsKey('Warning') -and $yamlResult.Warning) {
        $fileResult.Warnings += $yamlResult.Warning
    }
    
    # 2. Schema validation
    $schemaResult = Test-WorkflowSchema -FilePath $FilePath -YamlData $yamlResult.Data
    $fileResult.Errors += $schemaResult.Errors
    $fileResult.Warnings += $schemaResult.Warnings
    
    # 3. Check deprecated features
    if ($CheckDeprecated -or $All) {
        $deprecatedWarnings = Test-DeprecatedFeatures -FilePath $FilePath
        $fileResult.Warnings += $deprecatedWarnings
    }
    
    # 4. Check secret references
    if ($CheckSecrets -or $All) {
        $secretResult = Test-SecretReferences -FilePath $FilePath
        $fileResult.Errors += $secretResult.Errors
        $fileResult.Warnings += $secretResult.Warnings
    }
    
    # 5. Check best practices
    if ($CheckBestPractices -or $All) {
        $bestPracticeWarnings = Test-BestPractices -FilePath $FilePath
        $fileResult.Warnings += $bestPracticeWarnings
    }
    
    # Update file validity based on errors
    if ($fileResult.Errors -and $fileResult.Errors.Count -gt 0) {
        $fileResult.Valid = $false
    }
    
    # In strict mode, warnings also fail validation
    if ($Strict -and $fileResult.Warnings -and $fileResult.Warnings.Count -gt 0) {
        $fileResult.Valid = $false
    }
    
    return $fileResult
}

function Format-ValidationOutput {
    param(
        [object]$Results,
        [string]$Format
    )
    
    switch ($Format) {
        'Console' {
            Write-Host ""
            Write-Host "=== GitHub Actions Workflow Validation Results ===" -ForegroundColor Cyan
            Write-Host "Timestamp: $($Results.Timestamp)" -ForegroundColor Gray
            Write-Host ""
            
            Write-Host "Summary:" -ForegroundColor Yellow
            Write-Host "  Total Files: $($Results.TotalFiles)"
            Write-Host "  Valid Files: $($Results.ValidFiles)" -ForegroundColor Green
            Write-Host "  Invalid Files: $($Results.InvalidFiles)" -ForegroundColor Red
            Write-Host ""
            
            foreach ($file in $Results.FileResults.Keys) {
                $result = $Results.FileResults[$file]
                $fileName = Split-Path $file -Leaf
                
                if ($result.Valid) {
                    Write-Host "✓ $fileName" -ForegroundColor Green
                } else {
                    Write-Host "✗ $fileName" -ForegroundColor Red
                }
                
                foreach ($err in $result.Errors) {
                    Write-Host "    ERROR: $err" -ForegroundColor Red
                }
                
                foreach ($warning in $result.Warnings) {
                    Write-Host "    WARNING: $warning" -ForegroundColor Yellow
                }
                
                foreach ($info in $result.Info) {
                    Write-Host "    INFO: $info" -ForegroundColor Cyan
                }
            }
            
            Write-Host ""
            if ($Results.InvalidFiles -gt 0) {
                Write-Host "Validation FAILED" -ForegroundColor Red
            } else {
                Write-Host "Validation PASSED" -ForegroundColor Green
            }
        }
        
        'JSON' {
            $Results | ConvertTo-Json -Depth 10
        }
        
        'Markdown' {
            $md = @"
# GitHub Actions Workflow Validation Report

**Generated:** $($Results.Timestamp)

## Summary

| Metric | Value |
|--------|-------|
| Total Files | $($Results.TotalFiles) |
| Valid Files | $($Results.ValidFiles) |
| Invalid Files | $($Results.InvalidFiles) |

## File Results

"@
            foreach ($file in $Results.FileResults.Keys) {
                $result = $Results.FileResults[$file]
                $fileName = Split-Path $file -Leaf
                $status = if ($result.Valid) { "✅" } else { "❌" }
                
                $md += "`n### $status $fileName`n`n"
                
                if ($result.Errors -and $result.Errors.Count -gt 0) {
                    $md += "**Errors:**`n"
                    foreach ($err in $result.Errors) {
                        $md += "- $err`n"
                    }
                }
                
                if ($result.Warnings -and $result.Warnings.Count -gt 0) {
                    $md += "`n**Warnings:**`n"
                    foreach ($warning in $result.Warnings) {
                        $md += "- $warning`n"
                    }
                }
                
                if ($result.Info -and $result.Info.Count -gt 0) {
                    $md += "`n**Info:**`n"
                    foreach ($info in $result.Info) {
                        $md += "- $info`n"
                    }
                }
            }
            
            $md
        }
        
        'HTML' {
            @"
<!DOCTYPE html>
<html>
<head>
    <title>Workflow Validation Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #24292e; border-bottom: 2px solid #e1e4e8; padding-bottom: 10px; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .summary-card { flex: 1; padding: 15px; border-radius: 6px; text-align: center; }
        .summary-card.total { background: #f1f8ff; border: 1px solid #c8e1ff; }
        .summary-card.valid { background: #dcffe4; border: 1px solid #34d058; }
        .summary-card.invalid { background: #ffeef0; border: 1px solid #d73a49; }
        .file-result { margin: 20px 0; padding: 15px; border-radius: 6px; border-left: 4px solid; }
        .file-result.valid { border-color: #28a745; background: #f0fff4; }
        .file-result.invalid { border-color: #dc3545; background: #fff5f5; }
        .file-name { font-weight: bold; font-size: 1.1em; margin-bottom: 10px; }
        .error { color: #d73a49; margin: 5px 0; padding-left: 20px; }
        .warning { color: #f9826c; margin: 5px 0; padding-left: 20px; }
        .info { color: #0366d6; margin: 5px 0; padding-left: 20px; }
        .timestamp { color: #586069; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>GitHub Actions Workflow Validation Report</h1>
        <p class="timestamp">Generated: $($Results.Timestamp)</p>
        
        <div class="summary">
            <div class="summary-card total">
                <h3>Total Files</h3>
                <div style="font-size: 2em;">$($Results.TotalFiles)</div>
            </div>
            <div class="summary-card valid">
                <h3>Valid</h3>
                <div style="font-size: 2em; color: #28a745;">$($Results.ValidFiles)</div>
            </div>
            <div class="summary-card invalid">
                <h3>Invalid</h3>
                <div style="font-size: 2em; color: #dc3545;">$($Results.InvalidFiles)</div>
            </div>
        </div>
        
        <h2>File Results</h2>
"@
            foreach ($file in $Results.FileResults.Keys) {
                $result = $Results.FileResults[$file]
                $fileName = Split-Path $file -Leaf
                $validClass = if ($result.Valid) { "valid" } else { "invalid" }
                
                $html += @"
        <div class="file-result $validClass">
            <div class="file-name">$(if ($result.Valid) { "✓" } else { "✗" }) $fileName</div>
"@
                foreach ($err in $result.Errors) {
                    $html += "            <div class='error'>❌ ERROR: $err</div>`n"
                }
                foreach ($warning in $result.Warnings) {
                    $html += "            <div class='warning'>⚠️ WARNING: $warning</div>`n"
                }
                foreach ($info in $result.Info) {
                    $html += "            <div class='info'>ℹ️ INFO: $info</div>`n"
                }
                $html += "        </div>`n"
            }
            
            $html += @"
    </div>
</body>
</html>
"@
            $html
        }
    }
}

# Main execution
try {
    Write-ValidationLog "Starting GitHub Actions workflow validation..." -Level Information
    
    # Check for powershell-yaml module and auto-install if configured
    if (-not (Get-Module -ListAvailable -Name powershell-yaml -ErrorAction SilentlyContinue)) {
        $autoInstall = if (Get-Command Get-ConfiguredValue -ErrorAction SilentlyContinue) {
            Get-ConfiguredValue -Name "AutoInstallDependencies" -Section "Automation" -Default $true
        } else {
            $false
        }
        
        if ($autoInstall -or $CheckDependencies) {
            Write-ValidationLog "powershell-yaml module not found. Installing for full YAML validation..." -Level Information
            
            # Install using the dedicated script
            $installScript = Join-Path $PSScriptRoot "0443_Install-PowerShellYaml.ps1"
            if (Test-Path $installScript) {
                try {
                    & $installScript -CI:$CI -Force:$false
                    
                    # Import the newly installed module
                    Import-Module powershell-yaml -ErrorAction SilentlyContinue
                    Write-ValidationLog "powershell-yaml module installed and loaded successfully" -Level Information
                } catch {
                    Write-ValidationLog "Failed to install powershell-yaml: $_" -Level Warning
                    Write-ValidationLog "Continuing with basic validation..." -Level Information
                }
            } else {
                Write-ValidationLog "Installation script not found: 0443_Install-PowerShellYaml.ps1" -Level Warning
            }
        } else {
            Write-ValidationLog "powershell-yaml module not found. Install for complete validation" -Level Warning
            Write-ValidationLog "Run with -CheckDependencies or enable AutoInstallDependencies in config" -Level Information
        }
    }
    
    # Check if path exists
    if (-not (Test-Path $Path)) {
        throw "Path not found: $Path"
    }
    
    # Get workflow files
    $workflowFiles = @(if (Test-Path $Path -PathType Container) {
        Get-ChildItem -Path $Path -Filter "*.yml" -File
        Get-ChildItem -Path $Path -Filter "*.yaml" -File
    } else {
        Get-Item $Path
    })
    
    if ($workflowFiles.Count -eq 0) {
        Write-ValidationLog "No workflow files found in: $Path" -Level Warning
        exit 0
    }
    
    Write-ValidationLog "Found $($workflowFiles.Count) workflow file(s)" -Level Information
    
    # Validate each file
    foreach ($file in $workflowFiles) {
        if ($PSCmdlet.ShouldProcess($file.FullName, "Validate workflow")) {
            $result = Invoke-WorkflowValidation -FilePath $file.FullName
            $script:ValidationResults.FileResults[$file.FullName] = $result
            $script:ValidationResults.TotalFiles++
            
            if ($result.Valid) {
                $script:ValidationResults.ValidFiles++
            } else {
                $script:ValidationResults.InvalidFiles++
            }
            
            # Add to global lists
            $script:ValidationResults.Errors += $result.Errors
            $script:ValidationResults.Warnings += $result.Warnings
            $script:ValidationResults.Info += $result.Info
        }
    }
    
    # Output results
    $output = Format-ValidationOutput -Results $script:ValidationResults -Format $OutputFormat
    
    if ($OutputFormat -eq 'Console') {
        # Already output to console
    } else {
        # Save to file
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $extension = switch ($OutputFormat) {
            'JSON' { 'json' }
            'HTML' { 'html' }
            'Markdown' { 'md' }
        }
        
        $outputFile = Join-Path $OutputPath "workflow-validation-$timestamp.$extension"
        $output | Set-Content -Path $outputFile
        Write-ValidationLog "Results saved to: $outputFile" -Level Information
    }
    
    # Exit with appropriate code
    if ($script:ValidationResults.InvalidFiles -gt 0) {
        if ($CI) {
            exit 1
        }
        return $false
    } else {
        if ($CI) {
            exit 0
        }
        return $true
    }
}
catch {
    Write-ValidationLog "Validation failed: $_" -Level Error
    if ($CI) {
        exit 1
    }
    throw
}