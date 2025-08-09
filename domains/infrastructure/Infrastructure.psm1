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

# Log module initialization
Write-InfraLog -Message "Infrastructure module initialized" -Data @{
    OpenTofuAvailable = (Get-Command tofu -ErrorAction SilentlyContinue) -ne $null
    TerraformAvailable = (Get-Command terraform -ErrorAction SilentlyContinue) -ne $null
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
        & $tool init
        & $tool plan
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
        & $tool init
        if ($AutoApprove) {
            & $tool apply -auto-approve
        } else {
            & $tool apply
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
            & $tool destroy -auto-approve
        } else {
            & $tool destroy
        }
    }
    finally {
        Pop-Location
    }
}

Export-ModuleMember -Function Test-OpenTofu, Invoke-InfrastructurePlan, Invoke-InfrastructureApply, Invoke-InfrastructureDestroy