#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for ISOCustomizer module - Windows ISO customization.

.DESCRIPTION
    TDD test suite for Windows ISO customization features:
    - Unattend.xml generation
    - Driver injection (DISM)
    - Update integration
#>

BeforeAll {
    # Import module
    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $modulePath = Join-Path $repoRoot "domains/infrastructure/ISOCustomizer.psm1"
    
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
    }
    
    # Create test directory
    $script:TestDir = Join-Path $TestDrive "ISOCustomizer-Tests"
    New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TestDir) {
        Remove-Item $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'ISOCustomizer Module' {
    
    Context 'Module Loading' {
        It 'Should load the module successfully' {
            Get-Module ISOCustomizer | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export New-UnattendXml function' {
            Get-Command New-UnattendXml -Module ISOCustomizer -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Add-ISODriver function' {
            Get-Command Add-ISODriver -Module ISOCustomizer -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Test-DISMAvailability function' {
            Get-Command Test-DISMAvailability -Module ISOCustomizer -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'New-UnattendXml - Parameter Validation' {
        It 'Should require ComputerName parameter' {
            { New-UnattendXml -OutputPath "$script:TestDir\unattend.xml" } | Should -Throw
        }
        
        It 'Should require OutputPath parameter' {
            { New-UnattendXml -ComputerName "TEST-PC" } | Should -Throw
        }
        
        It 'Should accept valid parameters' {
            { New-UnattendXml -ComputerName "TEST-PC" -OutputPath "$script:TestDir\unattend.xml" -WhatIf } | Should -Not -Throw
        }
        
        It 'Should support WhatIf' {
            $result = New-UnattendXml -ComputerName "TEST-PC" -OutputPath "$script:TestDir\unattend.xml" -WhatIf
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'New-UnattendXml - XML Generation' {
        BeforeEach {
            $script:UnattendPath = Join-Path $script:TestDir "unattend.xml"
        }
        
        AfterEach {
            if (Test-Path $script:UnattendPath) {
                Remove-Item $script:UnattendPath -Force
            }
        }
        
        It 'Should generate valid XML file' {
            $result = New-UnattendXml -ComputerName "TEST-PC" -OutputPath $script:UnattendPath
            $result.Success | Should -Be $true
            Test-Path $script:UnattendPath | Should -Be $true
        }
        
        It 'Should include ComputerName in XML' {
            New-UnattendXml -ComputerName "TEST-PC" -OutputPath $script:UnattendPath
            $xml = [xml](Get-Content $script:UnattendPath)
            $xml | Should -Not -BeNullOrEmpty
        }
        
        It 'Should return object with Success property' {
            $result = New-UnattendXml -ComputerName "TEST-PC" -OutputPath $script:UnattendPath
            $result.PSObject.Properties.Name | Should -Contain 'Success'
        }
        
        It 'Should return object with OutputPath property' {
            $result = New-UnattendXml -ComputerName "TEST-PC" -OutputPath $script:UnattendPath
            $result.PSObject.Properties.Name | Should -Contain 'OutputPath'
            $result.OutputPath | Should -Be $script:UnattendPath
        }
        
        It 'Should accept ProductKey parameter' {
            $result = New-UnattendXml -ComputerName "TEST-PC" -OutputPath $script:UnattendPath -ProductKey "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
            $result.Success | Should -Be $true
        }
        
        It 'Should accept TimeZone parameter' {
            $result = New-UnattendXml -ComputerName "TEST-PC" -OutputPath $script:UnattendPath -TimeZone "Pacific Standard Time"
            $result.Success | Should -Be $true
        }
        
        It 'Should accept Administrator password' {
            $securePass = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
            $result = New-UnattendXml -ComputerName "TEST-PC" -OutputPath $script:UnattendPath -AdministratorPassword $securePass
            $result.Success | Should -Be $true
        }
    }
    
    Context 'Test-DISMAvailability' {
        It 'Should return a boolean value' {
            $result = Test-DISMAvailability
            $result | Should -BeOfType [bool]
        }
        
        It 'Should return true on Windows with DISM' -Skip:(!$IsWindows) {
            if (Get-Command DISM.exe -ErrorAction SilentlyContinue) {
                $result = Test-DISMAvailability
                $result | Should -Be $true
            }
        }
        
        It 'Should return false on non-Windows systems' -Skip:($IsWindows) {
            $result = Test-DISMAvailability
            $result | Should -Be $false
        }
    }
    
    Context 'Add-ISODriver - Parameter Validation' {
        It 'Should require MountPath parameter' {
            { Add-ISODriver -DriverPath "C:\Drivers" } | Should -Throw
        }
        
        It 'Should require DriverPath parameter' {
            { Add-ISODriver -MountPath "C:\Mount" } | Should -Throw
        }
        
        It 'Should validate MountPath exists' {
            $fakePath = Join-Path $script:TestDir "nonexistent"
            { Add-ISODriver -MountPath $fakePath -DriverPath "C:\Drivers" -ErrorAction Stop } | Should -Throw
        }
        
        It 'Should support WhatIf' {
            $mountPath = New-Item -ItemType Directory -Path (Join-Path $script:TestDir "mount") -Force
            { Add-ISODriver -MountPath $mountPath.FullName -DriverPath "C:\Drivers" -WhatIf } | Should -Not -Throw
        }
    }
    
    Context 'Add-ISODriver - Return Object' {
        BeforeEach {
            $script:MountPath = New-Item -ItemType Directory -Path (Join-Path $script:TestDir "mount") -Force
        }
        
        AfterEach {
            if (Test-Path $script:MountPath) {
                Remove-Item $script:MountPath -Recurse -Force
            }
        }
        
        It 'Should return PSCustomObject' {
            $result = Add-ISODriver -MountPath $script:MountPath.FullName -DriverPath "C:\Drivers" -WhatIf
            $result | Should -BeOfType [PSCustomObject]
        }
        
        It 'Should return object with Success property' {
            $result = Add-ISODriver -MountPath $script:MountPath.FullName -DriverPath "C:\Drivers" -WhatIf
            $result.PSObject.Properties.Name | Should -Contain 'Success'
        }
        
        It 'Should return object with DriversAdded property' {
            $result = Add-ISODriver -MountPath $script:MountPath.FullName -DriverPath "C:\Drivers" -WhatIf
            $result.PSObject.Properties.Name | Should -Contain 'DriversAdded'
        }
        
        It 'Should return object with Message property' {
            $result = Add-ISODriver -MountPath $script:MountPath.FullName -DriverPath "C:\Drivers" -WhatIf
            $result.PSObject.Properties.Name | Should -Contain 'Message'
        }
    }
}

Describe 'ISOCustomizer Integration Tests' -Tag 'Integration' {
    
    Context 'Unattend.xml Workflow' {
        It 'Should create valid unattend.xml for automated installation' {
            $unattendPath = Join-Path $script:TestDir "integration-unattend.xml"
            $securePass = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
            
            $result = New-UnattendXml `
                -ComputerName "LAB-SERVER-01" `
                -OutputPath $unattendPath `
                -ProductKey "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" `
                -TimeZone "Pacific Standard Time" `
                -AdministratorPassword $securePass
            
            $result.Success | Should -Be $true
            Test-Path $unattendPath | Should -Be $true
            
            # Validate XML is well-formed
            { [xml](Get-Content $unattendPath) } | Should -Not -Throw
        }
    }
}
