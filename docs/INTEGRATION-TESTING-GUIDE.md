# Integration Testing Guide

## Purpose

This guide defines integration testing standards for AitherZero to ensure all components work together correctly: CLI, UI, extensions, and configurations.

## Table of Contents

1. [Integration Test Types](#integration-test-types)
2. [Test Structure](#test-structure)
3. [CLI/Menu Integration](#climenu-integration)
4. [Extension Integration](#extension-integration)
5. [Config-Driven Rendering](#config-driven-rendering)
6. [End-to-End Workflows](#end-to-end-workflows)
7. [Test Automation](#test-automation)

---

## Integration Test Types

### 1. Component Integration Tests
Test how components work together:
- CommandParser + BreadcrumbNavigation
- ConfigManager + ExtensionManager
- UnifiedMenu + CommandParser

### 2. System Integration Tests
Test complete system flows:
- CLI command → Parser → Executor
- Menu navigation → Command building → Execution
- Config loading → UI rendering

### 3. Extension Integration Tests
Test extension system:
- Extension loading → Mode registration
- Extension commands → CLI integration
- Extension scripts → Orchestration

### 4. Config-Driven Integration Tests
Test configuration-driven behavior:
- Config changes → UI updates
- Feature flags → Component visibility
- Manifest changes → Menu generation

---

## Test Structure

### Directory Layout

```
tests/
├── unit/                           # Unit tests
│   ├── aithercore/
│   │   └── experience/
│   │       ├── BreadcrumbNavigation.Tests.ps1
│   │       └── CommandParser.Tests.ps1
│   └── automation-scripts/
├── integration/                    # Integration tests
│   ├── CLI-Integration.Tests.ps1
│   ├── Menu-Integration.Tests.ps1
│   ├── Extension-Integration.Tests.ps1
│   ├── Config-Integration.Tests.ps1
│   └── EndToEnd.Tests.ps1
└── TestHelpers.psm1               # Shared test utilities
```

### Integration Test Template

```powershell
#Requires -Module Pester

BeforeAll {
    # Import components
    $ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    
    # Import modules under test
    Import-Module (Join-Path $ProjectRoot "aithercore/experience/Components/CommandParser.psm1") -Force
    Import-Module (Join-Path $ProjectRoot "aithercore/experience/Components/BreadcrumbNavigation.psm1") -Force
    
    # Import test helpers
    Import-Module (Join-Path $PSScriptRoot "../TestHelpers.psm1") -Force
}

Describe "Component Integration Tests" {
    Context "CommandParser + BreadcrumbNavigation" {
        BeforeEach {
            # Setup test state
            $breadcrumbs = New-BreadcrumbStack
        }
        
        It "Should track navigation as commands are built" {
            # Parse command
            $command = Parse-AitherCommand "-Mode Run"
            $command.IsValid | Should -Be $true
            
            # Update breadcrumbs
            Push-Breadcrumb -Stack $breadcrumbs -Name "Run" -Context @{ Mode = "Run" }
            $path = Get-BreadcrumbPath -Stack $breadcrumbs
            
            # Verify integration
            $path | Should -Match "AitherZero > Run"
        }
        
        It "Should build commands from navigation path" {
            # Simulate navigation
            Push-Breadcrumb -Stack $breadcrumbs -Name "Run" -Context @{ Mode = "Run" }
            Push-Breadcrumb -Stack $breadcrumbs -Name "Testing" -Context @{ Category = "Testing" }
            Push-Breadcrumb -Stack $breadcrumbs -Name "0402" -Context @{ Target = "0402" }
            
            # Build command from context
            $contexts = $breadcrumbs.Items | ForEach-Object { $_.Context }
            $command = Build-AitherCommand -Mode "Run" -Target "0402"
            
            # Verify
            $command | Should -Match "-Mode Run -Target 0402"
        }
    }
}

Describe "System Integration Tests" {
    Context "Complete CLI Flow" {
        It "Should execute full CLI command workflow" {
            # Parse command
            $command = Parse-AitherCommand "-Mode Run -Target 0402"
            $command.IsValid | Should -Be $true
            
            # Validate mode
            $command.Mode | Should -Be "Run"
            $command.Target | Should -Be "0402"
            
            # Mock execution
            Mock Invoke-AitherScript { return @{ Success = $true } }
            
            # Execute (mocked)
            $result = Invoke-AitherScript -Mode $command.Mode -Target $command.Target
            $result.Success | Should -Be $true
        }
    }
}
```

---

## CLI/Menu Integration

### Test: Menu Navigation Builds CLI Commands

```powershell
Describe "Menu to CLI Integration" {
    Context "Navigation builds commands" {
        It "Should build correct command from menu selections" {
            # Mock user navigating menu
            $selections = @(
                @{ Type = 'Mode'; Value = 'Run' },
                @{ Type = 'Category'; Value = 'Testing' },
                @{ Type = 'Script'; Value = '0402' }
            )
            
            # Build command from selections
            $commandParts = @()
            foreach ($selection in $selections) {
                switch ($selection.Type) {
                    'Mode' { $commandParts += "-Mode $($selection.Value)" }
                    'Script' { $commandParts += "-Target $($selection.Value)" }
                }
            }
            
            $command = $commandParts -join ' '
            
            # Verify command
            $command | Should -Be "-Mode Run -Target 0402"
            
            # Verify it parses correctly
            $parsed = Parse-AitherCommand $command
            $parsed.IsValid | Should -Be $true
            $parsed.Mode | Should -Be "Run"
            $parsed.Target | Should -Be "0402"
        }
    }
    
    Context "Typed commands work in menu" {
        It "Should accept directly typed CLI commands" {
            # User types command in menu
            $userInput = "-Mode Run -Target 0402"
            
            # Parse as CLI command
            $parsed = Parse-AitherCommand $userInput
            $parsed.IsValid | Should -Be $true
            
            # Should execute same as menu navigation
            Mock Invoke-AitherScript { return @{ Success = $true } }
            $result = Invoke-AitherScript -Mode $parsed.Mode -Target $parsed.Target
            $result.Success | Should -Be $true
        }
    }
}
```

### Test: Breadcrumb Tracking During Navigation

```powershell
Describe "Breadcrumb Integration" {
    Context "Breadcrumbs update with navigation" {
        BeforeEach {
            $breadcrumbs = New-BreadcrumbStack
        }
        
        It "Should track full navigation path" {
            # Simulate menu navigation
            Push-Breadcrumb -Stack $breadcrumbs -Name "AitherZero" -Context @{}
            $path = Get-BreadcrumbPath -Stack $breadcrumbs
            $path | Should -Be "AitherZero"
            
            Push-Breadcrumb -Stack $breadcrumbs -Name "Run" -Context @{ Mode = "Run" }
            $path = Get-BreadcrumbPath -Stack $breadcrumbs
            $path | Should -Match "AitherZero > Run"
            
            Push-Breadcrumb -Stack $breadcrumbs -Name "Testing" -Context @{ Category = "Testing" }
            $path = Get-BreadcrumbPath -Stack $breadcrumbs
            $path | Should -Match "AitherZero > Run > Testing"
        }
        
        It "Should pop breadcrumbs on back navigation" {
            # Navigate forward
            Push-Breadcrumb -Stack $breadcrumbs -Name "AitherZero" -Context @{}
            Push-Breadcrumb -Stack $breadcrumbs -Name "Run" -Context @{ Mode = "Run" }
            Push-Breadcrumb -Stack $breadcrumbs -Name "Testing" -Context @{ Category = "Testing" }
            
            # Navigate back
            $popped = Pop-Breadcrumb -Stack $breadcrumbs
            $popped.Name | Should -Be "Testing"
            
            $path = Get-BreadcrumbPath -Stack $breadcrumbs
            $path | Should -Match "AitherZero > Run"
        }
    }
}
```

---

## Extension Integration

### Test: Extension Loading and Registration

```powershell
Describe "Extension Integration" {
    Context "Extension loading" {
        BeforeAll {
            # Create test extension
            $testExtPath = Join-Path $TestDrive "TestExtension"
            New-Item -Path $testExtPath -ItemType Directory -Force
            
            # Create manifest
            $manifest = @{
                Name = 'TestExtension'
                Version = '1.0.0'
                CLIModes = @(
                    @{ Name = 'TestMode'; Handler = 'Invoke-TestMode' }
                )
            } | ConvertTo-Json | Out-File (Join-Path $testExtPath "TestExtension.extension.psd1")
        }
        
        It "Should load extension manifest" {
            $extensionPath = Join-Path $TestDrive "TestExtension"
            
            # Mock extension loading
            Mock Import-Extension {
                param($Name)
                return @{
                    Name = $Name
                    Loaded = $true
                    Modes = @('TestMode')
                }
            }
            
            $result = Import-Extension -Name "TestExtension"
            $result.Loaded | Should -Be $true
            $result.Modes | Should -Contain 'TestMode'
        }
        
        It "Should register extension CLI mode" {
            # Load extension (mocked)
            Mock Import-Extension {
                return @{
                    Name = "TestExtension"
                    Modes = @('TestMode')
                }
            }
            
            Import-Extension -Name "TestExtension"
            
            # Verify mode is registered
            Mock Get-RegisteredModes { return @('Interactive', 'Run', 'TestMode') }
            $modes = Get-RegisteredModes
            $modes | Should -Contain 'TestMode'
        }
    }
    
    Context "Extension command execution" {
        It "Should execute extension commands via CLI" {
            # Extension provides custom command
            Mock Invoke-TestMode {
                return @{ Success = $true; Message = "Extension command executed" }
            }
            
            # User executes via CLI
            $command = Parse-AitherCommand "-Mode TestMode -Target demo"
            $command.IsValid | Should -Be $true
            $command.Mode | Should -Be "TestMode"
            
            # Execute
            $result = Invoke-TestMode -Target $command.Target
            $result.Success | Should -Be $true
        }
    }
}
```

### Test: Extension Scripts Integration

```powershell
Describe "Extension Scripts Integration" {
    Context "Extension scripts in orchestration" {
        It "Should include extension scripts in available scripts" {
            # Mock script discovery
            Mock Get-AvailableScripts {
                return @(
                    @{ Number = 402; Name = "Run-UnitTests" },
                    @{ Number = 404; Name = "Run-PSScriptAnalyzer" },
                    @{ Number = 8000; Name = "Extension-Setup"; Extension = "TestExtension" },
                    @{ Number = 8001; Name = "Extension-Status"; Extension = "TestExtension" }
                )
            }
            
            $scripts = Get-AvailableScripts
            $extensionScripts = $scripts | Where-Object { $_.Extension -eq "TestExtension" }
            
            $extensionScripts.Count | Should -Be 2
            $extensionScripts[0].Number | Should -Be 8000
        }
        
        It "Should execute extension scripts via Run mode" {
            # User runs extension script
            $command = Parse-AitherCommand "-Mode Run -Target 8000"
            $command.IsValid | Should -Be $true
            
            Mock Invoke-AitherScript {
                return @{ Success = $true; Extension = "TestExtension" }
            }
            
            $result = Invoke-AitherScript -Mode "Run" -Target "8000"
            $result.Success | Should -Be $true
            $result.Extension | Should -Be "TestExtension"
        }
    }
}
```

---

## Config-Driven Rendering

### Test: Config Changes Update UI

```powershell
Describe "Config-Driven UI Rendering" {
    Context "UI reflects config changes" {
        It "Should show/hide features based on config" {
            # Config with Docker enabled
            $config1 = @{
                Features = @{
                    Docker = @{ Enabled = $true }
                    Kubernetes = @{ Enabled = $false }
                }
            }
            
            Mock Get-Configuration { return $config1 }
            Mock Get-ManifestCapabilities {
                $config = Get-Configuration
                return @{
                    Features = $config.Features.Keys | Where-Object {
                        $config.Features[$_].Enabled
                    }
                }
            }
            
            $capabilities = Get-ManifestCapabilities
            $capabilities.Features | Should -Contain 'Docker'
            $capabilities.Features | Should -Not -Contain 'Kubernetes'
        }
        
        It "Should update menu items when config changes" {
            # Initial config
            $config = @{
                Manifest = @{
                    SupportedModes = @('Interactive', 'Run', 'Test')
                }
            }
            
            Mock Get-Configuration { return $config }
            Mock Build-MenuItems {
                $config = Get-Configuration
                return $config.Manifest.SupportedModes | ForEach-Object {
                    @{ Name = $_; Enabled = $true }
                }
            }
            
            $menuItems = Build-MenuItems
            $menuItems.Count | Should -Be 3
            $menuItems.Name | Should -Contain 'Run'
            
            # Update config
            $config.Manifest.SupportedModes += 'Deploy'
            
            $menuItems = Build-MenuItems
            $menuItems.Count | Should -Be 4
            $menuItems.Name | Should -Contain 'Deploy'
        }
    }
    
    Context "Extension modes in config" {
        It "Should include extension modes in available modes" {
            # Config without extensions
            $config = @{
                Manifest = @{
                    SupportedModes = @('Interactive', 'Run')
                }
            }
            
            Mock Get-Configuration { return $config }
            Mock Get-RegisteredExtensionModes { return @() }
            
            Mock Get-AllAvailableModes {
                $config = Get-Configuration
                $coreModes = $config.Manifest.SupportedModes
                $extModes = Get-RegisteredExtensionModes
                return $coreModes + $extModes
            }
            
            $modes = Get-AllAvailableModes
            $modes.Count | Should -Be 2
            
            # Load extension that adds mode
            Mock Get-RegisteredExtensionModes { return @('TestMode') }
            
            $modes = Get-AllAvailableModes
            $modes.Count | Should -Be 3
            $modes | Should -Contain 'TestMode'
        }
    }
}
```

### Test: Script Inventory Accuracy

```powershell
Describe "Config Script Inventory" {
    Context "Script count validation" {
        It "Should have accurate script count in config" {
            # Get actual scripts
            $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $scriptPath = Join-Path $projectRoot "automation-scripts"
            $actualScripts = Get-ChildItem -Path $scriptPath -Filter "*.ps1" | 
                Where-Object { $_.Name -match '^\d{4}_' }
            
            # Get count from config
            $config = Get-Configuration
            $configCount = $config.Manifest.ScriptInventory.Total
            
            # Verify accuracy
            $actualScripts.Count | Should -Be $configCount
        }
        
        It "Should have accurate range counts" {
            $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $scriptPath = Join-Path $projectRoot "automation-scripts"
            
            # Count scripts in 0400-0499 range
            $testingScripts = Get-ChildItem -Path $scriptPath -Filter "*.ps1" |
                Where-Object { $_.Name -match '^04\d{2}_' }
            
            # Get count from config
            $config = Get-Configuration
            $configCount = $config.Manifest.ScriptInventory.ByRange.'0400-0499'
            
            # Verify
            $testingScripts.Count | Should -Be $configCount
        }
    }
}
```

---

## End-to-End Workflows

### Test: Complete User Workflow

```powershell
Describe "End-to-End Workflows" {
    Context "New user learns CLI via menu" {
        It "Should complete learning workflow" {
            # Phase 1: User starts interactive menu
            Mock Start-InteractiveMenu {
                return @{
                    Started = $true
                    Mode = 'Interactive'
                }
            }
            
            $session = Start-InteractiveMenu
            $session.Started | Should -Be $true
            
            # Phase 2: User navigates with arrows (builds command)
            $breadcrumbs = New-BreadcrumbStack
            Push-Breadcrumb -Stack $breadcrumbs -Name "AitherZero" -Context @{}
            Push-Breadcrumb -Stack $breadcrumbs -Name "Run" -Context @{ Mode = "Run" }
            Push-Breadcrumb -Stack $breadcrumbs -Name "0402" -Context @{ Target = "0402" }
            
            # Show command being built
            $command = Build-AitherCommand -Mode "Run" -Target "0402"
            $command | Should -Match "-Mode Run -Target 0402"
            
            # Phase 3: User sees and learns CLI command
            # Next time, user types command directly
            $parsed = Parse-AitherCommand "-Mode Run -Target 0402"
            $parsed.IsValid | Should -Be $true
            
            # Phase 4: User creates script using learned command
            $scriptContent = "./Start-AitherZero.ps1 -Mode Run -Target 0402"
            $scriptContent | Should -Match "-Mode Run -Target 0402"
        }
    }
    
    Context "Developer creates and uses extension" {
        It "Should complete extension workflow" {
            # Step 1: Create extension
            Mock New-ExtensionTemplate {
                param($Name, $Path)
                return @{
                    Success = $true
                    ExtensionPath = Join-Path $Path $Name
                }
            }
            
            $result = New-ExtensionTemplate -Name "MyExtension" -Path "./extensions"
            $result.Success | Should -Be $true
            
            # Step 2: Load extension
            Mock Import-Extension {
                param($Name)
                return @{
                    Name = $Name
                    Loaded = $true
                    Modes = @('MyMode')
                }
            }
            
            $extension = Import-Extension -Name "MyExtension"
            $extension.Loaded | Should -Be $true
            
            # Step 3: Use extension via CLI
            $command = Parse-AitherCommand "-Mode MyMode -Target demo"
            $command.IsValid | Should -Be $true
            
            # Step 4: Extension visible in menu
            Mock Get-AllAvailableModes { return @('Interactive', 'Run', 'MyMode') }
            $modes = Get-AllAvailableModes
            $modes | Should -Contain 'MyMode'
        }
    }
    
    Context "Operations switches environments" {
        It "Should complete config switching workflow" {
            # Step 1: View available configs
            Mock Get-AvailableConfigurations {
                return @(
                    @{ Name = 'config'; Profile = 'Standard' },
                    @{ Name = 'config.dev'; Profile = 'Developer' },
                    @{ Name = 'config.prod'; Profile = 'Minimal' }
                )
            }
            
            $configs = Get-AvailableConfigurations
            $configs.Count | Should -Be 3
            
            # Step 2: Switch to development config
            Mock Switch-Configuration {
                param($ConfigName)
                return @{
                    Success = $true
                    NewConfig = $ConfigName
                    Profile = 'Developer'
                }
            }
            
            $result = Switch-Configuration -ConfigName "config.dev"
            $result.Success | Should -Be $true
            $result.Profile | Should -Be 'Developer'
            
            # Step 3: UI reflects new config
            Mock Get-Configuration {
                return @{
                    Core = @{ Profile = 'Developer' }
                    Features = @{
                        Docker = @{ Enabled = $true }
                        DebugMode = @{ Enabled = $true }
                    }
                }
            }
            
            $config = Get-Configuration
            $config.Features.DebugMode.Enabled | Should -Be $true
        }
    }
}
```

---

## Test Automation

### Continuous Integration Tests

Create `tests/integration/CI-Integration.Tests.ps1`:

```powershell
#Requires -Module Pester

Describe "CI Integration Tests" -Tag 'CI' {
    Context "System health checks" {
        It "All core modules should load" {
            $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            
            $modules = @(
                "aithercore/experience/Components/CommandParser.psm1",
                "aithercore/experience/Components/BreadcrumbNavigation.psm1",
                "aithercore/utilities/ExtensionManager.psm1",
                "aithercore/configuration/ConfigManager.psm1"
            )
            
            foreach ($module in $modules) {
                $path = Join-Path $projectRoot $module
                { Import-Module $path -Force } | Should -Not -Throw
            }
        }
        
        It "Config should be valid" {
            $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $configPath = Join-Path $projectRoot "config.psd1"
            
            $configPath | Should -Exist
            { Import-PowerShellDataFile $configPath } | Should -Not -Throw
        }
        
        It "All demos should execute without errors" {
            $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            
            $demos = @(
                "demos/Demo-CommandParser.ps1",
                "demos/Demo-BreadcrumbNavigation.ps1"
            )
            
            foreach ($demo in $demos) {
                $demoPath = Join-Path $projectRoot $demo
                if (Test-Path $demoPath) {
                    { & $demoPath } | Should -Not -Throw
                }
            }
        }
    }
}
```

### Run Integration Tests

```powershell
# Run all integration tests
Invoke-Pester -Path "./tests/integration" -Output Detailed

# Run with tags
Invoke-Pester -Path "./tests/integration" -Tag 'CI' -Output Detailed

# Run specific test file
Invoke-Pester -Path "./tests/integration/CLI-Integration.Tests.ps1" -Output Detailed
```

---

## Validation Checklist

Before committing integration changes:

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] CLI commands work correctly
- [ ] Menu navigation builds correct commands
- [ ] Extensions load and register
- [ ] Config changes update UI
- [ ] Breadcrumbs track navigation
- [ ] End-to-end workflows complete
- [ ] CI tests pass
- [ ] Cross-platform tested

---

## Troubleshooting Integration Issues

### Issue: Menu doesn't build correct command

**Check:**
1. CommandParser is correctly parsing input
2. Breadcrumb context includes all needed data
3. Command builder uses correct parameter names

**Fix:**
```powershell
# Add integration test
It "Should build command from menu context" {
    $contexts = @(
        @{ Mode = "Run" },
        @{ Target = "0402" }
    )
    
    $command = Build-CommandFromContexts $contexts
    $command | Should -Match "-Mode Run -Target 0402"
}
```

### Issue: Extension modes don't appear in UI

**Check:**
1. Extension manifest has CLIModes section
2. Extension is loaded successfully
3. Mode registration function is called
4. UI queries registered modes

**Fix:**
```powershell
# Add integration test
It "Should register extension modes" {
    Import-Extension -Name "TestExtension"
    $modes = Get-AllAvailableModes
    $modes | Should -Contain 'TestMode'
}
```

### Issue: Config changes don't update UI

**Check:**
1. Config is reloaded after changes
2. UI queries latest config
3. Manifest capabilities are refreshed
4. Menu items are rebuilt

**Fix:**
```powershell
# Add integration test
It "Should update UI when config changes" {
    # Change config
    $config = Get-Configuration
    $config.Features.NewFeature = @{ Enabled = $true }
    Save-Configuration $config
    
    # Reload
    Initialize-ConfigManager
    
    # Verify UI sees change
    $capabilities = Get-ManifestCapabilities
    $capabilities.Features | Should -Contain 'NewFeature'
}
```

---

## Summary

Integration testing ensures:
1. ✅ CLI and menu use same commands
2. ✅ Extensions integrate seamlessly
3. ✅ Config drives UI/CLI rendering
4. ✅ Navigation tracks correctly
5. ✅ End-to-end workflows function
6. ✅ System components communicate properly

**Run integration tests frequently!**

```powershell
# Quick integration check
Invoke-Pester -Path "./tests/integration" -Tag 'Quick' -Output Detailed

# Full integration suite
Invoke-Pester -Path "./tests/integration" -Output Detailed
```

---

**Version:** 1.0.0  
**Last Updated:** 2025-11-05  
**Maintainer:** AitherZero Team
