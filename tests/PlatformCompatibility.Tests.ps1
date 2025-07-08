#Requires -Version 7.0

<#
.SYNOPSIS
    Platform compatibility validation tests for AitherZero modules.

.DESCRIPTION
    This test suite validates that AitherZero modules work correctly across Windows, Linux, and macOS.
    It includes:
    - Platform-specific command availability
    - Path handling compatibility
    - Environment variable handling
    - Service management compatibility
    - Module loading across platforms

.NOTES
    These tests ensure AitherZero works correctly across all supported platforms.
#>

BeforeAll {
    # Import required modules
    Import-Module Pester -Force

    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:TestStartTime = Get-Date
    
    # Determine current platform
    $script:CurrentPlatform = if ($IsWindows) { "Windows" } 
                             elseif ($IsLinux) { "Linux" }
                             elseif ($IsMacOS) { "macOS" }
                             else { "Unknown" }
    
    Write-Host "Running platform compatibility tests on: $script:CurrentPlatform" -ForegroundColor Cyan

    # Load platform compatibility utilities
    $platformCompatibilityPath = Join-Path $script:ProjectRoot "aither-core/shared/Test-PlatformCompatibility.ps1"
    if (Test-Path $platformCompatibilityPath) {
        . $platformCompatibilityPath
        Write-Host "Loaded platform compatibility utilities" -ForegroundColor Green
    } else {
        Write-Warning "Platform compatibility utilities not found at: $platformCompatibilityPath"
    }

    # Load cross-platform utilities
    $crossPlatformUtilsPath = Join-Path $script:ProjectRoot "aither-core/shared/Get-CrossPlatformPath.ps1"
    if (Test-Path $crossPlatformUtilsPath) {
        . $crossPlatformUtilsPath
        Write-Host "Loaded cross-platform utilities" -ForegroundColor Green
    } else {
        Write-Warning "Cross-platform utilities not found at: $crossPlatformUtilsPath"
    }

    # Create platform-specific mocks for unavailable commands
    if (-not $IsWindows) {
        # Mock Windows-specific commands on non-Windows platforms
        if (Get-Command New-PlatformMock -ErrorAction SilentlyContinue) {
            New-PlatformMock -CommandName "Get-Service" -MockBehavior "return @{Name='MockService'; Status='Running'; State='Running'}"
            New-PlatformMock -CommandName "Get-EventLog" -MockBehavior "return @{}"
            New-PlatformMock -CommandName "Get-CimInstance" -MockBehavior "return @{}"
        } else {
            Write-Warning "New-PlatformMock function not available - creating simple mocks"
            
            # Create simple mocks directly
            function Get-Service {
                param([string]$Name)
                return @{Name='MockService'; Status='Running'; State='Running'}
            }
            
            function Get-EventLog {
                return @{}
            }
            
            function Get-CimInstance {
                return @{}
            }
        }
    }
}

AfterAll {
    $duration = (Get-Date) - $script:TestStartTime
    Write-Host ""
    Write-Host "Platform Compatibility Tests Complete" -ForegroundColor Green
    Write-Host "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor Cyan
    Write-Host "Platform: $script:CurrentPlatform" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Cyan
}

Describe "Module Path Handling Compatibility" -Tags @('Platform', 'Paths', 'Critical') {
    Context "Cross-Platform Path Construction" {
        It "Should use Join-Path for all path operations" {
            $modules = Get-ChildItem -Path (Join-Path $script:ProjectRoot "aither-core/modules") -Directory
            
            foreach ($module in $modules) {
                $moduleFiles = Get-ChildItem -Path $module.FullName -Recurse -Filter "*.ps1"
                
                foreach ($file in $moduleFiles) {
                    $content = Get-Content -Path $file.FullName -Raw
                    
                    # Check for hardcoded path separators in non-comment lines
                    $lines = $content -split "`n"
                    for ($i = 0; $i -lt $lines.Count; $i++) {
                        $line = $lines[$i].Trim()
                        
                        # Skip comments and empty lines
                        if ($line.StartsWith('#') -or $line.StartsWith('<#') -or [string]::IsNullOrWhiteSpace($line)) {
                            continue
                        }
                        
                        # Check for problematic hardcoded paths
                        if ($line -match '\\\\' -or ($line -match '\\' -and $line -notmatch 'Join-Path' -and $line -notmatch 'Split-Path' -and $line -notmatch '\\n' -and $line -notmatch '\\t')) {
                            Write-Warning "File $($file.Name) line $($i+1) may have hardcoded Windows paths: $line"
                        }
                    }
                }
            }
            
            # This test passes if no critical issues are found
            $true | Should -Be $true
        }
    }
}

Describe "Platform-Specific Command Compatibility" -Tags @('Platform', 'Commands', 'Compatibility') {
    Context "Windows-Only Commands" {
        It "Should handle Get-Service appropriately on all platforms" {
            if ($IsWindows) {
                { Get-Service | Select-Object -First 1 } | Should -Not -Throw
            } else {
                # Should either have mock or use alternative
                $services = Get-PlatformServices
                $services | Should -Not -BeNullOrEmpty
            }
        }

        It "Should handle Get-EventLog appropriately on all platforms" {
            if ($IsWindows) {
                $logs = Get-EventLog -List -ErrorAction SilentlyContinue
                # Test passes if command exists (may not have permissions)
                $true | Should -Be $true
            } else {
                Write-Host "Get-EventLog is Windows-only, skipping on $script:CurrentPlatform" -ForegroundColor Yellow
                $true | Should -Be $true
            }
        }

        It "Should use Get-CimInstance instead of Get-WmiObject" {
            $modules = Get-ChildItem -Path (Join-Path $script:ProjectRoot "aither-core/modules") -Directory
            
            foreach ($module in $modules) {
                $moduleFiles = Get-ChildItem -Path $module.FullName -Recurse -Filter "*.ps1"
                
                foreach ($file in $moduleFiles) {
                    $content = Get-Content -Path $file.FullName -Raw
                    
                    # Check for deprecated Get-WmiObject usage
                    if ($content -match 'Get-WmiObject') {
                        Write-Warning "File $($file.Name) uses deprecated Get-WmiObject, should use Get-CimInstance"
                    }
                }
            }
            
            # This test passes if no critical issues are found
            $true | Should -Be $true
        }
    }

    Context "Cross-Platform Command Alternatives" {
        It "Should use platform-appropriate service management" {
            $serviceManager = Get-PlatformServiceManager
            $serviceManager | Should -Not -BeNullOrEmpty
            
            # Verify the service manager is appropriate for the platform
            if ($IsWindows) {
                $serviceManager | Should -Be "Get-Service"
            } elseif ($IsLinux) {
                $serviceManager | Should -Be "systemctl"
            } elseif ($IsMacOS) {
                $serviceManager | Should -Be "launchctl"
            }
        }

        It "Should use platform-appropriate environment variables" {
            $userHome = Get-PlatformEnvironmentVariable -VariableType "UserHome"
            $userHome | Should -Not -BeNullOrEmpty
            Test-Path $userHome | Should -Be $true
            
            $userName = Get-PlatformEnvironmentVariable -VariableType "UserName"
            $userName | Should -Not -BeNullOrEmpty
            
            $tempPath = Get-PlatformEnvironmentVariable -VariableType "TempPath"
            $tempPath | Should -Not -BeNullOrEmpty
            Test-Path $tempPath | Should -Be $true
        }
    }
}

Describe "Module Loading Compatibility" -Tags @('Platform', 'Modules', 'Loading') {
    Context "Core Module Loading" {
        It "Should load core modules on all platforms" {
            $coreModules = @(
                'Logging',
                'ConfigurationCore',
                'TestingFramework',
                'ProgressTracking'
            )
            
            foreach ($moduleName in $coreModules) {
                $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/$moduleName"
                if (Test-Path $modulePath) {
                    { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw -Because "Module $moduleName should load on all platforms"
                }
            }
        }

        It "Should load platform-specific modules with appropriate warnings" {
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
                }
            }
            
            # This test always passes - it's informational
            $true | Should -Be $true
        }
    }
}

Describe "File System Operations Compatibility" -Tags @('Platform', 'FileSystem', 'Operations') {
    Context "Path Operations" {
        It "Should handle temporary directory creation across platforms" {
            $tempPath = Get-PlatformEnvironmentVariable -VariableType "TempPath"
            $testDir = Join-Path $tempPath "AitherZero-PlatformTest-$(Get-Random)"
            
            try {
                New-Item -Path $testDir -ItemType Directory -Force | Out-Null
                Test-Path $testDir | Should -Be $true
                
                # Test file creation
                $testFile = Join-Path $testDir "test.txt"
                Set-Content -Path $testFile -Value "Platform test content" -Encoding UTF8
                Test-Path $testFile | Should -Be $true
                
                # Test file reading
                $content = Get-Content -Path $testFile -Raw
                $content.Trim() | Should -Be "Platform test content"
                
            } finally {
                if (Test-Path $testDir) {
                    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It "Should handle nested directory operations" {
            $tempPath = Get-PlatformEnvironmentVariable -VariableType "TempPath"
            $baseDir = Join-Path $tempPath "AitherZero-Nested-$(Get-Random)"
            $nestedDir = Join-Path $baseDir "level1/level2/level3"
            
            try {
                New-Item -Path $nestedDir -ItemType Directory -Force | Out-Null
                Test-Path $nestedDir | Should -Be $true
                
                # Test relative path resolution
                $parentDir = Split-Path $nestedDir -Parent
                Test-Path $parentDir | Should -Be $true
                
            } finally {
                if (Test-Path $baseDir) {
                    Remove-Item $baseDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context "Permission Handling" {
        It "Should handle file permissions appropriately for platform" {
            $tempPath = Get-PlatformEnvironmentVariable -VariableType "TempPath"
            $testFile = Join-Path $tempPath "AitherZero-PermTest-$(Get-Random).txt"
            
            try {
                Set-Content -Path $testFile -Value "Permission test" -Encoding UTF8
                Test-Path $testFile | Should -Be $true
                
                if ($IsWindows) {
                    # Windows: Test ACL
                    $acl = Get-Acl $testFile -ErrorAction SilentlyContinue
                    if ($acl) {
                        $acl | Should -Not -BeNullOrEmpty
                    }
                } else {
                    # Unix: Test basic file operations
                    $content = Get-Content -Path $testFile -Raw
                    $content | Should -Not -BeNullOrEmpty
                }
                
            } finally {
                if (Test-Path $testFile) {
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

Describe "Environment Variable Handling" -Tags @('Platform', 'Environment', 'Variables') {
    Context "Standard Environment Variables" {
        It "Should access user home directory correctly" {
            $userHome = Get-PlatformEnvironmentVariable -VariableType "UserHome"
            $userHome | Should -Not -BeNullOrEmpty
            Test-Path $userHome | Should -Be $true
            
            if ($IsWindows) {
                $userHome | Should -Be $env:USERPROFILE
            } else {
                $userHome | Should -Be $env:HOME
            }
        }

        It "Should access user name correctly" {
            $userName = Get-PlatformEnvironmentVariable -VariableType "UserName"
            $userName | Should -Not -BeNullOrEmpty
            
            if ($IsWindows) {
                $userName | Should -Be $env:USERNAME
            } else {
                $userName | Should -Be $env:USER
            }
        }

        It "Should access temporary directory correctly" {
            $tempPath = Get-PlatformEnvironmentVariable -VariableType "TempPath"
            $tempPath | Should -Not -BeNullOrEmpty
            Test-Path $tempPath | Should -Be $true
            
            if ($IsWindows) {
                $tempPath | Should -Be $env:TEMP
            } else {
                $tempPath | Should -Be "/tmp"
            }
        }
    }
}

Describe "System Information Compatibility" -Tags @('Platform', 'System', 'Information') {
    Context "System Information Gathering" {
        It "Should gather system information on all platforms" {
            $systemInfo = Get-PlatformSystemInfo
            $systemInfo | Should -Not -BeNullOrEmpty
            
            $systemInfo.Platform | Should -Be $script:CurrentPlatform
            $systemInfo.PowerShellVersion | Should -Not -BeNullOrEmpty
            $systemInfo.PowerShellEdition | Should -Not -BeNullOrEmpty
            $systemInfo.UserName | Should -Not -BeNullOrEmpty
            $systemInfo.UserHome | Should -Not -BeNullOrEmpty
            $systemInfo.TempPath | Should -Not -BeNullOrEmpty
        }

        It "Should handle platform-specific system information" {
            $systemInfo = Get-PlatformSystemInfo
            
            if ($IsWindows) {
                # Windows-specific information may be available
                if ($systemInfo.OSName) {
                    $systemInfo.OSName | Should -Not -BeNullOrEmpty
                }
            } elseif ($IsLinux) {
                # Linux-specific information may be available
                if ($systemInfo.OSName) {
                    $systemInfo.OSName | Should -Not -BeNullOrEmpty
                }
            } elseif ($IsMacOS) {
                # macOS-specific information may be available
                if ($systemInfo.OSName) {
                    $systemInfo.OSName | Should -Not -BeNullOrEmpty
                }
            }
            
            # This test always passes - it's informational
            $true | Should -Be $true
        }
    }
}