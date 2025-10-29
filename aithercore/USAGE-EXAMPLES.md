# AitherCore Usage Examples

This document provides practical examples of using AitherCore modules.

## Loading AitherCore

```powershell
# Import the AitherCore module
Import-Module ./aithercore/AitherCore.psd1

# Verify it loaded
Get-Module AitherCore
```

## Logging Examples

```powershell
# Initialize logging
Initialize-Logging -Path "./logs" -Level 'Information' -Targets 'Console', 'File'

# Write log messages
Write-CustomLog -Message "Application started" -Level 'Information' -Source "MyApp"
Write-CustomLog -Message "Processing data" -Level 'Verbose' -Source "MyApp"
Write-CustomLog -Message "Operation completed" -Level 'Information' -Source "MyApp" -Data @{
    Records = 100
    Duration = "5s"
}

# Write audit log
Write-AuditLog -Action "UserLogin" -User "admin" -Resource "Dashboard" -Result "Success"

# Get logs
Get-Logs -Level 'Information' -Since (Get-Date).AddHours(-1)

# Export log report
Export-LogReport -Path "./reports/log-summary.html" -Format 'HTML'
```

## Configuration Examples

```powershell
# Initialize configuration
Initialize-ConfigurationSystem -ConfigFile "./config.psd1"

# Get configuration
$config = Get-Configuration
Write-Host "Environment: $($config.Environment)"

# Get specific value
$logLevel = Get-ConfigValue -Key "Logging.Level"
$dbConnection = Get-ConfigValue -Key "Database.ConnectionString"

# Set configuration
Set-Configuration -Key "Features.NewUI" -Value $true

# Export configuration
Export-Configuration -Path "./config-backup.psd1"

# Switch environment
Switch-ConfigurationEnvironment -Environment "Production"
```

## UI Examples

```powershell
# Initialize UI system
Initialize-AitherUI

# Show interactive menu
$items = @("Option 1", "Option 2", "Option 3", "Exit")
$selection = Show-UIMenu -Title "Main Menu" -Items $items
Write-Host "You selected: $selection"

# Show progress
Show-UIProgress -Activity "Processing files" -Status "Loading..." -PercentComplete 0
for ($i = 1; $i -le 100; $i++) {
    Start-Sleep -Milliseconds 50
    Show-UIProgress -Activity "Processing files" -Status "File $i of 100" -PercentComplete $i
}

# Show notification
Show-UINotification -Title "Success" -Message "Operation completed successfully" -Type "Success"

# Write styled text
Write-UISuccess "Task completed successfully"
Write-UIError "An error occurred"
Write-UIWarning "Please review this warning"
Write-UIInfo "FYI: System updated"

# Show section
Write-UISection -Title "System Status" -Message "All systems operational"

# Show wizard
$steps = @(
    @{ Name = "Welcome"; Description = "Welcome to setup" },
    @{ Name = "Configure"; Description = "Configure settings" },
    @{ Name = "Complete"; Description = "Setup complete" }
)
Show-UIWizard -Title "Setup Wizard" -Steps $steps
```

## Better Menu Examples

```powershell
# Simple menu
$items = @("Start Server", "Stop Server", "Restart Server", "Exit")
$choice = Show-BetterMenu -Title "Server Control" -Items $items -ShowNumbers
Write-Host "Selected: $choice"

# Multi-select menu
$features = @("Feature A", "Feature B", "Feature C", "Feature D")
$selected = Show-BetterMenu -Title "Select Features" -Items $features -MultiSelect
Write-Host "You enabled: $($selected -join ', ')"

# Menu with custom actions
$items = @("View Logs", "Clear Cache", "Run Tests", "Exit")
$actions = @{
    'r' = { Write-Host "Refreshing..." }
    'h' = { Write-Host "Help: Use arrow keys to navigate" }
}
$choice = Show-BetterMenu -Title "Admin Menu" -Items $items -CustomActions $actions
```

## Infrastructure Examples

```powershell
# Initialize infrastructure
Initialize-Infrastructure

# Get infrastructure provider (OpenTofu or Terraform)
$provider = Get-InfrastructureProvider
if ($provider) {
    Write-Host "Using provider: $($provider.Name) $($provider.Version)"
} else {
    Write-Host "No infrastructure provider available"
}
```

## Security Examples

```powershell
# Initialize security
Initialize-Security

# Test secure environment
$isSecure = Test-SecureEnvironment
if ($isSecure) {
    Write-Host "Environment is secure"
} else {
    Write-Host "Security checks failed"
}
```

## Orchestration Examples

```powershell
# Get available scripts
$scripts = Get-AvailableScripts
$scripts | ForEach-Object {
    Write-Host "$($_.Number): $($_.Name)"
}

# Get script metadata
$metadata = Get-ScriptMetadata -ScriptNumber "0402"
Write-Host "Script: $($metadata.Name)"
Write-Host "Description: $($metadata.Description)"

# Invoke orchestration sequence
Invoke-OrchestrationSequence -Sequence "0000-0099" -Configuration $config

# Run specific playbook
$playbook = Get-OrchestrationPlaybook -Name "test-quick"
Invoke-OrchestrationSequence -Playbook $playbook
```

## Complete Application Example

```powershell
# Example: Simple monitoring application using AitherCore

# 1. Load AitherCore
Import-Module ./aithercore/AitherCore.psd1

# 2. Initialize systems
Initialize-Logging -Path "./logs" -Level 'Information' -Targets 'Console', 'File'
Initialize-ConfigurationSystem -ConfigFile "./config.psd1"
Initialize-AitherUI

# 3. Get configuration
$config = Get-Configuration

# 4. Show welcome screen
Write-UISection -Title "System Monitor" -Message "Version 1.0"
Write-UIInfo "Configuration loaded: $($config.Environment) environment"

# 5. Show main menu
$running = $true
while ($running) {
    $items = @(
        "View System Status",
        "Check Logs",
        "Run Health Check",
        "Settings",
        "Exit"
    )
    
    $choice = Show-BetterMenu -Title "Main Menu" -Items $items
    
    switch ($choice) {
        "View System Status" {
            Write-CustomLog -Message "Viewing system status" -Source "Monitor"
            Write-UISuccess "CPU: 45% | Memory: 60% | Disk: 70%"
            Write-Host "`nPress Enter to continue..."
            Read-Host
        }
        
        "Check Logs" {
            $logs = Get-Logs -Level 'Warning' -Last 10
            Write-UISection -Title "Recent Warnings"
            $logs | ForEach-Object {
                Write-UIWarning "$($_.Timestamp): $($_.Message)"
            }
            Write-Host "`nPress Enter to continue..."
            Read-Host
        }
        
        "Run Health Check" {
            Write-UIInfo "Running health check..."
            Show-UIProgress -Activity "Health Check" -Status "Checking services..." -PercentComplete 30
            Start-Sleep -Seconds 1
            Show-UIProgress -Activity "Health Check" -Status "Checking connectivity..." -PercentComplete 60
            Start-Sleep -Seconds 1
            Show-UIProgress -Activity "Health Check" -Status "Complete" -PercentComplete 100
            Write-UISuccess "Health check passed"
            Write-CustomLog -Message "Health check completed" -Source "Monitor" -Data @{ Status = "Healthy" }
            Write-Host "`nPress Enter to continue..."
            Read-Host
        }
        
        "Settings" {
            $envItems = @("Development", "Staging", "Production", "Back")
            $env = Show-BetterMenu -Title "Select Environment" -Items $envItems
            if ($env -ne "Back") {
                Switch-ConfigurationEnvironment -Environment $env
                Write-UISuccess "Switched to $env environment"
                Write-CustomLog -Message "Environment changed" -Source "Monitor" -Data @{ Environment = $env }
            }
        }
        
        "Exit" {
            Write-UIInfo "Shutting down..."
            Write-CustomLog -Message "Application shutdown" -Source "Monitor"
            $running = $false
        }
    }
}

Write-UISuccess "Goodbye!"
```

## Integration with Full AitherZero

AitherCore can be used standalone or alongside the full AitherZero platform:

```powershell
# Use AitherCore for basic operations
Import-Module ./aithercore/AitherCore.psd1

# Later, load full platform if needed
Import-Module ./AitherZero.psd1

# Both modules can coexist, with AitherZero providing additional domains
```

## Best Practices

1. **Always initialize systems before use:**
   ```powershell
   Initialize-Logging
   Initialize-ConfigurationSystem
   Initialize-AitherUI
   ```

2. **Use structured logging with data:**
   ```powershell
   Write-CustomLog -Message "Operation" -Source "App" -Data @{ User = $user; Action = $action }
   ```

3. **Handle errors gracefully:**
   ```powershell
   try {
       # Your code
   } catch {
       Write-CustomLog -Level 'Error' -Message $_.Exception.Message -Source "App"
       Write-UIError "Operation failed: $($_.Exception.Message)"
   }
   ```

4. **Use configuration for flexibility:**
   ```powershell
   $timeout = Get-ConfigValue -Key "App.Timeout" -Default 30
   $enabled = Test-FeatureEnabled -Feature "NewUI"
   ```

5. **Provide feedback to users:**
   ```powershell
   Show-UIProgress -Activity "Processing" -Status "Step 1 of 3"
   Write-UISuccess "Completed successfully"
   ```
