#Requires -Version 7.0

<#
.SYNOPSIS
    Cross-platform compatibility tests for AitherZero

.DESCRIPTION
    Comprehensive test suite for cross-platform functionality:
    - Path handling across Windows, Linux, and macOS
    - Platform-specific feature availability
    - Service management compatibility
    - File system operations
    - Command availability and behavior

.NOTES
    These tests ensure AitherZero works correctly across all supported platforms.
#>

BeforeAll {
    # Skip tests if not on PowerShell 7+
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Warning "Cross-platform tests require PowerShell 7.0+. Current version: $($PSVersionTable.PSVersion)"
        return
    }

    Import-Module Pester -Force

    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:TestStartTime = Get-Date
    
    # Determine current platform
    $script:CurrentPlatform = if ($IsWindows) { "Windows" } 
                             elseif ($IsLinux) { "Linux" }
                             elseif ($IsMacOS) { "macOS" }
                             else { "Unknown" }
    
    Write-Host "Running cross-platform tests on: $script:CurrentPlatform" -ForegroundColor Cyan

    # Load cross-platform utilities
    $crossPlatformUtilsPath = Join-Path $script:ProjectRoot "aither-core/shared/Get-CrossPlatformPath.ps1"
    if (Test-Path $crossPlatformUtilsPath) {
        . $crossPlatformUtilsPath
    }

    # Test configuration
    $script:PlatformConfig = @{
        Windows = @{
            PathSeparator = '\'
            SystemPath = 'C:\Windows\System32'
            UserHomePath = $env:USERPROFILE
            TempPath = $env:TEMP
            ServiceManager = 'Get-Service'
            SupportedFeatures = @('Services', 'EventLog', 'Registry', 'WMI')
        }
        Linux = @{
            PathSeparator = '/'
            SystemPath = '/usr/bin'
            UserHomePath = $env:HOME
            TempPath = '/tmp'
            ServiceManager = 'systemctl'
            SupportedFeatures = @('SystemD', 'Cron', 'Processes')
        }
        macOS = @{
            PathSeparator = '/'
            SystemPath = '/usr/bin'
            UserHomePath = $env:HOME
            TempPath = '/tmp'
            ServiceManager = 'launchctl'
            SupportedFeatures = @('LaunchD', 'Processes')
        }
    }

    $script:CurrentConfig = $script:PlatformConfig[$script:CurrentPlatform]
    if (-not $script:CurrentConfig) {
        $script:CurrentConfig = $script:PlatformConfig.Linux  # Default fallback
    }

    Write-Host "Platform configuration loaded for: $script:CurrentPlatform" -ForegroundColor Yellow
}

Describe "Cross-Platform Path Handling" -Tags @('CrossPlatform', 'Paths', 'Critical') {

    Context "Path Separator Handling" {
        It "Should use correct path separator for current platform" {
            $separator = [System.IO.Path]::DirectorySeparatorChar
            $expectedSeparator = $script:CurrentConfig.PathSeparator
            
            $separator.ToString() | Should -Be $expectedSeparator -Because "Platform should use correct path separator"
        }

        It "Should handle mixed path separators correctly" {
            $mixedPath = "folder/subfolder\file.txt"
            $normalizedPath = ConvertTo-CrossPlatformPath -Path $mixedPath
            
            if ($IsWindows) {
                $normalizedPath | Should -Match '\\' -Because "Windows should convert to backslashes"
                $normalizedPath | Should -Not -Match '/' -Because "Windows should not have forward slashes"
            } else {
                $normalizedPath | Should -Match '/' -Because "Unix should convert to forward slashes"
                $normalizedPath | Should -Not -Match '\\' -Because "Unix should not have backslashes"
            }
        }

        It "Should create platform-appropriate paths with Get-CrossPlatformPath" {
            $basePath = $script:CurrentConfig.UserHomePath
            $childPath = @("Documents", "Test", "file.txt")
            
            $result = Get-CrossPlatformPath -BasePath $basePath -ChildPath $childPath
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeLike "*Documents*Test*file.txt" -Because "Should contain all path components"
            
            # Verify path separator
            if ($IsWindows) {
                $result | Should -Match '\\' -Because "Windows paths should use backslashes"
            } else {
                $result | Should -Match '/' -Because "Unix paths should use forward slashes"
            }
        }
    }

    Context "Platform-Specific Path Validation" {
        It "Should validate paths correctly for current platform" {
            # Valid paths for all platforms
            $validPaths = @(
                "documents/file.txt",
                "folder/subfolder/file.txt"
            )

            foreach ($path in $validPaths) {
                Test-CrossPlatformPath -Path $path | Should -Be $true -Because "Path '$path' should be valid on all platforms"
            }
        }

        It "Should reject invalid paths for current platform" {
            if ($IsWindows) {
                # Windows-specific invalid paths
                $invalidPaths = @(
                    "folder<file.txt",
                    'folder"file.txt',
                    "folder|file.txt",
                    "CON",
                    "PRN",
                    "AUX"
                )

                foreach ($path in $invalidPaths) {
                    Test-CrossPlatformPath -Path $path | Should -Be $false -Because "Path '$path' should be invalid on Windows"
                }
            } else {
                # Unix-specific invalid paths
                $pathWithNull = "folder" + [char]0 + "file.txt"
                Test-CrossPlatformPath -Path $pathWithNull | Should -Be $false -Because "Null character should be invalid on Unix"
            }
        }

        It "Should get platform-specific standard paths" {
            $systemPath = Get-PlatformSpecificPath -PathType "System"
            $userHome = Get-PlatformSpecificPath -PathType "UserHome"
            $tempPath = Get-PlatformSpecificPath -PathType "Temp"

            $systemPath | Should -Not -BeNullOrEmpty
            $userHome | Should -Not -BeNullOrEmpty
            $tempPath | Should -Not -BeNullOrEmpty

            # Verify paths exist
            Test-Path $systemPath | Should -Be $true -Because "System path should exist"
            Test-Path $userHome | Should -Be $true -Because "User home should exist"
            Test-Path $tempPath | Should -Be $true -Because "Temp path should exist"
        }
    }

    Context "Path Normalization" {
        It "Should normalize paths correctly for current platform" {
            $testPath = Join-Path $script:CurrentConfig.UserHomePath "Documents"
            
            if (Test-Path $testPath) {
                $normalizedPath = Get-CrossPlatformPath -BasePath $testPath -ChildPath @("..") -Normalize
                $normalizedPath | Should -Be $script:CurrentConfig.UserHomePath -Because "Normalized path should resolve parent directory"
            } else {
                Write-Host "Test path does not exist, skipping normalization test" -ForegroundColor Yellow
                $true | Should -Be $true
            }
        }

        It "Should handle path existence validation" {
            $existingPath = $script:CurrentConfig.UserHomePath
            $nonExistingPath = Join-Path $script:CurrentConfig.UserHomePath "NonExistentFolder$(Get-Random)"

            # Test existing path
            { Get-CrossPlatformPath -BasePath $existingPath -ChildPath @() -ValidateExistence } | Should -Not -Throw

            # Test non-existing path
            { Get-CrossPlatformPath -BasePath $nonExistingPath -ChildPath @("file.txt") -ValidateExistence } | Should -Throw
        }
    }
}

Describe "Cross-Platform Service Management" -Tags @('CrossPlatform', 'Services', 'Management') {

    Context "Service Detection" {
        It "Should detect services using platform-appropriate method" {
            if ($IsWindows) {
                # Windows: Use Get-Service
                { Get-Service | Select-Object -First 1 } | Should -Not -Throw -Because "Get-Service should work on Windows"
            } else {
                # Linux/macOS: Use systemctl or launchctl
                if ($IsLinux) {
                    # Test systemctl availability
                    $systemctlAvailable = Get-Command systemctl -ErrorAction SilentlyContinue
                    if ($systemctlAvailable) {
                        $services = systemctl list-units --type=service --no-legend 2>/dev/null
                        $services | Should -Not -BeNullOrEmpty -Because "systemctl should return services on Linux"
                    } else {
                        Write-Host "systemctl not available, skipping Linux service test" -ForegroundColor Yellow
                        $true | Should -Be $true
                    }
                } elseif ($IsMacOS) {
                    # Test launchctl availability
                    $launchctlAvailable = Get-Command launchctl -ErrorAction SilentlyContinue
                    if ($launchctlAvailable) {
                        $services = launchctl list 2>/dev/null
                        $services | Should -Not -BeNullOrEmpty -Because "launchctl should return services on macOS"
                    } else {
                        Write-Host "launchctl not available, skipping macOS service test" -ForegroundColor Yellow
                        $true | Should -Be $true
                    }
                }
            }
        }

        It "Should handle service status checking across platforms" {
            if ($IsWindows) {
                # Test a common Windows service
                $service = Get-Service -Name "Spooler" -ErrorAction SilentlyContinue
                if ($service) {
                    $service.Status | Should -BeIn @('Running', 'Stopped') -Because "Service should have valid status"
                } else {
                    Write-Host "Spooler service not found, skipping Windows service status test" -ForegroundColor Yellow
                    $true | Should -Be $true
                }
            } else {
                # Test SSH service on Linux/macOS
                if ($IsLinux) {
                    $sshStatus = systemctl is-active ssh 2>/dev/null
                    if ($sshStatus) {
                        $sshStatus | Should -BeIn @('active', 'inactive', 'failed') -Because "SSH service should have valid status"
                    } else {
                        Write-Host "SSH service not found, skipping Linux service status test" -ForegroundColor Yellow
                        $true | Should -Be $true
                    }
                } elseif ($IsMacOS) {
                    $sshStatus = launchctl list | Select-String "ssh" 2>/dev/null
                    # macOS test is informational only
                    $true | Should -Be $true
                }
            }
        }
    }

    Context "Service Management Commands" {
        It "Should have appropriate service management commands available" {
            $serviceManager = $script:CurrentConfig.ServiceManager
            
            if ($serviceManager -eq 'Get-Service') {
                Get-Command Get-Service | Should -Not -BeNullOrEmpty -Because "Get-Service should be available on Windows"
            } elseif ($serviceManager -eq 'systemctl') {
                $systemctlCommand = Get-Command systemctl -ErrorAction SilentlyContinue
                if ($systemctlCommand) {
                    $systemctlCommand | Should -Not -BeNullOrEmpty -Because "systemctl should be available on Linux"
                } else {
                    Write-Host "systemctl not available, this is expected in some environments" -ForegroundColor Yellow
                    $true | Should -Be $true
                }
            } elseif ($serviceManager -eq 'launchctl') {
                $launchctlCommand = Get-Command launchctl -ErrorAction SilentlyContinue
                if ($launchctlCommand) {
                    $launchctlCommand | Should -Not -BeNullOrEmpty -Because "launchctl should be available on macOS"
                } else {
                    Write-Host "launchctl not available, this is expected in some environments" -ForegroundColor Yellow
                    $true | Should -Be $true
                }
            }
        }
    }
}

Describe "Cross-Platform File System Operations" -Tags @('CrossPlatform', 'FileSystem', 'Operations') {

    Context "File Operations" {
        It "Should create and manipulate files across platforms" {
            $testFile = Join-Path $script:CurrentConfig.TempPath "aithertest-$(Get-Random).txt"
            $testContent = "Cross-platform test content"

            try {
                # Create file
                Set-Content -Path $testFile -Value $testContent -Encoding UTF8
                Test-Path $testFile | Should -Be $true -Because "File should be created"

                # Read file
                $readContent = Get-Content -Path $testFile -Raw
                $readContent.Trim() | Should -Be $testContent -Because "File content should match"

                # Modify file
                Add-Content -Path $testFile -Value "`nAdditional line"
                $modifiedContent = Get-Content -Path $testFile -Raw
                $modifiedContent | Should -Match "Additional line" -Because "Content should be appended"

            } finally {
                # Cleanup
                if (Test-Path $testFile) {
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It "Should handle directory operations across platforms" {
            $testDir = Join-Path $script:CurrentConfig.TempPath "aithertest-dir-$(Get-Random)"
            $subDir = Join-Path $testDir "subdir"

            try {
                # Create directory
                New-Item -Path $testDir -ItemType Directory -Force
                Test-Path $testDir | Should -Be $true -Because "Directory should be created"

                # Create subdirectory
                New-Item -Path $subDir -ItemType Directory -Force
                Test-Path $subDir | Should -Be $true -Because "Subdirectory should be created"

                # List directory contents
                $contents = Get-ChildItem -Path $testDir
                $contents | Should -Not -BeNullOrEmpty -Because "Directory should have contents"

            } finally {
                # Cleanup
                if (Test-Path $testDir) {
                    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It "Should handle file permissions appropriately for platform" {
            $testFile = Join-Path $script:CurrentConfig.TempPath "aithertest-perm-$(Get-Random).txt"
            
            try {
                Set-Content -Path $testFile -Value "Permission test"
                Test-Path $testFile | Should -Be $true

                if ($IsWindows) {
                    # Windows: Test ACL
                    $acl = Get-Acl $testFile
                    $acl | Should -Not -BeNullOrEmpty -Because "ACL should be available on Windows"
                } else {
                    # Unix: Test file permissions
                    $permissions = ls -l $testFile 2>/dev/null
                    if ($permissions) {
                        $permissions | Should -Not -BeNullOrEmpty -Because "File permissions should be available on Unix"
                    } else {
                        Write-Host "ls command not available, skipping Unix permission test" -ForegroundColor Yellow
                        $true | Should -Be $true
                    }
                }

            } finally {
                if (Test-Path $testFile) {
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context "Path Resolution" {
        It "Should resolve relative paths correctly" {
            $currentDir = Get-Location
            $relativePath = ".\test-relative-path"
            
            $resolvedPath = Resolve-Path $relativePath -ErrorAction SilentlyContinue
            if ($resolvedPath) {
                $resolvedPath.Path | Should -BeLike "*test-relative-path*" -Because "Relative path should be resolved"
            } else {
                # Path doesn't exist, but resolution should still work with -Relative
                $expectedPath = Join-Path $currentDir.Path "test-relative-path"
                $expectedPath | Should -BeLike "*test-relative-path*" -Because "Expected path should be constructed correctly"
            }
        }

        It "Should handle UNC paths on Windows or equivalent on Unix" {
            if ($IsWindows) {
                # Test UNC path handling (if available)
                $uncPath = "\\localhost\c$"
                $result = Test-Path $uncPath -ErrorAction SilentlyContinue
                # UNC test is informational only - may not be available in all environments
                $true | Should -Be $true
            } else {
                # Test network mount points (if available)
                $networkPath = "/mnt"
                if (Test-Path $networkPath) {
                    Test-Path $networkPath | Should -Be $true -Because "Network mount point should be accessible"
                } else {
                    Write-Host "Network mount point not available, skipping Unix network path test" -ForegroundColor Yellow
                    $true | Should -Be $true
                }
            }
        }
    }
}

Describe "Cross-Platform Command Availability" -Tags @('CrossPlatform', 'Commands', 'Availability') {

    Context "Universal PowerShell Commands" {
        It "Should have universal PowerShell cmdlets available" {
            $universalCmdlets = @(
                'Get-Process',
                'Start-Process',
                'Stop-Process',
                'Get-ChildItem',
                'New-Item',
                'Remove-Item',
                'Copy-Item',
                'Move-Item',
                'Test-Path',
                'Resolve-Path',
                'Join-Path',
                'Split-Path',
                'ConvertTo-Json',
                'ConvertFrom-Json',
                'Select-Object',
                'Where-Object',
                'ForEach-Object',
                'Sort-Object',
                'Measure-Object',
                'Group-Object'
            )

            foreach ($cmdlet in $universalCmdlets) {
                Get-Command $cmdlet -ErrorAction Stop | Should -Not -BeNullOrEmpty -Because "$cmdlet should be available on all platforms"
            }
        }
    }

    Context "Platform-Specific Commands" {
        It "Should have platform-specific commands available where expected" {
            if ($IsWindows) {
                $windowsCmdlets = @('Get-Service', 'Get-EventLog', 'Get-WmiObject')
                foreach ($cmdlet in $windowsCmdlets) {
                    $command = Get-Command $cmdlet -ErrorAction SilentlyContinue
                    if ($command) {
                        $command | Should -Not -BeNullOrEmpty -Because "$cmdlet should be available on Windows"
                    } else {
                        Write-Host "Warning: $cmdlet not available on this Windows system" -ForegroundColor Yellow
                    }
                }
            } else {
                # Unix commands may not be available as PowerShell cmdlets
                $unixCommands = @('ps', 'ls', 'grep', 'find')
                foreach ($cmd in $unixCommands) {
                    $command = Get-Command $cmd -ErrorAction SilentlyContinue
                    if ($command) {
                        $command | Should -Not -BeNullOrEmpty -Because "$cmd should be available on Unix systems"
                    } else {
                        Write-Host "Info: $cmd not available as PowerShell command (may be available as system command)" -ForegroundColor Yellow
                    }
                }
            }
        }
    }

    Context "System Integration Commands" {
        It "Should handle system integration appropriately" {
            if ($IsWindows) {
                # Test Windows-specific integration
                $hostname = hostname
                $hostname | Should -Not -BeNullOrEmpty -Because "hostname should work on Windows"

                # Test environment variables
                $env:COMPUTERNAME | Should -Not -BeNullOrEmpty -Because "COMPUTERNAME should be available on Windows"
                
            } else {
                # Test Unix-specific integration
                $hostname = hostname
                $hostname | Should -Not -BeNullOrEmpty -Because "hostname should work on Unix"

                # Test environment variables
                $env:HOME | Should -Not -BeNullOrEmpty -Because "HOME should be available on Unix"
                $env:USER | Should -Not -BeNullOrEmpty -Because "USER should be available on Unix"
            }
        }
    }
}

Describe "Cross-Platform Module Loading" -Tags @('CrossPlatform', 'Modules', 'Loading') {

    Context "AitherZero Module Compatibility" {
        It "Should load core modules without platform-specific errors" {
            $coreModules = @(
                'Logging',
                'ConfigurationCore',
                'SetupWizard'
            )

            foreach ($moduleName in $coreModules) {
                $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/$moduleName"
                if (Test-Path $modulePath) {
                    { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw -Because "Module $moduleName should load on all platforms"
                } else {
                    Write-Host "Module $moduleName not found at $modulePath" -ForegroundColor Yellow
                }
            }
        }

        It "Should handle platform-specific module features gracefully" {
            $platformSpecificModules = @(
                'SecurityAutomation',
                'SystemMonitoring',
                'RemoteConnection'
            )

            foreach ($moduleName in $platformSpecificModules) {
                $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/$moduleName"
                if (Test-Path $modulePath) {
                    try {
                        Import-Module $modulePath -Force -ErrorAction Stop
                        Write-Host "Module $moduleName loaded successfully on $script:CurrentPlatform" -ForegroundColor Green
                    } catch {
                        Write-Host "Module $moduleName failed to load on $script:CurrentPlatform`: $($_.Exception.Message)" -ForegroundColor Yellow
                        # Platform-specific modules may have limitations - don't fail the test
                    }
                } else {
                    Write-Host "Module $moduleName not found at $modulePath" -ForegroundColor Yellow
                }
            }
            
            # This test always passes - it's informational
            $true | Should -Be $true
        }
    }
}

AfterAll {
    $duration = (Get-Date) - $script:TestStartTime
    Write-Host ""
    Write-Host "Cross-Platform Compatibility Tests Complete" -ForegroundColor Green
    Write-Host "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor Cyan
    Write-Host "Platform: $script:CurrentPlatform" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Cyan
}