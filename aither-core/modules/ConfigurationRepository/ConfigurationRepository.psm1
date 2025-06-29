# Configuration Repository Manager Module for AitherZero
# Handles Git-based configuration repository management and automation

# Import required modules
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import logging if available
$loggingModule = Join-Path $projectRoot "aither-core/modules/Logging"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

# Import PatchManager if available for GitHub operations
$patchManagerModule = Join-Path $projectRoot "aither-core/modules/PatchManager"
if (Test-Path $patchManagerModule) {
    Import-Module $patchManagerModule -Force -ErrorAction SilentlyContinue
}

function New-ConfigurationRepository {
    <#
    .SYNOPSIS
        Creates a new Git repository for custom configurations
    .DESCRIPTION
        Creates a new repository with AitherZero configuration templates and structure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName,
        
        [Parameter(Mandatory)]
        [string]$LocalPath,
        
        [ValidateSet('github', 'gitlab', 'local')]
        [string]$Provider = 'github',
        
        [ValidateSet('default', 'minimal', 'enterprise', 'custom')]
        [string]$Template = 'default',
        
        [switch]$Private = $true,
        
        [string]$Description,
        
        [string]$GitHubOrg,
        
        [string[]]$Environments = @('dev', 'staging', 'prod'),
        
        [hashtable]$CustomSettings = @{}
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Creating new configuration repository: $RepositoryName"
        
        # Validate inputs
        if (Test-Path $LocalPath) {
            if ((Get-ChildItem $LocalPath | Measure-Object).Count -gt 0) {
                throw "Local path '$LocalPath' already exists and is not empty"
            }
        } else {
            New-Item -Path $LocalPath -ItemType Directory -Force | Out-Null
        }
        
        # Initialize local repository
        Write-CustomLog -Level 'INFO' -Message "Initializing Git repository at: $LocalPath"
        Push-Location $LocalPath
        
        try {
            # Initialize Git repository
            git init 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to initialize Git repository"
            }
            
            # Create repository structure from template
            $templateResult = Create-ConfigurationTemplate -Template $Template -Path $LocalPath -Environments $Environments -CustomSettings $CustomSettings
            if (-not $templateResult.Success) {
                throw "Failed to create configuration template: $($templateResult.Error)"
            }
            
            # Initial commit
            git add . 2>&1 | Out-Null
            git commit -m "Initial commit: AitherZero configuration repository
            
            Template: $Template
            Environments: $($Environments -join ', ')
            Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            
            🤖 Generated with AitherZero Configuration Repository Manager" 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create initial commit"
            }
            
            # Create remote repository if not local
            if ($Provider -ne 'local') {
                $remoteResult = Create-RemoteRepository -Provider $Provider -RepositoryName $RepositoryName -Description $Description -Private $Private -GitHubOrg $GitHubOrg
                if ($remoteResult.Success) {
                    # Add remote and push
                    git remote add origin $remoteResult.RepositoryUrl 2>&1 | Out-Null
                    git branch -M main 2>&1 | Out-Null
                    git push -u origin main 2>&1 | Out-Null
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-CustomLog -Level 'SUCCESS' -Message "Repository pushed to remote: $($remoteResult.RepositoryUrl)"
                    } else {
                        Write-CustomLog -Level 'WARNING' -Message "Failed to push to remote repository"
                    }
                } else {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to create remote repository: $($remoteResult.Error)"
                }
            }
            
        } finally {
            Pop-Location
        }
        
        # Generate repository documentation
        $docResult = Generate-RepositoryDocumentation -Path $LocalPath -RepositoryName $RepositoryName -Template $Template
        
        Write-CustomLog -Level 'SUCCESS' -Message "Configuration repository '$RepositoryName' created successfully"
        
        return @{
            Success = $true
            RepositoryName = $RepositoryName
            LocalPath = $LocalPath
            Template = $Template
            Environments = $Environments
            Provider = $Provider
            RemoteUrl = $remoteResult.RepositoryUrl ?? 'local'
            TemplateResult = $templateResult
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create configuration repository: $_"
        
        # Cleanup on failure
        if (Test-Path $LocalPath) {
            try {
                Remove-Item -Path $LocalPath -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Could not cleanup failed repository at: $LocalPath"
            }
        }
        
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Clone-ConfigurationRepository {
    <#
    .SYNOPSIS
        Clones an existing configuration repository
    .DESCRIPTION
        Clones a configuration repository and validates its structure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryUrl,
        
        [Parameter(Mandatory)]
        [string]$LocalPath,
        
        [string]$Branch = 'main',
        
        [switch]$Validate = $true,
        
        [switch]$SetupLocalSettings
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Cloning configuration repository: $RepositoryUrl"
        
        # Validate local path
        if (Test-Path $LocalPath) {
            if ((Get-ChildItem $LocalPath | Measure-Object).Count -gt 0) {
                throw "Local path '$LocalPath' already exists and is not empty"
            }
        }
        
        # Clone repository
        $cloneResult = git clone --branch $Branch $RepositoryUrl $LocalPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Git clone failed: $cloneResult"
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Repository cloned to: $LocalPath"
        
        # Validate repository structure if requested
        if ($Validate) {
            $validationResult = Validate-ConfigurationRepository -Path $LocalPath
            if (-not $validationResult.IsValid) {
                Write-CustomLog -Level 'WARNING' -Message "Repository validation warnings: $($validationResult.Warnings -join '; ')"
            }
        }
        
        # Setup local settings if requested
        if ($SetupLocalSettings) {
            $settingsResult = Setup-LocalRepositorySettings -Path $LocalPath
            Write-CustomLog -Level 'INFO' -Message "Local repository settings configured"
        }
        
        return @{
            Success = $true
            RepositoryUrl = $RepositoryUrl
            LocalPath = $LocalPath
            Branch = $Branch
            ValidationResult = $validationResult ?? @{ IsValid = $true }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to clone configuration repository: $_"
        
        # Cleanup on failure
        if (Test-Path $LocalPath) {
            try {
                Remove-Item -Path $LocalPath -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Could not cleanup failed clone at: $LocalPath"
            }
        }
        
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Sync-ConfigurationRepository {
    <#
    .SYNOPSIS
        Synchronizes a configuration repository with its remote
    .DESCRIPTION
        Pulls latest changes and optionally pushes local changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [ValidateSet('pull', 'push', 'sync')]
        [string]$Operation = 'sync',
        
        [string]$Branch = 'main',
        
        [switch]$Force,
        
        [switch]$CreateBackup = $true
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Synchronizing configuration repository: $Path"
        
        if (-not (Test-Path $Path)) {
            throw "Repository path does not exist: $Path"
        }
        
        Push-Location $Path
        
        try {
            # Verify it's a Git repository
            git status 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Not a Git repository: $Path"
            }
            
            # Create backup if requested
            $backupPath = $null
            if ($CreateBackup) {
                $backupPath = Join-Path (Split-Path $Path -Parent) "backup-$(Split-Path $Path -Leaf)-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item -Path $Path -Destination $backupPath -Recurse -Force
                Write-CustomLog -Level 'INFO' -Message "Backup created: $backupPath"
            }
            
            $result = @{
                Success = $true
                Operation = $Operation
                BackupPath = $backupPath
                Changes = @()
            }
            
            switch ($Operation) {
                'pull' {
                    Write-CustomLog -Level 'INFO' -Message "Pulling latest changes from remote"
                    $pullResult = git pull origin $Branch 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Git pull failed: $pullResult"
                    }
                    $result.Changes += "Pulled from remote: $pullResult"
                }
                'push' {
                    # Check for local changes
                    $status = git status --porcelain
                    if ($status) {
                        git add . 2>&1 | Out-Null
                        git commit -m "Sync: Local configuration changes $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1 | Out-Null
                    }
                    
                    Write-CustomLog -Level 'INFO' -Message "Pushing local changes to remote"
                    $pushResult = git push origin $Branch 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Git push failed: $pushResult"
                    }
                    $result.Changes += "Pushed to remote: $pushResult"
                }
                'sync' {
                    # Full synchronization: pull, merge, push
                    Write-CustomLog -Level 'INFO' -Message "Performing full synchronization"
                    
                    # Stash local changes if any
                    $status = git status --porcelain
                    $hasLocalChanges = [bool]$status
                    if ($hasLocalChanges) {
                        git stash push -m "Auto-stash before sync $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1 | Out-Null
                        $result.Changes += "Stashed local changes"
                    }
                    
                    # Pull latest
                    $pullResult = git pull origin $Branch 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Git pull failed: $pullResult"
                    }
                    $result.Changes += "Pulled from remote"
                    
                    # Restore local changes if any
                    if ($hasLocalChanges) {
                        $stashResult = git stash pop 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $result.Changes += "Restored local changes"
                            
                            # Commit and push merged changes
                            git add . 2>&1 | Out-Null
                            git commit -m "Sync: Merged local and remote changes $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1 | Out-Null
                            $pushResult = git push origin $Branch 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                $result.Changes += "Pushed merged changes"
                            } else {
                                Write-CustomLog -Level 'WARNING' -Message "Failed to push merged changes: $pushResult"
                            }
                        } else {
                            Write-CustomLog -Level 'WARNING' -Message "Merge conflicts detected: $stashResult"
                            $result.Changes += "Merge conflicts require manual resolution"
                        }
                    }
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Repository synchronization completed"
            return $result
            
        } finally {
            Pop-Location
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to synchronize repository: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
            Operation = $Operation
        }
    }
}

function Validate-ConfigurationRepository {
    <#
    .SYNOPSIS
        Validates the structure and content of a configuration repository
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $errors = @()
    $warnings = @()
    $info = @()
    
    try {
        if (-not (Test-Path $Path)) {
            $errors += "Repository path does not exist: $Path"
            return @{
                IsValid = $false
                Errors = $errors
                Warnings = $warnings
                Info = $info
            }
        }
        
        # Check if it's a Git repository
        if (-not (Test-Path (Join-Path $Path ".git"))) {
            $warnings += "Not a Git repository (missing .git directory)"
        }
        
        # Check for required structure
        $requiredDirs = @('configs', 'environments')
        foreach ($dir in $requiredDirs) {
            $dirPath = Join-Path $Path $dir
            if (-not (Test-Path $dirPath)) {
                $warnings += "Missing recommended directory: $dir"
            } else {
                $info += "Found directory: $dir"
            }
        }
        
        # Check for configuration files
        $configFiles = @('README.md', '.gitignore', 'configs/app-config.json')
        foreach ($file in $configFiles) {
            $filePath = Join-Path $Path $file
            if (Test-Path $filePath) {
                $info += "Found file: $file"
            } else {
                $warnings += "Missing recommended file: $file"
            }
        }
        
        # Validate JSON configuration files
        $jsonFiles = Get-ChildItem -Path $Path -Filter "*.json" -Recurse
        foreach ($jsonFile in $jsonFiles) {
            try {
                Get-Content $jsonFile.FullName | ConvertFrom-Json | Out-Null
                $info += "Valid JSON: $($jsonFile.Name)"
            } catch {
                $errors += "Invalid JSON file: $($jsonFile.Name) - $_"
            }
        }
        
        # Check environment configurations
        $envPath = Join-Path $Path "environments"
        if (Test-Path $envPath) {
            $envDirs = Get-ChildItem -Path $envPath -Directory
            if ($envDirs.Count -gt 0) {
                $info += "Environment configurations found: $($envDirs.Name -join ', ')"
            } else {
                $warnings += "No environment configurations found in environments directory"
            }
        }
        
        return @{
            IsValid = ($errors.Count -eq 0)
            Errors = $errors
            Warnings = $warnings
            Info = $info
            RepositoryPath = $Path
        }
        
    } catch {
        $errors += "Validation error: $($_.Exception.Message)"
        return @{
            IsValid = $false
            Errors = $errors
            Warnings = $warnings
            Info = $info
        }
    }
}

# Helper functions
function Create-ConfigurationTemplate {
    param(
        [string]$Template,
        [string]$Path,
        [string[]]$Environments,
        [hashtable]$CustomSettings
    )
    
    try {
        # Create directory structure
        $directories = @(
            'configs',
            'environments',
            'templates',
            'scripts'
        )
        
        foreach ($dir in $directories) {
            New-Item -Path (Join-Path $Path $dir) -ItemType Directory -Force | Out-Null
        }
        
        # Create environment-specific directories
        foreach ($env in $Environments) {
            New-Item -Path (Join-Path $Path "environments/$env") -ItemType Directory -Force | Out-Null
        }
        
        # Generate template files based on template type
        switch ($Template) {
            'minimal' {
                Create-MinimalTemplate -Path $Path -Environments $Environments
            }
            'enterprise' {
                Create-EnterpriseTemplate -Path $Path -Environments $Environments
            }
            'custom' {
                Create-CustomTemplate -Path $Path -Environments $Environments -Settings $CustomSettings
            }
            default {
                Create-DefaultTemplate -Path $Path -Environments $Environments
            }
        }
        
        # Create common files
        Create-CommonFiles -Path $Path
        
        return @{
            Success = $true
            Template = $Template
        }
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Create-DefaultTemplate {
    param([string]$Path, [string[]]$Environments)
    
    # Create default configuration
    $defaultConfig = @{
        version = "1.0"
        name = "AitherZero Custom Configuration"
        description = "Custom configuration repository for AitherZero"
        created = (Get-Date).ToString('yyyy-MM-dd')
        environments = $Environments
        settings = @{
            verbosity = "normal"
            autoUpdate = $true
            telemetryEnabled = $false
        }
        modules = @{
            enabledByDefault = @("Logging", "PatchManager", "LabRunner")
            autoLoad = $true
        }
    }
    
    $configPath = Join-Path $Path "configs/app-config.json"
    $defaultConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath
}

function Create-MinimalTemplate {
    param([string]$Path, [string[]]$Environments)
    
    $minimalConfig = @{
        version = "1.0"
        name = "Minimal AitherZero Configuration"
        environments = $Environments
        settings = @{
            verbosity = "silent"
        }
    }
    
    $configPath = Join-Path $Path "configs/app-config.json"
    $minimalConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $configPath
}

function Create-EnterpriseTemplate {
    param([string]$Path, [string[]]$Environments)
    
    $enterpriseConfig = @{
        version = "1.0"
        name = "Enterprise AitherZero Configuration"
        environments = $Environments
        settings = @{
            verbosity = "detailed"
            auditEnabled = $true
            securityEnforced = $true
            complianceMode = $true
        }
        security = @{
            requireApproval = $true
            multiFactorAuth = $true
            encryptionRequired = $true
        }
        compliance = @{
            retentionPeriod = "7y"
            auditTrail = $true
        }
    }
    
    $configPath = Join-Path $Path "configs/app-config.json"
    $enterpriseConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath
}

function Create-CustomTemplate {
    param([string]$Path, [string[]]$Environments, [hashtable]$Settings)
    
    $customConfig = @{
        version = "1.0"
        name = "Custom AitherZero Configuration"
        environments = $Environments
        settings = $Settings
    }
    
    $configPath = Join-Path $Path "configs/app-config.json"
    $customConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath
}

function Create-CommonFiles {
    param([string]$Path)
    
    # Create README.md
    $readme = @"
# AitherZero Configuration Repository

This repository contains custom configurations for AitherZero infrastructure automation.

## Structure

- `configs/` - Main configuration files
- `environments/` - Environment-specific configurations
- `templates/` - Configuration templates
- `scripts/` - Custom scripts and automation

## Usage

1. Clone this repository to your AitherZero configuration directory
2. Use AitherZero Configuration Carousel to switch to this configuration
3. Customize settings for your environment

## Generated

This repository was generated by AitherZero Configuration Repository Manager on $(Get-Date -Format 'yyyy-MM-dd').
"@
    
    Set-Content -Path (Join-Path $Path "README.md") -Value $readme
    
    # Create .gitignore
    $gitignore = @"
# AitherZero specific
*.log
temp/
cache/
local-settings.json

# OS specific
.DS_Store
Thumbs.db

# Editor specific
.vscode/
.idea/
*.swp
*.swo
"@
    
    Set-Content -Path (Join-Path $Path ".gitignore") -Value $gitignore
}

function Create-RemoteRepository {
    param(
        [string]$Provider,
        [string]$RepositoryName,
        [string]$Description,
        [bool]$Private,
        [string]$GitHubOrg
    )
    
    switch ($Provider) {
        'github' {
            # Use GitHub CLI if available, otherwise return instructions
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                try {
                    $ghArgs = @('repo', 'create', $RepositoryName)
                    if ($Private) { $ghArgs += '--private' }
                    if ($Description) { $ghArgs += '--description', $Description }
                    if ($GitHubOrg) { $ghArgs += '--org', $GitHubOrg }
                    
                    $createResult = & gh @ghArgs 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $repoUrl = if ($GitHubOrg) {
                            "https://github.com/$GitHubOrg/$RepositoryName.git"
                        } else {
                            # Get current user
                            $user = gh api user --jq .login
                            "https://github.com/$user/$RepositoryName.git"
                        }
                        
                        return @{
                            Success = $true
                            RepositoryUrl = $repoUrl
                            Provider = 'github'
                        }
                    } else {
                        throw "GitHub repository creation failed: $createResult"
                    }
                } catch {
                    return @{
                        Success = $false
                        Error = $_.Exception.Message
                    }
                }
            } else {
                return @{
                    Success = $false
                    Error = "GitHub CLI (gh) not available. Please install and authenticate with GitHub CLI."
                    Instructions = @(
                        "1. Install GitHub CLI: https://cli.github.com/",
                        "2. Authenticate: gh auth login",
                        "3. Create repository manually or re-run this command"
                    )
                }
            }
        }
        'gitlab' {
            return @{
                Success = $false
                Error = "GitLab provider not yet implemented"
            }
        }
        default {
            return @{
                Success = $false
                Error = "Unknown provider: $Provider"
            }
        }
    }
}

function Setup-LocalRepositorySettings {
    param([string]$Path)
    
    # Create local settings file
    $localSettings = @{
        repositoryPath = $Path
        lastSync = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        autoSync = $false
        backupBeforeSync = $true
    }
    
    $settingsPath = Join-Path $Path "local-settings.json"
    $localSettings | ConvertTo-Json -Depth 3 | Set-Content -Path $settingsPath
}

function Generate-RepositoryDocumentation {
    param([string]$Path, [string]$RepositoryName, [string]$Template)
    
    # This could generate additional documentation
    # For now, it's handled in Create-CommonFiles
    return @{ Success = $true }
}

# Logging fallback functions
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Write-CustomLog {
        param(
            [string]$Level,
            [string]$Message
        )
        $color = switch ($Level) {
            'SUCCESS' { 'Green' }
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            'INFO' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Export functions
Export-ModuleMember -Function @(
    'New-ConfigurationRepository',
    'Clone-ConfigurationRepository',
    'Sync-ConfigurationRepository',
    'Validate-ConfigurationRepository'
)