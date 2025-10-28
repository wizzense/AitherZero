<#
.SYNOPSIS
    Quick validation of PR Docker deployment configuration

.DESCRIPTION
    Fast validation script that checks Docker deployment configuration without requiring
    a full image build. Validates Dockerfile, docker-compose.yml, deployment scripts,
    and workflow configuration.

.PARAMETER Verbose
    Show detailed output

.EXAMPLE
    .\0853_Quick-Docker-Validation.ps1

.NOTES
    Script Number: 0853
    Category: Testing & Validation
    Required: Docker
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Detail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize results tracking
$ValidationResults = @{
    Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Tests = @()
    Summary = @{
        Total = 0
        Passed = 0
        Failed = 0
        Warnings = 0
    }
}

# Helper function to add test result
function Add-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message,
        [object]$Details = $null
    )
    
    $result = @{
        TestName = $TestName
        Status = $Status
        Message = $Message
        Details = $Details
    }
    
    $ValidationResults.Tests += $result
    $ValidationResults.Summary.Total++
    
    switch ($Status) {
        'Passed' {
            $ValidationResults.Summary.Passed++
            Write-Host "  ✅ $TestName`: $Message" -ForegroundColor Green
        }
        'Failed' {
            $ValidationResults.Summary.Failed++
            Write-Host "  ❌ $TestName`: $Message" -ForegroundColor Red
        }
        'Warning' {
            $ValidationResults.Summary.Warnings++
            Write-Host "  ⚠️ $TestName`: $Message" -ForegroundColor Yellow
        }
    }
    
    if ($Details -and $Detail) {
        Write-Host "     Details: $($Details | ConvertTo-Json -Compress)" -ForegroundColor Gray
    }
}

# Get project root
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$ProjectRoot = Split-Path -Parent $ScriptRoot

Write-Host "`n🚀 Quick PR Docker Deployment Validation" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta

try {
    # Test 1: Docker availability
    Write-Host "`n📋 Test 1: Docker Prerequisites" -ForegroundColor Cyan
    try {
        $dockerVersion = docker --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -TestName "Docker Installed" -Status "Passed" -Message "Docker is available: $dockerVersion"
        } else {
            throw "Docker command failed"
        }
    } catch {
        Add-TestResult -TestName "Docker Installed" -Status "Failed" -Message "Docker is not available"
    }
    
    try {
        docker compose version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $composeVersion = docker compose version 2>&1
            Add-TestResult -TestName "Docker Compose" -Status "Passed" -Message "Docker Compose is available: $composeVersion"
        } else {
            throw "Docker Compose command failed"
        }
    } catch {
        Add-TestResult -TestName "Docker Compose" -Status "Failed" -Message "Docker Compose is not available"
    }
    
    # Test 2: Dockerfile validation
    Write-Host "`n📋 Test 2: Dockerfile Validation" -ForegroundColor Cyan
    
    $dockerfilePath = Join-Path $ProjectRoot "Dockerfile"
    if (Test-Path $dockerfilePath) {
        Add-TestResult -TestName "Dockerfile Exists" -Status "Passed" -Message "Dockerfile found"
        
        $dockerfileContent = Get-Content $dockerfilePath -Raw
        
        # Check for essential instructions
        $requiredInstructions = @(
            @{ Pattern = 'FROM.*powershell'; Name = 'PowerShell base image' }
            @{ Pattern = 'WORKDIR'; Name = 'Working directory set' }
            @{ Pattern = 'COPY.*\.'; Name = 'Application files copied' }
            @{ Pattern = 'ENV.*AITHERZERO'; Name = 'AitherZero environment variables' }
            @{ Pattern = 'HEALTHCHECK'; Name = 'Health check configured' }
            @{ Pattern = 'CMD|ENTRYPOINT'; Name = 'Default command specified' }
        )
        
        foreach ($instruction in $requiredInstructions) {
            if ($dockerfileContent -match $instruction.Pattern) {
                Add-TestResult -TestName $instruction.Name -Status "Passed" -Message "Found in Dockerfile"
            } else {
                Add-TestResult -TestName $instruction.Name -Status "Warning" -Message "Not found or using different pattern"
            }
        }
        
        # Check for security best practices
        if ($dockerfileContent -match 'USER\s+\w+') {
            Add-TestResult -TestName "Non-root user" -Status "Passed" -Message "Container runs as non-root user"
        } else {
            Add-TestResult -TestName "Non-root user" -Status "Warning" -Message "May be running as root"
        }
        
    } else {
        Add-TestResult -TestName "Dockerfile" -Status "Failed" -Message "Dockerfile not found"
    }
    
    # Test 3: Docker Compose configuration
    Write-Host "`n📋 Test 3: Docker Compose Configuration" -ForegroundColor Cyan
    
    $composeFilePath = Join-Path $ProjectRoot "docker-compose.yml"
    if (Test-Path $composeFilePath) {
        Add-TestResult -TestName "Compose File Exists" -Status "Passed" -Message "docker-compose.yml found"
        
        $composeContent = Get-Content $composeFilePath -Raw
        
        # Check for essential configurations
        if ($composeContent -match 'version:') {
            Add-TestResult -TestName "Compose Version" -Status "Passed" -Message "Version specified"
        } else {
            Add-TestResult -TestName "Compose Version" -Status "Warning" -Message "No version specified (may be v2 format)"
        }
        
        if ($composeContent -match 'services:') {
            Add-TestResult -TestName "Services Defined" -Status "Passed" -Message "Services section present"
        }
        
        if ($composeContent -match 'aitherzero:') {
            Add-TestResult -TestName "AitherZero Service" -Status "Passed" -Message "Main service defined"
        }
        
        if ($composeContent -match 'volumes:') {
            Add-TestResult -TestName "Volume Mounts" -Status "Passed" -Message "Volumes configured"
        }
        
        if ($composeContent -match 'environment:') {
            Add-TestResult -TestName "Environment Variables" -Status "Passed" -Message "Environment variables defined"
        }
        
        if ($composeContent -match 'restart:') {
            Add-TestResult -TestName "Restart Policy" -Status "Passed" -Message "Restart policy configured"
        }
        
        if ($composeContent -match 'deploy:\s*\n\s*resources:') {
            Add-TestResult -TestName "Resource Limits" -Status "Passed" -Message "Resource limits configured"
        } else {
            Add-TestResult -TestName "Resource Limits" -Status "Warning" -Message "No resource limits specified"
        }
        
    } else {
        Add-TestResult -TestName "Compose File" -Status "Failed" -Message "docker-compose.yml not found"
    }
    
    # Test 4: .dockerignore validation
    Write-Host "`n📋 Test 4: .dockerignore Validation" -ForegroundColor Cyan
    
    $dockerignorePath = Join-Path $ProjectRoot ".dockerignore"
    if (Test-Path $dockerignorePath) {
        Add-TestResult -TestName ".dockerignore Exists" -Status "Passed" -Message ".dockerignore file found"
        
        $dockerignoreContent = Get-Content $dockerignorePath -Raw
        
        # Check for common exclusions
        $recommendedExclusions = @(
            @{ Pattern = '\.git'; Name = 'Git files excluded' }
            @{ Pattern = '\.vscode|\.idea'; Name = 'IDE files excluded' }
            @{ Pattern = 'logs/|\.log'; Name = 'Log files excluded' }
            @{ Pattern = 'tests/|\.Tests\.ps1'; Name = 'Test files excluded' }
            @{ Pattern = '\.md'; Name = 'Documentation excluded' }
        )
        
        foreach ($exclusion in $recommendedExclusions) {
            if ($dockerignoreContent -match $exclusion.Pattern) {
                Add-TestResult -TestName $exclusion.Name -Status "Passed" -Message "Pattern found"
            } else {
                Add-TestResult -TestName $exclusion.Name -Status "Warning" -Message "Pattern not found"
            }
        }
        
    } else {
        Add-TestResult -TestName ".dockerignore" -Status "Warning" -Message ".dockerignore not found"
    }
    
    # Test 5: Deployment scripts
    Write-Host "`n📋 Test 5: Deployment Scripts" -ForegroundColor Cyan
    
    $deployScript = Join-Path $ScriptRoot "0850_Deploy-PREnvironment.ps1"
    if (Test-Path $deployScript) {
        Add-TestResult -TestName "Deploy Script" -Status "Passed" -Message "Deployment script exists"
        
        # Check script content
        $deployContent = Get-Content $deployScript -Raw
        
        if ($deployContent -match 'param\s*\(') {
            Add-TestResult -TestName "Deploy Parameters" -Status "Passed" -Message "Script has parameters"
        }
        
        if ($deployContent -match 'docker\s+(build|compose)') {
            Add-TestResult -TestName "Deploy Docker Commands" -Status "Passed" -Message "Docker commands present"
        }
        
        if ($deployContent -match 'function.*Deploy-WithDocker') {
            Add-TestResult -TestName "Docker Deployment Function" -Status "Passed" -Message "Docker deployment function exists"
        }
        
    } else {
        Add-TestResult -TestName "Deploy Script" -Status "Failed" -Message "0850_Deploy-PREnvironment.ps1 not found"
    }
    
    $cleanupScript = Join-Path $ScriptRoot "0851_Cleanup-PREnvironment.ps1"
    if (Test-Path $cleanupScript) {
        Add-TestResult -TestName "Cleanup Script" -Status "Passed" -Message "Cleanup script exists"
        
        $cleanupContent = Get-Content $cleanupScript -Raw
        
        if ($cleanupContent -match 'function.*Remove-DockerEnvironment') {
            Add-TestResult -TestName "Docker Cleanup Function" -Status "Passed" -Message "Docker cleanup function exists"
        }
        
    } else {
        Add-TestResult -TestName "Cleanup Script" -Status "Failed" -Message "0851_Cleanup-PREnvironment.ps1 not found"
    }
    
    # Test 6: GitHub workflow validation
    Write-Host "`n📋 Test 6: GitHub Workflow Configuration" -ForegroundColor Cyan
    
    $workflowPath = Join-Path $ProjectRoot ".github/workflows/deploy-pr-environment.yml"
    if (Test-Path $workflowPath) {
        Add-TestResult -TestName "Workflow File" -Status "Passed" -Message "PR deployment workflow exists"
        
        $workflowContent = Get-Content $workflowPath -Raw
        
        # Check workflow triggers
        if ($workflowContent -match 'on:') {
            Add-TestResult -TestName "Workflow Triggers" -Status "Passed" -Message "Triggers configured"
        }
        
        if ($workflowContent -match 'pull_request:') {
            Add-TestResult -TestName "PR Trigger" -Status "Passed" -Message "PR events trigger workflow"
        }
        
        if ($workflowContent -match 'build-container:') {
            Add-TestResult -TestName "Build Job" -Status "Passed" -Message "Container build job defined"
        }
        
        if ($workflowContent -match 'deploy-docker-compose:') {
            Add-TestResult -TestName "Deploy Job" -Status "Passed" -Message "Docker deployment job defined"
        }
        
        if ($workflowContent -match 'docker/build-push-action') {
            Add-TestResult -TestName "Build Action" -Status "Passed" -Message "Docker build action configured"
        }
        
        if ($workflowContent -match 'docker compose.*up') {
            Add-TestResult -TestName "Compose Deployment" -Status "Passed" -Message "Docker Compose deployment configured"
        }
        
        if ($workflowContent -match 'healthcheck|health') {
            Add-TestResult -TestName "Health Checks" -Status "Passed" -Message "Health checks included"
        }
        
    } else {
        Add-TestResult -TestName "Workflow File" -Status "Warning" -Message "PR deployment workflow not found"
    }
    
    # Test 7: Documentation
    Write-Host "`n📋 Test 7: Documentation" -ForegroundColor Cyan
    
    $docFiles = @(
        @{ Path = "docs/PR-DEPLOYMENT-GUIDE.md"; Name = "Deployment Guide" }
        @{ Path = "docs/PR-DEPLOYMENT-QUICKREF.md"; Name = "Quick Reference" }
    )
    
    foreach ($doc in $docFiles) {
        $docPath = Join-Path $ProjectRoot $doc.Path
        if (Test-Path $docPath) {
            Add-TestResult -TestName $doc.Name -Status "Passed" -Message "Documentation exists"
        } else {
            Add-TestResult -TestName $doc.Name -Status "Warning" -Message "Documentation not found"
        }
    }
    
    # Test 8: Module files
    Write-Host "`n📋 Test 8: AitherZero Module Files" -ForegroundColor Cyan
    
    $moduleFiles = @(
        @{ Path = "AitherZero.psd1"; Name = "Module Manifest" }
        @{ Path = "AitherZero.psm1"; Name = "Root Module" }
        @{ Path = "Start-AitherZero.ps1"; Name = "Entry Point" }
    )
    
    foreach ($file in $moduleFiles) {
        $filePath = Join-Path $ProjectRoot $file.Path
        if (Test-Path $filePath) {
            Add-TestResult -TestName $file.Name -Status "Passed" -Message "File exists"
        } else {
            Add-TestResult -TestName $file.Name -Status "Failed" -Message "File not found"
        }
    }
    
    # Test 9: Dockerfile lint (basic)
    Write-Host "`n📋 Test 9: Dockerfile Best Practices" -ForegroundColor Cyan
    
    if (Test-Path $dockerfilePath) {
        $dockerfileLines = Get-Content $dockerfilePath
        
        # Check for common issues
        $aptGetMatches = @($dockerfileLines | Where-Object { $_ -match 'apt-get\s+(update|install)' })
        if ($aptGetMatches.Count -gt 0) {
            $rmCacheMatches = @($dockerfileLines | Where-Object { $_ -match 'rm.*apt/lists' })
            if ($rmCacheMatches.Count -gt 0) {
                Add-TestResult -TestName "Apt Cache Cleanup" -Status "Passed" -Message "Apt cache is cleaned up"
            } else {
                Add-TestResult -TestName "Apt Cache Cleanup" -Status "Warning" -Message "Consider cleaning apt cache to reduce image size"
            }
        }
        
        # Check for multi-stage build
        $fromMatches = @($dockerfileLines | Where-Object { $_ -match '^FROM' })
        if ($fromMatches.Count -gt 1) {
            Add-TestResult -TestName "Multi-stage Build" -Status "Passed" -Message "Using multi-stage build"
        } else {
            Add-TestResult -TestName "Multi-stage Build" -Status "Warning" -Message "Single stage build (may be acceptable)"
        }
        
        # Check for version pinning
        $dockerfileContent = Get-Content $dockerfilePath -Raw
        if ($dockerfileContent -match 'FROM.*:\d+\.\d+') {
            Add-TestResult -TestName "Base Image Versioning" -Status "Passed" -Message "Base image version is pinned"
        } else {
            Add-TestResult -TestName "Base Image Versioning" -Status "Warning" -Message "Consider pinning base image version"
        }
    }
    
    # Generate summary report
    Write-Host "`n📊 Validation Summary" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    Write-Host "  Total Tests: $($ValidationResults.Summary.Total)" -ForegroundColor Cyan
    Write-Host "  Passed: $($ValidationResults.Summary.Passed)" -ForegroundColor Green
    Write-Host "  Failed: $($ValidationResults.Summary.Failed)" -ForegroundColor Red
    Write-Host "  Warnings: $($ValidationResults.Summary.Warnings)" -ForegroundColor Yellow
    
    $successRate = if ($ValidationResults.Summary.Total -gt 0) { 
        ($ValidationResults.Summary.Passed / $ValidationResults.Summary.Total * 100).ToString('F2')
    } else { 0 }
    Write-Host "  Success Rate: $successRate%" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    
    # Save detailed results
    $reportPath = Join-Path $ProjectRoot "reports/pr-docker-quick-validation.json"
    $reportDir = Split-Path -Parent $reportPath
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $ValidationResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath -Force
    Write-Host "`n📄 Detailed report saved: $reportPath" -ForegroundColor Gray
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "Quick Docker validation completed: $($ValidationResults.Summary.Passed)/$($ValidationResults.Summary.Total) tests passed" -Level 'Information'
    }
    
    # Recommendations
    if ($ValidationResults.Summary.Failed -gt 0 -or $ValidationResults.Summary.Warnings -gt 0) {
        Write-Host "`n💡 Recommendations:" -ForegroundColor Cyan
        
        if ($ValidationResults.Summary.Failed -gt 0) {
            Write-Host "  • Address failed tests to ensure deployment functionality" -ForegroundColor Yellow
        }
        
        if ($ValidationResults.Summary.Warnings -gt 0) {
            Write-Host "  • Review warnings for potential improvements" -ForegroundColor Yellow
        }
        
        Write-Host "  • Run full validation with 0852_Validate-PRDockerDeployment.ps1" -ForegroundColor Yellow
        Write-Host "  • Test actual deployment with: ./automation-scripts/0850_Deploy-PREnvironment.ps1 -PRNumber 999" -ForegroundColor Yellow
    }
    
    # Exit with appropriate code
    if ($ValidationResults.Summary.Failed -gt 0) {
        Write-Host "`n⚠️ Validation completed with failures" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "`n✅ Validation completed successfully" -ForegroundColor Green
        exit 0
    }
    
} catch {
    Write-Host "`n❌ Validation failed with error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "Validation failed: $_" -Level 'Error'
    }
    
    exit 1
}
