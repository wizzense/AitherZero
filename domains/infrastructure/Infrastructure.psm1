#Requires -Version 7.0

# Simple infrastructure module for OpenTofu/Terraform

# Logging helper for Infrastructure module
function Write-InfraLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "Infrastructure" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] [Infrastructure] $Message" -ForegroundColor $color
    }
}

# Log module initialization (only once)
if (-not (Get-Variable -Name "AitherZeroInfrastructureInitialized" -Scope Global -ErrorAction SilentlyContinue)) {
    Write-InfraLog -Message "Infrastructure module initialized" -Data @{
        OpenTofuAvailable = (Get-Command tofu -ErrorAction SilentlyContinue) -ne $null
        TerraformAvailable = (Get-Command terraform -ErrorAction SilentlyContinue) -ne $null
    }
    $global:AitherZeroInfrastructureInitialized = $true
}

function Test-OpenTofu {
    Write-InfraLog -Level Debug -Message "Testing infrastructure tool availability"

    try {
        $null = Get-Command tofu -ErrorAction Stop
        Write-InfraLog -Message "OpenTofu found and available"
        return $true
    }
    catch {
        try {
            $null = Get-Command terraform -ErrorAction Stop
            Write-InfraLog -Message "Terraform found and available (OpenTofu not found)"
            return $true
        }
        catch {
            Write-InfraLog -Level Warning -Message "Neither OpenTofu nor Terraform found in PATH"
            return $false
        }
    }
}

function Get-InfrastructureTool {
    Write-InfraLog -Level Debug -Message "Determining available infrastructure tool"

    if (Get-Command tofu -ErrorAction SilentlyContinue) {
        Write-InfraLog -Message "Using OpenTofu as infrastructure tool"
        return "tofu"
    }
    elseif (Get-Command terraform -ErrorAction SilentlyContinue) {
        Write-InfraLog -Message "Using Terraform as infrastructure tool"
        return "terraform"
    }
    else {
        Write-InfraLog -Level Error -Message "No infrastructure tool available"
        throw "Neither OpenTofu nor Terraform found in PATH"
    }
}

# Helper function to execute infrastructure tool commands - this makes testing easier
function Invoke-InfrastructureToolCommand {
    param(
        [string]$Tool,
        [string[]]$Arguments
    )

    Write-InfraLog -Level Debug -Message "Executing $Tool with arguments: $($Arguments -join ' ')"

    try {
        & $Tool @Arguments
        Write-InfraLog -Level Debug -Message "Successfully executed: $Tool $($Arguments -join ' ')"
    }
    catch {
        Write-InfraLog -Level Error -Message "Failed to execute $Tool command" -Data @{
            Arguments = $Arguments
            Error = $_.Exception.Message
        }
        throw
    }
}

function Invoke-InfrastructurePlan {
    param(
        [string]$WorkingDirectory = "./infrastructure"
    )

    if (-not (Test-Path $WorkingDirectory)) {
        Write-Host "Infrastructure directory not found: $WorkingDirectory" -ForegroundColor Red
        return
    }

    $tool = Get-InfrastructureTool
    Write-Host "Using $tool for infrastructure planning..." -ForegroundColor Cyan

    Push-Location $WorkingDirectory
    try {
        Invoke-InfrastructureToolCommand -Tool $tool -Arguments @('init')
        Invoke-InfrastructureToolCommand -Tool $tool -Arguments @('plan')
    }
    finally {
        Pop-Location
    }
}

function Invoke-InfrastructureApply {
    param(
        [string]$WorkingDirectory = "./infrastructure",
        [switch]$AutoApprove
    )

    if (-not (Test-Path $WorkingDirectory)) {
        Write-Host "Infrastructure directory not found: $WorkingDirectory" -ForegroundColor Red
        return
    }

    $tool = Get-InfrastructureTool
    Write-Host "Using $tool for infrastructure deployment..." -ForegroundColor Cyan

    Push-Location $WorkingDirectory
    try {
        Invoke-InfrastructureToolCommand -Tool $tool -Arguments @('init')
        if ($AutoApprove) {
            Invoke-InfrastructureToolCommand -Tool $tool -Arguments @('apply', '-auto-approve')
        } else {
            Invoke-InfrastructureToolCommand -Tool $tool -Arguments @('apply')
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-InfrastructureDestroy {
    param(
        [string]$WorkingDirectory = "./infrastructure",
        [switch]$AutoApprove
    )

    if (-not (Test-Path $WorkingDirectory)) {
        Write-Host "Infrastructure directory not found: $WorkingDirectory" -ForegroundColor Red
        return
    }

    $tool = Get-InfrastructureTool
    Write-Host "Using $tool for infrastructure destruction..." -ForegroundColor Red

    if (-not $AutoApprove) {
        $confirm = Read-Host "Are you sure you want to destroy all infrastructure? (yes/no)"
        if ($confirm -ne 'yes') {
            Write-Host "Destruction cancelled" -ForegroundColor Yellow
            return
        }
    }

    Push-Location $WorkingDirectory
    try {
        if ($AutoApprove) {
            Invoke-InfrastructureToolCommand -Tool $tool -Arguments @('destroy', '-auto-approve')
        } else {
            Invoke-InfrastructureToolCommand -Tool $tool -Arguments @('destroy')
        }
    }
    finally {
        Pop-Location
    }
}

# Advanced Infrastructure Management Functions

function Get-InfrastructureState {
    <#
    .SYNOPSIS
        Get current infrastructure state information
    .DESCRIPTION
        Retrieves current state information from OpenTofu/Terraform state files
    .PARAMETER WorkingDirectory
        Infrastructure directory containing state files
    #>
    param(
        [string]$WorkingDirectory = "./infrastructure"
    )

    Write-InfraLog -Level Debug -Message "Getting infrastructure state from $WorkingDirectory"

    if (-not (Test-Path $WorkingDirectory)) {
        Write-InfraLog -Level Error -Message "Infrastructure directory not found: $WorkingDirectory"
        return $null
    }

    try {
        $tool = Get-InfrastructureTool
    } catch {
        Write-InfraLog -Level Warning -Message "Infrastructure tool not available: $_"
        return @{
            Resources = @()
            Outputs = @{}
            Status = "Tool not available"
            ResourceCount = 0
        }
    }
    
    Push-Location $WorkingDirectory
    try {
        Write-InfraLog -Message "Retrieving infrastructure state using $tool"
        
        # Get state list
        $stateList = & $tool state list 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-InfraLog -Level Warning -Message "No state found or state command failed"
            return @{
                Resources = @()
                Outputs = @{}
                Status = "No state"
            }
        }

        # Get outputs
        $outputs = @{}
        try {
            $outputJson = & $tool output -json 2>&1
            if ($LASTEXITCODE -eq 0 -and $outputJson) {
                $outputs = $outputJson | ConvertFrom-Json -AsHashtable
            }
        } catch {
            Write-InfraLog -Level Debug -Message "No outputs available"
        }

        # Parse state list
        $resources = if ($stateList) {
            $stateList -split "`n" | Where-Object { $_ -and $_ -notmatch "^$" } | ForEach-Object {
                $parts = $_ -split '\.'
                @{
                    Type = $parts[0]
                    Name = $parts[1]
                    FullName = $_
                }
            }
        } else {
            @()
        }

        return @{
            Resources = $resources
            Outputs = $outputs
            Status = "Active"
            ResourceCount = $resources.Count
        }
    } catch {
        Write-InfraLog -Level Error -Message "Failed to get infrastructure state: $_"
        return $null
    } finally {
        Pop-Location
    }
}

function Test-InfrastructureConfiguration {
    <#
    .SYNOPSIS
        Validate infrastructure configuration files
    .DESCRIPTION
        Validates OpenTofu/Terraform configuration syntax and logic
    .PARAMETER WorkingDirectory
        Infrastructure directory to validate
    #>
    param(
        [string]$WorkingDirectory = "./infrastructure"
    )

    Write-InfraLog -Level Debug -Message "Validating infrastructure configuration in $WorkingDirectory"

    if (-not (Test-Path $WorkingDirectory)) {
        Write-InfraLog -Level Error -Message "Infrastructure directory not found: $WorkingDirectory"
        return $false
    }

    $tool = Get-InfrastructureTool
    
    Push-Location $WorkingDirectory
    try {
        Write-InfraLog -Message "Validating infrastructure configuration using $tool"
        
        # Run validation
        $validationResult = & $tool validate -json 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-InfraLog -Message "Infrastructure configuration is valid"
            return $true
        } else {
            Write-InfraLog -Level Error -Message "Infrastructure configuration validation failed"
            if ($validationResult) {
                Write-InfraLog -Level Error -Message "Validation output: $validationResult"
            }
            return $false
        }
    } catch {
        Write-InfraLog -Level Error -Message "Failed to validate infrastructure configuration: $_"
        return $false
    } finally {
        Pop-Location
    }
}

function Invoke-InfrastructureRefresh {
    <#
    .SYNOPSIS
        Refresh infrastructure state
    .DESCRIPTION
        Updates infrastructure state from actual resource state
    .PARAMETER WorkingDirectory
        Infrastructure directory
    #>
    param(
        [string]$WorkingDirectory = "./infrastructure"
    )

    Write-InfraLog -Level Debug -Message "Refreshing infrastructure state in $WorkingDirectory"

    if (-not (Test-Path $WorkingDirectory)) {
        Write-InfraLog -Level Error -Message "Infrastructure directory not found: $WorkingDirectory"
        return $false
    }

    $tool = Get-InfrastructureTool
    
    Push-Location $WorkingDirectory
    try {
        Write-InfraLog -Message "Refreshing infrastructure state using $tool"
        
        # Run refresh
        Invoke-InfrastructureToolCommand -Tool $tool -Arguments @('refresh')
        Write-InfraLog -Message "Infrastructure state refreshed successfully"
        return $true
    } catch {
        Write-InfraLog -Level Error -Message "Failed to refresh infrastructure state: $_"
        return $false
    } finally {
        Pop-Location
    }
}

function Get-InfrastructureInventory {
    <#
    .SYNOPSIS
        Get comprehensive infrastructure inventory
    .DESCRIPTION
        Collects detailed inventory of all infrastructure resources
    .PARAMETER WorkingDirectory
        Infrastructure directory
    .PARAMETER Format
        Output format (Object, JSON, Table)
    #>
    param(
        [string]$WorkingDirectory = "./infrastructure",
        [ValidateSet("Object", "JSON", "Table")]
        [string]$Format = "Object"
    )

    Write-InfraLog -Level Debug -Message "Generating infrastructure inventory from $WorkingDirectory"

    $state = Get-InfrastructureState -WorkingDirectory $WorkingDirectory
    if (-not $state) {
        return $null
    }

    $inventory = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        WorkingDirectory = $WorkingDirectory
        Status = $state.Status
        Summary = @{
            TotalResources = $state.ResourceCount
            ResourceTypes = ($state.Resources | Group-Object Type | Select-Object Name, Count)
            Outputs = $state.Outputs.Keys
        }
        Resources = $state.Resources
        Outputs = $state.Outputs
    }

    switch ($Format) {
        "JSON" {
            return $inventory | ConvertTo-Json -Depth 10
        }
        "Table" {
            Write-Output "Infrastructure Inventory - $($inventory.Timestamp)"
            Write-Output "Working Directory: $($inventory.WorkingDirectory)"
            Write-Output "Status: $($inventory.Status)"
            Write-Output ""
            Write-Output "Resource Summary:"
            $inventory.Summary.ResourceTypes | Format-Table -AutoSize
            Write-Output ""
            Write-Output "Resources:"
            $inventory.Resources | Format-Table -AutoSize
            return
        }
        default {
            return $inventory
        }
    }
}

function Start-InfrastructureBootstrap {
    <#
    .SYNOPSIS
        Bootstrap infrastructure from zero state
    .DESCRIPTION
        Complete infrastructure bootstrap process from clean state to production ready
    .PARAMETER Configuration
        Configuration object with bootstrap settings
    .PARAMETER SkipPrerequisites
        Skip prerequisite checks
    #>
    param(
        [hashtable]$Configuration = @{},
        [switch]$SkipPrerequisites
    )

    Write-InfraLog -Message "Starting infrastructure bootstrap process"

    try {
        # Check prerequisites
        if (-not $SkipPrerequisites) {
            Write-InfraLog -Message "Checking prerequisites..."
            
            if (-not (Test-OpenTofu)) {
                Write-InfraLog -Level Error -Message "OpenTofu/Terraform not available. Please install first."
                return $false
            }
            
            # Check for Git
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                Write-InfraLog -Level Error -Message "Git not available. Please install Git first."
                return $false
            }
        }

        # Create infrastructure directory if it doesn't exist
        $infraDir = if ($Configuration.Infrastructure -and $Configuration.Infrastructure.WorkingDirectory) {
            $Configuration.Infrastructure.WorkingDirectory
        } else {
            "./infrastructure"
        }

        if (-not (Test-Path $infraDir)) {
            Write-InfraLog -Message "Creating infrastructure directory: $infraDir"
            New-Item -ItemType Directory -Path $infraDir -Force | Out-Null
        }

        # Initialize basic infrastructure structure
        $basicDirs = @("modules", "environments", "shared")
        foreach ($dir in $basicDirs) {
            $fullPath = Join-Path $infraDir $dir
            if (-not (Test-Path $fullPath)) {
                Write-InfraLog -Message "Creating directory: $fullPath"
                New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            }
        }

        # Create basic main.tf if it doesn't exist
        $mainTf = Join-Path $infraDir "main.tf"
        if (-not (Test-Path $mainTf)) {
            Write-InfraLog -Message "Creating basic main.tf"
            $basicConfig = @"
# AitherZero Infrastructure Configuration
# Generated by infrastructure bootstrap

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    hyperv = {
      source  = "taliesins/hyperv"
      version = "~>1.0"
    }
  }
}

# Configure providers based on your requirements
# Uncomment and configure as needed

# provider "azurerm" {
#   features {}
# }

# provider "hyperv" {
#   user            = "Administrator"
#   password        = var.hyperv_password
#   host            = var.hyperv_host
#   port            = 5986
#   https           = true
#   insecure        = true
#   use_ntlm        = true
#   timeout         = "30s"
#   script_path     = "C:/Temp/terraform_%RAND%.cmd"
# }

# Example resource definitions
# Remove or modify based on your needs

# resource "azurerm_resource_group" "main" {
#   name     = "rg-aitherzero-${var.environment}"
#   location = var.location
# }
"@
            Set-Content -Path $mainTf -Value $basicConfig -Encoding UTF8
        }

        # Create variables.tf
        $variablesTf = Join-Path $infraDir "variables.tf"
        if (-not (Test-Path $variablesTf)) {
            Write-InfraLog -Message "Creating variables.tf"
            $variablesConfig = @"
# AitherZero Infrastructure Variables

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "hyperv_host" {
  description = "Hyper-V host address"
  type        = string
  default     = "localhost"
}

variable "hyperv_password" {
  description = "Hyper-V host password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "resource_tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    Project     = "AitherZero"
    ManagedBy   = "OpenTofu"
    Environment = "Development"
  }
}
"@
            Set-Content -Path $variablesTf -Value $variablesConfig -Encoding UTF8
        }

        # Create outputs.tf
        $outputsTf = Join-Path $infraDir "outputs.tf"
        if (-not (Test-Path $outputsTf)) {
            Write-InfraLog -Message "Creating outputs.tf"
            $outputsConfig = @"
# AitherZero Infrastructure Outputs

# output "resource_group_name" {
#   description = "Name of the main resource group"
#   value       = azurerm_resource_group.main.name
# }

# output "resource_group_location" {
#   description = "Location of the main resource group"
#   value       = azurerm_resource_group.main.location
# }
"@
            Set-Content -Path $outputsTf -Value $outputsConfig -Encoding UTF8
        }

        # Initialize OpenTofu
        Write-InfraLog -Message "Initializing OpenTofu..."
        Push-Location $infraDir
        try {
            $tool = Get-InfrastructureTool
            Invoke-InfrastructureToolCommand -Tool $tool -Arguments @('init')
            Write-InfraLog -Message "OpenTofu initialized successfully"
        } finally {
            Pop-Location
        }

        # Validate configuration
        if (Test-InfrastructureConfiguration -WorkingDirectory $infraDir) {
            Write-InfraLog -Message "Infrastructure bootstrap completed successfully"
            Write-InfraLog -Message "Infrastructure directory: $infraDir"
            Write-InfraLog -Message "Next steps:"
            Write-InfraLog -Message "  1. Configure providers in main.tf"
            Write-InfraLog -Message "  2. Define your infrastructure resources"
            Write-InfraLog -Message "  3. Run 'tofu plan' to preview changes"
            Write-InfraLog -Message "  4. Run 'tofu apply' to deploy infrastructure"
            return $true
        } else {
            Write-InfraLog -Level Error -Message "Infrastructure bootstrap completed but configuration validation failed"
            return $false
        }

    } catch {
        Write-InfraLog -Level Error -Message "Infrastructure bootstrap failed: $_"
        return $false
    }
}

Export-ModuleMember -Function Test-OpenTofu, Get-InfrastructureTool, Invoke-InfrastructurePlan, Invoke-InfrastructureApply, Invoke-InfrastructureDestroy, Get-InfrastructureState, Test-InfrastructureConfiguration, Invoke-InfrastructureRefresh, Get-InfrastructureInventory, Start-InfrastructureBootstrap