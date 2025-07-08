function Show-ProfileManager {
    <#
    .SYNOPSIS
        Shows the profile management UI
    .DESCRIPTION
        Interactive interface for managing configuration profiles
    #>
    [CmdletBinding()]
    param()

    try {
        $exitManager = $false

        while (-not $exitManager) {
            Clear-Host
            Write-Host "┌─ Profile Manager ───────────────────────────┐" -ForegroundColor Cyan
            Write-Host "│ Configuration Profiles" -ForegroundColor Yellow
            Write-Host "│" -ForegroundColor Cyan

            # List profiles
            $profiles = Get-ConfigurationProfile -ListAvailable
            if ($profiles.Count -eq 0) {
                Write-Host "│ No profiles found" -ForegroundColor DarkGray
            } else {
                $index = 1
                foreach ($profile in $profiles) {
                    $current = if ($profile.IsCurrent) { " (current)" } else { "" }
                    $gitIcon = if ($profile.HasGitRepo) { " 🔗" } else { "" }

                    Write-Host "│ $index. $($profile.Name)$current$gitIcon" -ForegroundColor White
                    Write-Host "│    $($profile.Description)" -ForegroundColor DarkGray
                    Write-Host "│    Modified: $($profile.LastModified)" -ForegroundColor DarkGray
                    $index++
                }
            }

            Write-Host "│" -ForegroundColor Cyan
            Write-Host "│ [Actions]" -ForegroundColor Yellow
            Write-Host "│   N. New Profile" -ForegroundColor White
            Write-Host "│   S. Switch Profile" -ForegroundColor White
            Write-Host "│   E. Export Profile" -ForegroundColor White
            Write-Host "│   I. Import Profile" -ForegroundColor White
            Write-Host "│   D. Delete Profile" -ForegroundColor White
            Write-Host "│   G. GitHub Sync" -ForegroundColor White
            Write-Host "│   B. Back to Main Menu" -ForegroundColor White
            Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor Cyan

            $selection = Read-Host "`nSelect action"

            switch ($selection.ToUpper()) {
                'N' {
                    New-ProfileInteractive
                }
                'S' {
                    if ($profiles.Count -gt 0) {
                        $profileNum = Read-Host "Enter profile number to switch to"
                        if ($profileNum -match '^\d+$' -and [int]$profileNum -le $profiles.Count) {
                            $selectedProfile = $profiles[[int]$profileNum - 1]
                            Set-ConfigurationProfile -Name $selectedProfile.Name
                            Start-Sleep -Seconds 2
                        }
                    }
                }
                'E' {
                    if ($profiles.Count -gt 0) {
                        Export-ProfileInteractive -Profiles $profiles
                    }
                }
                'I' {
                    Import-ProfileInteractive
                }
                'D' {
                    if ($profiles.Count -gt 0) {
                        Delete-ProfileInteractive -Profiles $profiles
                    }
                }
                'G' {
                    Show-GitHubSync
                }
                'B' {
                    $exitManager = $true
                }
            }
        }

    } catch {
        Write-Error "Error in profile manager: $_"
        throw
    }
}

function New-ProfileInteractive {
    Clear-Host
    Write-Host "Create New Profile" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan

    Write-Host "Profile name (letters, numbers, hyphens only): " -NoNewline
    $name = Read-Host

    if (-not $name -or $name -match '[^a-zA-Z0-9\-_]') {
        Write-Host "Invalid profile name" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    Write-Host "Description (optional): " -NoNewline
    $description = Read-Host

    Write-Host "Create from current configuration? (Y/N): " -NoNewline
    $fromCurrent = Read-Host

    $config = if ($fromCurrent -match '^[Yy]') {
        $configPath = Get-CurrentConfigPath
        Get-Content $configPath -Raw | ConvertFrom-Json
    } else {
        Get-DefaultConfiguration
    }

    Write-Host "Set as current profile? (Y/N): " -NoNewline
    $setCurrent = Read-Host

    try {
        New-ConfigurationProfile -Name $name -Description $description -Config $config -SetAsCurrent:($setCurrent -match '^[Yy]')
        Write-Host "`nProfile created successfully!" -ForegroundColor Green
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "`nError creating profile: $_" -ForegroundColor Red
        Start-Sleep -Seconds 3
    }
}

function Export-ProfileInteractive {
    param($Profiles)

    Clear-Host
    Write-Host "Export Profile" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan

    for ($i = 0; $i -lt $Profiles.Count; $i++) {
        Write-Host "$($i + 1). $($Profiles[$i].Name)" -ForegroundColor White
    }

    Write-Host "`nSelect profile to export: " -NoNewline
    $selection = Read-Host

    if ($selection -match '^\d+$' -and [int]$selection -le $Profiles.Count) {
        $profile = $Profiles[[int]$selection - 1]

        Write-Host "Export format (JSON/YAML/EnvFile) [JSON]: " -NoNewline
        $format = Read-Host
        if (-not $format) { $format = 'JSON' }

        Write-Host "Include sensitive data? (Y/N) [N]: " -NoNewline
        $includeSecrets = (Read-Host) -match '^[Yy]'

        Write-Host "Output path (leave empty for default): " -NoNewline
        $path = Read-Host

        try {
            $params = @{
                Name = $profile.Name
                Format = $format
                IncludeSecrets = $includeSecrets
            }
            if ($path) { $params.Path = $path }

            Export-ConfigurationProfile @params
            Start-Sleep -Seconds 2
        } catch {
            Write-Host "`nError exporting profile: $_" -ForegroundColor Red
            Start-Sleep -Seconds 3
        }
    }
}

function Import-ProfileInteractive {
    Clear-Host
    Write-Host "Import Profile" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan

    Write-Host "Path to configuration file: " -NoNewline
    $path = Read-Host

    if (-not $path -or -not (Test-Path $path)) {
        Write-Host "File not found" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    Write-Host "Profile name (leave empty to auto-detect): " -NoNewline
    $name = Read-Host

    Write-Host "Set as current profile? (Y/N): " -NoNewline
    $setCurrent = (Read-Host) -match '^[Yy]'

    try {
        $params = @{
            Path = $path
            SetAsCurrent = $setCurrent
        }
        if ($name) { $params.Name = $name }

        Import-ConfigurationProfile @params
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "`nError importing profile: $_" -ForegroundColor Red
        Start-Sleep -Seconds 3
    }
}

function Delete-ProfileInteractive {
    param($Profiles)

    Clear-Host
    Write-Host "Delete Profile" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    Write-Host "WARNING: This cannot be undone!" -ForegroundColor Yellow
    Write-Host ""

    for ($i = 0; $i -lt $Profiles.Count; $i++) {
        $current = if ($Profiles[$i].IsCurrent) { " (current - cannot delete)" } else { "" }
        Write-Host "$($i + 1). $($Profiles[$i].Name)$current" -ForegroundColor White
    }

    Write-Host "`nSelect profile to delete (0 to cancel): " -NoNewline
    $selection = Read-Host

    if ($selection -eq '0') { return }

    if ($selection -match '^\d+$' -and [int]$selection -le $Profiles.Count) {
        $profile = $Profiles[[int]$selection - 1]

        if ($profile.IsCurrent) {
            Write-Host "Cannot delete the current profile" -ForegroundColor Red
            Start-Sleep -Seconds 2
            return
        }

        Write-Host "Are you sure you want to delete '$($profile.Name)'? (YES to confirm): " -NoNewline
        $confirm = Read-Host

        if ($confirm -eq 'YES') {
            try {
                Remove-ConfigurationProfile -Name $profile.Name -Force
                Start-Sleep -Seconds 2
            } catch {
                Write-Host "`nError deleting profile: $_" -ForegroundColor Red
                Start-Sleep -Seconds 3
            }
        } else {
            Write-Host "Deletion cancelled" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}

function Show-GitHubSync {
    Clear-Host
    Write-Host "┌─ GitHub Sync ───────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ Synchronize profiles with GitHub" -ForegroundColor Yellow
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│ 1. Initialize New Repository" -ForegroundColor White
    Write-Host "│ 2. Clone Existing Repository" -ForegroundColor White
    Write-Host "│ 3. Push Current Profile" -ForegroundColor White
    Write-Host "│ 4. Pull All Profiles" -ForegroundColor White
    Write-Host "│ 5. Create GitHub Repository" -ForegroundColor White
    Write-Host "│ 6. Back" -ForegroundColor White
    Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor Cyan

    $selection = Read-Host "`nSelect action"

    switch ($selection) {
        '1' {
            Write-Host "`nRepository URL (optional): " -NoNewline
            $url = Read-Host

            try {
                Sync-ConfigurationToGitHub -Action Init -RepositoryUrl $url
                Start-Sleep -Seconds 2
            } catch {
                Write-Host "`nError: $_" -ForegroundColor Red
                Start-Sleep -Seconds 3
            }
        }
        '2' {
            Write-Host "`nRepository URL: " -NoNewline
            $url = Read-Host

            if ($url) {
                try {
                    Sync-ConfigurationToGitHub -Action Clone -RepositoryUrl $url
                    Start-Sleep -Seconds 2
                } catch {
                    Write-Host "`nError: $_" -ForegroundColor Red
                    Start-Sleep -Seconds 3
                }
            }
        }
        '3' {
            Write-Host "`nProfile name (leave empty for current): " -NoNewline
            $profile = Read-Host

            try {
                $params = @{ Action = 'Push' }
                if ($profile) { $params.ProfileName = $profile }

                Sync-ConfigurationToGitHub @params
                Start-Sleep -Seconds 2
            } catch {
                Write-Host "`nError: $_" -ForegroundColor Red
                Start-Sleep -Seconds 3
            }
        }
        '4' {
            try {
                Sync-ConfigurationToGitHub -Action Pull
                Start-Sleep -Seconds 2
            } catch {
                Write-Host "`nError: $_" -ForegroundColor Red
                Start-Sleep -Seconds 3
            }
        }
        '5' {
            Write-Host "`nRepository name: " -NoNewline
            $repoName = Read-Host

            if ($repoName) {
                Write-Host "Make repository private? (Y/N): " -NoNewline
                $private = (Read-Host) -match '^[Yy]'

                try {
                    New-ConfigurationRepository -RepositoryName $repoName -Private:$private
                    Start-Sleep -Seconds 3
                } catch {
                    Write-Host "`nError: $_" -ForegroundColor Red
                    Start-Sleep -Seconds 3
                }
            }
        }
    }
}

function Get-DefaultConfiguration {
    # Return a minimal default configuration
    return [PSCustomObject]@{
        ComputerName = "aitherzero-system"
        SetComputerName = $false
        DNSServers = "8.8.8.8,1.1.1.1"
        SetDNSServers = $false
        InstallGit = $true
        InstallPwsh = $true
        InstallOpenTofu = $false
        profile = @{
            name = "default"
            description = "Default configuration"
            created = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            lastModified = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }
    }
}
