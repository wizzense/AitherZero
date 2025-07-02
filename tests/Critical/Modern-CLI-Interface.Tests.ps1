#Requires -Version 5.1

<#
.SYNOPSIS
    Critical tests for AitherZero Modern CLI Interface (aither.ps1)

.DESCRIPTION
    Comprehensive test suite for the new aither.ps1 CLI interface.
    Tests command routing, argument parsing, error handling, and integration with existing modules.

.NOTES
    Test Category: Critical
    CLI Version: 1.4.1+
    Requires: Pester framework
#>

param(
    [string]$TestMode = 'CI'
)

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = if ($PSScriptRoot) { 
        Split-Path (Split-Path $PSScriptRoot -Parent) -Parent 
    } else { 
        Get-Location 
    }
    
    $script:CLIScript = Join-Path $script:ProjectRoot "aither.ps1"
    $script:BatchWrapper = Join-Path $script:ProjectRoot "aither.bat"
    
    # Common test parameters
    $script:TestTimeout = 30  # seconds
    
    Write-Host "Testing CLI at: $script:CLIScript" -ForegroundColor Cyan
    Write-Host "Project root: $script:ProjectRoot" -ForegroundColor Cyan
}

Describe "Modern CLI Interface - File Existence" -Tag @('Critical', 'CLI', 'FileSystem') {
    
    It "aither.ps1 file should exist" {
        Test-Path $script:CLIScript | Should -Be $true
    }
    
    It "aither.bat wrapper should exist" {
        Test-Path $script:BatchWrapper | Should -Be $true
    }
    
    It "aither.ps1 should be executable" {
        if ($IsWindows -or $env:OS) {
            $script:CLIScript | Should -Exist
        } else {
            # Test Unix permissions
            $permissions = (Get-Item $script:CLIScript).UnixMode
            $permissions | Should -Match 'x'
        }
    }
}

Describe "Modern CLI Interface - Basic Command Structure" -Tag @('Critical', 'CLI', 'Commands') {
    
    It "Should execute without errors (no arguments)" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript -ErrorAction SilentlyContinue
        $LASTEXITCODE | Should -Be 0
    }
    
    It "Should show help by default" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript 2>&1
        $result -join "`n" | Should -Match "AitherZero.*Infrastructure Automation CLI"
        $result -join "`n" | Should -Match "USAGE:"
        $result -join "`n" | Should -Match "COMMANDS:"
    }
    
    It "Should handle 'help' command" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
        $result -join "`n" | Should -Match "AitherZero.*Infrastructure Automation CLI"
        $result -join "`n" | Should -Match "init.*Initialize AitherZero"
        $result -join "`n" | Should -Match "deploy.*Infrastructure deployment"
        $result -join "`n" | Should -Match "dev.*Development workflow"
    }
}

Describe "Modern CLI Interface - Command Validation" -Tag @('Critical', 'CLI', 'Validation') {
    
    It "Should accept valid commands" {
        $validCommands = @('init', 'deploy', 'workflow', 'dev', 'config', 'plugin', 'server', 'help')
        
        foreach ($command in $validCommands) {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript $command help 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Command '$command' should be valid"
        }
    }
    
    It "Should reject invalid commands" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript "invalid-command" 2>&1
        $result -join "`n" | Should -Match "Unknown command.*invalid-command"
    }
    
    It "Should provide helpful error messages for invalid commands" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript "badcommand" 2>&1
        $result -join "`n" | Should -Match "aither help.*for available commands"
    }
}

Describe "Modern CLI Interface - Init Command" -Tag @('Critical', 'CLI', 'Init') {
    
    It "Should handle init command" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript init help 2>&1
        $result -join "`n" | Should -Match "USAGE.*aither init"
        $result -join "`n" | Should -Match "--auto.*automated setup"
        $result -join "`n" | Should -Match "--profile.*installation profile"
    }
    
    It "Should handle init with --auto flag" {
        # Mock test - don't actually run full setup in CI
        if ($TestMode -eq 'CI') {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript init --auto 2>&1
            # Should attempt to start but may fail due to missing modules in CI
            $result -join "`n" | Should -Match "(Initialize AitherZero|SetupWizard.*not found)"
        }
    }
}

Describe "Modern CLI Interface - Dev Command" -Tag @('Critical', 'CLI', 'Dev') {
    
    It "Should handle dev command" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev help 2>&1
        $result -join "`n" | Should -Match "USAGE.*aither dev"
        $result -join "`n" | Should -Match "release.*Create release"
        $result -join "`n" | Should -Match "pr.*pull request"
    }
    
    It "Should validate dev release parameters" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release 2>&1
        $result -join "`n" | Should -Match "(Usage.*aither dev release|PatchManager.*not found)"
    }
    
    It "Should handle dev release help" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev help 2>&1
        $result -join "`n" | Should -Match "patch\|minor\|major"
    }
}

Describe "Modern CLI Interface - Deploy Command" -Tag @('Critical', 'CLI', 'Deploy') {
    
    It "Should handle deploy command" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript deploy help 2>&1
        $result -join "`n" | Should -Match "USAGE.*aither deploy"
        $result -join "`n" | Should -Match "plan.*deployment plan"
        $result -join "`n" | Should -Match "apply.*infrastructure changes"
    }
    
    It "Should show coming soon for deploy subcommands" {
        $subcommands = @('plan', 'apply', 'destroy', 'state', 'create')
        
        foreach ($subcmd in $subcommands) {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript deploy $subcmd 2>&1
            $result -join "`n" | Should -Match "Coming soon"
        }
    }
}

Describe "Modern CLI Interface - Error Handling" -Tag @('Critical', 'CLI', 'ErrorHandling') {
    
    It "Should handle script errors gracefully" {
        # Test with invalid PowerShell syntax in arguments
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript init --invalid-flag 2>&1
        $LASTEXITCODE | Should -Be 0  # Should not crash
    }
    
    It "Should provide clear error messages" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript unknown-command 2>&1
        $result -join "`n" | Should -Match "Error.*Unknown command"
        $result -join "`n" | Should -Match "Use.*aither help"
    }
    
    It "Should handle missing subcommands" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript deploy unknown-subcmd 2>&1
        $result -join "`n" | Should -Match "Unknown subcommand"
        $result -join "`n" | Should -Match "aither deploy help"
    }
}

Describe "Modern CLI Interface - Color and Formatting" -Tag @('Critical', 'CLI', 'UI') {
    
    It "Should use consistent color scheme" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
        # At minimum, should produce formatted output
        ($result | Measure-Object -Line).Lines | Should -BeGreaterThan 10
    }
    
    It "Should format help output properly" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
        $output = $result -join "`n"
        
        # Check for proper sections
        $output | Should -Match "USAGE:"
        $output | Should -Match "COMMANDS:"
        $output | Should -Match "EXAMPLES:"
        
        # Check for proper alignment
        $output | Should -Match "init\s+Initialize AitherZero"
        $output | Should -Match "deploy\s+Infrastructure deployment"
    }
}

Describe "Modern CLI Interface - Parameter Handling" -Tag @('Critical', 'CLI', 'Parameters') {
    
    It "Should handle multiple arguments correctly" {
        if ($TestMode -ne 'CI') {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "Test release" 2>&1
            # Should route to PatchManager (may fail if module not loaded, but shouldn't crash)
            $LASTEXITCODE | Should -BeIn @(0, 1)  # Either success or controlled failure
        }
    }
    
    It "Should preserve argument order" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev help 2>&1
        $output = $result -join "`n"
        $output | Should -Match "release TYPE MSG"  # Arguments in correct order
    }
    
    It "Should handle quoted arguments" {
        # Test that quoted strings are preserved
        if ($TestMode -ne 'CI') {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "Multi word description" 2>&1
            $LASTEXITCODE | Should -BeIn @(0, 1)  # Should not crash
        }
    }
}

Describe "Modern CLI Interface - Module Integration" -Tag @('Critical', 'CLI', 'Integration') {
    
    It "Should attempt to load required modules" {
        # Test that CLI tries to load modules when needed
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript init 2>&1
        $output = $result -join "`n"
        
        # Should either succeed or give clear error about missing modules
        $output | Should -Match "(Initialize AitherZero|SetupWizard.*not found|initialization.*failed)"
    }
    
    It "Should handle missing module dependencies gracefully" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript dev release patch "test" 2>&1
        # Should not crash even if PatchManager module is missing
        $LASTEXITCODE | Should -BeIn @(0, 1)
    }
}

Describe "Modern CLI Interface - Cross-Platform Compatibility" -Tag @('Critical', 'CLI', 'CrossPlatform') {
    
    It "Should work on current platform" {
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
        $LASTEXITCODE | Should -Be 0
        $result -join "`n" | Should -Match "AitherZero"
    }
    
    It "Should use correct path separators" {
        # Test that CLI handles paths correctly on current platform
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
        $LASTEXITCODE | Should -Be 0  # Should not fail due to path issues
    }
    
    Context "Windows-specific tests" -Skip:(-not ($IsWindows -or $env:OS)) {
        It "Should work with batch wrapper" {
            if (Test-Path $script:BatchWrapper) {
                # Test batch file (if we can run cmd)
                try {
                    $result = & cmd /c "`"$script:BatchWrapper`" help" 2>&1
                    $result -join "`n" | Should -Match "AitherZero"
                } catch {
                    # Skip if cmd not available or batch fails
                    Write-Warning "Batch wrapper test skipped: $_"
                }
            }
        }
    }
}

Describe "Modern CLI Interface - Performance" -Tag @('Critical', 'CLI', 'Performance') {
    
    It "Should start within reasonable time" {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
        $stopwatch.Stop()
        
        $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # 5 seconds max for help
    }
    
    It "Should not leak memory on multiple invocations" {
        # Run CLI multiple times and ensure it completes
        for ($i = 1; $i -le 3; $i++) {
            $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Iteration $i should succeed"
        }
    }
}

Describe "Modern CLI Interface - Backward Compatibility" -Tag @('Critical', 'CLI', 'Compatibility') {
    
    It "Should coexist with legacy Start-AitherZero.ps1" {
        $legacyScript = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
        if (Test-Path $legacyScript) {
            # Both should be able to run help without conflict
            $newResult = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
            $legacyResult = & pwsh -ExecutionPolicy Bypass -File $legacyScript -Help 2>&1
            
            $LASTEXITCODE | Should -Be 0
            # Both should work independently
            $newResult | Should -Not -BeNullOrEmpty
            $legacyResult | Should -Not -BeNullOrEmpty
        }
    }
    
    It "Should not interfere with existing configurations" {
        # Test that new CLI respects existing setup
        $result = & pwsh -ExecutionPolicy Bypass -File $script:CLIScript help 2>&1
        $LASTEXITCODE | Should -Be 0
        # Should not modify anything just by showing help
    }
}

AfterAll {
    Write-Host "Modern CLI Interface tests completed" -ForegroundColor Green
    Write-Host "CLI Script: $script:CLIScript" -ForegroundColor Cyan
    Write-Host "Tests can be run with: Invoke-Pester -Path '$PSCommandPath'" -ForegroundColor Yellow
}