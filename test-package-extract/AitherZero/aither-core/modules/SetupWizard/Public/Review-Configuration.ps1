function Review-Configuration {
    <#
    .SYNOPSIS
        Configuration review step for setup wizard
    .DESCRIPTION
        Prompts user to review and optionally edit configuration during setup
        Uses ConfigurationCore for unified configuration management
    #>
    param($SetupState)

    $result = @{
        Name = 'Configuration Review'
        Status = 'Unknown'
        Details = @()
        Data = @{}
    }

    try {
        Write-Host "`n📋 Configuration Review" -ForegroundColor Cyan
        Write-Host "Let's review your AitherZero configuration settings." -ForegroundColor White
        Write-Host ""

        # Try to use ConfigurationCore first
        $usingConfigCore = $false
        try {
            $configCoreModule = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "ConfigurationCore"
            if (Test-Path $configCoreModule) {
                Import-Module $configCoreModule -Force -ErrorAction Stop
                $usingConfigCore = $true
                $result.Details += "✓ Using ConfigurationCore for configuration management"
            }
        } catch {
            Write-Verbose "ConfigurationCore not available, using legacy method: $_"
        }

        if ($usingConfigCore) {
            # Use ConfigurationCore to get current configuration
            try {
                $setupConfig = Get-ModuleConfiguration -ModuleName 'SetupWizard' -ErrorAction SilentlyContinue

                if ($setupConfig) {
                    Write-Host "Current Configuration (via ConfigurationCore):" -ForegroundColor Yellow
                    Write-Host "  Platform: $($setupConfig.Platform)" -ForegroundColor White
                    Write-Host "  Installation Profile: $($setupConfig.InstallationProfile)" -ForegroundColor White

                    if ($setupConfig.Settings) {
                        Write-Host "  Settings:" -ForegroundColor White
                        Write-Host "    Verbosity: $($setupConfig.Settings.Verbosity)" -ForegroundColor Gray
                        Write-Host "    Auto Update: $($setupConfig.Settings.AutoUpdate)" -ForegroundColor Gray
                        Write-Host "    Max Parallel Jobs: $($setupConfig.Settings.MaxParallelJobs)" -ForegroundColor Gray
                    }

                    if ($setupConfig.Modules -and $setupConfig.Modules.EnabledByDefault) {
                        Write-Host "  Enabled Modules: $($setupConfig.Modules.EnabledByDefault.Count)" -ForegroundColor White
                        Write-Host "    $($setupConfig.Modules.EnabledByDefault -join ', ')" -ForegroundColor Gray
                    }

                    Write-Host ""

                    # Get current environment info
                    $currentEnv = Get-ConfigurationEnvironment
                    if ($currentEnv) {
                        Write-Host "  Current Environment: $($currentEnv.Name)" -ForegroundColor White
                        Write-Host "  Environment Description: $($currentEnv.Description)" -ForegroundColor Gray
                    }

                    Write-Host ""

                    # Ask if user wants to edit
                    $response = Show-SetupPrompt -Message "Would you like to edit the configuration now?" -DefaultYes:$false

                    if ($response) {
                        Write-Host ""
                        Write-Host "Opening enhanced configuration editor..." -ForegroundColor Yellow

                        # Use ConfigurationCore-aware Edit-Configuration function
                        if (Get-Command Edit-Configuration -ErrorAction SilentlyContinue) {
                            Edit-Configuration -UseConfigurationCore
                            $result.Details += "✓ Configuration reviewed and edited using ConfigurationCore"
                        } else {
                            Write-Host "Interactive configuration editing:" -ForegroundColor Cyan

                            # Simple interactive configuration update
                            $newVerbosity = Read-Host "Verbosity level (current: $($setupConfig.Settings.Verbosity)) [normal/verbose/quiet]"
                            if ($newVerbosity -and $newVerbosity -in @('normal', 'verbose', 'quiet')) {
                                $setupConfig.Settings.Verbosity = $newVerbosity
                            }

                            $newMaxJobs = Read-Host "Max parallel jobs (current: $($setupConfig.Settings.MaxParallelJobs)) [1-16]"
                            if ($newMaxJobs -and $newMaxJobs -match '\d+' -and [int]$newMaxJobs -ge 1 -and [int]$newMaxJobs -le 16) {
                                $setupConfig.Settings.MaxParallelJobs = [int]$newMaxJobs
                            }

                            Set-ModuleConfiguration -ModuleName 'SetupWizard' -Configuration $setupConfig
                            $result.Details += "✓ Configuration updated using ConfigurationCore"
                        }

                        # Validate configuration
                        try {
                            $isValid = Test-ModuleConfiguration -ModuleName 'SetupWizard'
                            if ($isValid) {
                                $result.Details += "✓ Configuration validated successfully"
                            } else {
                                $result.Details += "⚠️ Configuration validation warnings"
                            }
                        } catch {
                            $result.Details += "⚠️ Configuration validation failed: $_"
                            $SetupState.Warnings += "Configuration may have validation errors"
                        }
                    } else {
                        $result.Details += "✓ Configuration review skipped by user"
                    }

                } else {
                    Write-Host "No SetupWizard configuration found in ConfigurationCore." -ForegroundColor Yellow
                    $result.Details += "ℹ️ No existing configuration, will use defaults"
                }

            } catch {
                Write-Host "Error accessing ConfigurationCore: $_" -ForegroundColor Red
                $usingConfigCore = $false
            }
        }

        if (-not $usingConfigCore) {
            # Fallback to legacy configuration method
            $result.Details += "⚠️ Using legacy configuration method"

            # Find config file
            $configPath = $null
            $possiblePaths = @(
                (Join-Path $env:PROJECT_ROOT "configs/default-config.json"),
                (Join-Path (Find-ProjectRoot) "configs/default-config.json"),
                "./configs/default-config.json"
            )

            foreach ($path in $possiblePaths) {
                if (Test-Path $path) {
                    $configPath = $path
                    break
                }
            }

            if ($configPath) {
                # Read and display current configuration
                $config = Get-Content $configPath -Raw | ConvertFrom-Json

                Write-Host "Current Configuration (Legacy):" -ForegroundColor Yellow
                Write-Host "  Environment: $($config.environment ?? 'development')" -ForegroundColor White

                if ($config.modules -and $config.modules.enabled) {
                    Write-Host "  Enabled Modules: $($config.modules.enabled.Count)" -ForegroundColor White
                    Write-Host "    $($config.modules.enabled -join ', ')" -ForegroundColor Gray
                }

                if ($config.logging) {
                    Write-Host "  Logging Level: $($config.logging.level ?? 'INFO')" -ForegroundColor White
                }

                if ($config.infrastructure) {
                    Write-Host "  Infrastructure Provider: $($config.infrastructure.provider ?? 'opentofu')" -ForegroundColor White
                }

                Write-Host ""

                # Ask if user wants to edit
                $response = Show-SetupPrompt -Message "Would you like to edit the configuration now?" -DefaultYes:$false

                if ($response) {
                    Write-Host ""
                    Write-Host "Opening configuration editor..." -ForegroundColor Yellow

                    # Use the Edit-Configuration function
                    if (Get-Command Edit-Configuration -ErrorAction SilentlyContinue) {
                        Edit-Configuration -ConfigPath $configPath
                        $result.Details += "✓ Configuration reviewed and edited (legacy)"
                    } else {
                        # Fallback to simple external editor
                        if ($IsWindows) {
                            Start-Process notepad.exe -ArgumentList $configPath -Wait
                        } else {
                            $editor = $env:EDITOR ?? 'nano'
                            & $editor $configPath
                        }
                        $result.Details += "✓ Configuration edited in external editor"
                    }

                    # Reload and validate configuration
                    try {
                        $config = Get-Content $configPath -Raw | ConvertFrom-Json
                        $result.Details += "✓ Configuration validated successfully"
                    } catch {
                        $result.Details += "⚠️ Configuration validation failed: $_"
                        $SetupState.Warnings += "Configuration may have syntax errors"
                    }
                } else {
                    $result.Details += "✓ Configuration review skipped by user"
                }

            } else {
                # No config file exists yet
                Write-Host "No configuration file found. A default will be created." -ForegroundColor Yellow

                $response = Show-SetupPrompt -Message "Would you like to create and customize the configuration now?" -DefaultYes

                if ($response) {
                    # Create config directory
                    $configDir = Join-Path (Find-ProjectRoot) "configs"
                    if (-not (Test-Path $configDir)) {
                        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                    }

                    # Use Edit-Configuration with CreateIfMissing
                    if (Get-Command Edit-Configuration -ErrorAction SilentlyContinue) {
                        Edit-Configuration -CreateIfMissing
                        $result.Details += "✓ Configuration created and customized"
                    } else {
                        # Create basic default config
                        $defaultConfig = @{
                            environment = "development"
                            modules = @{
                                enabled = @("LabRunner", "BackupManager", "OpenTofuProvider")
                                autoLoad = $true
                            }
                            logging = @{
                                level = "INFO"
                                path = "./logs"
                            }
                            infrastructure = @{
                                provider = "opentofu"
                                stateBackend = "local"
                            }
                        }

                        $configPath = Join-Path $configDir "default-config.json"
                        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath
                        $result.Details += "✓ Default configuration created"
                    }
                } else {
                    $result.Details += "ℹ️ Configuration creation deferred"
                    $SetupState.Recommendations += "Run Edit-Configuration to customize settings later"
                }
            }
        }

        $result.Status = 'Success'

        # Add configuration tips
        Write-Host ""
        Write-Host "💡 Configuration Tips:" -ForegroundColor Cyan
        if ($usingConfigCore) {
            Write-Host "  • ConfigurationCore provides unified configuration management" -ForegroundColor White
            Write-Host "  • Use Get-ModuleConfiguration/Set-ModuleConfiguration for programmatic access" -ForegroundColor White
            Write-Host "  • Multiple environments supported (Get-ConfigurationEnvironment)" -ForegroundColor White
            Write-Host "  • Configuration schemas ensure validation and consistency" -ForegroundColor White
        } else {
            Write-Host "  • You can edit configuration anytime using Edit-Configuration" -ForegroundColor White
            Write-Host "  • Use -ConfigFile parameter to specify custom configs" -ForegroundColor White
            Write-Host "  • Consider upgrading to ConfigurationCore for better management" -ForegroundColor White
        }
        Write-Host "  • ConfigurationCarousel module enables multiple config profiles" -ForegroundColor White
        Write-Host ""

        if ($progressId) {
            Update-ProgressOperation -OperationId $progressId -IncrementStep -StepName "Configuration Review"
        }

    } catch {
        # Don't fail the entire setup just because of config review
        $result.Status = 'Success'
        $result.Details += "⚠️ Configuration review skipped due to error: $_"
        $result.Details += "✓ Configuration can be edited later using Edit-Configuration"
        $SetupState.Warnings += "Configuration review encountered an error but setup can continue"
    }

    return $result
}

# Helper function for prompts (if not already available)
if (-not (Get-Command Show-SetupPrompt -ErrorAction SilentlyContinue)) {
    function Show-SetupPrompt {
        param(
            [string]$Message,
            [switch]$DefaultYes
        )

        # In non-interactive mode or when host doesn't support prompts, use default
        if ([System.Console]::IsInputRedirected -or $env:NO_PROMPT -or $global:WhatIfPreference) {
            Write-Host "$Message [$(if ($DefaultYes) { 'Y' } else { 'N' })]" -ForegroundColor Yellow
            return $DefaultYes
        }

        try {
            $choices = '&Yes', '&No'
            $decision = $Host.UI.PromptForChoice('', $Message, $choices, $(if ($DefaultYes) { 0 } else { 1 }))
            return $decision -eq 0
        } catch {
            # Fallback to default if prompt fails
            Write-Host "$Message [$(if ($DefaultYes) { 'Y' } else { 'N' })] (auto-selected)" -ForegroundColor Yellow
            return $DefaultYes
        }
    }
}

Export-ModuleMember -Function Review-Configuration
