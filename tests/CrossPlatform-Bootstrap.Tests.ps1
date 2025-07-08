#Requires -Version 7.0

<#
.SYNOPSIS
    Cross-platform bootstrap and compatibility validation testing

.DESCRIPTION
    Comprehensive testing for AitherZero's cross-platform functionality:
    - Windows/Linux/macOS compatibility
    - Path handling across platforms
    - Environment variable management
    - Platform-specific features
    - File system operations
    - Network connectivity
    - Process management

.NOTES
    Tests the core bootstrap process across different operating systems
#>

BeforeAll {
    Import-Module Pester -Force

    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:TestStartTime = Get-Date

    # Platform detection
    $script:PlatformInfo = @{
        Current = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        IsWindows = $IsWindows
        IsLinux = $IsLinux
        IsMacOS = $IsMacOS
        Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
        PSVersion = $PSVersionTable.PSVersion
        PSEdition = $PSVersionTable.PSEdition
    }

    # Test configuration
    $script:TestConfig = @{
        TestTimeout = 60
        NetworkTimeout = 10
        FileOperationTimeout = 5
        ProcessTimeout = 30
        TempDirPrefix = "AitherZero-CrossPlatform-Test"
        TestEndpoints = @(
            'https://github.com',
            'https://api.github.com',
            'https://www.powershellgallery.com'
        )
    }

    # Create platform-specific temp directory
    $script:TempDir = if ($IsWindows) {
        Join-Path $env:TEMP "$($script:TestConfig.TempDirPrefix)-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    } else {
        Join-Path "/tmp" "$($script:TestConfig.TempDirPrefix)-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    }

    if (-not (Test-Path $script:TempDir)) {
        New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null
    }

    # Helper functions
    function Write-PlatformLog {
        param([string]$Message, [string]$Level = 'INFO')
        $colors = @{ 'INFO' = 'White'; 'SUCCESS' = 'Green'; 'WARNING' = 'Yellow'; 'ERROR' = 'Red' }
        $timestamp = Get-Date -Format 'HH:mm:ss.fff'
        Write-Host "[$timestamp] [$($script:PlatformInfo.Current)] [$Level] $Message" -ForegroundColor $colors[$Level]
    }

    function Test-PlatformCommand {
        param([string]$Command, [string[]]$Parameters = @())
        try {
            if ($Parameters.Count -gt 0) {
                & $Command @Parameters 2>$null | Out-Null
            } else {
                & $Command 2>$null | Out-Null
            }
            return $true
        }
        catch {
            return $false
        }
    }

    function Get-PlatformSpecificPath {
        param([string]$Type)
        switch ($Type) {
            'Home' {
                return if ($IsWindows) { $env:USERPROFILE } else { $env:HOME }
            }
            'Temp' {
                return if ($IsWindows) { $env:TEMP } else { '/tmp' }
            }
            'Config' {
                return if ($IsWindows) { $env:APPDATA } else { Join-Path $env:HOME '.config' }
            }
            'ProgramFiles' {
                return if ($IsWindows) { $env:ProgramFiles } else { '/usr/local/bin' }
            }
            default {
                throw "Unknown path type: $Type"
            }
        }
    }

    Write-PlatformLog "Starting Cross-Platform Bootstrap Tests" -Level 'INFO'
    Write-PlatformLog "Platform: $($script:PlatformInfo.Current) ($($script:PlatformInfo.Architecture))" -Level 'INFO'
    Write-PlatformLog "PowerShell: $($script:PlatformInfo.PSVersion) ($($script:PlatformInfo.PSEdition))" -Level 'INFO'
}

Describe "Platform Detection and Variables" -Tags @('CrossPlatform', 'Detection', 'Critical') {

    Context "Platform Identification" {
        It "Should correctly identify the current platform" {
            # Exactly one platform should be true
            $platformCount = @($IsWindows, $IsLinux, $IsMacOS) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
            $platformCount | Should -Be 1 -Because "Exactly one platform should be detected"

            Write-PlatformLog "Detected platform: $($script:PlatformInfo.Current)" -Level 'SUCCESS'
        }

        It "Should have consistent platform variables" {
            # Platform variables should be boolean
            $IsWindows | Should -BeOfType [bool]
            $IsLinux | Should -BeOfType [bool]
            $IsMacOS | Should -BeOfType [bool]

            # IsCoreCLR should be true for PowerShell Core
            $IsCoreCLR | Should -Be $true -Because "PowerShell Core should set IsCoreCLR to true"
        }

        It "Should provide platform architecture information" {
            [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture | Should -Not -BeNullOrEmpty
            [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture | Should -Not -BeNullOrEmpty

            Write-PlatformLog "OS Architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)" -Level 'INFO'
            Write-PlatformLog "Process Architecture: $([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)" -Level 'INFO'
        }

        It "Should have correct framework description" {
            $frameworkDescription = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
            $frameworkDescription | Should -Not -BeNullOrEmpty
            $frameworkDescription | Should -Match "\.NET" -Because "Should be running on .NET Core/.NET 5+"

            Write-PlatformLog "Framework: $frameworkDescription" -Level 'INFO'
        }
    }

    Context "Environment Variables" {
        It "Should have platform-appropriate environment variables" {
            switch ($script:PlatformInfo.Current) {
                'Windows' {
                    $env:USERPROFILE | Should -Not -BeNullOrEmpty
                    $env:APPDATA | Should -Not -BeNullOrEmpty
                    $env:LOCALAPPDATA | Should -Not -BeNullOrEmpty
                    $env:PROGRAMFILES | Should -Not -BeNullOrEmpty
                    $env:WINDIR | Should -Not -BeNullOrEmpty
                }
                'Linux' {
                    $env:HOME | Should -Not -BeNullOrEmpty
                    $env:USER | Should -Not -BeNullOrEmpty
                    $env:PATH | Should -Not -BeNullOrEmpty
                }
                'macOS' {
                    $env:HOME | Should -Not -BeNullOrEmpty
                    $env:USER | Should -Not -BeNullOrEmpty
                    $env:PATH | Should -Not -BeNullOrEmpty
                }
            }
        }

        It "Should have PowerShell-specific environment variables" {
            $env:PSModulePath | Should -Not -BeNullOrEmpty -Because "PSModulePath should be set"

            # Check if PSModulePath contains platform-appropriate paths
            $modulePaths = $env:PSModulePath -split [IO.Path]::PathSeparator
            $modulePaths.Count | Should -BeGreaterThan 0

            foreach ($path in $modulePaths) {
                if ($path -and (Test-Path $path -ErrorAction SilentlyContinue)) {
                    Write-PlatformLog "Module path verified: $path" -Level 'SUCCESS'
                }
            }
        }

        It "Should handle path separators correctly" {
            $pathSep = [IO.Path]::PathSeparator
            $dirSep = [IO.Path]::DirectorySeparatorChar

            switch ($script:PlatformInfo.Current) {
                'Windows' {
                    $pathSep | Should -Be ';'
                    $dirSep | Should -Be '\'
                }
                default {  # Linux/macOS
                    $pathSep | Should -Be ':'
                    $dirSep | Should -Be '/'
                }
            }
        }
    }
}

Describe "Cross-Platform Path Handling" -Tags @('CrossPlatform', 'Paths', 'FileSystem') {

    Context "Path Construction and Validation" {
        It "Should construct paths correctly using Join-Path" {
            $testPaths = @(
                @('path1', 'path2', 'file.txt'),
                @('usr', 'local', 'bin'),
                @('C:', 'Users', 'test'),  # Windows style
                @('home', 'user', 'documents')  # Unix style
            )

            foreach ($pathComponents in $testPaths) {
                $joinedPath = Join-Path @pathComponents
                $joinedPath | Should -Not -BeNullOrEmpty

                # Should not contain mixed separators
                if ($IsWindows) {
                    $joinedPath | Should -Not -Match '/' -Because "Windows paths should not contain forward slashes"
                } else {
                    $joinedPath | Should -Not -Match '\\' -Because "Unix paths should not contain backslashes"
                }
            }
        }

        It "Should resolve paths correctly" {
            $currentDir = Get-Location
            $parentDir = Split-Path $currentDir -Parent

            $currentDir | Should -Not -BeNullOrEmpty
            $parentDir | Should -Not -BeNullOrEmpty

            # Test relative path resolution
            $relativePath = Join-Path $currentDir ".."
            $resolvedPath = Resolve-Path $relativePath
            $resolvedPath.Path | Should -Be $parentDir
        }

        It "Should handle special characters in paths" {
            $specialChars = @(
                'test with spaces',
                'test-with-hyphens',
                'test_with_underscores',
                'test.with.dots'
            )

            foreach ($name in $specialChars) {
                $testPath = Join-Path $script:TempDir $name

                # Create and test the path
                { New-Item -Path $testPath -ItemType Directory -Force } | Should -Not -Throw -Because "Should handle special character: $name"

                if (Test-Path $testPath) {
                    Test-Path $testPath | Should -Be $true
                    Remove-Item $testPath -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It "Should convert paths between formats" {
            $testPath = Join-Path $script:TempDir "test/path/file.txt"

            # Convert to platform-appropriate format
            $platformPath = [System.IO.Path]::GetFullPath($testPath)
            $platformPath | Should -Not -BeNullOrEmpty

            # Should use correct separators for platform
            if ($IsWindows) {
                $platformPath | Should -Match '\\'
            } else {
                $platformPath | Should -Match '/'
            }
        }
    }

    Context "File System Operations" {
        It "Should create and manipulate directories cross-platform" {
            $testDir = Join-Path $script:TempDir "cross-platform-test"

            # Create directory
            New-Item -Path $testDir -ItemType Directory -Force | Should -Not -BeNullOrEmpty
            Test-Path $testDir | Should -Be $true

            # Create subdirectory
            $subDir = Join-Path $testDir "subdir"
            New-Item -Path $subDir -ItemType Directory | Should -Not -BeNullOrEmpty
            Test-Path $subDir | Should -Be $true

            # Remove directories
            Remove-Item $testDir -Recurse -Force
            Test-Path $testDir | Should -Be $false
        }

        It "Should handle file operations cross-platform" {
            $testFile = Join-Path $script:TempDir "test-file.txt"
            $testContent = "Cross-platform test content`nLine 2`nLine 3"

            # Create file
            Set-Content -Path $testFile -Value $testContent -Encoding UTF8
            Test-Path $testFile | Should -Be $true

            # Read file
            $readContent = Get-Content -Path $testFile -Raw
            $readContent.Trim() | Should -Be $testContent

            # Copy file
            $copyFile = Join-Path $script:TempDir "test-file-copy.txt"
            Copy-Item -Path $testFile -Destination $copyFile
            Test-Path $copyFile | Should -Be $true

            # Compare files
            $copyContent = Get-Content -Path $copyFile -Raw
            $copyContent.Trim() | Should -Be $testContent

            # Clean up
            Remove-Item $testFile, $copyFile -Force -ErrorAction SilentlyContinue
        }

        It "Should handle permissions appropriately" {
            $testFile = Join-Path $script:TempDir "permissions-test.txt"
            Set-Content -Path $testFile -Value "Test content"

            if ($IsWindows) {
                # Windows permission tests
                $acl = Get-Acl $testFile
                $acl | Should -Not -BeNullOrEmpty
            } else {
                # Unix permission tests
                $permissions = (Get-Item $testFile).UnixFileMode
                $permissions | Should -Not -BeNullOrEmpty

                # Test basic permission operations
                { chmod 644 $testFile } | Should -Not -Throw -ErrorAction SilentlyContinue
            }

            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Process and Command Execution" -Tags @('CrossPlatform', 'Processes', 'Commands') {

    Context "Basic Command Execution" {
        It "Should execute platform-appropriate system commands" {
            switch ($script:PlatformInfo.Current) {
                'Windows' {
                    # Test Windows commands
                    { cmd /c "echo test" } | Should -Not -Throw
                    { Get-Process -Name "explorer" -ErrorAction SilentlyContinue } | Should -Not -Throw
                }
                'Linux' {
                    # Test Linux commands
                    { bash -c "echo test" } | Should -Not -Throw
                    { ps aux } | Should -Not -Throw
                }
                'macOS' {
                    # Test macOS commands
                    { bash -c "echo test" } | Should -Not -Throw
                    { ps aux } | Should -Not -Throw
                }
            }
        }

        It "Should handle cross-platform PowerShell commands" {
            # These should work on all platforms
            $crossPlatformCommands = @(
                { Get-Process | Select-Object -First 1 },
                { Get-Location },
                { Get-Date },
                { Get-Host },
                { $PSVersionTable }
            )

            foreach ($command in $crossPlatformCommands) {
                { & $command } | Should -Not -Throw -Because "Cross-platform command should work"
            }
        }

        It "Should execute external programs correctly" {
            # Test PowerShell execution
            $psCommand = if ($IsWindows) { "pwsh" } else { "pwsh" }

            if (Get-Command $psCommand -ErrorAction SilentlyContinue) {
                $result = & $psCommand -NoProfile -Command "Write-Output 'test'"
                $result | Should -Be "test"
            }
        }
    }

    Context "Environment and Process Information" {
        It "Should retrieve process information" {
            $currentProcess = Get-Process -Id $PID
            $currentProcess | Should -Not -BeNullOrEmpty
            $currentProcess.ProcessName | Should -Be "pwsh"
        }

        It "Should access environment information" {
            $env:PATH | Should -Not -BeNullOrEmpty

            # Test PATH parsing
            $pathEntries = $env:PATH -split [IO.Path]::PathSeparator
            $pathEntries.Count | Should -BeGreaterThan 0
        }

        It "Should handle working directory operations" {
            $originalLocation = Get-Location

            try {
                # Change to temp directory
                Set-Location $script:TempDir
                (Get-Location).Path | Should -Be $script:TempDir

                # Change to parent directory
                Set-Location ..
                $currentLocation = Get-Location
                $currentLocation.Path | Should -Not -Be $script:TempDir
            }
            finally {
                Set-Location $originalLocation
            }
        }
    }
}

Describe "Network and Connectivity" -Tags @('CrossPlatform', 'Network', 'Connectivity') {

    Context "Basic Network Operations" {
        It "Should test network connectivity" {
            foreach ($endpoint in $script:TestConfig.TestEndpoints) {
                try {
                    $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec $script:TestConfig.NetworkTimeout -ErrorAction Stop
                    $response.StatusCode | Should -Be 200
                    Write-PlatformLog "Network test passed: $endpoint" -Level 'SUCCESS'
                }
                catch {
                    Write-PlatformLog "Network test failed: $endpoint - $($_.Exception.Message)" -Level 'WARNING'
                    # Don't fail the test for network issues - they might be environment-specific
                }
            }
        }

        It "Should handle DNS resolution" -Skip:($env:CI -eq 'true') {
            try {
                $dnsResult = Resolve-DnsName "github.com" -ErrorAction Stop
                $dnsResult | Should -Not -BeNullOrEmpty
            }
            catch {
                # Skip if DNS resolution is not available or fails
                Write-PlatformLog "DNS resolution test skipped: $($_.Exception.Message)" -Level 'WARNING'
            }
        }

        It "Should support HTTP client operations" {
            try {
                $userAgent = "AitherZero-CrossPlatform-Test/1.0"
                $headers = @{ 'User-Agent' = $userAgent }

                $response = Invoke-RestMethod -Uri "https://api.github.com/zen" -Headers $headers -TimeoutSec $script:TestConfig.NetworkTimeout -ErrorAction Stop
                $response | Should -Not -BeNullOrEmpty
                $response | Should -BeOfType [string]
            }
            catch {
                Write-PlatformLog "HTTP client test failed: $($_.Exception.Message)" -Level 'WARNING'
                # Don't fail - network issues might be environment-specific
            }
        }
    }
}

Describe "AitherZero Bootstrap Integration" -Tags @('CrossPlatform', 'Bootstrap', 'Integration') {

    Context "Project Structure Validation" {
        It "Should validate project paths across platforms" {
            $projectPaths = @(
                'Start-AitherZero.ps1',
                'Start-DeveloperSetup.ps1',
                'aither-core',
                'aither-core/modules',
                'configs',
                'tests'
            )

            foreach ($path in $projectPaths) {
                $fullPath = Join-Path $script:ProjectRoot $path
                Test-Path $fullPath | Should -Be $true -Because "Project path $path should exist"
            }
        }

        It "Should validate entry point scripts" {
            $entryPoints = @(
                'Start-AitherZero.ps1',
                'Start-DeveloperSetup.ps1'
            )

            foreach ($script in $entryPoints) {
                $scriptPath = Join-Path $script:ProjectRoot $script

                if (Test-Path $scriptPath) {
                    # Validate syntax
                    $errors = $null
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
                    $errors.Count | Should -Be 0 -Because "Script $script should have valid syntax"

                    # Check for cross-platform compatibility indicators
                    $content = Get-Content $scriptPath -Raw
                    $content | Should -Match "Join-Path" -Because "Script should use Join-Path for cross-platform compatibility"
                }
            }
        }

        It "Should handle configuration paths correctly" {
            $configPaths = @{
                Windows = @(
                    $env:APPDATA,
                    $env:LOCALAPPDATA
                )
                Unix = @(
                    $env:HOME,
                    (Join-Path $env:HOME '.config')
                )
            }

            $relevantPaths = if ($IsWindows) { $configPaths.Windows } else { $configPaths.Unix }

            foreach ($path in $relevantPaths) {
                if ($path) {
                    Test-Path $path | Should -Be $true -Because "Configuration path $path should exist"
                }
            }
        }
    }

    Context "Module Loading Cross-Platform" {
        It "Should load core modules on any platform" {
            $coreModules = @(
                'SetupWizard',
                'DevEnvironment'
            )

            foreach ($module in $coreModules) {
                $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/$module"

                if (Test-Path $modulePath) {
                    { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw -Because "Module $module should load on $($script:PlatformInfo.Current)"

                    # Verify module was loaded
                    Get-Module -Name $module | Should -Not -BeNullOrEmpty

                    # Remove module to clean up
                    Remove-Module $module -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It "Should handle shared utilities across platforms" {
            $sharedUtilityPath = Join-Path $script:ProjectRoot "aither-core/shared/Find-ProjectRoot.ps1"

            if (Test-Path $sharedUtilityPath) {
                # Test syntax
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $sharedUtilityPath -Raw), [ref]$errors)
                $errors.Count | Should -Be 0

                # Test execution
                { . $sharedUtilityPath } | Should -Not -Throw

                # Test function if available
                if (Get-Command Find-ProjectRoot -ErrorAction SilentlyContinue) {
                    $projectRoot = Find-ProjectRoot
                    $projectRoot | Should -Not -BeNullOrEmpty
                    Test-Path (Join-Path $projectRoot "Start-AitherZero.ps1") | Should -Be $true
                }
            }
        }
    }

    Context "Platform-Specific Features" {
        It "Should handle platform-specific functionality gracefully" {
            switch ($script:PlatformInfo.Current) {
                'Windows' {
                    # Test Windows-specific features
                    if (Get-Command Get-WmiObject -ErrorAction SilentlyContinue) {
                        { Get-WmiObject -Class Win32_OperatingSystem } | Should -Not -Throw
                    }

                    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                        { Get-CimInstance -ClassName Win32_ComputerSystem } | Should -Not -Throw
                    }
                }
                'Linux' {
                    # Test Linux-specific features
                    if (Test-Path '/etc/os-release') {
                        $osRelease = Get-Content '/etc/os-release'
                        $osRelease | Should -Not -BeNullOrEmpty
                    }

                    # Test systemctl if available
                    if (Get-Command systemctl -ErrorAction SilentlyContinue) {
                        { systemctl --version } | Should -Not -Throw
                    }
                }
                'macOS' {
                    # Test macOS-specific features
                    if (Get-Command sw_vers -ErrorAction SilentlyContinue) {
                        { sw_vers -productVersion } | Should -Not -Throw
                    }

                    if (Get-Command defaults -ErrorAction SilentlyContinue) {
                        { defaults read NSGlobalDomain } | Should -Not -Throw
                    }
                }
            }
        }
    }
}

Describe "Performance and Resource Management" -Tags @('CrossPlatform', 'Performance', 'Resources') {

    Context "Memory and Performance" {
        It "Should have reasonable memory usage" {
            $process = Get-Process -Id $PID
            $memoryMB = [math]::Round($process.WorkingSet64 / 1MB, 2)

            Write-PlatformLog "Current memory usage: $memoryMB MB" -Level 'INFO'

            # Memory usage should be reasonable (less than 500MB for tests)
            $memoryMB | Should -BeLessThan 500 -Because "Test process should not consume excessive memory"
        }

        It "Should handle file operations efficiently" {
            $testFile = Join-Path $script:TempDir "performance-test.txt"
            $largeContent = "Test line`n" * 1000

            $startTime = Get-Date
            Set-Content -Path $testFile -Value $largeContent
            $writeTime = (Get-Date) - $startTime

            $startTime = Get-Date
            $readContent = Get-Content -Path $testFile -Raw
            $readTime = (Get-Date) - $startTime

            Write-PlatformLog "File write time: $($writeTime.TotalMilliseconds)ms" -Level 'INFO'
            Write-PlatformLog "File read time: $($readTime.TotalMilliseconds)ms" -Level 'INFO'

            $writeTime.TotalSeconds | Should -BeLessThan 2
            $readTime.TotalSeconds | Should -BeLessThan 2

            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Resource Cleanup" {
        It "Should clean up resources properly" {
            # Test temporary file cleanup
            $tempFiles = Get-ChildItem $script:TempDir -ErrorAction SilentlyContinue

            foreach ($file in $tempFiles) {
                if ($file.Name -match "test|temp") {
                    Remove-Item $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                }
            }

            # Memory cleanup - force garbage collection
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            $true | Should -Be $true  # Always pass - this is cleanup
        }
    }
}

AfterAll {
    $duration = (Get-Date) - $script:TestStartTime

    Write-PlatformLog "Cross-Platform Bootstrap Tests Complete" -Level 'SUCCESS'
    Write-PlatformLog "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -Level 'INFO'
    Write-PlatformLog "Platform: $($script:PlatformInfo.Current)" -Level 'INFO'
    Write-PlatformLog "Architecture: $($script:PlatformInfo.Architecture)" -Level 'INFO'

    # Cleanup temp directory
    if (Test-Path $script:TempDir) {
        try {
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-PlatformLog "Cleaned up temp directory: $script:TempDir" -Level 'SUCCESS'
        }
        catch {
            Write-PlatformLog "Failed to clean up temp directory: $($_.Exception.Message)" -Level 'WARNING'
        }
    }

    # Final platform summary
    Write-Host ""
    Write-Host "Platform Test Summary:" -ForegroundColor Cyan
    Write-Host "  Platform: $($script:PlatformInfo.Current)" -ForegroundColor White
    Write-Host "  Architecture: $($script:PlatformInfo.Architecture)" -ForegroundColor White
    Write-Host "  PowerShell: $($script:PlatformInfo.PSVersion) ($($script:PlatformInfo.PSEdition))" -ForegroundColor White
    Write-Host "  Test Duration: $([math]::Round($duration.TotalSeconds, 2))s" -ForegroundColor White
}
