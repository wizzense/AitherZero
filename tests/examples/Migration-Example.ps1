<#
.SYNOPSIS
Example showing how to migrate from old test style to new framework

.DESCRIPTION
This file demonstrates the before and after of migrating a test to use
the new extensible testing framework.
#>

# ==============================================================================
# BEFORE: Manual test with lots of boilerplate
# ==============================================================================

<#
# Old style test (commented out)
. (Join-Path $PSScriptRoot '..' 'TestDriveCleanup.ps1')
. (Join-Path $PSScriptRoot '..' 'helpers' 'TestHelpers.ps1')

Describe '0007_Install-Go' {
    InModuleScope LabRunner {
        BeforeAll { 
            Enable-WindowsMocks
            $script:ScriptPath = Get-RunnerScriptPath '0007_Install-Go.ps1'
            if (-not $script:ScriptPath -or -not (Test-Path $script:ScriptPath)) {
                throw "Script under test not found: 0007_Install-Go.ps1 (resolved path: $script:ScriptPath)"
            }
        }

        It 'installs Go when enabled' {
            $cfg = pscustomobject@{ 
                InstallGo = $true
                Go = @{ InstallerUrl = 'http://example.com/go1.21.0.windows-amd64.msi' }
            }
            Mock Get-Command {} -ParameterFilter { $Name -eq 'go' }
            Mock Start-Process {}
            Mock Invoke-LabDownload { 
                if ($Action) { & $Action 'test-installer.msi' }
            }
            
            & $script:ScriptPath -Config $cfg
            Should -Invoke -CommandName Invoke-LabDownload -Times 1
            Should -Invoke -CommandName Start-Process -Times 1 -ParameterFilter { $FilePath -eq 'msiexec.exe' }
        }

        It 'skips when InstallGo is false' {
            $cfg = pscustomobject@{ 
                InstallGo = $false
                Go = @{ InstallerUrl = 'http://example.com/go1.21.0.windows-amd64.msi' }
            }
            Mock Invoke-LabDownload {}
            Mock Start-Process {}
            
            & $script:ScriptPath -Config $cfg
            Should -Invoke -CommandName Invoke-LabDownload -Times 0
            Should -Invoke -CommandName Start-Process -Times 0
        }

        It 'does nothing when Go is already installed' {
            $cfg = pscustomobject@{ 
                InstallGo = $true
                Go = @{ InstallerUrl = 'http://example.com/go1.21.0.windows-amd64.msi' }
            }
            Mock Get-Command { PSCustomObject@{ Name = 'go'; Source = 'C:\Go\bin\go.exe' } } -ParameterFilter { $Name -eq 'go' }
            Mock Invoke-LabDownload {}
            Mock Start-Process {}
            
            & $script:ScriptPath -Config $cfg
            Should -Invoke -CommandName Invoke-LabDownload -Times 0
            Should -Invoke -CommandName Start-Process -Times 0
        }
    }
    
    AfterAll {
        Get-Module LabRunner  Remove-Module -Force -ErrorAction SilentlyContinue
    }
}
#>

# ==============================================================================
# AFTER: New framework with template - much simpler!
# ==============================================================================

. (Join-Path $PSScriptRoot '..' 'TestDriveCleanup.ps1')
. (Join-Path $PSScriptRoot '..' 'helpers' 'TestHelpers.ps1')
. (Join-Path $PSScriptRoot '..' 'helpers' 'TestTemplates.ps1')

# This single line replaces all the boilerplate above and provides:
# - Standard syntax validation
# - Config parameter checking
# - Module import validation
# - Invoke-LabStep validation
# - Enabled/disabled scenarios
# - Already installed scenario
# - Cross-platform mocking
# - Automatic platform detection

New-InstallerScriptTest -ScriptName '0007_Install-Go.ps1' -EnabledProperty 'InstallGo' -InstallerCommand 'Start-Process' -EnabledConfig @{
    Go = @{ 
        InstallerUrl = 'http://example.com/go1.21.0.windows-amd64.msi' 
    }
} -RequiredPlatforms @('Windows') -AdditionalMocks @{
    # Override the default Get-Command mock for Go-specific behavior
    'Get-Command' = { 
        param($Name)
        if ($Name -eq 'go') { 
            return $null  # Simulate Go not installed
        } 
        return PSCustomObject@{ Name = $Name; Source = "/usr/bin/$Name" }
    }
}

# ==============================================================================
# Benefits of the new approach:
# ==============================================================================

<#
1. REDUCED CODE: ~80% less code for the same functionality
2. STANDARDIZED: Consistent patterns across all tests
3. EXTENSIBLE: Easy to add new scenarios
4. CROSS-PLATFORM: Automatic platform handling
5. MAINTAINABLE: Changes to framework benefit all tests
6. DISCOVERABLE: Tests are automatically categorized
7. REPORTABLE: Built-in reporting and metrics

Key improvements:
- No more BeforeAll/AfterAll boilerplate
- No more manual mock setup for common scenarios
- No more InModuleScope complexity
- No more repetitive It blocks for standard scenarios
- Automatic platform detection and skipping
- Built-in best practices and error handling
#>

# ==============================================================================
# Advanced usage - when you need custom scenarios beyond the template:
# ==============================================================================

<#
# You can still add custom scenarios when needed:
$customScenarios = @()

$customScenarios += New-TestScenario -Name 'Download failure handling' -Description 'handles download failures gracefully' -Config @{
    InstallGo = $true
    Go = @{ InstallerUrl = 'http://invalid-url.com/go.msi' }
} -Mocks @{
    'Invoke-LabDownload' = { throw 'Download failed' }
} -ShouldThrow $true -ExpectedError 'Download failed'

$customScenarios += New-TestScenario -Name 'Custom installer path' -Description 'supports custom installer paths' -Config @{
    InstallGo = $true
    Go = @{ 
        InstallerUrl = 'http://example.com/go.msi'
        CustomInstallPath = 'C:\CustomGo'
    }
} -Mocks @{
    'Start-Process' = {}
    'Invoke-LabDownload' = { if ($Action) { & $Action 'test-installer.msi' } }
} -ExpectedInvocations @{
    'Start-Process' = 1
} -CustomValidation {
    param($Result, $Error)
    # Verify custom path was used
    Should -Invoke -CommandName Start-Process -ParameterFilter { 
        $ArgumentList -contains 'INSTALLDIR=C:\CustomGo' 
    }
}

# Add the custom scenarios to the standard test
Test
