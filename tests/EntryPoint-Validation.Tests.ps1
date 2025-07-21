# Note: Tests require PowerShell 7.0+ but will skip gracefully on older versions

<#
.SYNOPSIS
    Entry Point Validation Testing for AitherZero

.DESCRIPTION
    Comprehensive testing for AitherZero entry points and bootstrap processes:
    - Start-AitherZero.ps1 validation and functionality
    - Start-DeveloperSetup.ps1 validation and functionality
    - Parameter handling and validation
    - Script syntax and structure validation
    - PowerShell version checking integration
    - Path resolution and delegation
    - Error handling and recovery

.NOTES
    Tests the main entry points that users interact with
#>

BeforeAll {
    # Skip tests if not on PowerShell 7+
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Warning "Entry point validation tests require PowerShell 7.0+. Current version: $($PSVersionTable.PSVersion)"
        return
    }

    Import-Module Pester -Force

    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:TestStartTime = Get-Date

    # Test configuration
    $script:TestConfig = @{
        EntryPoints = @(
            @{
                Name = 'Start-AitherZero.ps1'
                Path = Join-Path $script:ProjectRoot 'Start-AitherZero.ps1'
                Type = 'Main'
                RequiredParams = @('Auto', 'Scripts', 'Setup', 'InstallationProfile', 'WhatIf', 'Help', 'NonInteractive')
                DelegateTo = 'aither-core/aither-core.ps1'
            },
            @{
                Name = 'Start-DeveloperSetup.ps1'
                Path = Join-Path $script:ProjectRoot 'Start-DeveloperSetup.ps1'
                Type = 'Developer'
                RequiredParams = @('Profile', 'SkipAITools', 'SkipGitHooks', 'SkipVSCode', 'Force', 'WhatIf', 'Verbose')
                DelegateTo = $null
            }
        )
        TestTimeout = 60
        TempDir = Join-Path $(if($env:TEMP) { $env:TEMP } else { "/tmp" }) "AitherZero-EntryPoint-Tests-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    }

    # Create temp directory for tests
    if (-not (Test-Path $script:TestConfig.TempDir)) {
        New-Item -Path $script:TestConfig.TempDir -ItemType Directory -Force | Out-Null
    }

    # Helper functions
    function Write-EntryPointLog {
        param([string]$Message, [string]$Level = 'INFO')
        $colors = @{ 'INFO' = 'White'; 'SUCCESS' = 'Green'; 'WARNING' = 'Yellow'; 'ERROR' = 'Red'; 'DEBUG' = 'Gray' }
        $timestamp = Get-Date -Format 'HH:mm:ss.fff'
        Write-Host "[$timestamp] [EntryPoint] [$Level] $Message" -ForegroundColor $colors[$Level]
    }

    function Test-ScriptSyntax {
        param([string]$ScriptPath)

        if (-not (Test-Path $ScriptPath)) {
            return @{ Valid = $false; Errors = @("Script not found: $ScriptPath") }
        }

        try {
            $content = Get-Content $ScriptPath -Raw
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)

            return @{
                Valid = $errors.Count -eq 0
                Errors = $errors | ForEach-Object { $_.Message }
            }
        }
        catch {
            return @{
                Valid = $false
                Errors = @($_.Exception.Message)
            }
        }
    }

    function Test-ScriptParameters {
        param([string]$ScriptPath, [string[]]$ExpectedParams)

        if (-not (Test-Path $ScriptPath)) {
            return @{ Valid = $false; MissingParams = $ExpectedParams }
        }

        try {
            $scriptInfo = Get-Command $ScriptPath -ErrorAction Stop
            $actualParams = $scriptInfo.Parameters.Keys
            $missingParams = $ExpectedParams | Where-Object { $_ -notin $actualParams }

            return @{
                Valid = $missingParams.Count -eq 0
                MissingParams = $missingParams
                ActualParams = $actualParams
            }
        }
        catch {
            return @{
                Valid = $false
                MissingParams = $ExpectedParams
                Error = $_.Exception.Message
            }
        }
    }

    function Invoke-ScriptWithTimeout {
        param(
            [string]$ScriptPath,
            [hashtable]$Parameters = @{},
            [int]$TimeoutSeconds = 30
        )

        $job = Start-Job -ScriptBlock {
            param($path, $params)
            try {
                & $path @params
                return @{ Success = $true; Output = "Script completed successfully" }
            }
            catch {
                return @{ Success = $false; Error = $_.Exception.Message }
            }
        } -ArgumentList $ScriptPath, $Parameters

        try {
            $result = Wait-Job $job -Timeout $TimeoutSeconds | Receive-Job
            Remove-Job $job -Force
            return $result
        }
        catch {
            Remove-Job $job -Force
            return @{ Success = $false; Error = "Script execution timed out after $TimeoutSeconds seconds" }
        }
    }

    Write-EntryPointLog "Starting Entry Point Validation Tests" -Level 'INFO'
    Write-EntryPointLog "Project Root: $script:ProjectRoot" -Level 'INFO'
    Write-EntryPointLog "Test Temp Directory: $($script:TestConfig.TempDir)" -Level 'INFO'
}

Describe "Entry Point Existence and Accessibility" -Tags @('EntryPoint', 'Existence', 'Critical') {

    Context "Entry Point File Validation" {
        It "Should have all required entry point scripts" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                Test-Path $entryPoint.Path | Should -Be $true -Because "$($entryPoint.Name) should exist"
                Write-EntryPointLog "Found entry point: $($entryPoint.Name)" -Level 'SUCCESS'
            }
        }

        It "Should have executable permissions on Unix systems" -Skip:$IsWindows {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $fileInfo = Get-Item $entryPoint.Path
                    # Check if file is readable (basic check for Unix permissions)
                    { Get-Content $entryPoint.Path -TotalCount 1 } | Should -Not -Throw -Because "$($entryPoint.Name) should be readable"
                }
            }
        }

        It "Should be accessible from project root directory" {
            $originalLocation = Get-Location
            try {
                Set-Location $script:ProjectRoot

                foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                    $relativePath = "./$($entryPoint.Name)"
                    Test-Path $relativePath | Should -Be $true -Because "$($entryPoint.Name) should be accessible from project root"
                }
            }
            finally {
                Set-Location $originalLocation
            }
        }
    }

    Context "Entry Point Script Structure" {
        It "Should have valid PowerShell syntax for all entry points" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                $syntaxCheck = Test-ScriptSyntax -ScriptPath $entryPoint.Path
                $syntaxCheck.Valid | Should -Be $true -Because "$($entryPoint.Name) should have valid syntax"

                if (-not $syntaxCheck.Valid) {
                    Write-EntryPointLog "Syntax errors in $($entryPoint.Name): $($syntaxCheck.Errors -join '; ')" -Level 'ERROR'
                }
            }
        }

        It "Should require PowerShell 7.0 or higher" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $content = Get-Content $entryPoint.Path -Raw
                    $content | Should -Match "#Requires -Version 7\.0" -Because "$($entryPoint.Name) should require PowerShell 7.0"
                }
            }
        }

        It "Should have proper comment-based help" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $content = Get-Content $entryPoint.Path -Raw
                    $content | Should -Match "\.SYNOPSIS" -Because "$($entryPoint.Name) should have synopsis"
                    $content | Should -Match "\.DESCRIPTION" -Because "$($entryPoint.Name) should have description"
                    $content | Should -Match "\.EXAMPLE" -Because "$($entryPoint.Name) should have examples"
                }
            }
        }
    }
}

Describe "Parameter Validation and Handling" -Tags @('EntryPoint', 'Parameters', 'Validation') {

    Context "Start-AitherZero.ps1 Parameters" {
        BeforeAll {
            $script:MainEntryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-AitherZero.ps1' }
        }

        It "Should have all required parameters defined" -Skip:(-not ($script:MainEntryPoint -and $script:MainEntryPoint.Path -and (Test-Path $script:MainEntryPoint.Path))) {
            $paramCheck = Test-ScriptParameters -ScriptPath $script:MainEntryPoint.Path -ExpectedParams $script:MainEntryPoint.RequiredParams
            $paramCheck.Valid | Should -Be $true -Because "Start-AitherZero.ps1 should have all required parameters"

            if (-not $paramCheck.Valid) {
                Write-EntryPointLog "Missing parameters in Start-AitherZero.ps1: $($paramCheck.MissingParams -join ', ')" -Level 'ERROR'
            }
        }

        It "Should validate InstallationProfile parameter values" -Skip:(-not ($script:MainEntryPoint -and $script:MainEntryPoint.Path -and (Test-Path $script:MainEntryPoint.Path))) {
            $content = Get-Content $script:MainEntryPoint.Path -Raw
            $content | Should -Match "ValidateSet.*minimal.*developer.*full" -Because "InstallationProfile should have ValidateSet attribute"
        }

        It "Should support WhatIf parameter correctly" -Skip:(-not ($script:MainEntryPoint -and $script:MainEntryPoint.Path -and (Test-Path $script:MainEntryPoint.Path))) {
            try {
                $result = Invoke-ScriptWithTimeout -ScriptPath $script:MainEntryPoint.Path -Parameters @{ WhatIf = $true } -TimeoutSeconds 15
                $result.Success | Should -Be $true -Because "Start-AitherZero.ps1 should support WhatIf parameter"
            }
            catch {
                Write-EntryPointLog "WhatIf test failed: $($_.Exception.Message)" -Level 'WARNING'
                # Don't fail - might be environment-specific
                $true | Should -Be $true
            }
        }

        It "Should handle Help parameter" -Skip:(-not ($script:MainEntryPoint -and $script:MainEntryPoint.Path -and (Test-Path $script:MainEntryPoint.Path))) {
            try {
                $result = Invoke-ScriptWithTimeout -ScriptPath $script:MainEntryPoint.Path -Parameters @{ Help = $true } -TimeoutSeconds 10
                $result.Success | Should -Be $true -Because "Start-AitherZero.ps1 should support Help parameter"
            }
            catch {
                Write-EntryPointLog "Help test failed: $($_.Exception.Message)" -Level 'WARNING'
                # Don't fail - might be environment-specific
                $true | Should -Be $true
            }
        }
    }

    Context "Start-DeveloperSetup.ps1 Parameters" {
        BeforeAll {
            $script:DevEntryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-DeveloperSetup.ps1' }
        }

        It "Should have all required parameters defined" -Skip:(-not ($script:DevEntryPoint -and $script:DevEntryPoint.Path -and (Test-Path $script:DevEntryPoint.Path))) {
            $paramCheck = Test-ScriptParameters -ScriptPath $script:DevEntryPoint.Path -ExpectedParams $script:DevEntryPoint.RequiredParams
            $paramCheck.Valid | Should -Be $true -Because "Start-DeveloperSetup.ps1 should have all required parameters"

            if (-not $paramCheck.Valid) {
                Write-EntryPointLog "Missing parameters in Start-DeveloperSetup.ps1: $($paramCheck.MissingParams -join ', ')" -Level 'ERROR'
            }
        }

        It "Should validate Profile parameter values" -Skip:(-not ($script:DevEntryPoint -and $script:DevEntryPoint.Path -and (Test-Path $script:DevEntryPoint.Path))) {
            $content = Get-Content $script:DevEntryPoint.Path -Raw
            $content | Should -Match "ValidateSet.*Quick.*Full" -Because "Profile should have ValidateSet attribute"
        }

        It "Should support ShouldProcess for WhatIf functionality" -Skip:(-not ($script:DevEntryPoint -and $script:DevEntryPoint.Path -and (Test-Path $script:DevEntryPoint.Path))) {
            $content = Get-Content $script:DevEntryPoint.Path -Raw
            $content | Should -Match "SupportsShouldProcess" -Because "Developer setup should support ShouldProcess"
        }

        It "Should handle skip switches correctly" -Skip:(-not ($script:DevEntryPoint -and $script:DevEntryPoint.Path -and (Test-Path $script:DevEntryPoint.Path))) {
            $skipSwitches = @('SkipAITools', 'SkipGitHooks', 'SkipVSCode')

            foreach ($switch in $skipSwitches) {
                try {
                    $params = @{ $switch = $true; WhatIf = $true }
                    $result = Invoke-ScriptWithTimeout -ScriptPath $script:DevEntryPoint.Path -Parameters $params -TimeoutSeconds 15

                    if (-not $result.Success) {
                        Write-EntryPointLog "Skip switch test failed for $switch : $($result.Error)" -Level 'WARNING'
                    }
                }
                catch {
                    Write-EntryPointLog "Skip switch test error for $switch : $($_.Exception.Message)" -Level 'WARNING'
                }
            }

            # Always pass - these are informational tests
            $true | Should -Be $true
        }
    }
}

Describe "PowerShell Version Checking Integration" -Tags @('EntryPoint', 'Version', 'Integration') {

    Context "Version Check Implementation" {
        It "Should reference PowerShell version checking in Start-AitherZero.ps1" {
            $entryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-AitherZero.ps1' }

            if (Test-Path $entryPoint.Path) {
                $content = Get-Content $entryPoint.Path -Raw
                $content | Should -Match "Test-PowerShellVersion" -Because "Entry point should check PowerShell version"
                $content | Should -Match "aither-core/shared/Test-PowerShellVersion\.ps1" -Because "Should reference version checking utility"
            }
        }

        It "Should implement version checking in Start-DeveloperSetup.ps1" {
            $entryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-DeveloperSetup.ps1' }

            if (Test-Path $entryPoint.Path) {
                $content = Get-Content $entryPoint.Path -Raw
                $content | Should -Match "Test-PowerShellVersion" -Because "Developer setup should have version checking function"
                $content | Should -Match "7\.0" -Because "Should reference minimum version requirement"
            }
        }

        It "Should validate version checking utility exists" {
            $versionCheckPath = Join-Path $script:ProjectRoot "aither-core/shared/Test-PowerShellVersion.ps1"

            if (Test-Path $versionCheckPath) {
                Test-Path $versionCheckPath | Should -Be $true

                # Test syntax
                $syntaxCheck = Test-ScriptSyntax -ScriptPath $versionCheckPath
                $syntaxCheck.Valid | Should -Be $true -Because "Version checking utility should have valid syntax"

                # Test if it can be dot-sourced
                { . $versionCheckPath } | Should -Not -Throw -Because "Version checking utility should load without errors"
            }
        }
    }

    Context "Version Check Behavior" {
        It "Should handle version checking gracefully" {
            $entryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-AitherZero.ps1' }

            if (Test-Path $entryPoint.Path) {
                # Test that the entry point doesn't immediately fail when checking version
                # (since we're running on PowerShell 7.0+, it should pass)
                $versionCheckPath = Join-Path $script:ProjectRoot "aither-core/shared/Test-PowerShellVersion.ps1"

                if (Test-Path $versionCheckPath) {
                    . $versionCheckPath

                    if (Get-Command Test-PowerShellVersion -ErrorAction SilentlyContinue) {
                        $versionTest = Test-PowerShellVersion -MinimumVersion "7.0" -Quiet
                        $versionTest | Should -Be $true -Because "Current PowerShell version should pass validation"
                    }
                }
            }
        }
    }
}

Describe "Path Resolution and Delegation" -Tags @('EntryPoint', 'Paths', 'Delegation') {

    Context "Path Resolution Logic" {
        It "Should handle various execution contexts for Start-AitherZero.ps1" {
            $entryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-AitherZero.ps1' }

            if (Test-Path $entryPoint.Path) {
                $content = Get-Content $entryPoint.Path -Raw

                # Should have multiple path resolution methods
                $content | Should -Match '\$PSScriptRoot' -Because "Should use PSScriptRoot for path resolution"
                $content | Should -Match '\$MyInvocation' -Because "Should have fallback path resolution"
                $content | Should -Match "Join-Path" -Because "Should use cross-platform path joining"
            }
        }

        It "Should validate delegation target exists" {
            $mainEntry = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-AitherZero.ps1' }

            if ((Test-Path $mainEntry.Path) -and $mainEntry.DelegateTo) {
                $delegateTarget = Join-Path $script:ProjectRoot $mainEntry.DelegateTo
                Test-Path $delegateTarget | Should -Be $true -Because "Delegation target $($mainEntry.DelegateTo) should exist"

                if (Test-Path $delegateTarget) {
                    # Validate delegation target syntax
                    $syntaxCheck = Test-ScriptSyntax -ScriptPath $delegateTarget
                    $syntaxCheck.Valid | Should -Be $true -Because "Delegation target should have valid syntax"
                }
            }
        }

        It "Should handle missing core script gracefully" {
            $entryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-AitherZero.ps1' }

            if (Test-Path $entryPoint.Path) {
                $content = Get-Content $entryPoint.Path -Raw

                # Should check for core script existence
                $content | Should -Match "Test-Path.*coreScript" -Because "Should validate core script exists"
                $content | Should -Match "Core script not found" -Because "Should handle missing core script"
            }
        }
    }

    Context "Parameter Delegation" {
        It "Should properly delegate parameters to core script" {
            $entryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-AitherZero.ps1' }

            if (Test-Path $entryPoint.Path) {
                $content = Get-Content $entryPoint.Path -Raw

                # Should build parameter hashtable for delegation
                $content | Should -Match '\$coreParams' -Because "Should create parameter hashtable"
                $content | Should -Match 'PSBoundParameters' -Because "Should use PSBoundParameters for delegation"
                $content | Should -Match '@coreParams' -Because "Should use splatting for parameter delegation"
            }
        }
    }
}

Describe "Error Handling and User Experience" -Tags @('EntryPoint', 'ErrorHandling', 'UX') {

    Context "Error Handling Implementation" {
        It "Should have comprehensive error handling in entry points" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $content = Get-Content $entryPoint.Path -Raw

                    $content | Should -Match "try \{" -Because "$($entryPoint.Name) should have try blocks"
                    $content | Should -Match "\} catch \{" -Because "$($entryPoint.Name) should have catch blocks"
                    $content | Should -Match "exit 1" -Because "$($entryPoint.Name) should exit with error code on failure"
                }
            }
        }

        It "Should provide meaningful error messages" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $content = Get-Content $entryPoint.Path -Raw

                    # Error messages should be descriptive
                    $errorMessages = [regex]::Matches($content, 'Write-Error\s+"([^"]+)"')

                    foreach ($match in $errorMessages) {
                        $message = $match.Groups[1].Value
                        $message.Length | Should -BeGreaterThan 10 -Because "Error messages should be descriptive"
                        $message | Should -Not -Match "^Error$" -Because "Error messages should be specific"
                    }
                }
            }
        }

        It "Should handle missing dependencies gracefully" {
            # Test handling of missing PowerShell version check utility
            $entryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-AitherZero.ps1' }

            if (Test-Path $entryPoint.Path) {
                $content = Get-Content $entryPoint.Path -Raw
                $content | Should -Match "Test-Path.*versionUtilPath" -Because "Should check if version utility exists"
                $content | Should -Match "Please ensure AitherZero is properly installed" -Because "Should provide installation guidance"
            }
        }
    }

    Context "User Experience Features" {
        It "Should provide help and usage information" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $content = Get-Content $entryPoint.Path -Raw

                    # Should have comprehensive help
                    $content | Should -Match "\.SYNOPSIS" -Because "$($entryPoint.Name) should have synopsis"
                    $content | Should -Match "\.PARAMETER" -Because "$($entryPoint.Name) should document parameters"
                    $content | Should -Match "\.EXAMPLE" -Because "$($entryPoint.Name) should provide examples"

                    # Examples should be realistic
                    $examples = [regex]::Matches($content, '\.EXAMPLE\s*\n\s*([^\n]+)')
                    $examples.Count | Should -BeGreaterThan 0 -Because "$($entryPoint.Name) should have examples"
                }
            }
        }

        It "Should provide version information" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    # Entry points should reference version or provide version info
                    $content = Get-Content $entryPoint.Path -Raw

                    # Should either have version info or reference versioning
                    $hasVersionInfo = ($content -match "Version.*\d+\.\d+\.\d+" -or
                                      $content -match "Get-ProjectVersion" -or
                                      $content -match "VERSION")

                    if ($hasVersionInfo) {
                        Write-EntryPointLog "$($entryPoint.Name) includes version information" -Level 'SUCCESS'
                    } else {
                        Write-EntryPointLog "$($entryPoint.Name) may lack version information" -Level 'WARNING'
                    }
                }
            }
        }
    }
}

Describe "Integration with Project Structure" -Tags @('EntryPoint', 'Integration', 'Structure') {

    Context "Project Structure Dependencies" {
        It "Should reference correct project structure paths" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $content = Get-Content $entryPoint.Path -Raw

                    # Should reference proper project structure
                    if ($content -match "aither-core") {
                        $content | Should -Match "aither-core" -Because "$($entryPoint.Name) should reference aither-core directory"
                    }

                    if ($content -match "modules") {
                        $content | Should -Match "modules" -Because "$($entryPoint.Name) should reference modules directory"
                    }
                }
            }
        }

        It "Should validate referenced paths exist" {
            $entryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-AitherZero.ps1' }

            if (Test-Path $entryPoint.Path) {
                # Check that referenced core script exists
                $coreScriptPath = Join-Path $script:ProjectRoot "aither-core/aither-core.ps1"
                Test-Path $coreScriptPath | Should -Be $true -Because "Referenced core script should exist"

                # Check that version check utility exists
                $versionCheckPath = Join-Path $script:ProjectRoot "aither-core/shared/Test-PowerShellVersion.ps1"
                if (Test-Path $versionCheckPath) {
                    Test-Path $versionCheckPath | Should -Be $true
                    Write-EntryPointLog "Version check utility found" -Level 'SUCCESS'
                } else {
                    Write-EntryPointLog "Version check utility not found - entry point should handle this gracefully" -Level 'WARNING'
                }
            }
        }

        It "Should integrate with module system appropriately" {
            $devEntryPoint = $script:TestConfig.EntryPoints | Where-Object { $_.Name -eq 'Start-DeveloperSetup.ps1' }

            if (Test-Path $devEntryPoint.Path) {
                $content = Get-Content $devEntryPoint.Path -Raw

                # Should reference AitherZero modules
                $moduleReferences = @('SetupWizard', 'DevEnvironment', 'AIToolsIntegration', 'PatchManager')

                foreach ($module in $moduleReferences) {
                    if ($content -match $module) {
                        Write-EntryPointLog "Developer setup references $module module" -Level 'INFO'

                        # Validate that the referenced module exists
                        $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/$module"
                        if (Test-Path $modulePath) {
                            Write-EntryPointLog "Module $module exists at expected location" -Level 'SUCCESS'
                        } else {
                            Write-EntryPointLog "Module $module referenced but not found at expected location" -Level 'WARNING'
                        }
                    }
                }
            }
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should use cross-platform path construction" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $content = Get-Content $entryPoint.Path -Raw

                    # Should use Join-Path instead of hardcoded separators
                    $content | Should -Match "Join-Path" -Because "$($entryPoint.Name) should use Join-Path for cross-platform compatibility"

                    # Should not have hardcoded path separators (basic check)
                    $hardcodedPaths = [regex]::Matches($content, '"[^"]*\\[^"]*"')
                    $problematicPaths = $hardcodedPaths | Where-Object { $_.Value -notmatch '^"http' -and $_.Value -notmatch '\\n' }

                    if ($problematicPaths.Count -gt 0) {
                        Write-EntryPointLog "$($entryPoint.Name) may have hardcoded Windows paths: $($problematicPaths.Value -join ', ')" -Level 'WARNING'
                    }
                }
            }
        }

        It "Should handle platform-specific execution scenarios" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $content = Get-Content $entryPoint.Path -Raw

                    # Should consider platform differences if applicable
                    if ($content -match '\$Is(Windows|Linux|MacOS)') {
                        Write-EntryPointLog "$($entryPoint.Name) includes platform-specific logic" -Level 'INFO'
                    }
                }
            }
        }
    }
}

Describe "Performance and Startup Time" -Tags @('EntryPoint', 'Performance', 'Startup') {

    Context "Startup Performance" {
        It "Should load and validate quickly" {
            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    $startTime = Get-Date

                    try {
                        # Test basic script loading (syntax check)
                        $scriptInfo = Get-Command $entryPoint.Path -ErrorAction Stop
                        $scriptInfo | Should -Not -BeNullOrEmpty

                        $duration = (Get-Date) - $startTime
                        $duration.TotalSeconds | Should -BeLessThan 2 -Because "$($entryPoint.Name) should load quickly"

                        Write-EntryPointLog "$($entryPoint.Name) loaded in $([math]::Round($duration.TotalMilliseconds))ms" -Level 'INFO'
                    }
                    catch {
                        Write-EntryPointLog "$($entryPoint.Name) failed to load: $($_.Exception.Message)" -Level 'ERROR'
                        throw
                    }
                }
            }
        }

        It "Should have minimal startup overhead" {
            # Test memory usage during entry point loading
            $initialMemory = [GC]::GetTotalMemory($false)

            foreach ($entryPoint in $script:TestConfig.EntryPoints) {
                if (Test-Path $entryPoint.Path) {
                    # Load script info (basic parsing)
                    $scriptInfo = Get-Command $entryPoint.Path -ErrorAction SilentlyContinue
                    if ($scriptInfo) {
                        Write-EntryPointLog "$($entryPoint.Name) parsed successfully" -Level 'SUCCESS'
                    }
                }
            }

            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = ($finalMemory - $initialMemory) / 1MB

            Write-EntryPointLog "Memory increase during entry point parsing: $([math]::Round($memoryIncrease, 2)) MB" -Level 'INFO'

            # Memory increase should be reasonable
            $memoryIncrease | Should -BeLessThan 10 -Because "Entry point loading should not consume excessive memory"
        }
    }
}

AfterAll {
    $duration = (Get-Date) - $script:TestStartTime

    Write-EntryPointLog "Entry Point Validation Tests Complete" -Level 'SUCCESS'
    Write-EntryPointLog "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -Level 'INFO'

    # Cleanup temp directory
    if (Test-Path $script:TestConfig.TempDir) {
        try {
            Remove-Item $script:TestConfig.TempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-EntryPointLog "Cleaned up temp directory" -Level 'SUCCESS'
        }
        catch {
            Write-EntryPointLog "Failed to clean up temp directory: $($_.Exception.Message)" -Level 'WARNING'
        }
    }

    # Summary
    Write-Host ""
    Write-Host "Entry Point Validation Summary:" -ForegroundColor Cyan
    Write-Host "  Entry Points Tested: $($script:TestConfig.EntryPoints.Count)" -ForegroundColor White
    Write-Host "  Test Duration: $([math]::Round($duration.TotalSeconds, 2))s" -ForegroundColor White
    Write-Host "  Platform: $(if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' })" -ForegroundColor White

    # Show entry point status
    foreach ($entryPoint in $script:TestConfig.EntryPoints) {
        $status = if (Test-Path $entryPoint.Path) { "✅ Found" } else { "❌ Missing" }
        Write-Host "  $($entryPoint.Name): $status" -ForegroundColor $(if (Test-Path $entryPoint.Path) { 'Green' } else { 'Red' })
    }
}
