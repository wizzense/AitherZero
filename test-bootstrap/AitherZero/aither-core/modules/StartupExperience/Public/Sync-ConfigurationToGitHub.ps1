function Sync-ConfigurationToGitHub {
    <#
    .SYNOPSIS
        Syncs configuration profiles to/from GitHub
    .DESCRIPTION
        Manages GitHub repository integration for configuration sharing and backup
    .PARAMETER Action
        Action to perform: Push, Pull, Init, or Clone
    .PARAMETER RepositoryUrl
        GitHub repository URL
    .PARAMETER ProfileName
        Profile name to sync (defaults to current)
    .PARAMETER Token
        GitHub personal access token
    .EXAMPLE
        Sync-ConfigurationToGitHub -Action Init -RepositoryUrl "https://github.com/user/aither-configs"
    .EXAMPLE
        Sync-ConfigurationToGitHub -Action Push -ProfileName "production"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Push', 'Pull', 'Init', 'Clone')]
        [string]$Action,
        
        [Parameter()]
        [string]$RepositoryUrl,
        
        [Parameter()]
        [string]$ProfileName,
        
        [Parameter()]
        [string]$Token
    )
    
    try {
        # Get git command
        $gitCmd = Get-GitCommand
        if (-not $gitCmd) {
            throw "Git is required for GitHub synchronization. Please install Git."
        }
        
        # Get profile
        if (-not $ProfileName) {
            $ProfileName = $script:CurrentProfile ?? 'default'
        }
        
        $profilePath = Join-Path $script:ConfigProfilePath "$ProfileName.json"
        if (-not (Test-Path $profilePath) -and $Action -ne 'Clone') {
            throw "Profile '$ProfileName' not found"
        }
        
        # Set up repo directory
        $repoPath = Join-Path $script:ConfigProfilePath '.git-repo'
        
        switch ($Action) {
            'Init' {
                Initialize-ConfigRepository -RepoPath $repoPath -RepositoryUrl $RepositoryUrl -Token $Token
            }
            'Clone' {
                Clone-ConfigRepository -RepoPath $repoPath -RepositoryUrl $RepositoryUrl -Token $Token
            }
            'Push' {
                Push-ConfigToGitHub -RepoPath $repoPath -ProfilePath $profilePath -ProfileName $ProfileName
            }
            'Pull' {
                Pull-ConfigFromGitHub -RepoPath $repoPath -ProfileName $ProfileName
            }
        }
        
    } catch {
        Write-Error "Failed to sync configuration with GitHub: $_"
        throw
    }
}

function Initialize-ConfigRepository {
    param(
        [string]$RepoPath,
        [string]$RepositoryUrl,
        [string]$Token
    )
    
    Write-Host "Initializing configuration repository..." -ForegroundColor Yellow
    
    # Create repo directory
    if (Test-Path $RepoPath) {
        if (-not (Confirm-Action "Repository directory already exists. Reinitialize?")) {
            return
        }
        Remove-Item -Path $RepoPath -Recurse -Force
    }
    
    New-Item -Path $RepoPath -ItemType Directory -Force | Out-Null
    
    # Initialize git repo
    Push-Location $RepoPath
    try {
        & $gitCmd init
        
        # Create README
        @"
# AitherZero Configuration Profiles

This repository contains configuration profiles for AitherZero infrastructure automation.

## Usage

1. Clone this repository
2. Use ``Sync-ConfigurationToGitHub -Action Pull`` to import profiles
3. Use ``Sync-ConfigurationToGitHub -Action Push`` to upload changes

## Profiles

- Each JSON file represents a complete configuration profile
- Profiles include metadata about creation time and description
- Sensitive data should be encrypted or stored separately
"@ | Set-Content -Path "README.md" -Encoding UTF8
        
        # Create .gitignore
        @"
# Temporary files
*.tmp
*.bak

# Local settings
.current
.profile-index.json

# Sensitive data
*-secrets.json
*.key
*.pfx
"@ | Set-Content -Path ".gitignore" -Encoding UTF8
        
        # Initial commit
        & $gitCmd add .
        & $gitCmd commit -m "Initial configuration repository setup"
        
        # Add remote
        if ($RepositoryUrl) {
            # Add token to URL if provided
            if ($Token) {
                $uri = [System.Uri]$RepositoryUrl
                $RepositoryUrl = "https://$Token@$($uri.Host)$($uri.PathAndQuery)"
            }
            
            & $gitCmd remote add origin $RepositoryUrl
            Write-Host "✅ Repository initialized and linked to: $RepositoryUrl" -ForegroundColor Green
        } else {
            Write-Host "✅ Local repository initialized" -ForegroundColor Green
        }
        
        # Update profile metadata
        $profiles = Get-ConfigurationProfile -ListAvailable
        foreach ($profile in $profiles) {
            $profileData = Get-ConfigurationProfile -Name $profile.Name
            if ($profileData.profile) {
                $profileData.profile | Add-Member -MemberType NoteProperty -Name 'gitRepo' -Value $RepositoryUrl -Force
                $profilePath = Join-Path $script:ConfigProfilePath "$($profile.Name).json"
                $profileData | ConvertTo-Json -Depth 10 | Set-Content -Path $profilePath -Encoding UTF8
            }
        }
        
    } finally {
        Pop-Location
    }
}

function Clone-ConfigRepository {
    param(
        [string]$RepoPath,
        [string]$RepositoryUrl,
        [string]$Token
    )
    
    Write-Host "Cloning configuration repository..." -ForegroundColor Yellow
    
    if (-not $RepositoryUrl) {
        throw "Repository URL is required for cloning"
    }
    
    # Add token to URL if provided
    if ($Token) {
        $uri = [System.Uri]$RepositoryUrl
        $RepositoryUrl = "https://$Token@$($uri.Host)$($uri.PathAndQuery)"
    }
    
    # Clone repository
    if (Test-Path $RepoPath) {
        if (-not (Confirm-Action "Repository directory already exists. Replace with clone?")) {
            return
        }
        Remove-Item -Path $RepoPath -Recurse -Force
    }
    
    & $gitCmd clone $RepositoryUrl $RepoPath
    
    # Import profiles from repo
    Push-Location $RepoPath
    try {
        Get-ChildItem -Filter '*.json' | ForEach-Object {
            $importedProfile = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $profileName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            
            # Copy to profiles directory
            $destPath = Join-Path $script:ConfigProfilePath "$profileName.json"
            Copy-Item -Path $_.FullName -Destination $destPath -Force
            
            Write-Host "  ✅ Imported profile: $profileName" -ForegroundColor Green
        }
        
        Write-Host "✅ Repository cloned and profiles imported" -ForegroundColor Green
        
    } finally {
        Pop-Location
    }
}

function Push-ConfigToGitHub {
    param(
        [string]$RepoPath,
        [string]$ProfilePath,
        [string]$ProfileName
    )
    
    Write-Host "Pushing configuration to GitHub..." -ForegroundColor Yellow
    
    if (-not (Test-Path $RepoPath)) {
        throw "Repository not initialized. Run 'Sync-ConfigurationToGitHub -Action Init' first."
    }
    
    Push-Location $RepoPath
    try {
        # Copy profile to repo
        $destPath = Join-Path $RepoPath "$ProfileName.json"
        Copy-Item -Path $ProfilePath -Destination $destPath -Force
        
        # Check for changes
        $status = & $gitCmd status --porcelain
        if (-not $status) {
            Write-Host "No changes to push" -ForegroundColor Yellow
            return
        }
        
        # Commit and push
        & $gitCmd add "$ProfileName.json"
        & $gitCmd commit -m "Update configuration profile: $ProfileName"
        
        $result = & $gitCmd push origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Configuration pushed to GitHub successfully" -ForegroundColor Green
        } else {
            # Try to push to master if main doesn't exist
            $result = & $gitCmd push origin master 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Configuration pushed to GitHub successfully" -ForegroundColor Green
            } else {
                throw "Failed to push to GitHub: $result"
            }
        }
        
    } finally {
        Pop-Location
    }
}

function Pull-ConfigFromGitHub {
    param(
        [string]$RepoPath,
        [string]$ProfileName
    )
    
    Write-Host "Pulling configuration from GitHub..." -ForegroundColor Yellow
    
    if (-not (Test-Path $RepoPath)) {
        throw "Repository not initialized. Run 'Sync-ConfigurationToGitHub -Action Clone' first."
    }
    
    Push-Location $RepoPath
    try {
        # Pull latest changes
        & $gitCmd pull origin main 2>$null
        if ($LASTEXITCODE -ne 0) {
            # Try master branch
            & $gitCmd pull origin master
        }
        
        # Import specific profile or all
        if ($ProfileName) {
            $sourcePath = Join-Path $RepoPath "$ProfileName.json"
            if (Test-Path $sourcePath) {
                $destPath = Join-Path $script:ConfigProfilePath "$ProfileName.json"
                Copy-Item -Path $sourcePath -Destination $destPath -Force
                Write-Host "✅ Pulled profile: $ProfileName" -ForegroundColor Green
            } else {
                throw "Profile '$ProfileName' not found in repository"
            }
        } else {
            # Import all profiles
            $imported = 0
            Get-ChildItem $RepoPath -Filter '*.json' | ForEach-Object {
                $destPath = Join-Path $script:ConfigProfilePath $_.Name
                Copy-Item -Path $_.FullName -Destination $destPath -Force
                $imported++
            }
            Write-Host "✅ Pulled $imported profiles from GitHub" -ForegroundColor Green
        }
        
    } finally {
        Pop-Location
    }
}

function Get-GitCommand {
    # Find git command
    $gitPaths = @(
        'git',
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Program Files (x86)\Git\cmd\git.exe',
        '/usr/bin/git',
        '/usr/local/bin/git'
    )
    
    foreach ($path in $gitPaths) {
        if (Get-Command $path -ErrorAction SilentlyContinue) {
            return $path
        }
    }
    
    return $null
}

function New-ConfigurationRepository {
    <#
    .SYNOPSIS
        Creates a new GitHub repository for configurations
    .DESCRIPTION
        Uses GitHub CLI to create a new repository for storing configurations
    .PARAMETER RepositoryName
        Name for the new repository
    .PARAMETER Description
        Repository description
    .PARAMETER Private
        Create as private repository
    .EXAMPLE
        New-ConfigurationRepository -RepositoryName "aither-configs" -Private
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryName,
        
        [Parameter()]
        [string]$Description = "AitherZero configuration profiles",
        
        [Parameter()]
        [switch]$Private
    )
    
    try {
        # Check for gh CLI
        $ghCmd = Get-Command 'gh' -ErrorAction SilentlyContinue
        if (-not $ghCmd) {
            $ghCmd = Get-Command 'C:\Program Files\GitHub CLI\gh.exe' -ErrorAction SilentlyContinue
        }
        
        if (-not $ghCmd) {
            throw "GitHub CLI (gh) is required. Install from: https://cli.github.com/"
        }
        
        Write-Host "Creating GitHub repository..." -ForegroundColor Yellow
        
        # Create repository
        $visibility = if ($Private) { "--private" } else { "--public" }
        $result = & $ghCmd repo create $RepositoryName --description $Description $visibility --clone 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Repository created successfully" -ForegroundColor Green
            
            # Extract URL from output
            $repoUrl = $result | Where-Object { $_ -match 'https://github.com' } | Select-Object -First 1
            if ($repoUrl) {
                Write-Host "Repository URL: $repoUrl" -ForegroundColor Cyan
                
                # Initialize with this repo
                Sync-ConfigurationToGitHub -Action Init -RepositoryUrl $repoUrl
            }
            
            return $repoUrl
        } else {
            throw "Failed to create repository: $result"
        }
        
    } catch {
        Write-Error "Failed to create configuration repository: $_"
        throw
    }
}