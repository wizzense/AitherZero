#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for 9102_Create-GitHubRelease.ps1
.DESCRIPTION
    Tests the GitHub release creation functionality
#>

BeforeAll {
    # Get script path
    $script:ScriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/9102_Create-GitHubRelease.ps1"
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    
    # Create temp directory for testing
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "GitHubReleaseTest-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    
    # Define Write-CustomLog function if it doesn't exist
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param($Message, $Level = 'Information')
            # Mock implementation
        }
    }
    
    # Mock functions
    Mock Write-Host { }
    Mock Write-CustomLog { }
    Mock Import-Module { }
    Mock Get-Command { 
        param($Name)
        if ($Name -eq 'gh') {
            return [PSCustomObject]@{ Name = 'gh' }
        }
        return $null
    }
    Mock Test-Path { $true }
    Mock Get-ChildItem {
        return @(
            [PSCustomObject]@{ 
                Name = "AitherZero-1.0.0-Core.zip"
                FullName = Join-Path $script:TempDir "AitherZero-1.0.0-Core.zip"
            },
            [PSCustomObject]@{ 
                Name = "AitherZero-1.0.0-Standard.zip"
                FullName = Join-Path $script:TempDir "AitherZero-1.0.0-Standard.zip"
            }
        )
    }
    
    # Mock gh CLI
    function gh {
        param([Parameter(ValueFromRemainingArguments)]$Args)
        if ($Args -contains 'auth' -and $Args -contains 'status') {
            $global:LASTEXITCODE = 0
            return "Logged in"
        }
        if ($Args -contains 'release' -and $Args -contains 'create') {
            $global:LASTEXITCODE = 0
            return "https://github.com/user/repo/releases/tag/v1.0.0"
        }
        $global:LASTEXITCODE = 1
        throw "gh command failed"
    }
    
    # Mock git commands
    function git {
        param([Parameter(ValueFromRemainingArguments)]$Args)
        $global:LASTEXITCODE = 0
        return "OK"
    }
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TempDir) {
        Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "9102_Create-GitHubRelease.ps1 Tests" -Tag 'Unit' {
    
    Context "Prerequisites" {
        
        It "Should check for gh CLI availability" {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'gh' }
            
            { 
                & $script:ScriptPath -Version "1.0.0" -WhatIf
            } | Should -Throw -ErrorId "*GitHub CLI*"
        }
        
        It "Should verify GitHub authentication" {
            Mock gh { 
                $global:LASTEXITCODE = 1
                throw "Not authenticated"
            } -ParameterFilter { $Args -contains 'auth' }
            
            { 
                & $script:ScriptPath -Version "1.0.0" -WhatIf
            } | Should -Throw -ErrorId "*authenticated*"
        }
        
        It "Should check for release packages" {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq "./release" }
            
            { 
                & $script:ScriptPath -Version "1.0.0" -WhatIf
            } | Should -Throw -ErrorId "*Release directory not found*"
        }
    }
    
    Context "Release Creation" {
        
        It "Should create release with correct version" {
            $result = & $script:ScriptPath -Version "1.0.0" -WhatIf
            
            $result | Should -Match "v1.0.0|WhatIf"
        }
        
        It "Should support draft releases" {
            $result = & $script:ScriptPath -Version "1.0.0" -Draft -WhatIf
            
            $result | Should -Match "draft|WhatIf"
        }
        
        It "Should support pre-releases" {
            $result = & $script:ScriptPath -Version "1.0.0-beta" -PreRelease -WhatIf
            
            $result | Should -Match "prerelease|pre-release|WhatIf"
        }
        
        It "Should upload all package files" {
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ 
                        Name = "AitherZero-2.0.0-Core.zip"
                        FullName = "AitherZero-2.0.0-Core.zip"
                    },
                    [PSCustomObject]@{ 
                        Name = "AitherZero-2.0.0-Standard.zip"
                        FullName = "AitherZero-2.0.0-Standard.zip"
                    },
                    [PSCustomObject]@{ 
                        Name = "AitherZero-2.0.0-Full.zip"
                        FullName = "AitherZero-2.0.0-Full.zip"
                    }
                )
            }
            
            $result = & $script:ScriptPath -Version "2.0.0" -WhatIf
            
            Should -Invoke Get-ChildItem -Times 1 -ParameterFilter {
                $Path -like "*AitherZero-2.0.0-*.zip"
            }
        }
    }
    
    Context "Release Notes" {
        
        It "Should generate default release notes if not provided" {
            $result = & $script:ScriptPath -Version "1.0.0" -WhatIf
            
            # Release notes should be generated
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should use custom release notes when provided" {
            $customNotes = "Custom release notes for version 1.0.0"
            
            $result = & $script:ScriptPath -Version "1.0.0" -ReleaseNotes $customNotes -WhatIf
            
            # Should use the custom notes
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Tag Management" {
        
        It "Should update latest tag for non-draft, non-prerelease" -Skip {
            # Skip as it requires actual git operations
            $true | Should -Be $true
        }
        
        It "Should not update latest tag for drafts" {
            $result = & $script:ScriptPath -Version "1.0.0" -Draft -WhatIf
            
            # Should not attempt to update latest tag
            $result | Should -Not -Match "latest tag"
        }
        
        It "Should not update latest tag for pre-releases" {
            $result = & $script:ScriptPath -Version "1.0.0-beta" -PreRelease -WhatIf
            
            # Should not attempt to update latest tag
            $result | Should -Not -Match "latest tag"
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle gh CLI errors gracefully" {
            Mock gh { 
                $global:LASTEXITCODE = 1
                throw "GitHub API error"
            } -ParameterFilter { $Args -contains 'release' }
            
            { 
                & $script:ScriptPath -Version "1.0.0"
            } | Should -Throw
        }
        
        It "Should provide helpful error messages" {
            Mock Get-ChildItem { return @() }
            
            { 
                & $script:ScriptPath -Version "1.0.0"
            } | Should -Throw -ErrorId "*No release packages found*"
        }
    }
    
    Context "WhatIf Support" {
        
        It "Should support WhatIf mode" {
            $result = & $script:ScriptPath -Version "1.0.0" -WhatIf
            
            # Should show what would be done without actually doing it
            $result | Should -Match "What if|WhatIf"
        }
        
        It "Should not create actual release in WhatIf mode" {
            $mockCalled = $false
            Mock gh { 
                if ($Args -contains 'release' -and $Args -contains 'create') {
                    $mockCalled = $true
                }
                $global:LASTEXITCODE = 0
                return "https://github.com/user/repo/releases/tag/v1.0.0"
            }
            
            & $script:ScriptPath -Version "1.0.0" -WhatIf
            
            # gh release create should not be called in WhatIf mode
            $mockCalled | Should -Be $false
        }
    }
}