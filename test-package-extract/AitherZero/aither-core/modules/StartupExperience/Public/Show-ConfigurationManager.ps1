function Show-ConfigurationManager {
    <#
    .SYNOPSIS
        Displays the interactive configuration manager UI
    .DESCRIPTION
        Shows current configuration with ability to edit values inline
    .PARAMETER Tier
        License tier for feature access
    .EXAMPLE
        Show-ConfigurationManager -Tier "pro"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Tier = 'free'
    )

    try {
        $configPath = Get-CurrentConfigPath
        $config = Get-Content $configPath -Raw | ConvertFrom-Json

        $exitManager = $false
        while (-not $exitManager) {
            Clear-Host
            Write-Host "┌─ Configuration Manager ─────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "│ Current Profile: " -NoNewline -ForegroundColor Cyan
            Write-Host "$($script:CurrentProfile ?? 'default')" -ForegroundColor Yellow
            Write-Host "│" -ForegroundColor Cyan

            # Group configurations by category
            $categories = @{
                'General' = @('ComputerName', 'DNSServers', 'TrustedHosts')
                'Development Tools' = @('InstallGit', 'InstallGitHubCLI', 'InstallPwsh', 'InstallVSCode')
                'Infrastructure' = @('InstallOpenTofu', 'InstallHyperV', 'InstallDockerDesktop')
                'AI Tools' = @('InstallClaudeCode', 'InstallGeminiCLI', 'InstallCodexCLI')
                'Security' = @('InstallCA', 'InstallGPG', 'InstallCosign')
            }

            $menuItems = @()
            $itemIndex = 1

            foreach ($category in $categories.Keys) {
                Write-Host "│" -ForegroundColor Cyan
                Write-Host "│ [$category]" -ForegroundColor Green

                foreach ($key in $categories[$category]) {
                    if ($config.PSObject.Properties.Name -contains $key) {
                        $value = $config.$key
                        $displayValue = if ($value -is [bool]) {
                            if ($value) { "✓" } else { "☐" }
                        } else {
                            $value
                        }

                        # Check if this feature requires a higher tier
                        $isLocked = -not (Test-ConfigFeatureAccess -Feature $key -Tier $Tier)
                        $lockIcon = if ($isLocked) { " 🔒" } else { "" }

                        Write-Host "│   $itemIndex. $key : $displayValue$lockIcon" -ForegroundColor White
                        $menuItems += @{
                            Index = $itemIndex
                            Key = $key
                            Value = $value
                            Category = $category
                            Locked = $isLocked
                        }
                        $itemIndex++
                    }
                }
            }

            Write-Host "│" -ForegroundColor Cyan
            Write-Host "│ [Actions]" -ForegroundColor Yellow
            Write-Host "│   S. Save Configuration" -ForegroundColor White
            Write-Host "│   E. Export Configuration" -ForegroundColor White
            Write-Host "│   I. Import Configuration" -ForegroundColor White
            Write-Host "│   R. Reset to Defaults" -ForegroundColor White
            Write-Host "│   B. Back to Main Menu" -ForegroundColor White
            Write-Host "└─────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan

            $selection = Read-Host "`nSelect item to edit (1-$($menuItems.Count)) or action (S/E/I/R/B)"

            switch ($selection.ToUpper()) {
                'S' {
                    Save-Configuration -Config $config -Path $configPath
                    Write-Host "Configuration saved successfully!" -ForegroundColor Green
                    Start-Sleep -Seconds 2
                }
                'E' {
                    Export-ConfigurationProfile -Config $config
                }
                'I' {
                    $imported = Import-ConfigurationProfile
                    if ($imported) {
                        $config = $imported
                    }
                }
                'R' {
                    if (Confirm-Action "Reset configuration to defaults?") {
                        $config = Get-DefaultConfiguration
                        Write-Host "Configuration reset to defaults!" -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                    }
                }
                'B' {
                    $exitManager = $true
                }
                default {
                    if ($selection -match '^\d+$') {
                        $index = [int]$selection
                        $item = $menuItems | Where-Object { $_.Index -eq $index }

                        if ($item) {
                            if ($item.Locked) {
                                Write-Host "This feature requires a higher tier license!" -ForegroundColor Red
                                Show-UpgradePrompt -RequiredTier (Get-FeatureTier -Feature $item.Key)
                            } else {
                                $newValue = Edit-ConfigValue -Key $item.Key -CurrentValue $item.Value -Category $item.Category
                                if ($null -ne $newValue) {
                                    $config.$($item.Key) = $newValue
                                }
                            }
                        }
                    }
                }
            }
        }

    } catch {
        Write-Error "Error in configuration manager: $_"
        throw
    }
}

function Edit-ConfigValue {
    param(
        [string]$Key,
        $CurrentValue,
        [string]$Category
    )

    Clear-Host
    Write-Host "Edit Configuration Value" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host "Category: $Category" -ForegroundColor Green
    Write-Host "Setting: $Key" -ForegroundColor Yellow
    Write-Host "Current Value: $CurrentValue" -ForegroundColor White
    Write-Host ""

    if ($CurrentValue -is [bool]) {
        Write-Host "Toggle value? (Y/N): " -NoNewline
        $response = Read-Host
        if ($response -match '^[Yy]') {
            return -not $CurrentValue
        }
    } else {
        Write-Host "Enter new value (or press Enter to cancel): " -NoNewline
        $newValue = Read-Host
        if ($newValue) {
            return $newValue
        }
    }

    return $null
}

function Save-Configuration {
    param(
        $Config,
        [string]$Path
    )

    try {
        $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'SUCCESS' -Message "Configuration saved to $Path"
        }
    } catch {
        Write-Error "Failed to save configuration: $_"
        throw
    }
}

function Get-CurrentConfigPath {
    # Get the current configuration file path
    if ($script:CurrentProfile) {
        $profilePath = Join-Path $script:ConfigProfilePath "$($script:CurrentProfile).json"
        if (Test-Path $profilePath) {
            return $profilePath
        }
    }

    # Default to main config
    $projectRoot = Find-ProjectRoot
    return Join-Path $projectRoot "configs" "default-config.json"
}

function Test-ConfigFeatureAccess {
    param(
        [string]$Feature,
        [string]$Tier
    )

    # Define features that require higher tiers
    $proFeatures = @('InstallOpenTofu', 'InstallClaudeCode', 'InstallGeminiCLI', 'InstallCodexCLI')
    $enterpriseFeatures = @('InstallCA', 'SecureCredentials')

    if ($Feature -in $enterpriseFeatures) {
        return $Tier -eq 'enterprise'
    } elseif ($Feature -in $proFeatures) {
        return $Tier -in @('pro', 'enterprise')
    }

    return $true
}

function Show-UpgradePrompt {
    param(
        [string]$RequiredTier
    )

    Write-Host "`nThis feature requires $RequiredTier tier or higher." -ForegroundColor Yellow
    Write-Host "Visit https://github.com/wizzense/AitherZero for licensing options." -ForegroundColor Cyan
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
