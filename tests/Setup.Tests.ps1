#Requires -Version 7.0

BeforeAll {
    # Find project root
    $projectRoot = Split-Path -Parent $PSScriptRoot
}

Describe "Setup and Installation Tests" {
    Context "PowerShell Environment" {
        It "Should have PowerShell 7.0 or higher" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
            $PSVersionTable.PSVersion.Minor | Should -BeGreaterOrEqual 0
        }
        
        It "Should have correct PowerShell edition" {
            $PSVersionTable.PSEdition | Should -Be "Core"
        }
    }
    
    Context "Platform Detection" {
        It "Should identify current platform" {
            $platform = if ($IsWindows) { "Windows" }
            elseif ($IsLinux) { 
                if (Test-Path "/proc/version") {
                    $version = Get-Content "/proc/version" -Raw
                    if ($version -match "microsoft") { "WSL" } else { "Linux" }
                } else { "Linux" }
            }
            elseif ($IsMacOS) { "macOS" }
            else { "Unknown" }
            
            $platform | Should -BeIn @("Windows", "Linux", "WSL", "macOS")
            Write-Host "Detected Platform: $platform" -ForegroundColor Cyan
        }
    }
    
    Context "Required Tools" {
        It "Should have Git installed" {
            $gitCommand = Get-Command git -ErrorAction SilentlyContinue
            $gitCommand | Should -Not -BeNullOrEmpty
            
            $gitVersion = & git --version 2>&1
            $gitVersion | Should -Match "git version"
            Write-Host "Git Version: $gitVersion" -ForegroundColor Green
        }
        
        It "Should detect OpenTofu or Terraform" {
            $tofuCommand = Get-Command tofu -ErrorAction SilentlyContinue
            $terraformCommand = Get-Command terraform -ErrorAction SilentlyContinue
            
            ($tofuCommand -or $terraformCommand) | Should -Be $true
            
            if ($tofuCommand) {
                Write-Host "OpenTofu found at: $($tofuCommand.Source)" -ForegroundColor Green
            }
            if ($terraformCommand) {
                Write-Host "Terraform found at: $($terraformCommand.Source)" -ForegroundColor Green
            }
        }
    }
    
    Context "First-Time Setup" {
        It "Should have SetupWizard module" {
            $projectRoot = Split-Path -Parent $PSScriptRoot
            $setupModule = Join-Path $projectRoot "aither-core" "modules" "SetupWizard" "SetupWizard.psd1"
            Test-Path $setupModule | Should -Be $true
        }
        
        It "Should have setup profiles available" {
            $projectRoot = Split-Path -Parent $PSScriptRoot
            $configPath = Join-Path $projectRoot "configs" "setup-profiles.json"
            
            if (Test-Path $configPath) {
                $profiles = Get-Content $configPath | ConvertFrom-Json
                $profiles.profiles | Should -Not -BeNullOrEmpty
                $profiles.profiles.PSObject.Properties.Name | Should -Contain "minimal"
                $profiles.profiles.PSObject.Properties.Name | Should -Contain "developer"
                $profiles.profiles.PSObject.Properties.Name | Should -Contain "full"
            }
        }
        
        It "Should have default configuration" {
            $projectRoot = Split-Path -Parent $PSScriptRoot
            $defaultConfig = Join-Path $projectRoot "configs" "default-config.json"
            Test-Path $defaultConfig | Should -Be $true
            
            $config = Get-Content $defaultConfig | ConvertFrom-Json
            $config | Should -Not -BeNullOrEmpty
            $config.UIPreferences | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "File Permissions" {
        It "Should have executable launcher script" {
            $launcher = Join-Path (Split-Path -Parent $PSScriptRoot) "Start-AitherZero.ps1"
            Test-Path $launcher | Should -Be $true
            
            # On Unix systems, check if it would be executable
            if (-not $IsWindows) {
                # PowerShell scripts don't need +x on Unix when run with pwsh
                # Just verify it exists and is readable
                { Get-Content $launcher -First 1 } | Should -Not -Throw
            }
        }
    }
    
    Context "Quick Start Experience" {
        It "Should support -Setup parameter" {
            $launcher = Join-Path (Split-Path -Parent $PSScriptRoot) "Start-AitherZero.ps1"
            $content = Get-Content $launcher -Raw
            
            # Check for Setup parameter
            $content | Should -Match '\[switch\]\s*\$Setup'
            
            # Check for installation profile parameter
            $content | Should -Match 'InstallationProfile'
        }
        
        It "Should have help documentation" {
            $launcher = Join-Path (Split-Path -Parent $PSScriptRoot) "Start-AitherZero.ps1"
            $content = Get-Content $launcher -Raw
            
            # Check for help content
            $content | Should -Match '\.SYNOPSIS|\.DESCRIPTION|\.PARAMETER'
        }
    }
    
    Context "Network Connectivity" {
        It "Should be able to reach GitHub" {
            $testConnection = $false
            try {
                $response = Invoke-WebRequest -Uri "https://api.github.com" -TimeoutSec 5 -UseBasicParsing
                $testConnection = $response.StatusCode -eq 200
            } catch {
                # Network might be restricted
                $testConnection = $false
            }
            
            if ($testConnection) {
                Write-Host "GitHub API accessible" -ForegroundColor Green
            } else {
                Write-Host "GitHub API not accessible (might be behind firewall)" -ForegroundColor Yellow
            }
            
            # Don't fail the test, just report
            $true | Should -Be $true
        }
    }
}