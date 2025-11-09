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

#region Infrastructure Submodule Management

<#
.SYNOPSIS
    Initialize infrastructure Git submodules based on configuration.

.DESCRIPTION
    Initializes Git submodules for infrastructure repositories as configured in config.psd1.
    Supports both the default Aitherium infrastructure and custom repositories.

.PARAMETER Name
    Name of a specific submodule to initialize. If not specified, initializes all enabled submodules.

.PARAMETER Url
    Git repository URL (overrides configuration). Used for ad-hoc submodule initialization.

.PARAMETER Path
    Local path for the submodule (overrides configuration).

.PARAMETER Branch
    Git branch to checkout (overrides configuration).

.PARAMETER Force
    Force re-initialization even if submodule already exists.

.EXAMPLE
    Initialize-InfrastructureSubmodule
    Initializes all enabled submodules from configuration.

.EXAMPLE
    Initialize-InfrastructureSubmodule -Name 'aitherium-infrastructure'
    Initializes only the default Aitherium infrastructure submodule.

.EXAMPLE
    Initialize-InfrastructureSubmodule -Name 'custom' -Url 'https://github.com/me/infra.git' -Path 'infrastructure/custom'
    Initializes a custom submodule with specified URL and path.
#>
function Initialize-InfrastructureSubmodule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter()]
        [string]$Url,

        [Parameter()]
        [string]$Path,

        [Parameter()]
        [string]$Branch,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-InfraLog -Message "Initializing infrastructure submodules"
        
        # Check if git is available
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-InfraLog -Level Error -Message "Git is not installed or not in PATH"
            throw "Git is required for submodule management"
        }

        # Check if we're in a git repository
        try {
            $gitRoot = git rev-parse --show-toplevel 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Not in a git repository"
            }
            Write-InfraLog -Level Debug -Message "Git repository root: $gitRoot"
        }
        catch {
            Write-InfraLog -Level Error -Message "Not in a git repository: $($_.Exception.Message)"
            throw
        }

        # Load configuration
        try {
            $config = Get-Configuration
            $submoduleConfig = $config.Infrastructure.Submodules
            
            if (-not $submoduleConfig.Enabled) {
                Write-InfraLog -Level Warning -Message "Infrastructure submodules are disabled in configuration"
                return
            }
        }
        catch {
            Write-InfraLog -Level Error -Message "Failed to load configuration: $($_.Exception.Message)"
            throw
        }
    }

    process {
        try {
            # Determine which submodules to initialize
            $submodulesToInit = @()

            if ($Name -and $Url) {
                # Ad-hoc submodule initialization
                $submodulesToInit += @{
                    Name   = $Name
                    Url    = $Url
                    Path   = if ($Path) { $Path } else { "infrastructure/$Name" }
                    Branch = if ($Branch) { $Branch } else { 'main' }
                }
                Write-InfraLog -Message "Initializing ad-hoc submodule: $Name" -Data @{ Url = $Url; Path = $Path }
            }
            elseif ($Name) {
                # Initialize specific named submodule from configuration
                if ($Name -eq 'default' -or $Name -eq $submoduleConfig.Default.Name) {
                    if ($submoduleConfig.Default.Enabled) {
                        $submodulesToInit += $submoduleConfig.Default
                        Write-InfraLog -Message "Initializing default submodule from configuration"
                    }
                    else {
                        Write-InfraLog -Level Warning -Message "Default submodule is disabled in configuration"
                    }
                }
                elseif ($submoduleConfig.Repositories.ContainsKey($Name)) {
                    $repo = $submoduleConfig.Repositories[$Name]
                    if ($repo.Enabled) {
                        $submodulesToInit += $repo
                        Write-InfraLog -Message "Initializing submodule '$Name' from configuration"
                    }
                    else {
                        Write-InfraLog -Level Warning -Message "Submodule '$Name' is disabled in configuration"
                    }
                }
                else {
                    Write-InfraLog -Level Error -Message "Submodule '$Name' not found in configuration"
                    throw "Submodule '$Name' not configured"
                }
            }
            else {
                # Initialize all enabled submodules
                if ($submoduleConfig.Default.Enabled) {
                    $submodulesToInit += $submoduleConfig.Default
                }
                
                foreach ($key in $submoduleConfig.Repositories.Keys) {
                    $repo = $submoduleConfig.Repositories[$key]
                    if ($repo.Enabled) {
                        $submodulesToInit += $repo
                    }
                }
                Write-InfraLog -Message "Initializing all enabled submodules" -Data @{ Count = $submodulesToInit.Count }
            }

            # Initialize each submodule
            foreach ($submodule in $submodulesToInit) {
                $submodulePath = $submodule.Path
                $submoduleUrl = $submodule.Url
                $submoduleBranch = if ($submodule.Branch) { $submodule.Branch } else { 'main' }
                $submoduleName = if ($submodule.Name) { $submodule.Name } else { Split-Path $submodulePath -Leaf }

                Write-InfraLog -Message "Processing submodule: $submoduleName" -Data @{
                    Path   = $submodulePath
                    Url    = $submoduleUrl
                    Branch = $submoduleBranch
                }

                if ($PSCmdlet.ShouldProcess($submodulePath, "Initialize submodule")) {
                    # Check if submodule already exists
                    $submoduleExists = Test-Path $submodulePath
                    $isGitSubmodule = $false
                    
                    if ($submoduleExists) {
                        # Check if it's already a git submodule
                        $gitmodulesContent = git config --file .gitmodules --get-regexp "submodule\.$submodulePath\." 2>$null
                        $isGitSubmodule = $LASTEXITCODE -eq 0
                    }

                    if ($isGitSubmodule -and -not $Force) {
                        Write-InfraLog -Level Warning -Message "Submodule already exists: $submodulePath (use -Force to reinitialize)"
                        
                        # Just update the existing submodule
                        Write-InfraLog -Message "Updating existing submodule: $submodulePath"
                        git submodule update --init --recursive $submodulePath 2>&1 | Out-Null
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-InfraLog -Message "Successfully updated submodule: $submodulePath"
                        }
                        else {
                            Write-InfraLog -Level Error -Message "Failed to update submodule: $submodulePath"
                        }
                        continue
                    }

                    if ($Force -and $isGitSubmodule) {
                        Write-InfraLog -Message "Force removing existing submodule: $submodulePath"
                        git submodule deinit -f $submodulePath 2>&1 | Out-Null
                        git rm -f $submodulePath 2>&1 | Out-Null
                        Remove-Item -Path ".git/modules/$submodulePath" -Recurse -Force -ErrorAction SilentlyContinue
                    }

                    # Add the submodule
                    Write-InfraLog -Message "Adding submodule: $submodulePath"
                    $addArgs = @('submodule', 'add')
                    
                    if ($submoduleBranch) {
                        $addArgs += @('-b', $submoduleBranch)
                    }
                    
                    $addArgs += @($submoduleUrl, $submodulePath)
                    
                    $output = & git @addArgs 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-InfraLog -Message "Successfully added submodule: $submodulePath"
                        
                        # Initialize and update recursively if configured
                        if ($submoduleConfig.Behavior.RecursiveInit) {
                            Write-InfraLog -Level Debug -Message "Initializing submodule recursively"
                            git submodule update --init --recursive $submodulePath 2>&1 | Out-Null
                        }
                        else {
                            git submodule update --init $submodulePath 2>&1 | Out-Null
                        }
                        
                        Write-Host "✓ Initialized: $submoduleName at $submodulePath" -ForegroundColor Green
                    }
                    else {
                        Write-InfraLog -Level Error -Message "Failed to add submodule: $submodulePath" -Data @{ Output = ($output | Out-String) }
                        Write-Host "✗ Failed: $submoduleName - $output" -ForegroundColor Red
                    }
                }
            }

            Write-InfraLog -Message "Submodule initialization complete"
        }
        catch {
            Write-InfraLog -Level Error -Message "Failed to initialize submodules: $($_.Exception.Message)"
            throw
        }
    }
}

<#
.SYNOPSIS
    Update an infrastructure Git submodule.

.DESCRIPTION
    Updates a single infrastructure Git submodule to the latest commit on its configured branch.
    Designed to work with pipeline input from Get-InfrastructureSubmodule.

.PARAMETER InputObject
    Submodule object from Get-InfrastructureSubmodule (pipeline input).

.PARAMETER Name
    Name of a specific submodule to update.

.PARAMETER Path
    Path of the submodule to update.

.PARAMETER Merge
    Merge changes instead of checking out (default is checkout).

.PARAMETER Remote
    Update to the latest remote commit instead of the pinned commit.

.EXAMPLE
    Update-InfrastructureSubmodule -Name 'aitherium-infrastructure'
    Updates a specific submodule by name.

.EXAMPLE
    Get-InfrastructureSubmodule | Update-InfrastructureSubmodule
    Gets all submodules and updates each one via pipeline.

.EXAMPLE
    Get-InfrastructureSubmodule -Initialized | Update-InfrastructureSubmodule -Remote
    Updates only initialized submodules to their latest remote commits.

.EXAMPLE
    Get-InfrastructureSubmodule | Where-Object { $_.Name -like '*test*' } | Update-InfrastructureSubmodule -Merge
    Filters submodules and updates them with merge strategy.
#>
function Update-InfrastructureSubmodule {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSCustomObject]$InputObject,

        [Parameter(ParameterSetName = 'ByName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByPath')]
        [string]$Path,

        [Parameter()]
        [switch]$Merge,

        [Parameter()]
        [switch]$Remote
    )

    begin {
        Write-InfraLog -Level Debug -Message "Starting submodule update operation"
        
        # Check if git is available
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-InfraLog -Level Error -Message "Git is not installed or not in PATH"
            throw "Git is required for submodule management"
        }

        # Load config once in begin block
        try {
            $config = Get-Configuration
            $recursiveInit = $config.Infrastructure.Submodules.Behavior.RecursiveInit
        }
        catch {
            Write-InfraLog -Level Warning -Message "Could not load configuration, using default behavior"
            $recursiveInit = $true
        }
    }

    process {
        try {
            # Determine submodule path
            $submodulePath = $null
            $submoduleName = $null

            if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
                $submodulePath = $InputObject.Path
                $submoduleName = $InputObject.Name
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByPath') {
                $submodulePath = $Path
                $submoduleName = Split-Path $Path -Leaf
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByName') {
                # Find submodule from configuration
                $config = Get-Configuration
                $submoduleConfig = $config.Infrastructure.Submodules
                
                if ($Name -eq 'default' -or $Name -eq $submoduleConfig.Default.Name) {
                    $submodulePath = $submoduleConfig.Default.Path
                    $submoduleName = $submoduleConfig.Default.Name
                }
                elseif ($submoduleConfig.Repositories.ContainsKey($Name)) {
                    $submodulePath = $submoduleConfig.Repositories[$Name].Path
                    $submoduleName = $Name
                }
                else {
                    Write-InfraLog -Level Error -Message "Submodule '$Name' not found in configuration"
                    throw "Submodule '$Name' not configured"
                }
            }

            if (-not $submodulePath) {
                throw "Could not determine submodule path"
            }

            Write-InfraLog -Message "Updating submodule: $submoduleName at $submodulePath"

            # Build update command
            $updateArgs = @('submodule', 'update', '--init')
            
            if ($Merge) {
                $updateArgs += '--merge'
            }
            
            if ($Remote) {
                $updateArgs += '--remote'
            }
            
            if ($recursiveInit) {
                $updateArgs += '--recursive'
            }
            
            $updateArgs += $submodulePath

            if ($PSCmdlet.ShouldProcess($submodulePath, "Update submodule")) {
                Write-InfraLog -Level Debug -Message "Executing: git $($updateArgs -join ' ')"
                
                $output = & git @updateArgs 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-InfraLog -Message "Successfully updated submodule: $submoduleName"
                    Write-Host "✓ Updated: $submoduleName" -ForegroundColor Green
                    
                    # Return updated submodule object for pipeline
                    if ($InputObject) {
                        return $InputObject
                    }
                }
                else {
                    Write-InfraLog -Level Error -Message "Failed to update submodule: $submoduleName" -Data @{ Output = ($output | Out-String) }
                    Write-Host "✗ Failed: $submoduleName - $output" -ForegroundColor Red
                    throw "Git submodule update failed for $submoduleName"
                }
            }
        }
        catch {
            Write-InfraLog -Level Error -Message "Failed to update submodule: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-InfraLog -Level Debug -Message "Submodule update operation complete"
    }
}

<#
.SYNOPSIS
    Get information about infrastructure submodules.

.DESCRIPTION
    Retrieves infrastructure submodule configuration and status.
    Outputs one submodule object at a time, suitable for pipeline processing.

.PARAMETER Name
    Get a specific submodule by name.

.PARAMETER Initialized
    Show only initialized submodules.

.PARAMETER Enabled
    Show only enabled submodules (default).

.PARAMETER All
    Show all submodules (enabled and disabled).

.PARAMETER Detailed
    Include detailed information (current commit, branch).

.EXAMPLE
    Get-InfrastructureSubmodule
    Gets all enabled submodules.

.EXAMPLE
    Get-InfrastructureSubmodule -Initialized
    Gets only initialized submodules.

.EXAMPLE
    Get-InfrastructureSubmodule -All -Detailed
    Gets all submodules with detailed information.

.EXAMPLE
    Get-InfrastructureSubmodule | Update-InfrastructureSubmodule
    Pipeline: Gets all submodules and updates each one.

.EXAMPLE
    Get-InfrastructureSubmodule -Name 'aitherium-infrastructure'
    Gets a specific submodule by name.
#>
function Get-InfrastructureSubmodule {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter()]
        [switch]$Initialized,

        [Parameter()]
        [switch]$Enabled,

        [Parameter()]
        [switch]$All,

        [Parameter()]
        [switch]$Detailed
    )

    begin {
        Write-InfraLog -Level Debug -Message "Getting infrastructure submodules"

        try {
            # Load configuration once in begin block
            $config = Get-Configuration
            $submoduleConfig = $config.Infrastructure.Submodules

            if (-not $submoduleConfig.Enabled) {
                Write-InfraLog -Level Warning -Message "Infrastructure submodules are disabled in configuration"
                return
            }

            $gitAvailable = Get-Command git -ErrorAction SilentlyContinue
        }
        catch {
            Write-InfraLog -Level Error -Message "Failed to load configuration: $($_.Exception.Message)"
            throw
        }
    }

    process {
        try {
            $submodules = @()

            # If Name is specified, only get that one
            if ($Name) {
                if ($Name -eq 'default' -or $Name -eq $submoduleConfig.Default.Name) {
                    if ($submoduleConfig.Default) {
                        $submodules += $submoduleConfig.Default
                    }
                }
                elseif ($submoduleConfig.Repositories.ContainsKey($Name)) {
                    $repo = $submoduleConfig.Repositories[$Name]
                    $repo.Name = $Name
                    $submodules += $repo
                }
                else {
                    Write-InfraLog -Level Warning -Message "Submodule '$Name' not found in configuration"
                    return
                }
            }
            else {
                # Get all submodules
                
                # Add default submodule
                if ($submoduleConfig.Default) {
                    $submodules += $submoduleConfig.Default
                }

                # Add additional repositories
                foreach ($key in $submoduleConfig.Repositories.Keys) {
                    $repo = $submoduleConfig.Repositories[$key]
                    if (-not $repo.Name) {
                        $repo.Name = $key
                    }
                    $submodules += $repo
                }
            }

            # Process each submodule and output one at a time
            foreach ($submodule in $submodules) {
                # Skip disabled unless -All is specified
                if (-not $All -and -not $submodule.Enabled) {
                    continue
                }

                # Create output object
                $outputObject = [PSCustomObject]@{
                    PSTypeName  = 'AitherZero.InfrastructureSubmodule'
                    Name        = $submodule.Name
                    Url         = $submodule.Url
                    Path        = $submodule.Path
                    Branch      = $submodule.Branch
                    Description = $submodule.Description
                    Enabled     = $submodule.Enabled
                    IsDefault   = if ($submodule.PSObject.Properties['IsDefault']) { $submodule.IsDefault } else { $false }
                    Initialized = $false
                }

                # Check git status
                if ($gitAvailable -and (Test-Path $submodule.Path)) {
                    # Check if path is a git submodule
                    $gitmodulesContent = git config --file .gitmodules --get-regexp "submodule\.$($submodule.Path)\." 2>$null
                    $outputObject.Initialized = $LASTEXITCODE -eq 0

                    if ($outputObject.Initialized -and $Detailed) {
                        Push-Location $submodule.Path
                        try {
                            $currentCommit = git rev-parse --short HEAD 2>$null
                            $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
                            
                            $outputObject | Add-Member -NotePropertyName 'CurrentCommit' -NotePropertyValue $currentCommit
                            $outputObject | Add-Member -NotePropertyName 'CurrentBranch' -NotePropertyValue $currentBranch
                        }
                        finally {
                            Pop-Location
                        }
                    }
                }

                # Filter if requested
                if ($Initialized -and -not $outputObject.Initialized) {
                    continue
                }

                # Output one submodule at a time for pipeline
                Write-Output $outputObject
            }
        }
        catch {
            Write-InfraLog -Level Error -Message "Failed to get submodule information: $($_.Exception.Message)"
            throw
        }
    }
}

<#
.SYNOPSIS
    Synchronize .gitmodules with config.psd1 configuration.

.DESCRIPTION
    Ensures that .gitmodules file matches the configuration in config.psd1.
    Can add missing submodules or remove unmanaged ones.

.PARAMETER Force
    Remove submodules that are not in configuration.

.EXAMPLE
    Sync-InfrastructureSubmodule
    Adds missing submodules from configuration.

.EXAMPLE
    Sync-InfrastructureSubmodule -Force
    Adds missing and removes unmanaged submodules.
#>
function Sync-InfrastructureSubmodule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$Force
    )

    Write-InfraLog -Message "Synchronizing infrastructure submodules with configuration"

    try {
        # Get configured submodules
        $configured = Get-InfrastructureSubmodule

        # Get actual git submodules
        $actual = @()
        if (Test-Path '.gitmodules') {
            $gitSubmodules = git config --file .gitmodules --get-regexp 'submodule\..*\.path' 2>$null
            if ($LASTEXITCODE -eq 0) {
                $gitSubmodules | ForEach-Object {
                    if ($_ -match 'submodule\.(.+)\.path (.+)') {
                        $actual += [PSCustomObject]@{
                            Name = $matches[1]
                            Path = $matches[2]
                        }
                    }
                }
            }
        }

        # Find submodules to add (configured but not in git)
        $configuredPaths = $configured | Where-Object { $_.Enabled } | Select-Object -ExpandProperty Path
        $actualPaths = $actual | Select-Object -ExpandProperty Path
        
        $toAdd = $configured | Where-Object { $_.Enabled -and $_.Path -notin $actualPaths }
        
        if ($toAdd) {
            Write-InfraLog -Message "Found $($toAdd.Count) submodule(s) to add"
            foreach ($submodule in $toAdd) {
                if ($PSCmdlet.ShouldProcess($submodule.Path, "Add submodule")) {
                    Write-Host "Adding submodule: $($submodule.Name) at $($submodule.Path)" -ForegroundColor Cyan
                    Initialize-InfrastructureSubmodule -Name $submodule.Name -WhatIf:$false
                }
            }
        }
        else {
            Write-InfraLog -Message "No submodules to add"
            Write-Host "✓ All configured submodules are already initialized" -ForegroundColor Green
        }

        # Find submodules to remove (in git but not configured)
        if ($Force) {
            $toRemove = $actual | Where-Object { $_.Path -notin $configuredPaths -and $_.Path -like 'infrastructure/*' }
            
            if ($toRemove) {
                Write-InfraLog -Level Warning -Message "Found $($toRemove.Count) unmanaged submodule(s) to remove"
                foreach ($submodule in $toRemove) {
                    if ($PSCmdlet.ShouldProcess($submodule.Path, "Remove unmanaged submodule")) {
                        Write-Host "Removing unmanaged submodule: $($submodule.Path)" -ForegroundColor Yellow
                        Remove-InfrastructureSubmodule -Path $submodule.Path -WhatIf:$false
                    }
                }
            }
            else {
                Write-InfraLog -Message "No unmanaged submodules to remove"
            }
        }

        Write-InfraLog -Message "Submodule synchronization complete"
    }
    catch {
        Write-InfraLog -Level Error -Message "Failed to sync submodules: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Remove an infrastructure Git submodule.

.DESCRIPTION
    Removes a Git submodule and optionally cleans up its working directory.

.PARAMETER Name
    Name of the submodule to remove (from configuration).

.PARAMETER Path
    Path of the submodule to remove (if not using name).

.PARAMETER Clean
    Remove the submodule's working directory and .git cache.

.EXAMPLE
    Remove-InfrastructureSubmodule -Name 'old-infra'
    Removes the specified submodule.

.EXAMPLE
    Remove-InfrastructureSubmodule -Path 'infrastructure/old' -Clean
    Removes submodule and cleans up directories.
#>
function Remove-InfrastructureSubmodule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ParameterSetName = 'ByName', ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByPath', ValueFromPipelineByPropertyName)]
        [string]$Path,

        [Parameter()]
        [switch]$Clean
    )

    Write-InfraLog -Message "Removing infrastructure submodule"

    # Check if git is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-InfraLog -Level Error -Message "Git is not installed or not in PATH"
        throw "Git is required for submodule management"
    }

    try {
        # Determine submodule path
        if ($Name -and -not $Path) {
            $config = Get-Configuration
            $submoduleConfig = $config.Infrastructure.Submodules
            
            if ($Name -eq 'default' -or $Name -eq $submoduleConfig.Default.Name) {
                $Path = $submoduleConfig.Default.Path
            }
            elseif ($submoduleConfig.Repositories.ContainsKey($Name)) {
                $Path = $submoduleConfig.Repositories[$Name].Path
            }
            else {
                Write-InfraLog -Level Error -Message "Submodule '$Name' not found in configuration"
                throw "Submodule '$Name' not configured"
            }
        }

        if (-not $Path) {
            throw "Path must be specified or derivable from Name"
        }

        Write-InfraLog -Message "Removing submodule at path: $Path"

        if ($PSCmdlet.ShouldProcess($Path, "Remove submodule")) {
            # Deinitialize submodule
            Write-InfraLog -Level Debug -Message "Deinitializing submodule"
            git submodule deinit -f $Path 2>&1 | Out-Null

            # Remove from git
            Write-InfraLog -Level Debug -Message "Removing submodule from git"
            git rm -f $Path 2>&1 | Out-Null

            if ($Clean) {
                # Remove git cache
                $gitModulePath = ".git/modules/$Path"
                if (Test-Path $gitModulePath) {
                    Write-InfraLog -Level Debug -Message "Removing git cache: $gitModulePath"
                    Remove-Item -Path $gitModulePath -Recurse -Force
                }
            }

            if ($LASTEXITCODE -eq 0) {
                Write-InfraLog -Message "Successfully removed submodule: $Path"
                Write-Host "✓ Removed submodule: $Path" -ForegroundColor Green
            }
            else {
                Write-InfraLog -Level Error -Message "Failed to remove submodule: $Path"
                Write-Host "✗ Failed to remove submodule: $Path" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-InfraLog -Level Error -Message "Failed to remove submodule: $($_.Exception.Message)"
        throw
    }
}

#endregion Infrastructure Submodule Management

Export-ModuleMember -Function Test-OpenTofu, Get-InfrastructureTool, Invoke-InfrastructurePlan, Invoke-InfrastructureApply, Invoke-InfrastructureDestroy, Initialize-InfrastructureSubmodule, Update-InfrastructureSubmodule, Get-InfrastructureSubmodule, Sync-InfrastructureSubmodule, Remove-InfrastructureSubmodule