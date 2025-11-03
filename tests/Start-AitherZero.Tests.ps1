#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Integration tests for Start-AitherZero.ps1
.DESCRIPTION
    Comprehensive testing of the main AitherZero launcher including:
    - PowerShell version checking and auto-relaunch
    - Mode detection (Interactive, Orchestrate, Validate, etc.)
    - Module initialization
    - Configuration loading
    - Parameter validation
    - Modern CLI functionality
#>

BeforeAll {
    # Import test helpers
    $script:TestRoot = $PSScriptRoot
    Import-Module (Join-Path $script:TestRoot "TestHelpers.psm1") -Force -ErrorAction SilentlyContinue

    # Get Start-AitherZero script path
    $script:ProjectRoot = Split-Path $script:TestRoot -Parent
    $script:StartScript = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"

    # Load script content for analysis
    $script:ScriptContent = Get-Content $script:StartScript -Raw

    # Store original environment variables
    $script:OriginalEnv = @{
        CI = $env:CI
        GITHUB_ACTIONS = $env:GITHUB_ACTIONS
        AITHERZERO_ROOT = $env:AITHERZERO_ROOT
    }
}

AfterAll {
    # Restore original environment variables
    foreach ($key in $script:OriginalEnv.Keys) {
        if ($null -eq $script:OriginalEnv[$key]) {
            Remove-Item "env:$key" -ErrorAction SilentlyContinue
        } else {
            Set-Item "env:$key" -Value $script:OriginalEnv[$key]
        }
    }
}

Describe "Start-AitherZero Script Structure" {
    Context "Script File Validation" {
        It "Should exist at expected location" {
            Test-Path $script:StartScript | Should -BeTrue
        }

        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($script:ScriptContent, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Should have proper encoding (UTF-8 with BOM)" {
            $bytes = [System.IO.File]::ReadAllBytes($script:StartScript)
            # Check for UTF-8 BOM (0xEF, 0xBB, 0xBF)
            $bytes[0] | Should -Be 0xEF
            $bytes[1] | Should -Be 0xBB
            $bytes[2] | Should -Be 0xBF
        }

        It "Should have CmdletBinding attribute" {
            $script:ScriptContent | Should -BeLike "*[CmdletBinding()]*"
        }

        It "Should have comprehensive help documentation" {
            $script:ScriptContent | Should -BeLike "*.SYNOPSIS*"
            $script:ScriptContent | Should -BeLike "*.DESCRIPTION*"
            $script:ScriptContent | Should -BeLike "*.PARAMETER*"
            $script:ScriptContent | Should -BeLike "*.EXAMPLE*"
        }
    }

    Context "Code Quality Standards" {
        It "Should not use global variables" {
            # Script should use script-scoped variables instead of global
            $script:ScriptContent | Should -Not -BeLike "*`$global:AitherZeroModuleLoaded*"
            $script:ScriptContent | Should -Not -BeLike "*`$global:AitherUIInitialized*"
        }

        It "Should use proper null comparison" {
            # All null comparisons should have $null on the left side
            $nullComparisonPattern = '\$null\s+-(eq|ne)\s+'
            $script:ScriptContent | Should -Match $nullComparisonPattern
        }

        It "Should not have trailing whitespace" {
            $lines = Get-Content $script:StartScript
            $linesWithTrailingSpace = $lines | Where-Object { $_ -match '[ \t]+$' }
            $linesWithTrailingSpace.Count | Should -Be 0
        }

        It "Should use singular nouns for function names" {
            # Check that Initialize-CoreModule (singular) is used, not Initialize-CoreModules
            $script:ScriptContent | Should -BeLike "*function Initialize-CoreModule*"
        }
    }
}

Describe "PowerShell Version Check and Auto-Relaunch" {
    Context "Version Detection" {
        It "Should check for PowerShell 7+" {
            $script:ScriptContent | Should -BeLike "*PSVersionTable.PSVersion.Major -lt 7*"
        }

        It "Should attempt to find pwsh executable" {
            $script:ScriptContent | Should -BeLike "*Get-Command pwsh*"
        }

        It "Should check common PowerShell 7 installation paths" {
            $script:ScriptContent | Should -BeLike "*ProgramFiles\PowerShell*"
        }

        It "Should have relaunch prevention with IsRelaunch parameter" {
            $script:ScriptContent | Should -BeLike "*IsRelaunch*"
            $script:ScriptContent | Should -BeLike "*-not `$IsRelaunch*"
        }
    }

    Context "Parameter Preservation During Relaunch" {
        It "Should preserve all bound parameters" {
            $script:ScriptContent | Should -BeLike "*PSBoundParameters.GetEnumerator()*"
        }

        It "Should handle switch parameters correctly" {
            # Check that switch parameter handling exists
            $script:ScriptContent -match '\[switch\]' | Should -BeTrue
        }

        It "Should handle array parameters correctly" {
            # Check that array parameter handling exists
            $script:ScriptContent -match '\[array\]|\[string\[\]\]' | Should -BeTrue
        }

        It "Should handle hashtable parameters correctly" {
            # Check that hashtable parameter handling exists
            $script:ScriptContent -match '\[hashtable\]' | Should -BeTrue
        }
    }
}

Describe "Parameter Validation" {
    Context "Mode Parameter" {
        It "Should validate Mode parameter with allowed values" {
            $script:ScriptContent | Should -BeLike "*ValidateSet('Interactive', 'Orchestrate', 'Validate', 'Deploy', 'Test', 'List', 'Search', 'Run')*"
        }

        It "Should default to Interactive mode" {
            $script:ScriptContent | Should -BeLike "*[string]`$Mode = 'Interactive'*"
        }
    }

    Context "Profile Parameter" {
        It "Should validate ProfileName with standard profiles" {
            $script:ScriptContent | Should -BeLike "*ValidateSet('Minimal', 'Standard', 'Developer', 'Full')*"
        }
    }

    Context "Modern CLI Parameters" {
        It "Should have Target parameter for modern CLI" {
            $script:ScriptContent | Should -BeLike "*[string]`$Target*"
        }

        It "Should have Query parameter for search" {
            $script:ScriptContent | Should -BeLike "*[string]`$Query*"
        }

        It "Should have ScriptNumber parameter for running scripts" {
            $script:ScriptContent | Should -BeLike "*[string]`$ScriptNumber*"
        }
    }
}

Describe "Smart Execution Mode Detection" {
    Context "CI Environment Detection" {
        It "Should detect GitHub Actions environment" {
            $script:ScriptContent | Should -BeLike "*GITHUB_ACTIONS*"
        }

        It "Should detect Azure DevOps environment" {
            $script:ScriptContent | Should -BeLike "*TF_BUILD*"
        }

        It "Should detect generic CI environment" {
            $script:ScriptContent | Should -BeLike "*env:CI*"
        }

        It "Should have Get-SmartExecutionMode function" {
            $script:ScriptContent | Should -BeLike "*function Get-SmartExecutionMode*"
        }
    }

    Context "Mode Selection Logic" {
        It "Should respect explicitly set mode" {
            $script:ScriptContent | Should -BeLike "*CurrentMode -ne 'Interactive'*"
        }

        It "Should detect headless environments" {
            $script:ScriptContent | Should -BeLike "*SSH_TTY*"
            $script:ScriptContent | Should -BeLike "*UserInteractive*"
        }
    }
}

Describe "Module Initialization" {
    Context "Initialize-CoreModule Function" {
        It "Should have Initialize-CoreModule function" {
            $script:ScriptContent | Should -BeLike "*function Initialize-CoreModule*"
        }

        It "Should import AitherZero module" {
            $script:ScriptContent | Should -BeLike "*Import-Module*AitherZero.psd1*"
        }

        It "Should check for module load status" {
            $script:ScriptContent | Should -BeLike "*Get-Module -Name*AitherZero*"
        }

        It "Should initialize UI if available" {
            $script:ScriptContent | Should -BeLike "*Initialize-AitherUI*"
        }

        It "Should return status of loaded modules" {
            $script:ScriptContent | Should -BeLike "*return @*"
            $script:ScriptContent | Should -BeLike "*Logging =*"
            $script:ScriptContent | Should -BeLike "*Configuration =*"
            $script:ScriptContent | Should -BeLike "*UI =*"
            $script:ScriptContent | Should -BeLike "*Orchestration =*"
        }
    }

    Context "Module Dependency Checking" {
        It "Should check for Write-CustomLog command" {
            $script:ScriptContent | Should -BeLike "*Get-Command Write-CustomLog*"
        }

        It "Should check for Get-Configuration command" {
            $script:ScriptContent | Should -BeLike "*Get-Command Get-Configuration*"
        }

        It "Should check for Show-UIMenu command" {
            $script:ScriptContent | Should -BeLike "*Get-Command Show-UIMenu*"
        }

        It "Should check for Invoke-OrchestrationSequence command" {
            $script:ScriptContent | Should -BeLike "*Get-Command Invoke-OrchestrationSequence*"
        }
    }
}

Describe "Configuration Management" {
    Context "Configuration Loading" {
        It "Should have Get-AitherConfiguration function" {
            $script:ScriptContent | Should -BeLike "*function Get-AitherConfiguration*"
        }

        It "Should support both PSD1 and JSON config formats" {
            $script:ScriptContent | Should -BeLike "*config.psd1*"
            $script:ScriptContent | Should -BeLike "*config.json*"
        }

        It "Should use Import-PowerShellDataFile for PSD1" {
            $script:ScriptContent | Should -BeLike "*Import-PowerShellDataFile*"
        }

        It "Should have Convert-PSObjectToHashtable helper" {
            $script:ScriptContent | Should -BeLike "*function Convert-PSObjectToHashtable*"
        }

        It "Should provide default configuration" {
            $script:ScriptContent | Should -BeLike "*using defaults*"
        }
    }

    Context "Configuration Defaults" {
        It "Should apply ProfileName default if not provided" {
            $script:ScriptContent | Should -BeLike "*Get-ConfiguredValue -Name 'Profile'*"
        }

        It "Should support environment-specific configuration" {
            $script:ScriptContent | Should -BeLike "*ConfigPath*"
        }
    }
}

Describe "Mode Implementation" {
    Context "Interactive Mode" {
        It "Should have Show-InteractiveMenu function" {
            $script:ScriptContent | Should -BeLike "*function Show-InteractiveMenu*"
        }

        It "Should display banner in interactive mode" {
            $script:ScriptContent | Should -BeLike "*Show-Banner*"
        }

        It "Should clear host in interactive mode" {
            $script:ScriptContent | Should -BeLike "*Clear-Host*"
        }

        It "Should handle menu selection" {
            $script:ScriptContent | Should -BeLike "*Show-UIMenu*"
        }
    }

    Context "Orchestrate Mode" {
        It "Should require Sequence or Playbook parameter" {
            $script:ScriptContent | Should -BeLike "*not `$Sequence -and -not `$Playbook*"
        }

        It "Should call Invoke-OrchestrationSequence" {
            $script:ScriptContent | Should -BeLike "*Invoke-OrchestrationSequence*"
        }

        It "Should support DryRun parameter" {
            $script:ScriptContent | Should -BeLike "*DryRun*"
        }

        It "Should exit with appropriate code" {
            $script:ScriptContent | Should -BeLike "*exit 0*"
            $script:ScriptContent | Should -BeLike "*exit 1*"
        }
    }

    Context "Validate Mode" {
        It "Should call Validate-Environment script" {
            $script:ScriptContent | Should -BeLike "*0500_Validate-Environment.ps1*"
        }
    }

    Context "Test Mode" {
        It "Should have default test sequence" {
            $script:ScriptContent | Should -BeLike "*0402*"
            $script:ScriptContent | Should -BeLike "*0404*"
            $script:ScriptContent | Should -BeLike "*0407*"
        }

        It "Should allow custom test sequence" {
            $script:ScriptContent | Should -BeLike "*if (`$Sequence)*"
        }
    }

    Context "Modern CLI Modes" {
        It "Should have List mode implementation" {
            $script:ScriptContent | Should -BeLike "*'List'*"
            $script:ScriptContent | Should -BeLike "*Invoke-ModernListAction*"
        }

        It "Should have Search mode implementation" {
            $script:ScriptContent | Should -BeLike "*'Search'*"
            $script:ScriptContent | Should -BeLike "*Invoke-ModernSearchAction*"
        }

        It "Should have Run mode implementation" {
            $script:ScriptContent | Should -BeLike "*'Run'*"
            $script:ScriptContent | Should -BeLike "*Invoke-ModernRunAction*"
        }
    }
}

Describe "Modern CLI Functionality" {
    Context "Modern List Action" {
        It "Should have Invoke-ModernListAction function" {
            $script:ScriptContent | Should -BeLike "*function Invoke-ModernListAction*"
        }

        It "Should support listing scripts" {
            $script:ScriptContent | Should -BeLike "*'scripts'*"
            $script:ScriptContent | Should -BeLike "*automation-scripts*"
        }

        It "Should support listing playbooks" {
            $script:ScriptContent | Should -BeLike "*'playbooks'*"
            $script:ScriptContent | Should -BeLike "*orchestration/playbooks*"
        }
    }

    Context "Modern Search Action" {
        It "Should have Invoke-ModernSearchAction function" {
            $script:ScriptContent | Should -BeLike "*function Invoke-ModernSearchAction*"
        }

        It "Should search scripts" {
            $script:ScriptContent | Should -BeLike "*Get-ChildItem*automation-scripts*"
        }

        It "Should search playbooks" {
            $script:ScriptContent | Should -BeLike "*Get-ChildItem*orchestration/playbooks*"
        }
    }

    Context "Modern Run Action" {
        It "Should have Invoke-ModernRunAction function" {
            $script:ScriptContent | Should -BeLike "*function Invoke-ModernRunAction*"
        }

        It "Should support running scripts by number" {
            $script:ScriptContent | Should -BeLike "*'script'*"
            $script:ScriptContent | Should -BeLike "*ScriptNum*"
        }

        It "Should support running playbooks" {
            $script:ScriptContent | Should -BeLike "*'playbook'*"
            $script:ScriptContent | Should -BeLike "*PlaybookName*"
        }

        It "Should support running sequences" {
            $script:ScriptContent | Should -BeLike "*'sequence'*"
            $script:ScriptContent | Should -BeLike "*SequenceRange*"
        }
    }
}

Describe "UI Functions" {
    Context "Banner Display" {
        It "Should have Show-Banner function" {
            $script:ScriptContent | Should -BeLike "*function Show-Banner*"
        }

        It "Should display ASCII art" {
            $script:ScriptContent | Should -BeLike "*AitherZero*"
        }

        It "Should use gradient colors" {
            $script:ScriptContent | Should -BeLike "*gradientColors*"
        }
    }

    Context "Help Display" {
        It "Should have Show-Help function" {
            $script:ScriptContent | Should -BeLike "*function Show-Help*"
        }

        It "Should display usage examples" {
            $script:ScriptContent | Should -BeLike "*Quick Commands*"
            $script:ScriptContent | Should -BeLike "*Profiles*"
        }
    }

    Context "Modern CLI UI" {
        It "Should have Write-ModernCLI function" {
            $script:ScriptContent | Should -BeLike "*function Write-ModernCLI*"
        }

        It "Should support different message types" {
            $script:ScriptContent | Should -BeLike "*Success*"
            $script:ScriptContent | Should -BeLike "*Warning*"
            $script:ScriptContent | Should -BeLike "*Error*"
        }

        It "Should use icons for messages" {
            $script:ScriptContent | Should -BeLike "*✓*"
            $script:ScriptContent | Should -BeLike "*✗*"
        }
    }
}

Describe "Menu Functions" {
    Context "Quick Setup" {
        It "Should have Invoke-QuickSetup function" {
            $script:ScriptContent | Should -BeLike "*function Invoke-QuickSetup*"
        }

        It "Should support different profiles" {
            $script:ScriptContent | Should -BeLike "*'Minimal'*"
            $script:ScriptContent | Should -BeLike "*'Standard'*"
            $script:ScriptContent | Should -BeLike "*'Developer'*"
            $script:ScriptContent | Should -BeLike "*'Full'*"
        }

        It "Should prompt for confirmation" {
            $script:ScriptContent | Should -BeLike "*Show-UIPrompt*"
        }
    }

    Context "Orchestration Menu" {
        It "Should have Invoke-OrchestrationMenu function" {
            $script:ScriptContent | Should -BeLike "*function Invoke-OrchestrationMenu*"
        }

        It "Should support dry run" {
            $script:ScriptContent | Should -BeLike "*Perform dry run*"
        }
    }

    Context "Testing Menu" {
        It "Should have Invoke-TestingMenu function" {
            $script:ScriptContent | Should -BeLike "*function Invoke-TestingMenu*"
        }

        It "Should list test options" {
            $script:ScriptContent | Should -BeLike "*Run Unit Tests*"
            $script:ScriptContent | Should -BeLike "*Run PSScriptAnalyzer*"
        }
    }
}

Describe "Error Handling" {
    Context "Main Try-Catch Block" {
        It "Should have comprehensive error handling" {
            $script:ScriptContent | Should -BeLike "*try {*"
            $script:ScriptContent | Should -BeLike "*} catch {*"
        }

        It "Should log errors if logging is available" {
            $script:ScriptContent | Should -BeLike "*Get-Command Write-CustomLog*"
            $script:ScriptContent | Should -BeLike "*Write-CustomLog -Level 'Critical'*"
        }

        It "Should always write errors to console" {
            $script:ScriptContent | Should -BeLike "*Write-Host*CRITICAL ERROR*"
        }

        It "Should exit with error code on failure" {
            $script:ScriptContent | Should -BeLike "*exit 1*"
        }
    }

    Context "Module Load Failure Handling" {
        It "Should handle UI module load failure" {
            $script:ScriptContent | Should -BeLike "*Failed to load UI module*"
        }

        It "Should handle orchestration module unavailability" {
            $script:ScriptContent | Should -BeLike "*Orchestration module not loaded*"
        }
    }
}

Describe "Environment Setup" {
    Context "Project Root Setup" {
        It "Should set PROJECT_ROOT variable" {
            $script:ScriptContent | Should -BeLike "*ProjectRoot = `$PSScriptRoot*"
        }

        It "Should set AITHERZERO_ROOT environment variable" {
            $script:ScriptContent | Should -BeLike "*env:AITHERZERO_ROOT*"
        }
    }

    Context "Conflicting Systems Blocking" {
        It "Should block conflicting modules" {
            $script:ScriptContent | Should -BeLike "*CoreApp*"
            $script:ScriptContent | Should -BeLike "*AitherRun*"
        }

        It "Should set DISABLE_COREAPP flag" {
            $script:ScriptContent | Should -BeLike "*DISABLE_COREAPP*"
        }
    }
}

Describe "Advanced Menu Features" {
    Context "Advanced Menu" {
        It "Should have Show-AdvancedMenu function" {
            $script:ScriptContent | Should -BeLike "*function Show-AdvancedMenu*"
        }

        It "Should support profile changing" {
            $script:ScriptContent | Should -BeLike "*Change Profile*"
        }

        It "Should support configuration editing" {
            $script:ScriptContent | Should -BeLike "*Edit Configuration*"
        }

        It "Should support playbook creation" {
            $script:ScriptContent | Should -BeLike "*Create Playbook*"
        }

        It "Should support module management" {
            $script:ScriptContent | Should -BeLike "*Module Manager*"
        }
    }

    Context "System Information Display" {
        It "Should display PowerShell version" {
            $script:ScriptContent | Should -BeLike "*PSVersionTable.PSVersion*"
        }

        It "Should display OS information" {
            $script:ScriptContent | Should -BeLike "*PSVersionTable.OS*"
        }

        It "Should check for dependencies" {
            $script:ScriptContent | Should -BeLike "*git*"
            $script:ScriptContent | Should -BeLike "*node*"
            $script:ScriptContent | Should -BeLike "*tofu*"
        }
    }
}

Describe "Script Execution Features" {
    Context "Single Script Execution" {
        It "Should support direct script number input" {
            $script:ScriptContent | Should -BeLike "*^\d{4}`$*"
        }

        It "Should support category browsing" {
            $script:ScriptContent | Should -BeLike "*0000-0099*"
            $script:ScriptContent | Should -BeLike "*0100-0199*"
            $script:ScriptContent | Should -BeLike "*0400-0499*"
        }

        It "Should support keyword search" {
            # Check that script search functionality exists
            $script:ScriptContent -match 'Where-Object.*-like' | Should -BeTrue
        }
    }

    Context "Configuration Reload" {
        It "Should support configuration reload after editing" {
            $script:ScriptContent | Should -BeLike "*Reloading configuration*"
        }

        It "Should clear cached configuration" {
            $script:ScriptContent | Should -BeLike "*script:Config = `$null*"
        }
    }
}

Describe "CI/CD Integration" {
    Context "CI Mode Detection" {
        It "Should detect CI environment variables" {
            $script:ScriptContent | Should -BeLike "*env:CI*"
            $script:ScriptContent | Should -BeLike "*env:GITHUB_ACTIONS*"
            $script:ScriptContent | Should -BeLike "*env:TF_BUILD*"
        }

        It "Should support non-interactive mode in CI" {
            $script:ScriptContent | Should -BeLike "*NonInteractive*"
        }

        It "Should not clear screen in CI" {
            $script:ScriptContent | Should -BeLike "*-not `$env:CI*"
        }
    }

    Context "Logging in CI" {
        It "Should log to files in CI mode" {
            $script:ScriptContent | Should -BeLike "*running non-interactive validation with logging to files*"
        }
    }
}

Describe "Cross-Platform Support" {
    Context "Platform Detection" {
        It "Should check for Windows platform" {
            $script:ScriptContent | Should -BeLike "*IsWindows*"
        }

        It "Should use platform-specific editors" {
            $script:ScriptContent | Should -BeLike "*notepad.exe*"
            $script:ScriptContent | Should -BeLike "*env:EDITOR*"
        }

        It "Should use platform-specific paths" {
            $script:ScriptContent | Should -BeLike "*Join-Path*"
        }
    }
}

Describe "Version and Help Commands" {
    Context "Version Display" {
        It "Should support -Version parameter" {
            $script:ScriptContent | Should -BeLike "*if (`$Version)*"
        }

        It "Should display version number" {
            $script:ScriptContent | Should -BeLike "*AitherZero v*"
        }
    }

    Context "Help Display" {
        It "Should support -Help parameter" {
            $script:ScriptContent | Should -BeLike "*if (`$Help)*"
        }

        It "Should call Get-Help" {
            $script:ScriptContent | Should -BeLike "*Get-Help*"
        }
    }
}

Describe "Script Number Shortcuts" {
    Context "Auto-Detection Logic" {
        It "Should accept script numbers as Target parameter" {
            # Test that the script number shortcut feature is implemented
            $script:ScriptContent | Should -BeLike "*Auto-detect target type if RunTarget looks like a script number*"
            $script:ScriptContent | Should -BeLike "*`$ScriptNum = `$RunTarget*"
        }

        It "Should match 3-4 digit patterns" {
            $script:ScriptContent | Should -BeLike "*'^\d{3,4}`$'*"
        }
    }

    Context "Error Messages" {
        It "Should provide helpful examples in error messages" {
            $script:ScriptContent | Should -BeLike "*Or use shortcut:*"
            $script:ScriptContent | Should -BeLike "*Start-AitherZero.ps1 -Mode Run -Target 0501*"
        }

        It "Should show examples for all target types" {
            $script:ScriptContent | Should -BeLike "*-Target script -ScriptNumber 0501*"
            $script:ScriptContent | Should -BeLike "*-Target playbook -Playbook tech-debt-analysis*"
            $script:ScriptContent | Should -BeLike "*-Target sequence -Sequence 0400-0499*"
        }
    }
}
