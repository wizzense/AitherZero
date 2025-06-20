#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Tests for 0000_Cleanup-Files.ps1
.DESCRIPTION
    Comprehensive tests for the file cleanup script including validation,
    execution, and cross-platform compatibility.
#>

BeforeAll {
    # Set up paths
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $script:ScriptPath = Join-Path $ProjectRoot "aither-core/scripts/0000_Cleanup-Files.ps1"
    $script:LabRunnerPath = Join-Path $ProjectRoot "pwsh\modules\LabRunner"
    
    # Mock the LabRunner module functions
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message" -ForegroundColor Green
    }
    
    function global:Invoke-LabStep {
        param([object]$Config, [scriptblock]$Body)
        & $Body
    }
    
    function global:Get-CrossPlatformTempPath {
        if ($IsWindows) { return $env:TEMP }
        else { return "/tmp" }
    }
    
    # Create test configuration
    $script:TestConfig = @{
        LocalPath = Get-CrossPlatformTempPath
        RepoUrl = "https://github.com/test/test-repo.git"
        InfraRepoPath = Join-Path (Get-CrossPlatformTempPath) "test-infra"
    }
}

Describe '0000_Cleanup-Files Script Tests' {
    
    Context 'Script Validation' {
        It 'Should exist' {
            Test-Path $script:ScriptPath | Should -Be $true
        }
        
        It 'Should have valid PowerShell syntax' {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0
        }
        
        It 'Should have required parameters' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Param\s*\(\s*\[object\]\s*\$Config\s*\)'
        }
        
        It 'Should import LabRunner module' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Import-Module.*LabRunner'
        }
        
        It 'Should use Invoke-LabStep' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Invoke-LabStep'
        }
    }
    
    Context 'Function Execution' {
        BeforeEach {
            # Set up test directories
            $testRepoPath = Join-Path $script:TestConfig.LocalPath "test-repo"
            $testInfraPath = $script:TestConfig.InfraRepoPath
            
            # Create test directories if they don't exist
            if (-not (Test-Path $testRepoPath)) {
                if (-not (Test-Path $testRepoPath)) { New-Item -Path $testRepoPath -ItemType Directory -Force | Out-Null }
            }
            if (-not (Test-Path $testInfraPath)) {
                if (-not (Test-Path $testInfraPath)) { New-Item -Path $testInfraPath -ItemType Directory -Force | Out-Null }
            }
        }
        
        It 'Should execute without errors with valid config' {
            { & $script:ScriptPath -Config $script:TestConfig } | Should -Not -Throw
        }
        
        It 'Should handle missing directories gracefully' {
            $configWithMissingDirs = @{
                LocalPath = Join-Path (Get-CrossPlatformTempPath) "nonexistent"
                RepoUrl = "https://github.com/test/missing-repo.git"
                InfraRepoPath = Join-Path (Get-CrossPlatformTempPath) "missing-infra"
            }
            
            { & $script:ScriptPath -Config $configWithMissingDirs } | Should -Not -Throw
        }
        
        It 'Should clean up test directories' {
            # Create test directories
            $testRepoPath = Join-Path $script:TestConfig.LocalPath "test-repo"
            $testInfraPath = $script:TestConfig.InfraRepoPath
            
            if (-not (Test-Path $testRepoPath)) { New-Item -Path $testRepoPath -ItemType Directory -Force | Out-Null }
            if (-not (Test-Path $testInfraPath)) { New-Item -Path $testInfraPath -ItemType Directory -Force | Out-Null }
            
            # Run the cleanup script
            & $script:ScriptPath -Config $script:TestConfig
            
            # Verify directories are removed
            Test-Path $testRepoPath | Should -Be $false
            Test-Path $testInfraPath | Should -Be $false
        }
    }
    
    Context 'Cross-Platform Compatibility' {
        It 'Should work on Windows' -Skip:(-not $IsWindows) {
            Mock Get-CrossPlatformTempPath { return $env:TEMP }
            { & $script:ScriptPath -Config $script:TestConfig } | Should -Not -Throw
        }
        
        It 'Should work on Linux/macOS' -Skip:($IsWindows) {
            Mock Get-CrossPlatformTempPath { return "/tmp" }
            { & $script:ScriptPath -Config $script:TestConfig } | Should -Not -Throw
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle null config gracefully' {
            { & $script:ScriptPath -Config $null } | Should -Not -Throw
        }
        
        It 'Should handle empty config gracefully' {
            { & $script:ScriptPath -Config @{} } | Should -Not -Throw
        }
        
        It 'Should handle invalid RepoUrl' {
            $invalidConfig = @{
                LocalPath = Get-CrossPlatformTempPath
                RepoUrl = "not-a-valid-url"
                InfraRepoPath = Join-Path (Get-CrossPlatformTempPath) "test-infra"
            }
            
            { & $script:ScriptPath -Config $invalidConfig } | Should -Not -Throw
        }
    }
    
    AfterEach {
        # Clean up any test artifacts
        $testPaths = @(
            (Join-Path $script:TestConfig.LocalPath "test-repo"),
            $script:TestConfig.InfraRepoPath,
            (Join-Path (Get-CrossPlatformTempPath) "test-infra")
        )
        
        foreach ($path in $testPaths) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

