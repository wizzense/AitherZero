# Launcher Integration Tests
# These tests validate that the launcher scripts work properly and catch basic failures

BeforeAll {
    $ProjectRoot = $PSScriptRoot -replace 'tests[/\\]integration.*', ''
    $script:TestTempDir = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-LauncherTests-$(Get-Date -Format 'yyyyMMddHHmmss')"

    # Create test environment
    if (-not (Test-Path $script:TestTempDir)) {
        New-Item -Path $script:TestTempDir -ItemType Directory -Force | Out-Null
    }

    # Copy essential files for launcher testing
    $essentialFiles = @(
        'aither-core/aither-core.ps1',
        'templates/launchers/Start-AitherZero.ps1',
        'templates/launchers/AitherZero.bat'
    )

    foreach ($file in $essentialFiles) {
        $sourcePath = Join-Path $ProjectRoot $file
        $destPath = Join-Path $script:TestTempDir (Split-Path $file -Leaf)

        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Write-Host "Copied test file: $file" -ForegroundColor Yellow
        } else {
            Write-Warning "Test file not found: $sourcePath"
        }
    }

    # Create minimal modules directory for testing
    $testModulesDir = Join-Path $script:TestTempDir "modules"
    if (-not (Test-Path $testModulesDir)) {
        New-Item -Path $testModulesDir -ItemType Directory -Force | Out-Null
    }

    # Copy Logging module for basic functionality
    $loggingModulePath = Join-Path $ProjectRoot "$env:PWSH_MODULES_PATH/Logging"
    if (Test-Path $loggingModulePath) {
        Copy-Item -Path $loggingModulePath -Destination $testModulesDir -Recurse -Force
    }
}

AfterAll {
    # Clean up test directory
    if (Test-Path $script:TestTempDir) {
        Remove-Item -Path $script:TestTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Launcher Integration Tests" {

    Context "PowerShell Launcher (Start-AitherZero.ps1)" {

        It "Should exist and be readable" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"
            $launcherPath | Should -Exist
            { Get-Content $launcherPath -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should have valid PowerShell syntax" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $launcherPath -Raw), [ref]$errors)
            $errors | Should -BeNullOrEmpty
        }

        It "Should contain proper path resolution logic" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"
            $content = Get-Content $launcherPath -Raw

            # Should use Join-Path for cross-platform compatibility
            $content | Should -Match "Join-Path"

            # Should handle multiple path scenarios
            $content | Should -Match "aither-core/aither-core\.ps1"
            # Validate updated path resolution logic
            $content | Should -Match "Join-Path.*aither-core"
        }

        It "Should handle Help parameter without crashing" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"
            $result = & pwsh -File $launcherPath -Help -ErrorAction SilentlyContinue 2>&1
            $LASTEXITCODE | Should -Be 0
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle Setup parameter without crashing" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"
            $result = & pwsh -File $launcherPath -Setup -ErrorAction SilentlyContinue 2>&1
            $LASTEXITCODE | Should -Be 0
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should fail gracefully when core script is missing" {
            # Temporarily rename the core script
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"
            $corePath = Join-Path $script:TestTempDir "aither-core.ps1"
            $coreBackup = "$corePath.backup"

            if (Test-Path $corePath) {
                Move-Item $corePath $coreBackup -Force
            }

            try {
                # This should fail but not crash
                $result = & pwsh -File $launcherPath -ErrorAction SilentlyContinue 2>&1
                $LASTEXITCODE | Should -Not -Be 0
                $result | Should -Match "not found"
            } finally {
                # Restore the core script
                if (Test-Path $coreBackup) {
                    Move-Item $coreBackup $corePath -Force
                }
            }
        }
    }

    Context "Windows Batch Launcher (AitherZero.bat)" -Skip:(-not $IsWindows) {

        It "Should exist and be readable" {
            $batchPath = Join-Path $script:TestTempDir "AitherZero.bat"
            $batchPath | Should -Exist
            { Get-Content $batchPath -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should have valid batch syntax (no nested if-else)" {
            $batchPath = Join-Path $script:TestTempDir "AitherZero.bat"
            $content = Get-Content $batchPath -Raw

            # Should not contain problematic nested if-else structures
            $content | Should -Not -Match "if.*else.*if.*else"

            # Should use goto for flow control instead of nested if-else
            $content | Should -Match "goto.*:.*HandleExitCode"
        }

        It "Should detect PowerShell properly" {
            $batchPath = Join-Path $script:TestTempDir "AitherZero.bat"
            $content = Get-Content $batchPath -Raw

            # Should check for pwsh first, then powershell
            $content | Should -Match "where pwsh"
            $content | Should -Match "where powershell"
        }

        It "Should execute without syntax errors" {
            $batchPath = Join-Path $script:TestTempDir "AitherZero.bat"

            # Run the batch file and capture output
            # Use timeout to prevent hanging
            $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$batchPath`" -Help" -WorkingDirectory $script:TestTempDir -PassThru -WindowStyle Hidden -RedirectStandardOutput "$script:TestTempDir\batch_output.txt" -RedirectStandardError "$script:TestTempDir\batch_error.txt"

            # Wait with timeout
            $finished = $process.WaitForExit(10000) # 10 second timeout

            if (-not $finished) {
                $process.Kill()
                $process.WaitForExit()
                throw "Batch script timed out - likely hanging due to syntax error"
            }

            # Check for syntax errors in stderr
            $errorOutput = Get-Content "$script:TestTempDir\batch_error.txt" -Raw -ErrorAction SilentlyContinue
            $errorOutput | Should -Not -Match "was unexpected at this time"
            $errorOutput | Should -Not -Match "syntax error"

            # Exit code should not indicate syntax error (code 1 is usually syntax error)
            $process.ExitCode | Should -Not -Be 1
        }
    }

    Context "Core Script Integration" {

        It "Should be able to find and execute core script" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"
            $corePath = Join-Path $script:TestTempDir "aither-core.ps1"

            # Ensure core script exists
            $corePath | Should -Exist

            # Test that launcher can find core script (even if execution fails due to missing dependencies)
            $result = & pwsh -File $launcherPath -WhatIf -ErrorAction SilentlyContinue 2>&1

            # Should not fail with "file not found" error
            $result | Should -Not -Match "Core application file not found"
        }
    }

    Context "Cross-Platform Path Handling" {

        It "Should use forward slashes for cross-platform compatibility" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"
            $content = Get-Content $launcherPath -Raw

            # Should use forward slashes in paths for cross-platform compatibility
            $content | Should -Match "aither-core/aither-core\.ps1"

            # Should use Join-Path for proper path construction
            $content | Should -Match "Join-Path"
        }

        It "Should work with different working directories" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"

            # Test from a different directory to ensure path resolution works
            $originalLocation = Get-Location
            try {
                Set-Location ([System.IO.Path]::GetTempPath())

                # Execute launcher from different directory
                $result = & pwsh -File $launcherPath -Help -ErrorAction SilentlyContinue 2>&1

                # Should work regardless of current directory
                $LASTEXITCODE | Should -Be 0

            } finally {
                Set-Location $originalLocation
            }
        }
    }
}

Describe "Launcher Error Handling" {

    Context "Missing Dependencies" {

        It "Should provide helpful error messages when core dependencies are missing" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"

            # Remove modules directory to simulate missing dependencies
            $modulesPath = Join-Path $script:TestTempDir "modules"
            if (Test-Path $modulesPath) {
                Remove-Item $modulesPath -Recurse -Force
            }

            $result = & pwsh -File $launcherPath -ErrorAction SilentlyContinue 2>&1

            # Should provide helpful guidance, not just crash
            $result | Should -Match "(help|troubleshoot|setup|requirements)"
        }
    }

    Context "Parameter Validation" {

        It "Should handle invalid parameters gracefully" {
            $launcherPath = Join-Path $script:TestTempDir "Start-AitherZero.ps1"

            # Test with invalid verbosity level
            $result = & pwsh -File $launcherPath -Verbosity "invalid" -ErrorAction SilentlyContinue 2>&1

            # Should not crash with PowerShell error, should handle validation
            $result | Should -Not -Match "Cannot validate argument"
        }
    }
}

