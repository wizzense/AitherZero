<#
.SYNOPSIS
    Cleanup PR environment after testing

.DESCRIPTION
    Removes ephemeral test environments including containers, volumes, and cloud resources.
    Supports multiple cleanup targets with comprehensive resource removal.

.PARAMETER PRNumber
    Pull request number to cleanup

.PARAMETER Target
    Cleanup target: Docker, Kubernetes, Azure, AWS, or All

.PARAMETER Force
    Force cleanup without confirmation

.EXAMPLE
    .\0851_Cleanup-PREnvironment.ps1 -PRNumber 123 -Target Docker

.NOTES
    Script Number: 0811
    Category: Environment Management
    Required: Docker or kubectl (depending on target)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$PRNumber,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Docker', 'Kubernetes', 'Azure', 'AWS', 'All')]
    [string]$Target = 'All',
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Starting PR environment cleanup for PR #$PRNumber" -Level 'Information'
} else {
    Write-Host "🧹 Starting PR environment cleanup for PR #$PRNumber" -ForegroundColor Cyan
}

# Environment configuration
$EnvironmentName = "pr-$PRNumber"
$ContainerName = "aitherzero-pr-$PRNumber"

# Get current directory
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$ProjectRoot = Split-Path -Parent $ScriptRoot

# Track cleanup results
$CleanupResults = @{
    PRNumber = $PRNumber
    Target = $Target
    Docker = @{ Status = 'NotAttempted'; Details = @() }
    Kubernetes = @{ Status = 'NotAttempted'; Details = @() }
    Azure = @{ Status = 'NotAttempted'; Details = @() }
    AWS = @{ Status = 'NotAttempted'; Details = @() }
}

# Function to cleanup Docker resources
function Remove-DockerEnvironment {
    Write-Host "`n🐳 Cleaning up Docker resources..." -ForegroundColor Cyan
    $CleanupResults.Docker.Status = 'InProgress'
    
    try {
        # Check if Docker is available
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            $CleanupResults.Docker.Status = 'Skipped'
            $CleanupResults.Docker.Details += "Docker not available"
            Write-Host "⏭️ Docker not available, skipping..." -ForegroundColor Yellow
            return
        }
        
        # Stop and remove container
        $containerExists = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
        
        if ($containerExists) {
            Write-Host "  📦 Stopping container: $ContainerName" -ForegroundColor Yellow
            docker stop $ContainerName 2>$null | Out-Null
            $CleanupResults.Docker.Details += "Container stopped: $ContainerName"
            
            Write-Host "  🗑️ Removing container: $ContainerName" -ForegroundColor Yellow
            docker rm $ContainerName 2>$null | Out-Null
            $CleanupResults.Docker.Details += "Container removed: $ContainerName"
        } else {
            Write-Host "  ⏭️ No container found: $ContainerName" -ForegroundColor Gray
            $CleanupResults.Docker.Details += "No container found"
        }
        
        # Remove compose file
        $composeFile = Join-Path $ProjectRoot "docker-compose.pr-$PRNumber.yml"
        if (Test-Path $composeFile) {
            Write-Host "  📄 Removing compose file" -ForegroundColor Yellow
            Remove-Item $composeFile -Force
            $CleanupResults.Docker.Details += "Compose file removed"
        }
        
        # Remove volumes
        $volumes = docker volume ls --format "{{.Name}}" | Where-Object { $_ -match "pr-$PRNumber" }
        if ($volumes) {
            foreach ($volume in $volumes) {
                Write-Host "  💾 Removing volume: $volume" -ForegroundColor Yellow
                docker volume rm $volume 2>$null | Out-Null
                $CleanupResults.Docker.Details += "Volume removed: $volume"
            }
        }
        
        # Remove image (optional, to save space)
        $imageName = "aitherzero:pr-$PRNumber"
        $imageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq $imageName }
        if ($imageExists) {
            Write-Host "  🖼️ Removing image: $imageName" -ForegroundColor Yellow
            docker rmi $imageName 2>$null | Out-Null
            $CleanupResults.Docker.Details += "Image removed: $imageName"
        }
        
        # Remove deployment result file
        $resultFile = Join-Path $ProjectRoot "deployment-result-pr-$PRNumber.json"
        if (Test-Path $resultFile) {
            Remove-Item $resultFile -Force
            $CleanupResults.Docker.Details += "Deployment result file removed"
        }
        
        $CleanupResults.Docker.Status = 'Success'
        Write-Host "  ✅ Docker cleanup completed" -ForegroundColor Green
        
    } catch {
        $CleanupResults.Docker.Status = 'Failed'
        $CleanupResults.Docker.Details += "Error: $_"
        Write-Host "  ❌ Docker cleanup failed: $_" -ForegroundColor Red
    }
}

# Function to cleanup Kubernetes resources
function Remove-KubernetesEnvironment {
    Write-Host "`n☸️ Cleaning up Kubernetes resources..." -ForegroundColor Cyan
    $CleanupResults.Kubernetes.Status = 'InProgress'
    
    try {
        # Check if kubectl is available
        if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
            $CleanupResults.Kubernetes.Status = 'Skipped'
            $CleanupResults.Kubernetes.Details += "kubectl not available"
            Write-Host "⏭️ kubectl not available, skipping..." -ForegroundColor Yellow
            return
        }
        
        $namespace = "aitherzero-$EnvironmentName"
        
        # Check if namespace exists
        $namespaceExists = kubectl get namespace $namespace --ignore-not-found=true 2>$null
        
        if ($namespaceExists) {
            Write-Host "  📦 Deleting namespace: $namespace" -ForegroundColor Yellow
            kubectl delete namespace $namespace --timeout=60s 2>$null | Out-Null
            $CleanupResults.Kubernetes.Details += "Namespace deleted: $namespace"
        } else {
            Write-Host "  ⏭️ No namespace found: $namespace" -ForegroundColor Gray
            $CleanupResults.Kubernetes.Details += "No namespace found"
        }
        
        $CleanupResults.Kubernetes.Status = 'Success'
        Write-Host "  ✅ Kubernetes cleanup completed" -ForegroundColor Green
        
    } catch {
        $CleanupResults.Kubernetes.Status = 'Failed'
        $CleanupResults.Kubernetes.Details += "Error: $_"
        Write-Host "  ❌ Kubernetes cleanup failed: $_" -ForegroundColor Red
    }
}

# Function to cleanup Azure resources
function Remove-AzureEnvironment {
    Write-Host "`n☁️ Cleaning up Azure resources..." -ForegroundColor Cyan
    $CleanupResults.Azure.Status = 'InProgress'
    
    try {
        # Check if Azure CLI is available
        if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
            $CleanupResults.Azure.Status = 'Skipped'
            $CleanupResults.Azure.Details += "Azure CLI not available"
            Write-Host "⏭️ Azure CLI not available, skipping..." -ForegroundColor Yellow
            return
        }
        
        # Use Terraform to cleanup (if state exists)
        $terraformPath = Join-Path $ProjectRoot "infrastructure/terraform"
        if (Test-Path $terraformPath) {
            Push-Location $terraformPath
            try {
                Write-Host "  📦 Running Terraform destroy..." -ForegroundColor Yellow
                
                # Initialize Terraform
                terraform init -input=false 2>$null | Out-Null
                
                # Select workspace
                $workspaceExists = terraform workspace list | Select-String -Pattern "pr-$PRNumber"
                if ($workspaceExists) {
                    terraform workspace select "pr-$PRNumber" 2>$null | Out-Null
                    
                    # Destroy resources
                    terraform destroy -auto-approve `
                        -var="pr_number=$PRNumber" `
                        -var="branch_name=cleanup" `
                        -var="commit_sha=cleanup" 2>$null
                    
                    # Delete workspace
                    terraform workspace select default 2>$null | Out-Null
                    terraform workspace delete "pr-$PRNumber" 2>$null | Out-Null
                    
                    $CleanupResults.Azure.Details += "Terraform resources destroyed"
                } else {
                    $CleanupResults.Azure.Details += "No Terraform workspace found"
                }
            }
            finally {
                Pop-Location
            }
        }
        
        # Fallback: Direct resource group deletion
        $resourceGroupName = "aitherzero-pr-$PRNumber-rg-*"
        $resourceGroups = az group list --query "[?starts_with(name, `"aitherzero-pr-$PRNumber`")].name" -o tsv 2>$null
        
        if ($resourceGroups) {
            foreach ($rg in $resourceGroups) {
                Write-Host "  🗑️ Deleting resource group: $rg" -ForegroundColor Yellow
                az group delete --name $rg --yes --no-wait 2>$null
                $CleanupResults.Azure.Details += "Resource group deletion initiated: $rg"
            }
        } else {
            $CleanupResults.Azure.Details += "No resource groups found"
        }
        
        $CleanupResults.Azure.Status = 'Success'
        Write-Host "  ✅ Azure cleanup completed" -ForegroundColor Green
        
    } catch {
        $CleanupResults.Azure.Status = 'Failed'
        $CleanupResults.Azure.Details += "Error: $_"
        Write-Host "  ❌ Azure cleanup failed: $_" -ForegroundColor Red
    }
}

# Function to cleanup AWS resources
function Remove-AWSEnvironment {
    Write-Host "`n☁️ Cleaning up AWS resources..." -ForegroundColor Cyan
    $CleanupResults.AWS.Status = 'Skipped'
    $CleanupResults.AWS.Details += "AWS cleanup not implemented yet"
    Write-Host "  ⏭️ AWS cleanup not implemented, skipping..." -ForegroundColor Yellow
}

# Main cleanup logic
try {
    Write-Host "`n🧹 PR Environment Cleanup for PR #$PRNumber" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    
    # Confirmation prompt unless Force is specified
    if (-not $Force) {
        $confirmation = Read-Host "Are you sure you want to cleanup environment for PR #$PRNumber? (yes/no)"
        if ($confirmation -ne 'yes') {
            Write-Host "❌ Cleanup cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Perform cleanup based on target
    switch ($Target) {
        'Docker' {
            Remove-DockerEnvironment
        }
        'Kubernetes' {
            Remove-KubernetesEnvironment
        }
        'Azure' {
            Remove-AzureEnvironment
        }
        'AWS' {
            Remove-AWSEnvironment
        }
        'All' {
            Remove-DockerEnvironment
            Remove-KubernetesEnvironment
            Remove-AzureEnvironment
            Remove-AWSEnvironment
        }
    }
    
    # Generate summary
    Write-Host "`n📊 Cleanup Summary" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    
    $successCount = 0
    $failedCount = 0
    $skippedCount = 0
    
    foreach ($key in $CleanupResults.Keys) {
        if ($key -in @('Docker', 'Kubernetes', 'Azure', 'AWS')) {
            $status = $CleanupResults[$key].Status
            $statusColor = switch ($status) {
                'Success' { 'Green'; $successCount++ }
                'Failed' { 'Red'; $failedCount++ }
                'Skipped' { 'Yellow'; $skippedCount++ }
                'NotAttempted' { 'Gray'; continue }
                default { 'Gray'; continue }
            }
            
            Write-Host "  $key`: $status" -ForegroundColor $statusColor
            if ($CleanupResults[$key].Details.Count -gt 0) {
                foreach ($detail in $CleanupResults[$key].Details) {
                    Write-Host "    • $detail" -ForegroundColor Gray
                }
            }
        }
    }
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    Write-Host "  Success: $successCount | Failed: $failedCount | Skipped: $skippedCount" -ForegroundColor Cyan
    
    # Save cleanup report
    $reportPath = Join-Path $ProjectRoot "cleanup-report-pr-$PRNumber.json"
    $CleanupResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Force
    Write-Host "`n📄 Cleanup report saved: $reportPath" -ForegroundColor Gray
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "Environment cleanup completed for PR #$PRNumber" -Level 'Information'
    }
    
    # Exit with appropriate code
    if ($failedCount -gt 0) {
        Write-Host "`n⚠️ Cleanup completed with errors" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "`n✅ Cleanup completed successfully" -ForegroundColor Green
        exit 0
    }
    
} catch {
    Write-Host "`n❌ Cleanup failed: $_" -ForegroundColor Red
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "Cleanup failed: $_" -Level 'Error'
    }
    
    exit 1
}
