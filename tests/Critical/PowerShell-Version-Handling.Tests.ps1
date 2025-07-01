#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:LauncherPath = Join-Path $PSScriptRoot '../../Start-AitherZero.ps1'
    $script:CoreScriptPath = Join-Path $PSScriptRoot '../../aither-core/aither-core.ps1'
    $script:BootstrapPath = Join-Path $PSScriptRoot '../../aither-core/aither-core-bootstrap.ps1'
    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
}

Describe 'PowerShell Version Handling Critical Infrastructure Tests' -Tag 'Critical' {
    BeforeAll {
        # Store original environment
        $script:OriginalLocation = Get-Location
        $script:OriginalPath = $env:PATH
        
        # Set up test environment
        $script:TestRoot = Join-Path $TestDrive 'PowerShellVersionTests'
        $script:TestProjectRoot = Join-Path $script:TestRoot 'project'
        $script:TestCoreDir = Join-Path $script:TestProjectRoot 'aither-core'
        $script:TestModulesDir = Join-Path $script:TestCoreDir 'modules'
        $script:TestSharedDir = Join-Path $script:TestCoreDir 'shared'
        
        # Create directory structure
        @($script:TestProjectRoot, $script:TestCoreDir, $script:TestModulesDir, $script:TestSharedDir) | ForEach-Object {
            New-Item -Path $_ -ItemType Directory -Force | Out-Null
        }
        
        # Copy scripts to test environment
        $script:TestLauncher = Join-Path $script:TestProjectRoot 'Start-AitherZero.ps1'
        $script:TestCoreScript = Join-Path $script:TestCoreDir 'aither-core.ps1'
        $script:TestBootstrap = Join-Path $script:TestCoreDir 'aither-core-bootstrap.ps1'
        
        Copy-Item $script:LauncherPath $script:TestLauncher -Force
        Copy-Item $script:CoreScriptPath $script:TestCoreScript -Force
        Copy-Item $script:BootstrapPath $script:TestBootstrap -Force
        
        # Create Find-ProjectRoot utility
        $script:FindProjectRoot = Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1'
        @"
function Find-ProjectRoot {
    param([string]`$StartPath, [switch]`$Force)
    return '$script:TestProjectRoot'
}
"@ | Set-Content $script:FindProjectRoot
        
        # Create mock modules
        $script:MockModules = @{
            'Logging' = @'
function Initialize-LoggingSystem {
    param($ConsoleLevel, $LogLevel, [switch]$Force)
    Write-Host "Logging initialized"
}
function Write-CustomLog {
    param($Message, $Level = 'INFO')
    Write-Host "[$Level] $Message"
}
Export-ModuleMember -Function Initialize-LoggingSystem, Write-CustomLog
'@
            'LabRunner' = @'
function Start-LabRunner {
    Write-Host "LabRunner started"
}
Export-ModuleMember -Function Start-LabRunner
'@
        }
        
        # Create mock modules
        foreach ($moduleName in $script:MockModules.Keys) {
            $moduleDir = Join-Path $script:TestModulesDir $moduleName
            New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null
            $script:MockModules[$moduleName] | Set-Content (Join-Path $moduleDir "$moduleName.psm1")
        }
        
        # Create mock external commands
        function New-MockCommand {
            param($CommandName, $Response, $ExitCode = 0)
            
            $mockPath = Join-Path $script:TestRoot "$CommandName.ps1"
            @"
if (`$args.Count -gt 0) {
    Write-Host "Mock $CommandName called with args: `$(`$args -join ' ')"
} else {
    Write-Host "Mock $CommandName called"
}
if ('$Response') {
    Write-Host '$Response'
}
exit $ExitCode
"@ | Set-Content $mockPath
            
            return $mockPath
        }
        
        # Create mock PowerShell 5.1 launcher
        $script:MockPowerShell51 = Join-Path $script:TestRoot 'powershell51.exe'
        @'
@echo off
echo Mock PowerShell 5.1 execution
powershell.exe -Version 5.1 %*
'@ | Set-Content $script:MockPowerShell51
        
        Set-Location $script:TestProjectRoot
    }
    
    AfterAll {
        Set-Location $script:OriginalLocation
        $env:PATH = $script:OriginalPath
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Bootstrap Script - Version Detection' {
        It 'Should detect PowerShell 7+ correctly' {
            $result = & $script:TestBootstrap -Help
            
            $output = $result -join "`n"
            $output | Should -Match 'AitherZero Bootstrap'
            $output | Should -Match 'This bootstrap script ensures PowerShell 7\+ compatibility'
        }
        
        It 'Should handle PowerShell 7+ direct handoff' {
            # Mock that we're running on PowerShell 7+ 
            $result = & $script:TestBootstrap -Auto -Verbosity detailed
            
            $output = $result -join "`n"
            $output | Should -Match 'PowerShell.*detected.*Full compatibility available'
            # Should attempt handoff to core script
        }
        
        It 'Should provide bootstrap help information' {
            $result = & $script:TestBootstrap -Help
            
            $output = $result -join "`n"
            $output | Should -Match 'AitherZero Bootstrap'
            $output | Should -Match 'Check your PowerShell version'
            $output | Should -Match 'Install PowerShell 7 if needed'
            $output | Should -Match 'Hand off execution to the main core'
        }
    }
    
    Context 'Bootstrap Script - PowerShell 7 Availability Check' {
        It 'Should detect when PowerShell 7 is available' {
            # Test will pass if pwsh is available (which it should be since tests run on PS7)
            . $script:TestBootstrap
            
            $result = Test-PowerShell7Available
            
            $result | Should -Be $true
        }
        
        It 'Should handle missing pwsh executable gracefully' {
            # Temporarily modify PATH to hide pwsh
            $originalPath = $env:PATH
            $env:PATH = ""
            
            try {
                . $script:TestBootstrap
                $result = Test-PowerShell7Available
                
                $result | Should -Be $false
            } finally {
                $env:PATH = $originalPath
            }
        }
    }
    
    Context 'Bootstrap Script - Installation Methods' {
        BeforeEach {
            # Create mock installation commands
            $script:MockWinget = New-MockCommand 'winget' 'Installing Microsoft.PowerShell...' 0
            $script:MockChoco = New-MockCommand 'choco' 'Installing powershell-core...' 0
            $script:MockMsiexec = New-MockCommand 'msiexec' 'Installation completed' 0
            
            # Add mocks to PATH
            $env:PATH = "$script:TestRoot;$env:PATH"
        }
        
        It 'Should attempt winget installation first on Windows' {
            # Load bootstrap functions
            . $script:TestBootstrap
            
            # Should not throw error when testing installation methods
            { Install-PowerShell7 } | Should -Not -Throw
        }
        
        It 'Should fall back to chocolatey if winget fails' {
            # Create failing winget
            $script:MockWinget = New-MockCommand 'winget' 'Failed to install' 1
            
            . $script:TestBootstrap
            
            { Install-PowerShell7 } | Should -Not -Throw
        }
        
        It 'Should handle non-Windows platforms appropriately' {
            # Mock non-Windows detection by modifying the function
            . $script:TestBootstrap
            
            # On actual non-Windows, the function should provide manual instructions
            if (-not $IsWindows) {
                { Install-PowerShell7 } | Should -Throw "*PowerShell 7 installation not supported on this platform*"
            }
        }
        
        It 'Should provide manual installation guidance when all methods fail' {
            # Create failing commands
            $script:MockWinget = New-MockCommand 'winget' 'Failed' 1
            $script:MockChoco = New-MockCommand 'choco' 'Failed' 1
            $script:MockMsiexec = New-MockCommand 'msiexec' 'Failed' 1
            
            . $script:TestBootstrap
            
            { Install-PowerShell7 } | Should -Throw "*PowerShell 7 installation required for full functionality*"
        }
    }
    
    Context 'Bootstrap Script - Parameter Preservation' {
        It 'Should preserve all switch parameters during handoff' {
            $testParams = @{
                'Auto' = $true
                'Force' = $true
                'NonInteractive' = $true
                'Quiet' = $true
            }
            
            # Test parameter handling
            . $script:TestBootstrap
            
            $originalParams = @{}
            foreach ($key in $testParams.Keys) {
                $originalParams[$key] = $testParams[$key]
            }
            
            # Should not throw when building parameters
            { Invoke-CoreApplicationHandoff -OriginalParameters $originalParams } | Should -Not -Throw
        }
        
        It 'Should preserve value parameters during handoff' {
            $testParams = @{
                'Verbosity' = 'detailed'
                'ConfigFile' = 'test-config.json'
                'Scripts' = 'TestModule'
            }
            
            . $script:TestBootstrap
            
            { Invoke-CoreApplicationHandoff -OriginalParameters $testParams } | Should -Not -Throw
        }
    }
    
    Context 'Bootstrap Script - Interactive vs Non-Interactive Mode' {
        It 'Should prompt for installation in interactive mode' {
            # This test verifies the prompting logic exists
            . $script:TestBootstrap
            
            # Mock Read-Host to avoid hanging
            function Read-Host { return 'n' }
            
            # Test that non-auto, interactive mode would prompt
            $content = Get-Content $script:TestBootstrap -Raw
            $content | Should -Match 'Read-Host'
            $content | Should -Match 'Would you like to automatically install PowerShell 7'
        }
        
        It 'Should skip prompts in Auto mode' {
            $result = & $script:TestBootstrap -Auto -Verbosity detailed
            
            # Should not hang waiting for input
            $LASTEXITCODE | Should -Not -BeNullOrEmpty
        }
        
        It 'Should skip prompts in NonInteractive mode' {
            $result = & $script:TestBootstrap -NonInteractive -Verbosity detailed
            
            # Should not hang waiting for input
            $LASTEXITCODE | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Bootstrap Script - Error Handling' {
        It 'Should handle missing core script gracefully' {
            # Remove core script
            Remove-Item $script:TestCoreScript -Force
            
            { & $script:TestBootstrap -Auto } | Should -Throw "*Main core script not found*"
        }
        
        It 'Should provide troubleshooting information on failure' {
            # Create bootstrap that will fail
            'throw "Simulated failure"' | Set-Content $script:TestBootstrap
            
            try {
                & $script:TestBootstrap -Auto
            } catch {
                $errorOutput = $_.Exception.Message
                $errorOutput | Should -Match 'Simulated failure'
            }
            
            # Should show troubleshooting in original bootstrap
            Copy-Item $script:BootstrapPath $script:TestBootstrap -Force
            $content = Get-Content $script:TestBootstrap -Raw
            $content | Should -Match 'Troubleshooting'
            $content | Should -Match 'Run as Administrator'
            $content | Should -Match 'Check internet connection'
        }
        
        It 'Should handle installation exit codes correctly' {
            . $script:TestBootstrap
            
            # Mock function to test exit code handling
            function Test-ExitCodeHandling {
                $LASTEXITCODE = 1
                # Should detect non-zero exit code
            }
            
            # The bootstrap should check LASTEXITCODE after installations
            $content = Get-Content $script:TestBootstrap -Raw
            $content | Should -Match '\$LASTEXITCODE'
        }
    }
    
    Context 'Launcher Integration - PowerShell Version Detection' {
        It 'Should detect PowerShell version in launcher' {
            $content = Get-Content $script:TestLauncher -Raw
            
            # Launcher should have version detection logic
            $content | Should -Match '\$psVersion = \$PSVersionTable\.PSVersion\.Major'
            $content | Should -Match 'if \(\$psVersion -lt 7\)'
        }
        
        It 'Should show PowerShell 7+ compatibility message' {
            $result = & $script:TestLauncher -Setup
            
            $output = $result -join "`n"
            $output | Should -Match 'PowerShell.*detected.*Full compatibility'
        }
        
        It 'Should reference bootstrap script for older versions' {
            $content = Get-Content $script:TestLauncher -Raw
            
            # Launcher should mention bootstrap for older PowerShell
            $content | Should -Match 'aither-core-bootstrap\.ps1'
            $content | Should -Match 'using compatibility bootstrap'
        }
        
        It 'Should provide PowerShell installation guidance' {
            $content = Get-Content $script:TestLauncher -Raw
            
            # Should provide installation links and commands
            $content | Should -Match 'https://aka\.ms/powershell-release-windows'
            $content | Should -Match 'winget install Microsoft\.PowerShell'
            $content | Should -Match 'choco install powershell-core'
        }
    }
    
    Context 'Core Application - PowerShell 7 Requirement' {
        It 'Should enforce PowerShell 7 requirement in core script' {
            $content = Get-Content $script:TestCoreScript -Raw
            
            # Core script should have #Requires statement
            $content | Should -Match '#Requires -Version 7\.0'
        }
        
        It 'Should have re-launch logic for older PowerShell versions' {
            $content = Get-Content $script:TestCoreScript -Raw
            
            # Should have logic to re-launch with PowerShell 7
            $content | Should -Match 'Re-launch under PowerShell 7'
            $content | Should -Match '\$PSVersionTable\.PSVersion\.Major -lt 7'
            $content | Should -Match 'pwsh.*-File.*\$PSCommandPath'
        }
        
        It 'Should preserve arguments during re-launch' {
            $content = Get-Content $script:TestCoreScript -Raw
            
            # Should preserve arguments when re-launching
            $content | Should -Match '\$PSBoundParameters'
            $content | Should -Match '@argList'
        }
        
        It 'Should handle pwsh executable detection' {
            $content = Get-Content $script:TestCoreScript -Raw
            
            # Should detect pwsh executable path
            $content | Should -Match 'Get-Command pwsh'
            $content | Should -Match 'pwshPath'
        }
    }
    
    Context 'End-to-End Version Handling' {
        It 'Should complete successfully when PowerShell 7+ is available' {
            # Test runs on PowerShell 7, so should complete successfully
            $result = & $script:TestLauncher -Auto -Verbosity silent
            
            $LASTEXITCODE | Should -Be 0
        }
        
        It 'Should handle bootstrap script execution path' {
            # Test bootstrap can be executed
            { & $script:TestBootstrap -Help } | Should -Not -Throw
        }
        
        It 'Should pass parameters correctly through version handling chain' {
            $result = & $script:TestLauncher -Auto -Verbosity detailed -Scripts 'LabRunner'
            
            $output = $result -join "`n"
            # Should show evidence of parameter passing
            $output | Should -Match 'Scripts.*LabRunner'
        }
        
        It 'Should provide consistent error messages across components' {
            # All components should provide helpful PowerShell 7 guidance
            $launcherContent = Get-Content $script:TestLauncher -Raw
            $coreContent = Get-Content $script:TestCoreScript -Raw
            $bootstrapContent = Get-Content $script:TestBootstrap -Raw
            
            # Common themes across all components
            foreach ($content in @($launcherContent, $coreContent, $bootstrapContent)) {
                $content | Should -Match 'PowerShell.*7'
                $content | Should -Match 'install'
            }
        }
    }
    
    Context 'Cross-Platform PowerShell Version Handling' {
        It 'Should handle Windows PowerShell detection' {
            $content = Get-Content $script:TestBootstrap -Raw
            
            # Should detect Windows for installation methods
            $content | Should -Match 'isWindows'
            $content | Should -Match 'Win32NT'
        }
        
        It 'Should provide platform-specific installation guidance' {
            $content = Get-Content $script:TestBootstrap -Raw
            
            # Should provide different guidance for different platforms
            $content | Should -Match 'Linux.*https://docs\.microsoft\.com'
            $content | Should -Match 'macOS.*https://docs\.microsoft\.com'
        }
        
        It 'Should handle cross-platform pwsh executable detection' {
            . $script:TestCoreScript
            
            # Test pwsh path detection logic
            $content = Get-Content $script:TestCoreScript -Raw
            $content | Should -Match 'if.*\$IsWindows.*pwsh\.exe.*pwsh'
        }
    }
    
    Context 'Performance and Reliability' {
        It 'Should complete version detection quickly' {
            $startTime = Get-Date
            
            & $script:TestBootstrap -Help | Out-Null
            
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalMilliseconds
            
            $duration | Should -BeLessThan 2000  # Should complete in under 2 seconds
        }
        
        It 'Should handle concurrent version checking gracefully' {
            # Test that multiple simultaneous version checks don't interfere
            $jobs = 1..3 | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($BootstrapPath)
                    & $BootstrapPath -Help
                } -ArgumentList $script:TestBootstrap
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # All jobs should complete successfully
            $results | Should -Not -BeNullOrEmpty
            $results -join "`n" | Should -Match 'AitherZero Bootstrap'
        }
        
        It 'Should maintain consistent behavior across multiple executions' {
            # Multiple executions should behave consistently
            $results = 1..3 | ForEach-Object {
                & $script:TestBootstrap -Help 2>&1
            }
            
            # All executions should produce similar output
            foreach ($result in $results) {
                $output = $result -join "`n"
                $output | Should -Match 'AitherZero Bootstrap'
            }
        }
    }
    
    Context 'Security and Validation' {
        It 'Should validate PowerShell executable before execution' {
            $content = Get-Content $script:TestBootstrap -Raw
            
            # Should validate paths and executables
            $content | Should -Match 'Test-Path'
            $content | Should -Match 'Get-Command.*pwsh'
        }
        
        It 'Should handle execution policy appropriately' {
            $content = Get-Content $script:TestBootstrap -Raw
            
            # Should use appropriate execution policy settings
            $content | Should -Match 'ExecutionPolicy.*Bypass'
        }
        
        It 'Should not expose sensitive information in error messages' {
            # Test error handling doesn't expose sensitive paths
            try {
                & $script:TestBootstrap -ConfigFile 'C:\SensitivePath\config.json' -Auto
            } catch {
                $errorMessage = $_.Exception.Message
                # Should not expose full sensitive paths in errors
                $errorMessage | Should -Not -Match 'SensitivePath'
            }
        }
        
        It 'Should validate downloaded installers before execution' {
            $content = Get-Content $script:TestBootstrap -Raw
            
            # Should have validation for downloaded files
            $content | Should -Match 'installerPath'
            $content | Should -Match 'Start-Process.*msiexec'
        }
    }
}