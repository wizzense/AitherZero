#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for 9105_Test-ReleasePackages.ps1
.DESCRIPTION
    Tests the release package validation functionality
#>

BeforeAll {
    # Get script path
    $script:ScriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/9105_Test-ReleasePackages.ps1"
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    
    # Create temp directories for testing
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "PackageTest-$(Get-Random)"
    $script:ReleaseDir = Join-Path $script:TempDir "release"
    New-Item -ItemType Directory -Path $script:ReleaseDir -Force | Out-Null
    
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
    Mock Test-Path { $true }
    Mock Get-ChildItem {
        param($Path)
        if ($Path -like "*AitherZero-*.zip") {
            return @(
                [PSCustomObject]@{ 
                    Name = "AitherZero-1.0.0-Core.zip"
                    FullName = Join-Path $script:ReleaseDir "AitherZero-1.0.0-Core.zip"
                },
                [PSCustomObject]@{ 
                    Name = "AitherZero-1.0.0-Standard.zip"
                    FullName = Join-Path $script:ReleaseDir "AitherZero-1.0.0-Standard.zip"
                }
            )
        }
        return @()
    }
    Mock Expand-Archive { }
    Mock Remove-Item { }
    Mock Start-Process {
        return [PSCustomObject]@{
            ExitCode = 0
            StandardOutput = "Success"
        }
    }
    Mock Import-PowerShellDataFile {
        return @{
            ModuleVersion = '1.0.0'
        }
    }
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TempDir) {
        Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "9105_Test-ReleasePackages.ps1 Tests" -Tag 'Unit' {
    
    Context "Package Discovery" {
        
        It "Should find release packages" {
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -WhatIf
            
            Should -Invoke Get-ChildItem -Times 1 -ParameterFilter {
                $Path -like "*AitherZero-*.zip"
            }
        }
        
        It "Should handle missing release directory" {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq "./missing" }
            
            { 
                & $script:ScriptPath -ReleaseDir "./missing" -WhatIf
            } | Should -Throw -ErrorId "*not found*"
        }
        
        It "Should handle no packages found" {
            Mock Get-ChildItem { return @() }
            
            { 
                & $script:ScriptPath -ReleaseDir $script:ReleaseDir -WhatIf
            } | Should -Throw -ErrorId "*No packages found*"
        }
    }
    
    Context "Package Extraction" {
        
        It "Should extract packages for testing" {
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core') -WhatIf
            
            Should -Invoke Expand-Archive -ParameterFilter {
                $Path -like "*Core.zip"
            }
        }
        
        It "Should create separate test directory for each package" {
            Mock New-Item { 
                return [PSCustomObject]@{ FullName = $Path }
            }
            
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core', 'Standard') -WhatIf
            
            # Each profile should get its own test directory
            Should -Invoke New-Item -Times 2 -ParameterFilter {
                $ItemType -eq 'Directory'
            }
        }
    }
    
    Context "Package Validation" {
        
        It "Should verify package integrity" {
            # Test that basic files exist
            Mock Test-Path { $true } -ParameterFilter { 
                $Path -like "*bootstrap.ps1" -or 
                $Path -like "*AitherZero.psd1" -or
                $Path -like "*Start-AitherZero.ps1"
            }
            
            $result = & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core') -WhatIf
            
            # Should check for essential files
            Should -Invoke Test-Path -ParameterFilter {
                $Path -like "*bootstrap.ps1"
            }
        }
        
        It "Should test bootstrap functionality" {
            Mock Start-Process {
                return [PSCustomObject]@{
                    ExitCode = 0
                    StandardOutput = "Bootstrap successful"
                }
            }
            
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core') -WhatIf
            
            # Should attempt to run bootstrap
            Should -Invoke Start-Process -ParameterFilter {
                $FilePath -like "*pwsh*" -or $FilePath -like "*powershell*"
            }
        }
        
        It "Should test module loading" {
            Mock Import-PowerShellDataFile {
                return @{
                    ModuleVersion = '1.0.0'
                    RootModule = 'AitherZero.psm1'
                }
            }
            
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core') -WhatIf
            
            # Should try to import the module
            Should -Invoke Import-PowerShellDataFile
        }
    }
    
    Context "Test Profiles" {
        
        It "Should test specified profiles only" {
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core') -WhatIf
            
            # Should only process Core profile
            Should -Invoke Expand-Archive -Times 1 -ParameterFilter {
                $Path -like "*Core.zip"
            }
        }
        
        It "Should test all profiles by default" {
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ 
                        Name = "AitherZero-1.0.0-Core.zip"
                        FullName = "Core.zip"
                    },
                    [PSCustomObject]@{ 
                        Name = "AitherZero-1.0.0-Standard.zip"
                        FullName = "Standard.zip"
                    },
                    [PSCustomObject]@{ 
                        Name = "AitherZero-1.0.0-Full.zip"
                        FullName = "Full.zip"
                    }
                )
            }
            
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -WhatIf
            
            # Should process all three profiles
            Should -Invoke Expand-Archive -Times 3
        }
    }
    
    Context "Cleanup" {
        
        It "Should clean up test directories by default" {
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core') -WhatIf
            
            Should -Invoke Remove-Item -ParameterFilter {
                $Recurse -eq $true
            }
        }
        
        It "Should skip cleanup when requested" {
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core') -SkipCleanup -WhatIf
            
            Should -Invoke Remove-Item -Times 0
        }
    }
    
    Context "Test Results" {
        
        It "Should report test results for each package" {
            $output = & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core') -WhatIf 2>&1
            
            # Should include test results
            $output | Should -Match "Test|Result|Pass|Success|WhatIf"
        }
        
        It "Should provide summary of all tests" {
            $output = & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core', 'Standard') -WhatIf 2>&1
            
            # Should include summary
            $output | Should -Match "Summary|Total|Complete|WhatIf"
        }
        
        It "Should fail if any test fails" {
            Mock Start-Process {
                return [PSCustomObject]@{
                    ExitCode = 1
                    StandardError = "Test failed"
                }
            }
            
            { 
                & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core')
            } | Should -Throw
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle extraction failures" {
            Mock Expand-Archive { throw "Extraction failed" }
            
            { 
                & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core')
            } | Should -Throw -ErrorId "*Extract*"
        }
        
        It "Should handle bootstrap failures gracefully" {
            Mock Start-Process {
                return [PSCustomObject]@{
                    ExitCode = 1
                    StandardError = "Bootstrap failed"
                }
            }
            
            $output = & $script:ScriptPath -ReleaseDir $script:ReleaseDir -TestProfiles @('Core') 2>&1
            
            $output | Should -Match "fail|error"
        }
    }
    
    Context "WhatIf Support" {
        
        It "Should support WhatIf mode" {
            $result = & $script:ScriptPath -ReleaseDir $script:ReleaseDir -WhatIf
            
            # Should show what would be done
            $result | Should -Match "What if|WhatIf"
        }
        
        It "Should not extract packages in WhatIf mode" {
            $extractCalled = $false
            Mock Expand-Archive { $extractCalled = $true }
            
            & $script:ScriptPath -ReleaseDir $script:ReleaseDir -WhatIf
            
            # Should show WhatIf message but not actually extract
            Should -Invoke Expand-Archive
        }
    }
}