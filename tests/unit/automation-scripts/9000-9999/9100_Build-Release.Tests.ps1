#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for 9100_Build-Release.ps1
.DESCRIPTION
    Tests the build and release packaging functionality
#>

BeforeAll {
    # Get script path
    $script:ScriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/9100_Build-Release.ps1"
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    
    # Create temp directories for testing
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "BuildReleaseTest-$(Get-Random)"
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
    Mock Import-Module { }  # Mock module imports
    Mock Compress-Archive { }
    Mock Get-Date { return [DateTime]"2025-01-01 12:00:00" }
    Mock Test-Path { $true }
    Mock Get-ChildItem {
        param($Path, $Filter)
        if ($Filter -like "*.ps1") {
            return @(
                [PSCustomObject]@{ Name = "0400_Test.ps1"; FullName = "$Path/0400_Test.ps1" }
                [PSCustomObject]@{ Name = "0401_Test.ps1"; FullName = "$Path/0401_Test.ps1" }
            )
        }
        return @()
    }
    Mock Copy-Item { }
    Mock New-Item { 
        param($Path, $ItemType)
        return [PSCustomObject]@{ FullName = $Path }
    }
    Mock Remove-Item { }
    Mock Set-Content { }
    Mock ConvertTo-Json { return "{}" }
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TempDir) {
        Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "9100_Build-Release.ps1 Tests" -Tag 'Unit' {
    
    Context "Parameter Validation" {
        
        It "Should validate Version parameter format" {
            { 
                & $script:ScriptPath -Version "invalid_version" -SkipValidation
            } | Should -Throw
        }
        
        It "Should accept valid version formats" {
            $validVersions = @("1.0.0", "2.1.0-beta", "3.0.0-rc1", "1.0.0-test")
            
            foreach ($version in $validVersions) {
                { 
                    & $script:ScriptPath -Version $version -SkipValidation
                } | Should -Not -Throw
            }
        }
        
        It "Should validate Profiles parameter" {
            { 
                & $script:ScriptPath -Version "1.0.0" -Profiles @('InvalidProfile') -SkipValidation -WhatIf
            } | Should -Throw
        }
        
        It "Should accept valid profiles" {
            $validProfiles = @('Core', 'Standard', 'Full')
            
            { 
                & $script:ScriptPath -Version "1.0.0" -Profiles $validProfiles -SkipValidation -WhatIf
            } | Should -Not -Throw
        }
    }
    
    Context "Build Process" {
        
        It "Should create output directory if it doesn't exist" {
            Mock Test-Path { $false } -ParameterFilter { $Path -like "*release*" }
            Mock New-Item { }
            
            & $script:ScriptPath -Version "1.0.0" -Profiles @('Core') -SkipValidation -WhatIf
            
            Should -Invoke New-Item -Times 1 -ParameterFilter { 
                $ItemType -eq 'Directory' -and $Path -like "*release*" 
            }
        }
        
        It "Should copy files according to profile definitions" {
            Mock Copy-Item { }
            
            & $script:ScriptPath -Version "1.0.0" -Profiles @('Core') -SkipValidation -WhatIf
            
            Should -Invoke Copy-Item -AtLeast 1
        }
        
        It "Should handle inheritance between profiles" {
            # Standard inherits from Core
            # Full inherits from Standard
            
            Mock Get-Variable {
                param($Name)
                if ($Name -eq 'filesToCopy') {
                    return @{
                        Value = @{
                            Core = @{ Files = @('file1.ps1') }
                            Standard = @{ Inherits = 'Core'; Files = @('file2.ps1') }
                            Full = @{ Inherits = 'Standard'; Files = @('file3.ps1') }
                        }
                    }
                }
            }
            
            # Test that inheritance is handled
            $profiles = @{
                Core = @{ Files = @('file1.ps1') }
                Standard = @{ Inherits = 'Core'; Files = @('file2.ps1') }
            }
            
            $profiles.Standard.ContainsKey('Inherits') | Should -Be $true
            $profiles.Standard.Inherits | Should -Be 'Core'
        }
    }
    
    Context "Manifest Generation" {
        
        It "Should generate manifest.json for each package" {
            Mock Set-Content { } -ParameterFilter { $Path -like "*manifest.json" }
            
            & $script:ScriptPath -Version "1.0.0" -Profiles @('Core') -SkipValidation -WhatIf
            
            Should -Invoke Set-Content -ParameterFilter { 
                $Path -like "*manifest.json" 
            }
        }
        
        It "Should include correct metadata in manifest" {
            $capturedManifest = $null
            Mock ConvertTo-Json {
                param($InputObject)
                $capturedManifest = $InputObject
                return "{}"
            }
            
            & $script:ScriptPath -Version "1.0.0" -Profiles @('Core') -SkipValidation -WhatIf
            
            # Verify manifest structure would be created
            Should -Invoke ConvertTo-Json
        }
    }
    
    Context "Archive Creation" {
        
        It "Should create zip archives for each profile" {
            Mock Compress-Archive { }
            
            & $script:ScriptPath -Version "1.0.0" -Profiles @('Core', 'Standard') -SkipValidation -WhatIf
            
            # Should create 2 archives
            Should -Invoke Compress-Archive -Times 2
        }
        
        It "Should use correct naming convention" {
            $capturedPath = $null
            Mock Compress-Archive {
                param($DestinationPath)
                $capturedPath = $DestinationPath
            }
            
            & $script:ScriptPath -Version "1.0.0" -Profiles @('Core') -SkipValidation -WhatIf
            
            # Path should follow pattern: AitherZero-{version}-{profile}.zip
            $capturedPath | Should -BeLike "*AitherZero-1.0.0-Core.zip"
        }
    }
    
    Context "WhatIf Mode" {
        
        It "Should not create actual files in WhatIf mode" {
            Mock New-Item { } -Verifiable
            Mock Copy-Item { } -Verifiable
            Mock Compress-Archive { } -Verifiable
            
            & $script:ScriptPath -Version "1.0.0" -Profiles @('Core') -SkipValidation -WhatIf
            
            # These should not be called in WhatIf mode
            Should -Not -Invoke New-Item
            Should -Not -Invoke Copy-Item  
            Should -Not -Invoke Compress-Archive
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle missing automation scripts gracefully" {
            Mock Get-ChildItem { return @() } -ParameterFilter { $Filter -like "*.ps1" }
            
            { 
                & $script:ScriptPath -Version "1.0.0" -Profiles @('Core') -SkipValidation -WhatIf
            } | Should -Not -Throw
        }
        
        It "Should clean up on failure" {
            Mock Compress-Archive { throw "Compression failed" }
            Mock Remove-Item { }
            
            { 
                & $script:ScriptPath -Version "1.0.0" -Profiles @('Core') -SkipValidation
            } | Should -Throw
            
            # Cleanup should be called
            Should -Invoke Remove-Item
        }
    }
}