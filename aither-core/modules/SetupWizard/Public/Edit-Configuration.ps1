function Edit-Configuration {
    <#
    .SYNOPSIS
        Interactive configuration editor for AitherZero
    .DESCRIPTION
        Provides an interactive way to edit configuration settings
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [switch]$CreateIfMissing
    )
    
    # Find config file
    if (-not $ConfigPath) {
        $possiblePaths = @(
            (Join-Path $env:PROJECT_ROOT "configs/default-config.json"),
            "./configs/default-config.json",
            (Join-Path (Find-ProjectRoot) "configs/default-config.json")
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $ConfigPath = $path
                break
            }
        }
    }
    
    if (-not $ConfigPath -or -not (Test-Path $ConfigPath)) {
        if ($CreateIfMissing) {
            # Create default config
            $ConfigPath = Join-Path (Find-ProjectRoot) "configs/default-config.json"
            $configDir = Split-Path $ConfigPath -Parent
            
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            
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
            
            $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
            Write-Host "✓ Created default configuration at: $ConfigPath" -ForegroundColor Green
        } else {
            Write-Host "❌ Configuration file not found!" -ForegroundColor Red
            return
        }
    }
    
    Write-Host "`n⚙️  Configuration Editor" -ForegroundColor Green
    Write-Host "File: $ConfigPath" -ForegroundColor Yellow
    Write-Host ""
    
    # Read current config
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        $configHash = $config | ConvertTo-Json -Depth 10 | Get-FileHash -Algorithm MD5
    } catch {
        Write-Host "❌ Error reading configuration: $_" -ForegroundColor Red
        return
    }
    
    $editing = $true
    while ($editing) {
        Clear-Host
        Write-Host "`n⚙️  Configuration Editor" -ForegroundColor Green
        Write-Host "=" * 50 -ForegroundColor Cyan
        
        # Display current config
        Write-Host "`nCurrent Configuration:" -ForegroundColor Yellow
        $config | ConvertTo-Json -Depth 10 | Write-Host
        
        Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  [1] Edit Environment (current: $($config.environment ?? 'not set'))" -ForegroundColor White
        Write-Host "  [2] Manage Enabled Modules" -ForegroundColor White
        Write-Host "  [3] Configure Logging" -ForegroundColor White
        Write-Host "  [4] Infrastructure Settings" -ForegroundColor White
        Write-Host "  [5] Add Custom Setting" -ForegroundColor White
        Write-Host "  [6] Remove Setting" -ForegroundColor White
        Write-Host "  [7] Open in External Editor" -ForegroundColor White
        Write-Host "  [8] Reset to Defaults" -ForegroundColor White
        Write-Host "  [S] Save Changes" -ForegroundColor Green
        Write-Host "  [Q] Quit Without Saving" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "Select option"
        
        switch ($choice.ToUpper()) {
            '1' {
                Write-Host "`nAvailable environments:" -ForegroundColor Yellow
                Write-Host "  • development" -ForegroundColor White
                Write-Host "  • staging" -ForegroundColor White
                Write-Host "  • production" -ForegroundColor White
                Write-Host "  • custom (enter your own)" -ForegroundColor White
                
                $env = Read-Host "`nEnter environment"
                if ($env) {
                    $config.environment = $env
                    Write-Host "✓ Environment set to: $env" -ForegroundColor Green
                }
            }
            '2' {
                Write-Host "`nModule Management" -ForegroundColor Yellow
                
                # Get available modules
                $availableModules = Get-ChildItem -Path $env:PWSH_MODULES_PATH -Directory | Select-Object -ExpandProperty Name | Sort-Object
                $enabledModules = @($config.modules.enabled)
                
                Write-Host "`nAvailable Modules:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $availableModules.Count; $i++) {
                    $module = $availableModules[$i]
                    $status = if ($module -in $enabledModules) { "[✓]" } else { "[ ]" }
                    Write-Host "  $status $($i+1). $module" -ForegroundColor $(if ($module -in $enabledModules) { 'Green' } else { 'Gray' })
                }
                
                Write-Host "`nEnter module numbers to toggle (comma-separated), or 'all' to enable all:" -ForegroundColor Yellow
                $moduleChoice = Read-Host "Selection"
                
                if ($moduleChoice -eq 'all') {
                    $config.modules.enabled = $availableModules
                    Write-Host "✓ All modules enabled" -ForegroundColor Green
                } elseif ($moduleChoice) {
                    $selections = $moduleChoice -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
                    foreach ($idx in $selections) {
                        if ($idx -ge 0 -and $idx -lt $availableModules.Count) {
                            $module = $availableModules[$idx]
                            if ($module -in $enabledModules) {
                                $config.modules.enabled = $config.modules.enabled | Where-Object { $_ -ne $module }
                                Write-Host "✗ Disabled: $module" -ForegroundColor Yellow
                            } else {
                                $config.modules.enabled += $module
                                Write-Host "✓ Enabled: $module" -ForegroundColor Green
                            }
                        }
                    }
                }
            }
            '3' {
                Write-Host "`nLogging Configuration" -ForegroundColor Yellow
                Write-Host "Current level: $($config.logging.level ?? 'INFO')" -ForegroundColor Gray
                Write-Host "Current path: $($config.logging.path ?? './logs')" -ForegroundColor Gray
                
                Write-Host "`nLog Levels:" -ForegroundColor Cyan
                Write-Host "  [1] DEBUG - All messages" -ForegroundColor White
                Write-Host "  [2] INFO - Informational and above" -ForegroundColor White
                Write-Host "  [3] WARN - Warnings and errors only" -ForegroundColor White
                Write-Host "  [4] ERROR - Errors only" -ForegroundColor White
                
                $levelChoice = Read-Host "Select level (1-4)"
                switch ($levelChoice) {
                    '1' { $config.logging.level = 'DEBUG' }
                    '2' { $config.logging.level = 'INFO' }
                    '3' { $config.logging.level = 'WARN' }
                    '4' { $config.logging.level = 'ERROR' }
                }
                
                $newPath = Read-Host "`nLog path (Enter to keep current)"
                if ($newPath) {
                    $config.logging.path = $newPath
                }
            }
            '4' {
                Write-Host "`nInfrastructure Settings" -ForegroundColor Yellow
                
                Write-Host "`nProvider:" -ForegroundColor Cyan
                Write-Host "  [1] OpenTofu (recommended)" -ForegroundColor White
                Write-Host "  [2] Terraform" -ForegroundColor White
                
                $provChoice = Read-Host "Select provider"
                switch ($provChoice) {
                    '1' { $config.infrastructure.provider = 'opentofu' }
                    '2' { $config.infrastructure.provider = 'terraform' }
                }
                
                Write-Host "`nState Backend:" -ForegroundColor Cyan
                Write-Host "  [1] Local" -ForegroundColor White
                Write-Host "  [2] S3" -ForegroundColor White
                Write-Host "  [3] Azure Storage" -ForegroundColor White
                Write-Host "  [4] GCS" -ForegroundColor White
                
                $backendChoice = Read-Host "Select backend"
                switch ($backendChoice) {
                    '1' { $config.infrastructure.stateBackend = 'local' }
                    '2' { $config.infrastructure.stateBackend = 's3' }
                    '3' { $config.infrastructure.stateBackend = 'azurerm' }
                    '4' { $config.infrastructure.stateBackend = 'gcs' }
                }
            }
            '5' {
                $key = Read-Host "`nEnter setting key (e.g., 'myapp.feature.enabled')"
                $value = Read-Host "Enter value"
                
                if ($key -and $value) {
                    # Convert dot notation to nested object
                    $parts = $key -split '\.'
                    $current = $config
                    
                    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
                        if (-not $current.PSObject.Properties[$parts[$i]]) {
                            $current | Add-Member -NotePropertyName $parts[$i] -NotePropertyValue ([PSCustomObject]@{})
                        }
                        $current = $current.($parts[$i])
                    }
                    
                    $current | Add-Member -NotePropertyName $parts[-1] -NotePropertyValue $value -Force
                    Write-Host "✓ Added: $key = $value" -ForegroundColor Green
                }
            }
            '6' {
                $key = Read-Host "`nEnter setting key to remove"
                if ($key) {
                    # Simple implementation - only removes top-level keys
                    if ($config.PSObject.Properties[$key]) {
                        $config.PSObject.Properties.Remove($key)
                        Write-Host "✓ Removed: $key" -ForegroundColor Green
                    } else {
                        Write-Host "Key not found: $key" -ForegroundColor Yellow
                    }
                }
            }
            '7' {
                if ($IsWindows) {
                    Start-Process notepad.exe -ArgumentList $ConfigPath -Wait
                } else {
                    $editor = $env:EDITOR ?? 'nano'
                    & $editor $ConfigPath
                }
                
                # Reload config after external edit
                try {
                    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                    Write-Host "✓ Configuration reloaded" -ForegroundColor Green
                } catch {
                    Write-Host "❌ Error reloading configuration: $_" -ForegroundColor Red
                }
            }
            '8' {
                $confirm = Read-Host "`nReset to defaults? This will lose all custom settings! (yes/no)"
                if ($confirm -eq 'yes') {
                    $config = @{
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
                    Write-Host "✓ Reset to defaults" -ForegroundColor Green
                }
            }
            'S' {
                try {
                    $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
                    Write-Host "`n✅ Configuration saved successfully!" -ForegroundColor Green
                    Start-Sleep -Seconds 2
                    $editing = $false
                } catch {
                    Write-Host "❌ Error saving configuration: $_" -ForegroundColor Red
                    Read-Host "Press Enter to continue"
                }
            }
            'Q' {
                $newHash = $config | ConvertTo-Json -Depth 10 | Get-FileHash -Algorithm MD5
                if ($newHash.Hash -ne $configHash.Hash) {
                    $confirm = Read-Host "`nYou have unsaved changes. Quit anyway? (yes/no)"
                    if ($confirm -eq 'yes') {
                        $editing = $false
                    }
                } else {
                    $editing = $false
                }
            }
        }
        
        if ($editing) {
            Read-Host "`nPress Enter to continue"
        }
    }
}

# Export the function
Export-ModuleMember -Function Edit-Configuration