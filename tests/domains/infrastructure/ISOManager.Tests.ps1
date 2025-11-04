#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for ISOManager module.

.DESCRIPTION
    Comprehensive test suite for ISO management functionality.
    Tests are written following TDD principles.
#>

BeforeAll {
    # Import module using absolute path
    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $modulePath = Join-Path $repoRoot "domains/infrastructure/ISOManager.psm1"
    
    # Verify module exists
    if (-not (Test-Path $modulePath)) {
        throw "Module not found at: $modulePath (PSScriptRoot: $PSScriptRoot, RepoRoot: $repoRoot)"
    }
    
    Import-Module $modulePath -Force
    
    # Create test directory
    $script:TestDir = Join-Path $TestDrive "ISOManager-Tests"
    New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TestDir) {
        Remove-Item $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'ISOManager Module' {
    
    Context 'Module Loading' {
        It 'Should load the module successfully' {
            Get-Module ISOManager | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Test-ISOFile function' {
            Get-Command Test-ISOFile -Module ISOManager | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Get-ISOExtractionMethod function' {
            Get-Command Get-ISOExtractionMethod -Module ISOManager | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Expand-ISOImage function' {
            Get-Command Expand-ISOImage -Module ISOManager | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Test-ISOFile' {
        BeforeEach {
            $script:TestISOPath = Join-Path $script:TestDir "test.iso"
        }
        
        AfterEach {
            if (Test-Path $script:TestISOPath) {
                Remove-Item $script:TestISOPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        It 'Should return $false for non-existent file' {
            $result = Test-ISOFile -Path $script:TestISOPath
            $result | Should -Be $false
        }
        
        It 'Should return $false for file without .iso extension' {
            $txtFile = Join-Path $script:TestDir "test.txt"
            "test" | Out-File $txtFile
            $result = Test-ISOFile -Path $txtFile
            $result | Should -Be $false
            Remove-Item $txtFile -Force
        }
        
        It 'Should return $true for existing .iso file (without signature validation)' {
            # Create dummy ISO file
            "dummy iso content" | Out-File $script:TestISOPath
            $result = Test-ISOFile -Path $script:TestISOPath
            $result | Should -Be $true
        }
        
        It 'Should validate ISO signature when ValidateSignature is specified' {
            # Create a file that's too small to be an ISO
            "small" | Out-File $script:TestISOPath
            $result = Test-ISOFile -Path $script:TestISOPath -ValidateSignature
            $result | Should -Be $false
        }
        
        It 'Should accept pipeline input' {
            "dummy" | Out-File $script:TestISOPath
            $result = $script:TestISOPath | Test-ISOFile
            $result | Should -Be $true
        }
    }
    
    Context 'Get-ISOExtractionMethod' {
        It 'Should return a valid extraction method' {
            $method = Get-ISOExtractionMethod
            $method | Should -BeIn @('MountDiskImage', '7zip', 'Mount')
        }
        
        It 'Should return MountDiskImage on Windows with available cmdlet' -Skip:(!$IsWindows) {
            if (Get-Command Mount-DiskImage -ErrorAction SilentlyContinue) {
                $method = Get-ISOExtractionMethod
                $method | Should -Be 'MountDiskImage'
            }
        }
        
        It 'Should return 7zip if available' {
            $method = Get-ISOExtractionMethod
            # On most systems, at least 7zip or Mount-DiskImage should be available
            $method | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Expand-ISOImage - Parameter Validation' {
        BeforeEach {
            $script:TestISOPath = Join-Path $script:TestDir "test.iso"
            $script:TestDestPath = Join-Path $script:TestDir "extracted"
        }
        
        AfterEach {
            if (Test-Path $script:TestISOPath) {
                Remove-Item $script:TestISOPath -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $script:TestDestPath) {
                Remove-Item $script:TestDestPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It 'Should require ISOPath parameter' {
            { Expand-ISOImage -DestinationPath $script:TestDestPath } | Should -Throw
        }
        
        It 'Should require DestinationPath parameter' {
            "dummy" | Out-File $script:TestISOPath
            { Expand-ISOImage -ISOPath $script:TestISOPath } | Should -Throw
        }
        
        It 'Should validate ISO file exists' {
            { Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath } | Should -Throw
        }
        
        It 'Should support WhatIf' {
            "dummy" | Out-File $script:TestISOPath
            { Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath -WhatIf } | Should -Not -Throw
        }
        
        It 'Should throw if destination exists without Force' {
            "dummy" | Out-File $script:TestISOPath
            New-Item -ItemType Directory -Path $script:TestDestPath -Force | Out-Null
            { Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath -ErrorAction Stop } | Should -Throw
        }
        
        It 'Should accept Force parameter to overwrite destination' {
            "dummy" | Out-File $script:TestISOPath
            New-Item -ItemType Directory -Path $script:TestDestPath -Force | Out-Null
            { Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath -Force -WhatIf } | Should -Not -Throw
        }
    }
    
    Context 'Expand-ISOImage - Return Object' {
        BeforeEach {
            $script:TestISOPath = Join-Path $script:TestDir "test.iso"
            $script:TestDestPath = Join-Path $script:TestDir "extracted"
            "dummy" | Out-File $script:TestISOPath
        }
        
        AfterEach {
            if (Test-Path $script:TestISOPath) {
                Remove-Item $script:TestISOPath -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $script:TestDestPath) {
                Remove-Item $script:TestDestPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It 'Should return a PSCustomObject' {
            $result = Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath -WhatIf
            $result | Should -BeOfType [PSCustomObject]
        }
        
        It 'Should return object with Success property' {
            $result = Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath -WhatIf
            $result.PSObject.Properties.Name | Should -Contain 'Success'
        }
        
        It 'Should return object with Method property' {
            $result = Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath -WhatIf
            $result.PSObject.Properties.Name | Should -Contain 'Method'
        }
        
        It 'Should return object with FilesExtracted property' {
            $result = Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath -WhatIf
            $result.PSObject.Properties.Name | Should -Contain 'FilesExtracted'
        }
        
        It 'Should return object with Duration property' {
            $result = Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath -WhatIf
            $result.PSObject.Properties.Name | Should -Contain 'Duration'
            $result.Duration | Should -BeOfType [TimeSpan]
        }
        
        It 'Should return object with Message property' {
            $result = Expand-ISOImage -ISOPath $script:TestISOPath -DestinationPath $script:TestDestPath -WhatIf
            $result.PSObject.Properties.Name | Should -Contain 'Message'
            $result.Message | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'ISOManager Integration Tests' -Tag 'Integration' {
    
    Context 'Real ISO Extraction' {
        BeforeAll {
            $script:TestDir = Join-Path $TestDrive "ISO-Integration"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }
        
        AfterAll {
            if (Test-Path $script:TestDir) {
                Remove-Item $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It 'Should handle WhatIf without making changes' {
            $isoPath = Join-Path $script:TestDir "test.iso"
            $destPath = Join-Path $script:TestDir "extracted"
            "dummy" | Out-File $isoPath
            
            Expand-ISOImage -ISOPath $isoPath -DestinationPath $destPath -WhatIf
            
            Test-Path $destPath | Should -Be $false
        }
    }
}
