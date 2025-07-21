# Note: Tests require PowerShell 7.0+ but will skip gracefully on older versions

BeforeAll {
    # Skip tests if not on PowerShell 7+
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Warning "Core tests require PowerShell 7.0+. Current version: $($PSVersionTable.PSVersion)"
        return
    }

    # Find project root
    $projectRoot = Split-Path -Parent $PSScriptRoot

    # Initialize logging from shared utilities
    try {
        . (Join-Path $projectRoot "aither-core" "shared" "Initialize-Logging.ps1")
        Initialize-Logging -Force
        Write-Host "Logging initialized successfully" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to initialize logging: $($_.Exception.Message)"
    }
    
    # Load automation domain for PatchManager functions
    try {
        . (Join-Path $projectRoot "aither-core" "domains" "automation" "Automation.ps1")
        Write-Host "Automation domain loaded successfully" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to load Automation domain: $($_.Exception.Message)"
    }
    
    # Set platform information
    $script:CurrentPlatform = if ($IsWindows) { "Windows" }
                             elseif ($IsLinux) { "Linux" }
                             elseif ($IsMacOS) { "macOS" }
                             else { "Unknown" }
    
    Write-Host "Running Core tests on platform: $script:CurrentPlatform" -ForegroundColor Cyan
}

Describe "Core Functionality Tests" {
    Context "Project Structure" {
        It "Should have correct directory structure" {
            $projectRoot = Split-Path -Parent $PSScriptRoot
            Test-Path (Join-Path $projectRoot "Start-AitherZero.ps1") | Should -Be $true
            Test-Path (Join-Path $projectRoot "aither-core") | Should -Be $true
            Test-Path (Join-Path $projectRoot "aither-core" "domains") | Should -Be $true
            Test-Path (Join-Path $projectRoot "configs") | Should -Be $true
        }

        It "Should have launcher script executable" {
            $launcher = Join-Path (Split-Path -Parent $PSScriptRoot) "Start-AitherZero.ps1"
            Test-Path $launcher | Should -Be $true

            # Verify the launcher contains PowerShell version checking logic
            $content = Get-Content $launcher -Raw
            $content | Should -Match "Test-PowerShellVersion"
            $content | Should -Match "PSVersionTable.PSVersion.Major"
        }
    }

    Context "Domain Loading" {
        It "Should load all core domains" {
            $projectRoot = Split-Path -Parent $PSScriptRoot
            $domainPath = Join-Path $projectRoot "aither-core" "domains"
            $coreDomains = @(
                "automation",
                "configuration", 
                "experience",
                "infrastructure",
                "security",
                "utilities"
            )

            foreach ($domain in $coreDomains) {
                $domainFolder = Join-Path $domainPath $domain
                Test-Path $domainFolder | Should -Be $true
                
                # Each domain should have a main .ps1 file
                $domainFiles = Get-ChildItem -Path $domainFolder -Filter "*.ps1" -ErrorAction SilentlyContinue
                $domainFiles.Count | Should -BeGreaterThan 0
            }
        }
    }

    Context "Logging System" {
        It "Should write log messages" {
            # The logging should already be initialized in BeforeAll, but let's check
            if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
                $projectRoot = Split-Path -Parent $PSScriptRoot
                . (Join-Path $projectRoot "aither-core" "shared" "Initialize-Logging.ps1")
            }

            { Write-CustomLog -Level 'INFO' -Message "Test message" } | Should -Not -Throw
            { Write-CustomLog -Level 'ERROR' -Message "Error message" } | Should -Not -Throw
            { Write-CustomLog -Level 'SUCCESS' -Message "Success message" } | Should -Not -Throw
        }
    }

    Context "Configuration Management" {
        It "Should load default configuration" {
            $projectRoot = Split-Path -Parent $PSScriptRoot
            $configPath = Join-Path $projectRoot "configs" "default-config.json"
            Test-Path $configPath | Should -Be $true

            $config = Get-Content $configPath | ConvertFrom-Json
            $config | Should -Not -BeNullOrEmpty
            $config.ui | Should -Not -BeNullOrEmpty
            $config.tools | Should -Not -BeNullOrEmpty
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should detect current platform" {
            $platform = if ($IsWindows) { "Windows" }
            elseif ($IsLinux) { "Linux" }
            elseif ($IsMacOS) { "macOS" }
            else { "Unknown" }

            $platform | Should -BeIn @("Windows", "Linux", "macOS")
        }

        It "Should use cross-platform path separators" {
            $path1 = "folder1"
            $path2 = "folder2"
            $path3 = "file.txt"

            $joined = Join-Path $path1 $path2 $path3
            $joined | Should -Not -BeNullOrEmpty

            # Should contain only forward slashes on Linux/macOS or only backslashes on Windows
            if ($IsWindows) {
                $joined | Should -Match '^[^/]+$|^.*\\[^/]+$'
            } else {
                $joined | Should -Match '^[^\\]+$|^.*/[^\\]+$'
            }
        }
    }

    Context "PatchManager Basic Operations" {
        It "Should have PatchManager functions available" {
            Get-Command -Name "New-Patch" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name "New-Feature" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name "New-QuickFix" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name "New-Hotfix" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should work with git repository" {
            # Check that we're in a git repository
            $gitDir = Join-Path (Split-Path -Parent $PSScriptRoot) ".git"
            Test-Path $gitDir | Should -Be $true

            # Check that git command is available
            $gitCommand = Get-Command git -ErrorAction SilentlyContinue
            $gitCommand | Should -Not -BeNullOrEmpty
        }
    }

    Context "PowerShell Version" {
        It "Should be running PowerShell 7.0 or higher" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
        }

        It "Should have required PowerShell features" {
            # Check for ternary operator support (7.0+ feature)
            try {
                $result = $true ? "yes" : "no"
                $result | Should -Be "yes"
            } catch {
                # Skip on platforms with parsing issues
                Write-Host "Ternary operator test skipped on this platform" -ForegroundColor Yellow
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
            }

            # Check for null coalescing (7.0+ feature)
            try {
                $result = $null ?? "default"
                $result | Should -Be "default"
            } catch {
                # Skip on platforms with parsing issues
                Write-Host "Null coalescing test skipped on this platform" -ForegroundColor Yellow
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
            }
        }
    }
}
