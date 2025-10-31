<#
.SYNOPSIS
    Validate PR Docker deployment functionality

.DESCRIPTION
    Comprehensive validation script that tests the PR Docker deployment process end-to-end.
    Tests image building, container deployment, health checks, module loading, and cleanup.

.PARAMETER PRNumber
    Pull request number to use for testing (default: 999 for testing)

.PARAMETER SkipBuild
    Skip Docker image build step (use existing image)

.PARAMETER SkipCleanup
    Skip cleanup step (leave container running for inspection)

.PARAMETER Verbose
    Show detailed output

.EXAMPLE
    .\0852_Validate-PRDockerDeployment.ps1

.EXAMPLE
    .\0852_Validate-PRDockerDeployment.ps1 -PRNumber 123 -Verbose

.NOTES
    Script Number: 0852
    Category: Testing & Validation
    Required: Docker
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$PRNumber = 999,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipCleanup,
    
    [Parameter(Mandatory = $false)]
    [switch]$Detail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize results tracking
$ValidationResults = @{
    Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    PRNumber = $PRNumber
    Tests = @()
    Summary = @{
        Total = 0
        Passed = 0
        Failed = 0
        Skipped = 0
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
        'Skipped' {
            $ValidationResults.Summary.Skipped++
            Write-Host "  ⏭️ $TestName`: $Message" -ForegroundColor Yellow
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

# Environment configuration
$ContainerName = "aitherzero-pr-$PRNumber"
$ImageName = "aitherzero:pr-$PRNumber"
$ComposeFile = Join-Path $ProjectRoot "docker-compose.pr-$PRNumber.yml"

Write-Host "`n🧪 PR Docker Deployment Validation" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "PR Number: $PRNumber" -ForegroundColor Cyan
Write-Host "Container: $ContainerName" -ForegroundColor Cyan
Write-Host "Image: $ImageName" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta

try {
    # Test 1: Check Docker availability
    Write-Host "`n📋 Test 1: Docker Prerequisites" -ForegroundColor Cyan
    try {
        $dockerVersion = docker --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -TestName "Docker Installed" -Status "Passed" -Message "Docker is available" -Details $dockerVersion
        } else {
            throw "Docker command failed"
        }
    } catch {
        Add-TestResult -TestName "Docker Installed" -Status "Failed" -Message "Docker is not available: $_"
        throw "Docker is required but not available"
    }
    
    try {
        $composeVersion = docker compose version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -TestName "Docker Compose Installed" -Status "Passed" -Message "Docker Compose is available" -Details $composeVersion
        } else {
            throw "Docker Compose command failed"
        }
    } catch {
        Add-TestResult -TestName "Docker Compose Installed" -Status "Failed" -Message "Docker Compose is not available: $_"
        throw "Docker Compose is required but not available"
    }
    
    # Test 2: Check required files
    Write-Host "`n📋 Test 2: Required Files" -ForegroundColor Cyan
    
    $requiredFiles = @(
        @{ Path = "Dockerfile"; Description = "Dockerfile" }
        @{ Path = "docker-compose.yml"; Description = "Docker Compose template" }
        @{ Path = ".dockerignore"; Description = ".dockerignore" }
        @{ Path = "AitherZero.psd1"; Description = "Module manifest" }
        @{ Path = "AitherZero.psm1"; Description = "Root module" }
    )
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $ProjectRoot $file.Path
        if (Test-Path $filePath) {
            Add-TestResult -TestName "File: $($file.Description)" -Status "Passed" -Message "File exists" -Details $filePath
        } else {
            Add-TestResult -TestName "File: $($file.Description)" -Status "Failed" -Message "File not found" -Details $filePath
        }
    }
    
    # Test 3: Build Docker image
    Write-Host "`n📋 Test 3: Docker Image Build" -ForegroundColor Cyan
    
    if ($SkipBuild) {
        Add-TestResult -TestName "Docker Build" -Status "Skipped" -Message "Build skipped by parameter"
    } else {
        try {
            Write-Host "  Building Docker image (this may take a few minutes)..." -ForegroundColor Yellow
            $buildStart = Get-Date
            
            Push-Location $ProjectRoot
            $buildOutput = docker build -t $ImageName -f Dockerfile --build-arg PR_NUMBER=$PRNumber . 2>&1
            Pop-Location
            
            $buildDuration = (Get-Date) - $buildStart
            
            if ($LASTEXITCODE -eq 0) {
                Add-TestResult -TestName "Docker Build" -Status "Passed" -Message "Image built successfully in $($buildDuration.TotalSeconds.ToString('F2')) seconds"
            } else {
                Add-TestResult -TestName "Docker Build" -Status "Failed" -Message "Build failed with exit code $LASTEXITCODE" -Details $buildOutput[-20..-1]
                throw "Docker build failed"
            }
            
            # Verify image exists
            $imageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq $ImageName }
            if ($imageExists) {
                Add-TestResult -TestName "Image Verification" -Status "Passed" -Message "Image exists in local registry"
            } else {
                Add-TestResult -TestName "Image Verification" -Status "Failed" -Message "Image not found in local registry"
            }
            
        } catch {
            Add-TestResult -TestName "Docker Build" -Status "Failed" -Message "Build process failed: $_"
            throw
        }
    }
    
    # Test 4: Deploy with deployment script
    Write-Host "`n📋 Test 4: Deployment Script Execution" -ForegroundColor Cyan
    
    try {
        $deployScript = Join-Path $ScriptRoot "0850_Deploy-PREnvironment.ps1"
        
        if (Test-Path $deployScript) {
            Add-TestResult -TestName "Deploy Script Exists" -Status "Passed" -Message "Deployment script found"
            
            # Run deployment
            Write-Host "  Running deployment script..." -ForegroundColor Yellow
            $deployStart = Get-Date
            
            # Clean up any existing container first
            docker stop $ContainerName 2>$null | Out-Null
            docker rm $ContainerName 2>$null | Out-Null
            
            & $deployScript -PRNumber $PRNumber -BranchName "test/validation" -CommitSHA "validation" -DeploymentTarget Docker -Force
            
            $deployDuration = (Get-Date) - $deployStart
            
            if ($LASTEXITCODE -eq 0) {
                Add-TestResult -TestName "Deploy Script Execution" -Status "Passed" -Message "Deployment completed in $($deployDuration.TotalSeconds.ToString('F2')) seconds"
            } else {
                Add-TestResult -TestName "Deploy Script Execution" -Status "Failed" -Message "Deployment failed with exit code $LASTEXITCODE"
            }
        } else {
            Add-TestResult -TestName "Deploy Script Exists" -Status "Failed" -Message "Deployment script not found: $deployScript"
            throw "Deployment script not found"
        }
        
    } catch {
        Add-TestResult -TestName "Deploy Script Execution" -Status "Failed" -Message "Deployment failed: $_"
        throw
    }
    
    # Test 5: Container status checks
    Write-Host "`n📋 Test 5: Container Status" -ForegroundColor Cyan
    
    try {
        # Check if container is running
        $containerStatus = docker inspect --format='{{.State.Status}}' $ContainerName 2>$null
        if ($containerStatus -eq 'running') {
            Add-TestResult -TestName "Container Running" -Status "Passed" -Message "Container is in running state"
        } else {
            Add-TestResult -TestName "Container Running" -Status "Failed" -Message "Container is not running (status: $containerStatus)"
        }
        
        # Check health status
        $healthStatus = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>$null
        if ($healthStatus -eq 'healthy' -or $healthStatus -eq '') {
            Add-TestResult -TestName "Container Health" -Status "Passed" -Message "Container is healthy"
        } else {
            Add-TestResult -TestName "Container Health" -Status "Failed" -Message "Container health: $healthStatus"
        }
        
        # Check compose file created
        if (Test-Path $ComposeFile) {
            Add-TestResult -TestName "Compose File Created" -Status "Passed" -Message "Docker Compose file created"
        } else {
            Add-TestResult -TestName "Compose File Created" -Status "Failed" -Message "Docker Compose file not found"
        }
        
    } catch {
        Add-TestResult -TestName "Container Status" -Status "Failed" -Message "Status check failed: $_"
    }
    
    # Test 6: Module loading
    Write-Host "`n📋 Test 6: PowerShell Module Loading" -ForegroundColor Cyan
    
    try {
        # Test module import
        Write-Host "  Testing module import..." -ForegroundColor Yellow
        $moduleTest = docker exec $ContainerName pwsh -Command "try { Import-Module /opt/aitherzero/AitherZero.psd1 -ErrorAction Stop; Write-Output 'SUCCESS' } catch { Write-Output `"ERROR: `$_`"; exit 1 }" 2>&1
        
        if ($moduleTest -match 'SUCCESS') {
            Add-TestResult -TestName "Module Import" -Status "Passed" -Message "AitherZero module loads successfully"
        } else {
            Add-TestResult -TestName "Module Import" -Status "Failed" -Message "Module import failed" -Details $moduleTest
        }
        
        # Test module commands availability
        $commandTest = docker exec $ContainerName pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1 -WarningAction SilentlyContinue; (Get-Command -Module AitherZero).Count" 2>&1
        
        if ($commandTest -match '^\d+$' -and [int]$commandTest -gt 0) {
            Add-TestResult -TestName "Module Commands" -Status "Passed" -Message "$commandTest commands exported from module"
        } else {
            Add-TestResult -TestName "Module Commands" -Status "Failed" -Message "Failed to get module commands" -Details $commandTest
        }
        
        # Test basic command execution
        $functionTest = docker exec $ContainerName pwsh -Command "Import-Module /opt/aitherzero/AitherZero.psd1 -WarningAction SilentlyContinue; Get-Command Get-AitherConfig -ErrorAction Stop; Write-Output 'SUCCESS'" 2>&1
        
        if ($functionTest -match 'SUCCESS') {
            Add-TestResult -TestName "Command Execution" -Status "Passed" -Message "Module commands are executable"
        } else {
            Add-TestResult -TestName "Command Execution" -Status "Failed" -Message "Command execution failed" -Details $functionTest
        }
        
    } catch {
        Add-TestResult -TestName "Module Loading" -Status "Failed" -Message "Module testing failed: $_"
    }
    
    # Test 7: Environment variables
    Write-Host "`n📋 Test 7: Environment Variables" -ForegroundColor Cyan
    
    try {
        $envVars = @('AITHERZERO_ROOT', 'PR_NUMBER', 'DEPLOYMENT_ENVIRONMENT')
        
        foreach ($envVar in $envVars) {
            $value = docker exec $ContainerName pwsh -Command "`$env:$envVar" 2>&1
            if ($value -and $value -ne '') {
                Add-TestResult -TestName "Env: $envVar" -Status "Passed" -Message "Variable set" -Details $value
            } else {
                Add-TestResult -TestName "Env: $envVar" -Status "Failed" -Message "Variable not set or empty"
            }
        }
        
    } catch {
        Add-TestResult -TestName "Environment Variables" -Status "Failed" -Message "Environment check failed: $_"
    }
    
    # Test 8: File system structure
    Write-Host "`n📋 Test 8: Container File System" -ForegroundColor Cyan
    
    try {
        $requiredPaths = @('/opt/aitherzero/AitherZero.psd1', '/opt/aitherzero/domains', '/opt/aitherzero/automation-scripts', '/opt/aitherzero/logs', '/opt/aitherzero/reports')
        
        foreach ($path in $requiredPaths) {
            $pathExists = docker exec $ContainerName pwsh -Command "Test-Path '$path'" 2>&1
            if ($pathExists -eq 'True') {
                Add-TestResult -TestName "Path: $path" -Status "Passed" -Message "Path exists in container"
            } else {
                Add-TestResult -TestName "Path: $path" -Status "Failed" -Message "Path not found in container"
            }
        }
        
    } catch {
        Add-TestResult -TestName "File System Structure" -Status "Failed" -Message "File system check failed: $_"
    }
    
    # Test 9: Network connectivity
    Write-Host "`n📋 Test 9: Container Network" -ForegroundColor Cyan
    
    try {
        # Check port mapping
        $portInfo = docker port $ContainerName 2>&1
        if ($LASTEXITCODE -eq 0 -and $portInfo) {
            Add-TestResult -TestName "Port Mapping" -Status "Passed" -Message "Ports are mapped" -Details $portInfo
        } else {
            Add-TestResult -TestName "Port Mapping" -Status "Failed" -Message "No port mappings found"
        }
        
        # Check network connectivity
        $ipAddress = docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $ContainerName 2>&1
        if ($ipAddress -and $ipAddress -ne '') {
            Add-TestResult -TestName "IP Address" -Status "Passed" -Message "Container has IP address" -Details $ipAddress
        } else {
            Add-TestResult -TestName "IP Address" -Status "Failed" -Message "No IP address assigned"
        }
        
    } catch {
        Add-TestResult -TestName "Network Connectivity" -Status "Failed" -Message "Network check failed: $_"
    }
    
    # Test 10: Resource limits
    Write-Host "`n📋 Test 10: Resource Configuration" -ForegroundColor Cyan
    
    try {
        # Check container stats
        $stats = docker stats $ContainerName --no-stream --format "{{.MemUsage}}|{{.CPUPerc}}" 2>&1
        if ($LASTEXITCODE -eq 0 -and $stats) {
            $memUsage, $cpuUsage = $stats -split '\|'
            Add-TestResult -TestName "Resource Stats" -Status "Passed" -Message "Container is consuming resources" -Details "Memory: $memUsage, CPU: $cpuUsage"
        } else {
            Add-TestResult -TestName "Resource Stats" -Status "Failed" -Message "Unable to get resource stats"
        }
        
    } catch {
        Add-TestResult -TestName "Resource Configuration" -Status "Failed" -Message "Resource check failed: $_"
    }
    
    # Test 11: Logs and output
    Write-Host "`n📋 Test 11: Container Logs" -ForegroundColor Cyan
    
    try {
        $logs = docker logs $ContainerName --tail 50 2>&1
        if ($logs) {
            # Check for errors in logs
            $errorLines = $logs | Where-Object { $_ -match 'error|exception|failed' -and $_ -notmatch 'ErrorAction|error-free' }
            if ($errorLines.Count -eq 0) {
                Add-TestResult -TestName "Log Analysis" -Status "Passed" -Message "No critical errors in logs"
            } else {
                Add-TestResult -TestName "Log Analysis" -Status "Failed" -Message "Found $($errorLines.Count) error lines in logs" -Details $errorLines[0..2]
            }
        } else {
            Add-TestResult -TestName "Log Access" -Status "Failed" -Message "Unable to access container logs"
        }
        
    } catch {
        Add-TestResult -TestName "Container Logs" -Status "Failed" -Message "Log check failed: $_"
    }
    
    # Test 12: Cleanup process
    Write-Host "`n📋 Test 12: Cleanup Process" -ForegroundColor Cyan
    
    if ($SkipCleanup) {
        Add-TestResult -TestName "Cleanup" -Status "Skipped" -Message "Cleanup skipped by parameter"
    } else {
        try {
            $cleanupScript = Join-Path $ScriptRoot "0851_Cleanup-PREnvironment.ps1"
            
            if (Test-Path $cleanupScript) {
                Write-Host "  Running cleanup script..." -ForegroundColor Yellow
                & $cleanupScript -PRNumber $PRNumber -Target Docker -Force
                
                if ($LASTEXITCODE -eq 0) {
                    Add-TestResult -TestName "Cleanup Script" -Status "Passed" -Message "Cleanup script executed successfully"
                    
                    # Verify cleanup
                    Start-Sleep -Seconds 2
                    $containerExists = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
                    if (-not $containerExists) {
                        Add-TestResult -TestName "Container Removed" -Status "Passed" -Message "Container successfully removed"
                    } else {
                        Add-TestResult -TestName "Container Removed" -Status "Failed" -Message "Container still exists after cleanup"
                    }
                    
                } else {
                    Add-TestResult -TestName "Cleanup Script" -Status "Failed" -Message "Cleanup failed with exit code $LASTEXITCODE"
                }
            } else {
                Add-TestResult -TestName "Cleanup Script" -Status "Failed" -Message "Cleanup script not found"
            }
            
        } catch {
            Add-TestResult -TestName "Cleanup Process" -Status "Failed" -Message "Cleanup failed: $_"
        }
    }
    
    # Generate summary report
    Write-Host "`n📊 Validation Summary" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    Write-Host "  Total Tests: $($ValidationResults.Summary.Total)" -ForegroundColor Cyan
    Write-Host "  Passed: $($ValidationResults.Summary.Passed)" -ForegroundColor Green
    Write-Host "  Failed: $($ValidationResults.Summary.Failed)" -ForegroundColor Red
    Write-Host "  Skipped: $($ValidationResults.Summary.Skipped)" -ForegroundColor Yellow
    
    $successRate = if ($ValidationResults.Summary.Total -gt 0) { 
        ($ValidationResults.Summary.Passed / $ValidationResults.Summary.Total * 100).ToString('F2')
    } else { 0 }
    Write-Host "  Success Rate: $successRate%" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    
    # Save detailed results
    $reportPath = Join-Path $ProjectRoot "reports/pr-docker-validation-$PRNumber.json"
    $reportDir = Split-Path -Parent $reportPath
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $ValidationResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath -Force
    Write-Host "`n📄 Detailed report saved: $reportPath" -ForegroundColor Gray
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "PR Docker deployment validation completed: $($ValidationResults.Summary.Passed)/$($ValidationResults.Summary.Total) tests passed" -Level 'Information'
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
    
    # Save error report
    $ValidationResults.Error = @{
        Message = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
    
    $reportPath = Join-Path $ProjectRoot "reports/pr-docker-validation-$PRNumber-error.json"
    $reportDir = Split-Path -Parent $reportPath
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $ValidationResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath -Force
    
    exit 1
}
