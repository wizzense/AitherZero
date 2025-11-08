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
    Update infrastructure Git submodules.

.DESCRIPTION
    Updates Git submodules to the latest commits on their configured branches.

.PARAMETER Name
    Name of a specific submodule to update. If not specified, updates all submodules.

.PARAMETER Merge
    Merge changes instead of checking out (default is checkout).

.PARAMETER Remote
    Update to the latest remote commit instead of the pinned commit.

.EXAMPLE
    Update-InfrastructureSubmodules
    Updates all submodules to their pinned commits.

.EXAMPLE
    Update-InfrastructureSubmodules -Remote
    Updates all submodules to the latest commits from remote.

.EXAMPLE
    Update-InfrastructureSubmodules -Name 'aitherium-infrastructure' -Merge
    Updates the default submodule and merges changes.
#>
function Update-InfrastructureSubmodules {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter()]
        [switch]$Merge,

        [Parameter()]
        [switch]$Remote
    )

    Write-InfraLog -Message "Updating infrastructure submodules"

    # Check if git is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-InfraLog -Level Error -Message "Git is not installed or not in PATH"
        throw "Git is required for submodule management"
    }

    try {
        # Build update command
        $updateArgs = @('submodule', 'update', '--init')
        
        if ($Merge) {
            $updateArgs += '--merge'
        }
        
        if ($Remote) {
            $updateArgs += '--remote'
        }
        
        # Add recursive flag from config
        try {
            $config = Get-Configuration
            if ($config.Infrastructure.Submodules.Behavior.RecursiveInit) {
                $updateArgs += '--recursive'
            }
        }
        catch {
            Write-InfraLog -Level Warning -Message "Could not load configuration, using default behavior"
        }

        # Add specific submodule if specified
        if ($Name) {
            # Find submodule path from configuration
            try {
                $config = Get-Configuration
                $submoduleConfig = $config.Infrastructure.Submodules
                
                $submodulePath = $null
                if ($Name -eq 'default' -or $Name -eq $submoduleConfig.Default.Name) {
                    $submodulePath = $submoduleConfig.Default.Path
                }
                elseif ($submoduleConfig.Repositories.ContainsKey($Name)) {
                    $submodulePath = $submoduleConfig.Repositories[$Name].Path
                }
                
                if ($submodulePath) {
                    $updateArgs += $submodulePath
                    Write-InfraLog -Message "Updating specific submodule: $Name at $submodulePath"
                }
                else {
                    Write-InfraLog -Level Error -Message "Submodule '$Name' not found in configuration"
                    throw "Submodule '$Name' not configured"
                }
            }
            catch {
                Write-InfraLog -Level Error -Message "Failed to determine submodule path: $($_.Exception.Message)"
                throw
            }
        }

        if ($PSCmdlet.ShouldProcess("Infrastructure submodules", "Update")) {
            Write-InfraLog -Level Debug -Message "Executing: git $($updateArgs -join ' ')"
            
            $output = & git @updateArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-InfraLog -Message "Successfully updated submodules"
                Write-Host "✓ Submodules updated successfully" -ForegroundColor Green
            }
            else {
                Write-InfraLog -Level Error -Message "Failed to update submodules" -Data @{ Output = ($output | Out-String) }
                Write-Host "✗ Failed to update submodules: $output" -ForegroundColor Red
                throw "Git submodule update failed"
            }
        }
    }
    catch {
        Write-InfraLog -Level Error -Message "Failed to update submodules: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Get information about configured infrastructure submodules.

.DESCRIPTION
    Lists infrastructure submodules configured in config.psd1 and their status.

.PARAMETER Initialized
    Show only initialized submodules.

.PARAMETER Detailed
    Show detailed information including commit hashes and branches.

.EXAMPLE
    Get-InfrastructureSubmodules
    Lists all configured submodules.

.EXAMPLE
    Get-InfrastructureSubmodules -Initialized
    Lists only initialized submodules.

.EXAMPLE
    Get-InfrastructureSubmodules -Detailed
    Shows detailed information about all submodules.
#>
function Get-InfrastructureSubmodules {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Initialized,

        [Parameter()]
        [switch]$Detailed
    )

    Write-InfraLog -Level Debug -Message "Getting infrastructure submodules"

    try {
        # Load configuration
        $config = Get-Configuration
        $submoduleConfig = $config.Infrastructure.Submodules

        if (-not $submoduleConfig.Enabled) {
            Write-InfraLog -Level Warning -Message "Infrastructure submodules are disabled in configuration"
            Write-Host "Infrastructure submodules are disabled in configuration" -ForegroundColor Yellow
            return
        }

        $submodules = @()

        # Add default submodule
        if ($submoduleConfig.Default) {
            $submodules += [PSCustomObject]@{
                Name        = $submoduleConfig.Default.Name
                Url         = $submoduleConfig.Default.Url
                Path        = $submoduleConfig.Default.Path
                Branch      = $submoduleConfig.Default.Branch
                Description = $submoduleConfig.Default.Description
                Enabled     = $submoduleConfig.Default.Enabled
                IsDefault   = $true
            }
        }

        # Add additional repositories
        foreach ($key in $submoduleConfig.Repositories.Keys) {
            $repo = $submoduleConfig.Repositories[$key]
            $submodules += [PSCustomObject]@{
                Name        = if ($repo.Name) { $repo.Name } else { $key }
                Url         = $repo.Url
                Path        = $repo.Path
                Branch      = $repo.Branch
                Description = $repo.Description
                Enabled     = $repo.Enabled
                IsDefault   = $false
            }
        }

        # Check git status for each submodule
        $gitAvailable = Get-Command git -ErrorAction SilentlyContinue
        
        foreach ($submodule in $submodules) {
            $isInitialized = $false
            $currentCommit = $null
            $currentBranch = $null

            if ($gitAvailable -and (Test-Path $submodule.Path)) {
                # Check if path is a git submodule
                $gitmodulesContent = git config --file .gitmodules --get-regexp "submodule\.$($submodule.Path)\." 2>$null
                $isInitialized = $LASTEXITCODE -eq 0

                if ($isInitialized -and $Detailed) {
                    Push-Location $submodule.Path
                    try {
                        $currentCommit = git rev-parse --short HEAD 2>$null
                        $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
                    }
                    finally {
                        Pop-Location
                    }
                }
            }

            $submodule | Add-Member -NotePropertyName 'Initialized' -NotePropertyValue $isInitialized -Force
            if ($Detailed) {
                $submodule | Add-Member -NotePropertyName 'CurrentCommit' -NotePropertyValue $currentCommit -Force
                $submodule | Add-Member -NotePropertyName 'CurrentBranch' -NotePropertyValue $currentBranch -Force
            }
        }

        # Filter if requested
        if ($Initialized) {
            $submodules = $submodules | Where-Object { $_.Initialized }
        }

        # Display results
        if ($Detailed) {
            $submodules | Format-Table -Property Name, Path, Url, Branch, CurrentBranch, CurrentCommit, Enabled, Initialized -AutoSize
        }
        else {
            $submodules | Format-Table -Property Name, Path, Branch, Enabled, Initialized, Description -AutoSize
        }

        return $submodules
    }
    catch {
        Write-InfraLog -Level Error -Message "Failed to get submodule information: $($_.Exception.Message)"
        throw
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
    Sync-InfrastructureSubmodules
    Adds missing submodules from configuration.

.EXAMPLE
    Sync-InfrastructureSubmodules -Force
    Adds missing and removes unmanaged submodules.
#>
function Sync-InfrastructureSubmodules {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$Force
    )

    Write-InfraLog -Message "Synchronizing infrastructure submodules with configuration"

    try {
        # Get configured submodules
        $configured = Get-InfrastructureSubmodules

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

Export-ModuleMember -Function Test-OpenTofu, Get-InfrastructureTool, Invoke-InfrastructurePlan, Invoke-InfrastructureApply, Invoke-InfrastructureDestroy, Initialize-InfrastructureSubmodule, Update-InfrastructureSubmodules, Get-InfrastructureSubmodules, Sync-InfrastructureSubmodules, Remove-InfrastructureSubmodule