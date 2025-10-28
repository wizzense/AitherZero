<#
.SYNOPSIS
    Deploy PR environment for testing

.DESCRIPTION
    Creates and deploys an ephemeral test environment for a pull request using Docker Compose or Kubernetes.
    Supports multiple deployment targets and provides comprehensive status reporting.

.PARAMETER PRNumber
    Pull request number to deploy

.PARAMETER BranchName
    Git branch name

.PARAMETER CommitSHA
    Git commit SHA

.PARAMETER DeploymentTarget
    Target platform: Docker, Kubernetes, Azure, or AWS

.PARAMETER Force
    Force redeployment even if environment exists

.EXAMPLE
    .\0810_Deploy-PREnvironment.ps1 -PRNumber 123 -BranchName "feature/new-feature" -CommitSHA "abc123"

.NOTES
    Script Number: 0810
    Category: Environment Management
    Required: Docker or kubectl (depending on target)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$PRNumber,
    
    [Parameter(Mandatory = $false)]
    [string]$BranchName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$CommitSHA = "",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Docker', 'Kubernetes', 'Azure', 'AWS')]
    [string]$DeploymentTarget = 'Docker',
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Starting PR environment deployment for PR #$PRNumber" -Level 'Information'
} else {
    Write-Host "🚀 Starting PR environment deployment for PR #$PRNumber" -ForegroundColor Cyan
}

# Environment configuration
$EnvironmentName = "pr-$PRNumber"
$ContainerName = "aitherzero-pr-$PRNumber"
$ImageName = "aitherzero:pr-$PRNumber"

# Get current directory
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$ProjectRoot = Split-Path -Parent $ScriptRoot

# Function to check if environment exists
function Test-EnvironmentExists {
    param([string]$Name)
    
    switch ($DeploymentTarget) {
        'Docker' {
            $containers = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}"
            return ($containers -contains $ContainerName)
        }
        'Kubernetes' {
            $namespaces = kubectl get namespace -o jsonpath='{.items[*].metadata.name}' 2>$null
            return ($namespaces -match "aitherzero-$EnvironmentName")
        }
        default {
            return $false
        }
    }
}

# Function to deploy with Docker Compose
function Deploy-WithDocker {
    Write-Host "🐳 Deploying with Docker Compose..." -ForegroundColor Cyan
    
    # Check if Docker is available
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker is not installed or not in PATH"
    }
    
    # Build image
    Write-Host "📦 Building container image..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    try {
        $buildArgs = @(
            "build",
            "-t", $ImageName,
            "-f", "Dockerfile",
            "--build-arg", "PR_NUMBER=$PRNumber",
            "--build-arg", "COMMIT_SHA=$CommitSHA",
            "."
        )
        
        & docker @buildArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Docker build failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
    
    # Create compose file
    Write-Host "📝 Creating Docker Compose configuration..." -ForegroundColor Yellow
    $composeFile = Join-Path $ProjectRoot "docker-compose.pr-$PRNumber.yml"
    
    $composeContent = @"
version: '3.8'
services:
  aitherzero:
    image: $ImageName
    container_name: $ContainerName
    hostname: aitherzero-pr-$PRNumber
    environment:
      - AITHERZERO_NONINTERACTIVE=true
      - DEPLOYMENT_ENVIRONMENT=preview
      - PR_NUMBER=$PRNumber
      - BRANCH_NAME=$BranchName
      - COMMIT_SHA=$CommitSHA
    ports:
      - "808$($PRNumber % 10):8080"
      - "844$($PRNumber % 10):8443"
    volumes:
      - aitherzero-pr-${PRNumber}-logs:/app/logs
      - aitherzero-pr-${PRNumber}-reports:/app/reports
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "pwsh", "-Command", "Test-Path /app/AitherZero.psd1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

volumes:
  aitherzero-pr-${PRNumber}-logs:
  aitherzero-pr-${PRNumber}-reports:
"@
    
    Set-Content -Path $composeFile -Value $composeContent -Force
    
    # Deploy
    Write-Host "🚀 Starting containers..." -ForegroundColor Yellow
    & docker-compose -f $composeFile up -d
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose deployment failed"
    }
    
    # Wait for health check
    Write-Host "⏳ Waiting for environment to be healthy..." -ForegroundColor Yellow
    $maxAttempts = 30
    $attempt = 0
    $healthy = $false
    
    while ($attempt -lt $maxAttempts -and -not $healthy) {
        Start-Sleep -Seconds 2
        $healthStatus = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>$null
        $healthy = ($healthStatus -eq 'healthy' -or $healthStatus -eq '')
        $attempt++
    }
    
    if (-not $healthy -and $attempt -ge $maxAttempts) {
        Write-Warning "Health check timeout - environment may not be fully ready"
    }
    
    # Get container info
    $containerInfo = docker inspect $ContainerName | ConvertFrom-Json
    $ipAddress = $containerInfo[0].NetworkSettings.IPAddress
    
    return @{
        Success = $true
        EnvironmentName = $EnvironmentName
        ContainerName = $ContainerName
        IPAddress = $ipAddress
        Port = "808$($PRNumber % 10)"
        URL = "http://localhost:808$($PRNumber % 10)"
        ComposeFile = $composeFile
    }
}

# Function to deploy with Kubernetes
function Deploy-WithKubernetes {
    Write-Host "☸️ Deploying with Kubernetes..." -ForegroundColor Cyan
    
    # Check if kubectl is available
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        throw "kubectl is not installed or not in PATH"
    }
    
    $namespace = "aitherzero-$EnvironmentName"
    $manifestPath = Join-Path $ProjectRoot "infrastructure/kubernetes/deployment.yml"
    
    if (-not (Test-Path $manifestPath)) {
        throw "Kubernetes manifest not found: $manifestPath"
    }
    
    # Create namespace
    Write-Host "📦 Creating namespace: $namespace" -ForegroundColor Yellow
    kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply manifests with substitutions
    Write-Host "🚀 Applying Kubernetes manifests..." -ForegroundColor Yellow
    $manifest = Get-Content $manifestPath -Raw
    $manifest = $manifest -replace 'PR_NUMBER: ""', "PR_NUMBER: `"$PRNumber`""
    $manifest = $manifest -replace 'BRANCH_NAME: ""', "BRANCH_NAME: `"$BranchName`""
    $manifest = $manifest -replace 'COMMIT_SHA: ""', "COMMIT_SHA: `"$CommitSHA`""
    $manifest = $manifest -replace 'namespace: aitherzero-preview', "namespace: $namespace"
    
    $manifest | kubectl apply -f - -n $namespace
    
    # Wait for deployment
    Write-Host "⏳ Waiting for deployment to be ready..." -ForegroundColor Yellow
    kubectl wait --for=condition=available --timeout=300s deployment/aitherzero -n $namespace
    
    # Get service info
    $serviceIP = kubectl get service aitherzero-service -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    
    return @{
        Success = $true
        EnvironmentName = $EnvironmentName
        Namespace = $namespace
        ServiceIP = $serviceIP
        URL = "http://$serviceIP"
    }
}

# Main deployment logic
try {
    # Check if environment already exists
    if ((Test-EnvironmentExists -Name $EnvironmentName) -and -not $Force) {
        Write-Warning "Environment '$EnvironmentName' already exists. Use -Force to redeploy."
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Environment already exists: $EnvironmentName" -Level 'Warning'
        }
        
        exit 0
    }
    
    # Cleanup existing environment if Force is specified
    if ($Force -and (Test-EnvironmentExists -Name $EnvironmentName)) {
        Write-Host "🧹 Cleaning up existing environment..." -ForegroundColor Yellow
        
        if ($DeploymentTarget -eq 'Docker') {
            docker stop $ContainerName 2>$null | Out-Null
            docker rm $ContainerName 2>$null | Out-Null
        }
    }
    
    # Deploy based on target
    $deploymentResult = switch ($DeploymentTarget) {
        'Docker' { Deploy-WithDocker }
        'Kubernetes' { Deploy-WithKubernetes }
        default { throw "Unsupported deployment target: $DeploymentTarget" }
    }
    
    # Report success
    Write-Host "`n✅ Deployment successful!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "Environment: $($deploymentResult.EnvironmentName)" -ForegroundColor Cyan
    Write-Host "Target: $DeploymentTarget" -ForegroundColor Cyan
    if ($deploymentResult.URL) {
        Write-Host "URL: $($deploymentResult.URL)" -ForegroundColor Green
    }
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "Environment deployed successfully: $EnvironmentName" -Level 'Information'
    }
    
    # Output result as JSON for CI/CD integration
    $deploymentResult | ConvertTo-Json -Depth 3 | Out-File -FilePath "deployment-result-pr-$PRNumber.json" -Force
    
    exit 0
    
} catch {
    Write-Host "`n❌ Deployment failed: $_" -ForegroundColor Red
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "Deployment failed: $_" -Level 'Error'
    }
    
    exit 1
}
