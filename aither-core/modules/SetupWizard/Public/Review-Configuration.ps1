function Review-Configuration {
    <#
    .SYNOPSIS
        Configuration review step for setup wizard
    .DESCRIPTION
        Prompts user to review and optionally edit configuration during setup
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
            
            Write-Host "Current Configuration:" -ForegroundColor Yellow
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
                    $result.Details += "✓ Configuration reviewed and edited"
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
            
            $result.Status = 'Success'
            
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
            
            $result.Status = 'Success'
        }
        
        # Add configuration tips
        Write-Host ""
        Write-Host "💡 Configuration Tips:" -ForegroundColor Cyan
        Write-Host "  • You can edit configuration anytime using Edit-Configuration" -ForegroundColor White
        Write-Host "  • Use -ConfigFile parameter to specify custom configs" -ForegroundColor White
        Write-Host "  • ConfigurationCarousel module enables multiple config profiles" -ForegroundColor White
        Write-Host ""
        
        if ($progressId) {
            Update-ProgressOperation -OperationId $progressId -IncrementStep -StepName "Configuration Review"
        }
        
    } catch {
        $result.Status = 'Failed'
        $result.Details += "❌ Error during configuration review: $_"
        $SetupState.Errors += $_
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
        
        $prompt = if ($DefaultYes) { " [Y/n]" } else { " [y/N]" }
        $response = Read-Host "$Message$prompt"
        
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $DefaultYes
        }
        
        return $response -match '^[Yy]'
    }
}

Export-ModuleMember -Function Review-Configuration