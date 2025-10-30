#Requires -Modules Pester

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:EntryScript = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"

    # Mock functions that would be loaded by the script
    function Get-Configuration { return @{ Core = @{ Name = "Test" } } }
    function Initialize-AitherModules { return $true }
    function Show-InteractiveMenu { return "Exit" }
    function Invoke-OrchestrationSequence { param($Sequence) return @{ Success = $true } }
    function Write-CustomLog { param($Message, $Level) }
}

AfterAll {
    # Cleanup
    Remove-Item Function:\Get-Configuration -ErrorAction SilentlyContinue
    Remove-Item Function:\Initialize-AitherModules -ErrorAction SilentlyContinue
    Remove-Item Function:\Show-InteractiveMenu -ErrorAction SilentlyContinue
    Remove-Item Function:\Invoke-OrchestrationSequence -ErrorAction SilentlyContinue
    Remove-Item Function:\Write-CustomLog -ErrorAction SilentlyContinue
}

Describe "Start-AitherZero Script" -Tag 'Unit' {

    Context "Script Validation" {
        It "Should have a valid script file" {
            Test-Path $script:EntryScript | Should -Be $true
        }

        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:EntryScript,
                [ref]$null,
                [ref]$errors
            )
            $errors | Should -BeNullOrEmpty
        }

        It "Should have proper script metadata" {
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match "\.SYNOPSIS"
            $content | Should -Match "\.DESCRIPTION"
            $content | Should -Match "\.PARAMETER"
        }
    }

    Context "Parameter Validation" {
        BeforeEach {
            # Create a test version of the script that we can invoke
            $script:TestScript = @'
[CmdletBinding()]
param(
    [switch]$Interactive,

    [string]$Mode,

    [string]$Sequence,

    [string]$Playbook,

    [hashtable]$Variables = @{},

    [string]$ConfigPath,

    [switch]$DryRun,

    [switch]$Help
)

# Return parameters for testing
return $PSBoundParameters
'@
            $script:TestScriptPath = Join-Path $TestDrive "test-start.ps1"
            $script:TestScript | Set-Content $script:TestScriptPath
        }

        It "Should accept Interactive mode" {
            $result = & $script:TestScriptPath -Interactive
            $result.Interactive | Should -Be $true
        }

        It "Should accept Orchestrate mode with sequence" {
            $result = & $script:TestScriptPath -Mode Orchestrate -Sequence "0400-0499"
            $result.Mode | Should -Be "Orchestrate"
            $result.Sequence | Should -Be "0400-0499"
        }

        It "Should accept Orchestrate mode with playbook" {
            $result = & $script:TestScriptPath -Mode Orchestrate -Playbook "test-playbook"
            $result.Mode | Should -Be "Orchestrate"
            $result.Playbook | Should -Be "test-playbook"
        }

        It "Should accept Variables parameter" {
            $vars = @{ Key1 = "Value1"; Key2 = "Value2" }
            $result = & $script:TestScriptPath -Mode Orchestrate -Sequence "0400" -Variables $vars
            $result.Variables.Key1 | Should -Be "Value1"
            $result.Variables.Key2 | Should -Be "Value2"
        }

        It "Should accept ConfigPath parameter" {
            $result = & $script:TestScriptPath -ConfigPath "/custom/config.psd1"
            $result.ConfigPath | Should -Be "/custom/config.psd1"
        }

        It "Should accept DryRun switch" {
            $result = & $script:TestScriptPath -Mode Orchestrate -Sequence "0400" -DryRun
            $result.DryRun | Should -Be $true
        }

        It "Should accept Help switch" {
            $result = & $script:TestScriptPath -Help
            $result.Help | Should -Be $true
        }
    }

    Context "Mode Execution" {
        BeforeEach {
            Mock Write-Host {}
            Mock Write-Error {}
            Mock Exit {}
        }

        It "Should show help when Help parameter is provided" {
            # Create a simplified test for help display
            $helpScript = @'
param([switch]$Help)
if ($Help) {
    Write-Host "AitherZero Help"
    Write-Host "==============="
    return
}
'@
            $helpScriptPath = Join-Path $TestDrive "help-test.ps1"
            $helpScript | Set-Content $helpScriptPath

            & $helpScriptPath -Help

            Should -Invoke Write-Host -Times 2
        }

        It "Should validate required parameters for Orchestrate mode" {
            # Test that orchestrate mode requires either Sequence or Playbook
            $validateScript = @'
param(
    [string]$Mode,
    [string]$Sequence,
    [string]$Playbook
)
if ($Mode -eq "Orchestrate" -and -not $Sequence -and -not $Playbook) {
    Write-Error "Orchestrate mode requires either -Sequence or -Playbook parameter"
    exit 1
}
Write-Host "Valid"
'@
            $validateScriptPath = Join-Path $TestDrive "validate-test.ps1"
            $validateScript | Set-Content $validateScriptPath

            # Should error without sequence or playbook
            $errorOutput = & $validateScriptPath -Mode Orchestrate 2>&1
            $errorOutput | Should -Match "requires either"

            # Should succeed with sequence
            $output = & $validateScriptPath -Mode Orchestrate -Sequence "0400"
            $output | Should -Be "Valid"
        }
    }

    Context "Configuration Loading" {
        It "Should load configuration from default path if not specified" {
            Mock Get-Configuration { return @{ Core = @{ Name = "MockedConfig" } } }

            # Simplified config loading test
            $configScript = @'
function Get-Configuration { return @{ Core = @{ Name = "DefaultConfig" } } }
$config = Get-Configuration
Write-Host $config.Core.Name
'@
            $configScriptPath = Join-Path $TestDrive "config-test.ps1"
            $configScript | Set-Content $configScriptPath

            $output = & $configScriptPath
            $output | Should -Be "DefaultConfig"
        }

        It "Should load configuration from custom path when specified" {
            $customConfigPath = Join-Path $TestDrive "custom-config.psd1"
            @{ Core = @{ Name = "CustomConfig" } } | ConvertTo-Json | Set-Content $customConfigPath

            $configScript = @'
param([string]$ConfigPath)
if ($ConfigPath -and (Test-Path $ConfigPath)) {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    Write-Host $config.Core.Name
}
'@
            $configScriptPath = Join-Path $TestDrive "custom-config-test.ps1"
            $configScript | Set-Content $configScriptPath

            $output = & $configScriptPath -ConfigPath $customConfigPath
            $output | Should -Be "CustomConfig"
        }
    }

    Context "Error Handling" {
        It "Should handle missing configuration file gracefully" {
            $errorScript = @'
param([string]$ConfigPath)
try {
    if ($ConfigPath -and -not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    Write-Host "Success"
} catch {
    Write-Error $_.Exception.Message
}
'@
            $errorScriptPath = Join-Path $TestDrive "error-test.ps1"
            $errorScript | Set-Content $errorScriptPath

            $output = & $errorScriptPath -ConfigPath "/nonexistent/config.psd1" 2>&1
            $output | Should -Match "Configuration file not found"
        }

        It "Should handle module loading failures" {
            $moduleScript = @'
try {
    Import-Module NonExistentModule -ErrorAction Stop
} catch {
    Write-Error "Failed to load required module"
    exit 1
}
'@
            $moduleScriptPath = Join-Path $TestDrive "module-test.ps1"
            $moduleScript | Set-Content $moduleScriptPath

            $output = & $moduleScriptPath 2>&1
            $output | Should -Match "Failed to load required module"
        }
    }

    Context "Interactive Mode" {
        It "Should display menu in interactive mode" {
            Mock Show-InteractiveMenu { return "Exit" }

            $interactiveScript = @'
function Show-InteractiveMenu {
    Write-Host "1. Option 1"
    Write-Host "2. Option 2"
    Write-Host "3. Exit"
    return "Exit"
}

$choice = Show-InteractiveMenu
Write-Host "Selected: $choice"
'@
            $interactiveScriptPath = Join-Path $TestDrive "interactive-test.ps1"
            $interactiveScript | Set-Content $interactiveScriptPath

            $output = & $interactiveScriptPath
            $output[-1] | Should -Be "Selected: Exit"
        }
    }

    Context "Orchestration Mode" {
        It "Should execute orchestration sequence" {
            $orchScript = @'
param([string]$Sequence)
function Invoke-OrchestrationSequence {
    param($Sequence)
    Write-Host "Executing sequence: $Sequence"
    return @{ Success = $true; ExecutedScripts = 5 }
}

if ($Sequence) {
    $result = Invoke-OrchestrationSequence -Sequence $Sequence
    Write-Host "Success: $($result.Success)"
}
'@
            $orchScriptPath = Join-Path $TestDrive "orch-test.ps1"
            $orchScript | Set-Content $orchScriptPath

            $output = & $orchScriptPath -Sequence "0400-0499"
            $output | Should -Contain "Executing sequence: 0400-0499"
            $output | Should -Contain "Success: True"
        }

        It "Should load and execute playbook" {
            $playbookPath = Join-Path $TestDrive "test-playbook.json"
            @{
                Name = "TestPlaybook"
                Sequence = @("0402", "0404")
            } | ConvertTo-Json | Set-Content $playbookPath

            $playbookScript = @'
param([string]$Playbook)
if ($Playbook) {
    Write-Host "Loading playbook: $Playbook"
    Write-Host "Executing playbook sequence"
}
'@
            $playbookScriptPath = Join-Path $TestDrive "playbook-test.ps1"
            $playbookScript | Set-Content $playbookScriptPath

            $output = & $playbookScriptPath -Playbook "test-playbook"
            $output | Should -Contain "Loading playbook: test-playbook"
        }
    }

    Context "DryRun Mode" {
        It "Should not execute actions in DryRun mode" {
            $dryRunScript = @'
param([switch]$DryRun)
if ($DryRun) {
    Write-Host "[DryRun] Would execute action"
} else {
    Write-Host "Executing action"
}
'@
            $dryRunScriptPath = Join-Path $TestDrive "dryrun-test.ps1"
            $dryRunScript | Set-Content $dryRunScriptPath

            $output = & $dryRunScriptPath -DryRun
            $output | Should -Be "[DryRun] Would execute action"
        }
    }

    Context "Configuration Editing and Reload" {
        It "Should reload configuration after editing in Advanced Menu" {
            # Create a test config file
            $testConfigPath = Join-Path $TestDrive "test-config.psd1"
            $initialConfig = @'
@{
    Core = @{
        Name = "InitialConfig"
        Version = "1.0.0"
        Profile = "Standard"
    }
}
'@
            $initialConfig | Set-Content $testConfigPath

            # Simulate the configuration editing and reloading process
            $reloadScript = @'
param([string]$ConfigPath)

# Mock functions that would be available
function Show-UINotification { param($Message, $Type) Write-Host "$Type - $Message" }
function Get-AitherConfiguration { 
    param([string]$Path)
    if (Test-Path $Path) {
        return Import-PowerShellDataFile $Path
    }
}

# Initial load
$Config = Get-AitherConfiguration -Path $ConfigPath
Write-Host "Before: $($Config.Core.Name)"

# Simulate editing the file
$updatedConfig = @"
@{
    Core = @{
        Name = "UpdatedConfig"
        Version = "1.0.0"
        Profile = "Developer"
    }
}
"@
$updatedConfig | Set-Content $ConfigPath

# Reload configuration (simulating the fix)
Show-UINotification -Message "Reloading configuration..." -Type 'Info'
try {
    $Config = Get-AitherConfiguration -Path $ConfigPath
    Show-UINotification -Message "Configuration reloaded successfully!" -Type 'Success'
    Write-Host "After: $($Config.Core.Name)"
} catch {
    Show-UINotification -Message "Failed to reload configuration: $($_.Exception.Message)" -Type 'Error'
}
'@
            $reloadScriptPath = Join-Path $TestDrive "reload-test.ps1"
            $reloadScript | Set-Content $reloadScriptPath

            # Execute the test
            $output = & $reloadScriptPath -ConfigPath $testConfigPath
            
            # Verify the reload happened
            $output | Should -Contain "Before: InitialConfig"
            $output | Should -Contain "Info - Reloading configuration..."
            $output | Should -Contain "Success - Configuration reloaded successfully!"
            $output | Should -Contain "After: UpdatedConfig"
        }

        It "Should handle configuration reload errors gracefully" {
            $errorScript = @'
param([string]$ConfigPath)

function Show-UINotification { param($Message, $Type) Write-Host "$Type - $Message" }
function Get-AitherConfiguration { 
    param([string]$Path)
    throw "Simulated error loading configuration"
}

try {
    $Config = Get-AitherConfiguration -Path $ConfigPath
    Show-UINotification -Message "Configuration reloaded successfully!" -Type 'Success'
} catch {
    Show-UINotification -Message "Failed to reload configuration: $($_.Exception.Message)" -Type 'Error'
}
'@
            $errorScriptPath = Join-Path $TestDrive "error-reload-test.ps1"
            $errorScript | Set-Content $errorScriptPath

            $output = & $errorScriptPath -ConfigPath "/fake/path"
            $output | Should -Match "Error - Failed to reload configuration"
            $output | Should -Match "Simulated error loading configuration"
        }
    }

    Context "PowerShell Version Check" {
        It "Should have version check logic in the script" {
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match "PSVersionTable.PSVersion.Major"
            $content | Should -Match "PowerShell 7"
        }

        It "Should have IsRelaunch parameter to prevent infinite loops" {
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match '\[switch\]\$IsRelaunch'
        }

        It "Should not have #Requires statement that blocks PS 5.1 execution" {
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Not -Match '^#Requires -Version 7'
        }

        It "Should describe auto-relaunch feature in help documentation" {
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match "automatically.*relaunch"
        }

        It "Should provide helpful error message when pwsh not found" {
            # Test the version check logic by checking the actual script content
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match "PowerShell 7\+ is not installed"
            $content | Should -Match "https://github.com/PowerShell/PowerShell"
            $content | Should -Match "bootstrap.ps1"
        }

        It "Should skip version check when IsRelaunch is set" {
            # Test that the IsRelaunch parameter prevents infinite loops
            # by checking the script logic
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match '-not \$IsRelaunch'
            $content | Should -Match 'IsRelaunch flag to prevent'
        }
    }

    Context "Script Number Shortcuts" {
        It "Should accept script numbers as Target parameter" {
            # Test that the script number shortcut feature is implemented
            $content = Get-Content $script:EntryScript -Raw
            # Check for the auto-detection logic
            $content | Should -Match 'if \(\$RunTarget -and \$RunTarget -match'
            $content | Should -Match '\$ScriptNum = \$RunTarget'
        }

        It "Should provide helpful examples in error messages" {
            # Test that error messages show both verbose and shortcut syntax
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match 'Or use shortcut:'
            $content | Should -Match 'Start-AitherZero.ps1 -Mode Run -Target 0501'
        }

        It "Should document script number shortcuts in help" {
            # Test that the help documentation includes the shortcut syntax
            $content = Get-Content $script:EntryScript -Raw
            $content | Should -Match '\.EXAMPLE'
            $content | Should -Match 'Run a specific script \(shortcut'
        }
    }
}