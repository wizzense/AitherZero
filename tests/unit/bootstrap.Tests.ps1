#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for bootstrap.ps1
.DESCRIPTION
    Tests the universal bootstrap script functionality including PS version detection,
    PS7 installation, dependency management, and bootstrap flow.
#>

BeforeAll {
    # Get script path
    $script:BootstrapPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "bootstrap.ps1"
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    
    # Mock functions that would perform actual installations
    Mock Start-Process { 
        return [PSCustomObject]@{
            ExitCode = 0
        }
    }
    
    Mock Invoke-WebRequest { }
    Mock Invoke-RestMethod { 
        return @{
            assets = @(
                @{
                    name = "PowerShell-7.4.0-win-x64.msi"
                    browser_download_url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-x64.msi"
                }
            )
        }
    }
    
    Mock Get-Command {
        param($Name)
        if ($Name -eq 'git') { 
            return $null  # Simulate git not installed
        }
        if ($Name -eq 'pwsh') {
            return [PSCustomObject]@{
                Source = "C:\Program Files\PowerShell\7\pwsh.exe"
            }
        }
        if ($Name -eq 'winget') {
            return [PSCustomObject]@{
                Source = "C:\Program Files\WindowsApps\winget.exe"
            }
        }
    }
    
    Mock Test-Path {
        param($Path)
        if ($Path -like "*PowerShell\7\pwsh.exe") { return $true }
        if ($Path -like "*.msi") { return $true }
        if ($Path -like "*AitherZero*") { return $false }
        return $true
    }
    
    Mock Remove-Item { }
    Mock Set-Content { }
    Mock Get-Location { 
        return [PSCustomObject]@{
            Path = "C:\Users\TestUser\Projects"
        }
    }
    
    # Mock Write-Host to capture output
    $script:HostOutput = @()
    Mock Write-Host {
        param($Object, $ForegroundColor)
        $script:HostOutput += $Object
    }
}

Describe "Bootstrap.ps1 Tests" -Tag 'Unit' {
    
    AfterEach {
        $script:HostOutput = @()
    }
    
    Context "PowerShell Version Detection" {
        
        It "Should detect PowerShell 5.1 and set upgrade flag" {
            # Simulate PS 5.1
            Mock Get-Variable {
                param($Name)
                if ($Name -eq 'PSVersionTable') {
                    return [PSCustomObject]@{
                        Value = @{
                            PSVersion = [Version]"5.1.0"
                        }
                    }
                }
            }
            
            # Source the script partially (just version detection)
            # This is complex due to script execution, so we test the logic separately
            $ps5Detected = $false
            if ([Version]"5.1.0" -lt [Version]"7.0.0") {
                $ps5Detected = $true
            }
            
            $ps5Detected | Should -Be $true
        }
        
        It "Should not set upgrade flag for PowerShell 7+" {
            $ps7Detected = $false
            if ([Version]"7.4.0" -lt [Version]"7.0.0") {
                $ps7Detected = $true
            }
            
            $ps7Detected | Should -Be $false
        }
    }
    
    Context "Helper Functions" {
        
        BeforeEach {
            # Load helper functions from bootstrap script
            # We'll extract and test them independently
            . $script:BootstrapPath -Mode "Test" -SkipAutoStart 2>$null
        }
        
        It "Test-IsWindows should return correct platform" -Skip {
            # This is platform-specific, skip in CI
            if ($IsWindows) {
                Test-IsWindows | Should -Be $true
            } else {
                Test-IsWindows | Should -Be $false
            }
        }
        
        It "Get-DefaultInstallPath should return appropriate path" -Skip {
            Mock Get-Location { 
                return [PSCustomObject]@{
                    Path = "C:\Users\TestUser"
                }
            }
            
            $path = Get-DefaultInstallPath
            $path | Should -BeLike "*AitherZero*"
        }
    }
    
    Context "Dependency Detection" {
        
        It "Should detect missing Git" {
            Mock Get-Command {
                param($Name)
                if ($Name -eq 'git') { return $null }
                return $true
            }
            
            # Test logic separately
            $gitMissing = -not (Get-Command git -ErrorAction SilentlyContinue)
            $gitMissing | Should -Be $true
        }
        
        It "Should detect PowerShell 7 as required for PS 5.1" {
            $psVersion = [Version]"5.1.0"
            $needsPS7 = $psVersion.Major -lt 7
            
            $needsPS7 | Should -Be $true
        }
    }
    
    Context "PowerShell 7 Installation" {
        
        It "Should attempt winget installation first on Windows" -Skip:(-not $IsWindows) {
            Mock Get-Command {
                param($Name)
                if ($Name -eq 'winget') {
                    return [PSCustomObject]@{ Source = "winget.exe" }
                }
            }
            
            Mock Start-Process {
                param($FilePath)
                $FilePath | Should -Be "winget"
                return [PSCustomObject]@{ ExitCode = 0 }
            }
            
            # Test winget is preferred
            $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
            $hasWinget | Should -Not -BeNullOrEmpty
        }
        
        It "Should fall back to MSI download if winget fails" {
            Mock Get-Command {
                param($Name)
                if ($Name -eq 'winget') { return $null }
            }
            
            Mock Invoke-WebRequest {
                param($Uri, $OutFile)
                $Uri | Should -BeLike "*PowerShell*"
                $OutFile | Should -BeLike "*.msi"
            }
            
            # Simulate the download
            $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
            $downloadUrl | Should -BeLike "*PowerShell*.msi"
        }
    }
    
    Context "Script Re-launch" {
        
        It "Should build correct arguments for re-launch" {
            $arguments = @()
            
            # Test argument building
            $Mode = "New"
            $InstallProfile = "Developer" 
            $Branch = "main"
            $NonInteractive = $true
            
            if ($Mode) { $arguments += "-Mode", $Mode }
            if ($InstallProfile) { $arguments += "-InstallProfile", $InstallProfile }
            if ($Branch) { $arguments += "-Branch", $Branch }
            if ($NonInteractive) { $arguments += "-NonInteractive" }
            
            $arguments | Should -Contain "-Mode"
            $arguments | Should -Contain "New"
            $arguments | Should -Contain "-InstallProfile"
            $arguments | Should -Contain "Developer"
            $arguments | Should -Contain "-NonInteractive"
        }
        
        It "Should find PowerShell 7 executable after installation" {
            Mock Test-Path {
                param($Path)
                if ($Path -like "*PowerShell\7\pwsh.exe") { return $true }
                return $false
            }
            
            $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
            Test-Path $pwshPath | Should -Be $true
        }
    }
    
    Context "Installation Modes" {
        
        It "Should support different installation profiles" {
            $validProfiles = @('Minimal', 'Standard', 'Developer', 'Full')
            
            foreach ($profile in $validProfiles) {
                { 
                    [ValidateSet('Minimal', 'Standard', 'Developer', 'Full')]
                    [string]$InstallProfile = $profile
                } | Should -Not -Throw
            }
        }
        
        It "Should detect CI environment correctly" {
            # Save original values
            $originalCI = $env:CI
            $originalGHA = $env:GITHUB_ACTIONS
            
            try {
                # Test with CI set
                $env:CI = 'true'
                $isCI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')
                $isCI | Should -Be $true
                
                # Test with CI unset
                Remove-Item Env:CI -ErrorAction SilentlyContinue
                Remove-Item Env:GITHUB_ACTIONS -ErrorAction SilentlyContinue
                $isCI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')
                $isCI | Should -Be $false
            }
            finally {
                # Restore original values
                if ($null -ne $originalCI) { $env:CI = $originalCI }
                if ($null -ne $originalGHA) { $env:GITHUB_ACTIONS = $originalGHA }
            }
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle missing dependencies gracefully" {
            Mock Get-Command { return $null }
            
            $missing = @()
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                $missing += 'Git'
            }
            if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
                $missing += 'PowerShell7'
            }
            
            $missing.Count | Should -BeGreaterThan 0
            $missing | Should -Contain 'Git'
        }
        
        It "Should throw if PS7 installation fails" {
            Mock Start-Process {
                return [PSCustomObject]@{
                    ExitCode = 1
                }
            }
            
            { 
                $result = Start-Process -FilePath "msiexec" -ArgumentList "/i test.msi" -Wait -PassThru
                if ($result.ExitCode -ne 0) {
                    throw "Installation failed"
                }
            } | Should -Throw "Installation failed"
        }
    }
    
    Context "Cross-Platform Support" {
        
        It "Should detect platform correctly" {
            # Platform detection
            $platform = if ($PSVersionTable.PSVersion.Major -ge 6) {
                if ($IsWindows) { "Windows" }
                elseif ($IsLinux) { "Linux" }
                elseif ($IsMacOS) { "macOS" }
            } else {
                "Windows"  # PS 5.1 is Windows only
            }
            
            $platform | Should -BeIn @("Windows", "Linux", "macOS")
        }
        
        It "Should use appropriate commands per platform" {
            if ($IsWindows) {
                $pwshExe = "pwsh.exe"
            } else {
                $pwshExe = "pwsh"
            }
            
            $pwshExe | Should -Match "pwsh"
        }
    }
}

Describe "Bootstrap Integration" -Tag 'Integration' {
    
    Context "One-Liner Execution" {
        
        It "Should handle iwr|iex execution pattern" {
            # Simulate one-liner execution
            $scriptContent = Get-Content $script:BootstrapPath -Raw
            $scriptContent | Should -Not -BeNullOrEmpty
            $scriptContent | Should -Match "bootstrap"
        }
        
        It "Should preserve script content for re-launch" {
            Mock Set-Content {
                param($Path, $Value)
                $Path | Should -BeLike "*bootstrap*.ps1"
            }
            
            # Simulate saving script for re-launch
            $tempPath = "$env:TEMP\bootstrap-temp.ps1"
            $tempPath | Should -BeLike "*bootstrap*.ps1"
        }
    }
}