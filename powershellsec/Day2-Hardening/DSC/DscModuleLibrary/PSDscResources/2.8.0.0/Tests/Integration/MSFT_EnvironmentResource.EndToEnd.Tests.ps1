﻿<#
    Please note that some of these tests depend on each other.
    They must be run in the order given - if one test fails, subsequent tests may
    also fail.
#>

if ($PSVersionTable.PSVersion -lt [Version] '5.1')
{
    Write-Warning -Message 'Cannot run PSDscResources integration tests on PowerShell versions lower than 5.1'
    return
}

$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

# Import CommonTestHelper for Enter-DscResourceTestEnvironment, Exit-DscResourceTestEnvironment
$script:testFolderPath = Split-Path -Path $PSScriptRoot -Parent
$script:testHelpersPath = Join-Path -Path $script:testFolderPath -ChildPath 'TestHelpers'
Import-Module -Name (Join-Path -Path $script:testHelpersPath -ChildPath 'CommonTestHelper.psm1')

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DscResourceModuleName 'PSDscResources' `
    -DscResourceName 'MSFT_EnvironmentResource' `
    -TestType 'Integration'

try
{
    Describe 'EnvironmentResouce Integration Tests - with both Targets specified (default)' {
        BeforeAll {
            $testEnvironmentVarName = 'TestEnvironmentVariableName'
            $testPathEnvironmentVarName = 'TestPathEnvironmentVariableName'
            $machineEnvironmentRegistryPath = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'

            $testValue = 'InitialTestValue'
            $newTestValue = 'NewTestValue'

            $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_EnvironmentResource.config.ps1'
        }

        AfterAll {
            # Remove variables from the process:
            [System.Environment]::SetEnvironmentVariable($testEnvironmentVarName, $null)
            [System.Environment]::SetEnvironmentVariable($testPathEnvironmentVarName, $null)

            # Remove variables from machine:
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName
            }
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName
            }
        }

        Context "Should create the environment variable $testEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Create'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            # Ensure the environment variable doesn't exist

            # Remove variable from the process:
            [System.Environment]::SetEnvironmentVariable($testEnvironmentVarName, $null)

            # Remove variable from machine:
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName
            }

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value $testValue `
                                         -Ensure 'Present' `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $testValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should update environment variable $testEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Update'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value $newTestValue `
                                         -Ensure 'Present' `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $newTestValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context 'Should not remove environment variable when value is different than what is already set' {
            $configurationName = 'MSFT_EnvironmentResource_NonRemove'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value 'otherValue' `
                                         -Ensure 'Absent' `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $newTestValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should remove environment variable $testEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Remove'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value $null `
                                         -Ensure 'Absent' `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $null
               $currentConfig.Ensure | Should Be 'Absent'
            }
        }

        Context "Should create the path environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Create_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            # Ensure the environment variable doesn't exist

            # Remove variable from the process:
            [System.Environment]::SetEnvironmentVariable($testPathEnvironmentVarName, $null)

            # Remove variable from machine:
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName
            }

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $testValue `
                                         -Ensure 'Present' `
                                         -Path $true `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $testValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should update environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Update_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $expectedValue = $testValue + ';' + $newTestValue

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $newTestValue `
                                         -Ensure 'Present' `
                                         -Path $true `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $expectedValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context 'Should not remove environment variable when value is different than what is already set' {
            $configurationName = 'MSFT_EnvironmentResource_NonRemove_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $expectedValue = $testValue + ';' + $newTestValue

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value 'otherValue' `
                                         -Ensure 'Absent' `
                                         -Path $true `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $expectedValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should remove only one value from environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_PartialRemove_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $testValue `
                                         -Ensure 'Absent' `
                                         -Path $true `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $newTestValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should remove the environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Remove_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $null `
                                         -Ensure 'Absent' `
                                         -Path $true `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $null
               $currentConfig.Ensure | Should Be 'Absent'
            }
        }
    }

    Describe 'EnvironmentResouce Integration Tests - only Process Target specified' {
        BeforeAll {
            $testEnvironmentVarName = 'TestProcessEnvironmentVariableName'
            $testPathEnvironmentVarName = 'TestProcessPathEnvironmentVariableName'

            $testValue = 'InitialProcessTestValue'
            $newTestValue = 'NewProcessTestValue'

            $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_EnvironmentResource.config.ps1'
        }

        AfterAll {
            # Remove variables from the process:
            [System.Environment]::SetEnvironmentVariable($testEnvironmentVarName, $null)
            [System.Environment]::SetEnvironmentVariable($testPathEnvironmentVarName, $null)

            # Remove variables from machine (these shouldn't have been set):
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName
            }
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName
            }
        }

        Context "Should create the environment variable $testEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Create'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            # Ensure the environment variable doesn't exist

            # Remove variable from the process:
            [System.Environment]::SetEnvironmentVariable($testEnvironmentVarName, $null)

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value $testValue `
                                         -Ensure 'Present' `
                                         -Target @('Process') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $testValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should update environment variable $testEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Update'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value $newTestValue `
                                         -Ensure 'Present' `
                                         -Target @('Process') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $newTestValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context 'Should not remove environment variable when value is different than what is already set' {
            $configurationName = 'MSFT_EnvironmentResource_NonRemove'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value 'otherValue' `
                                         -Ensure 'Absent' `
                                         -Target @('Process') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $newTestValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should remove environment variable $testEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Remove'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value $null `
                                         -Ensure 'Absent' `
                                         -Target @('Process') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $null
               $currentConfig.Ensure | Should Be 'Absent'
            }
        }

        Context "Should create the path environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Create_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            # Ensure the environment variable doesn't exist

            # Remove variable from the process:
            [System.Environment]::SetEnvironmentVariable($testPathEnvironmentVarName, $null)

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $testValue `
                                         -Ensure 'Present' `
                                         -Path $true `
                                         -Target @('Process') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $testValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should update environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Update_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $expectedValue = $testValue + ';' + $newTestValue

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $newTestValue `
                                         -Ensure 'Present' `
                                         -Path $true `
                                         -Target @('Process') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $expectedValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context 'Should not remove environment variable when value is different than what is already set' {
            $configurationName = 'MSFT_EnvironmentResource_NonRemove_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $expectedValue = $testValue + ';' + $newTestValue

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value 'otherValue' `
                                         -Ensure 'Absent' `
                                         -Path $true `
                                         -Target @('Process') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $expectedValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should remove only one value from environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_PartialRemove_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $testValue `
                                         -Ensure 'Absent' `
                                         -Path $true `
                                         -Target @('Process') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $newTestValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should remove the environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Remove_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $null `
                                         -Ensure 'Absent' `
                                         -Path $true `
                                         -Target @('Process') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $null
               $currentConfig.Ensure | Should Be 'Absent'
            }
        }
    }

    Describe 'EnvironmentResouce Integration Tests - only Machine Target specified' {
        BeforeAll {
            $testEnvironmentVarName = 'TestMachineEnvironmentVariableName'
            $testPathEnvironmentVarName = 'TestMachinePathEnvironmentVariableName'

            $testValue = 'InitialMachineTestValue'
            $newTestValue = 'NewMachineTestValue'

            $configFile = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_EnvironmentResource.config.ps1'
        }

        AfterAll {
            # Remove variables from the process (these shouldn't have been set):
            [System.Environment]::SetEnvironmentVariable($testEnvironmentVarName, $null)
            [System.Environment]::SetEnvironmentVariable($testPathEnvironmentVarName, $null)

            # Remove variables from machine:
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName
            }
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName
            }
        }

        Context "Should create the environment variable $testEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Create'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            # Ensure the environment variable doesn't exist:

            # Remove variable from machine:
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testEnvironmentVarName
            }

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value $testValue `
                                         -Ensure 'Present' `
                                         -Target @('Machine') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $testValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should update environment variable $testEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Update'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value $newTestValue `
                                         -Ensure 'Present' `
                                         -Target @('Machine') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $newTestValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context 'Should not remove environment variable when value is different than what is already set' {
            $configurationName = 'MSFT_EnvironmentResource_NonRemove'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value 'otherValue' `
                                         -Ensure 'Absent' `
                                         -Target @('Machine') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $newTestValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should remove environment variable $testEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Remove'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testEnvironmentVarName `
                                         -Value $null `
                                         -Ensure 'Absent' `
                                         -Target @('Machine') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testEnvironmentVarName
               $currentConfig.Value | Should Be $null
               $currentConfig.Ensure | Should Be 'Absent'
            }
        }

        Context "Should create the path environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Create_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            # Ensure the environment variable doesn't exist:

            # Remove variable from machine:
            if (Get-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName -ErrorAction 'SilentlyContinue')
            {
                Remove-ItemProperty -Path $machineEnvironmentRegistryPath -Name $testPathEnvironmentVarName
            }

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $testValue `
                                         -Ensure 'Present' `
                                         -Path $true `
                                         -Target @('Machine') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $testValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should update environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Update_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $expectedValue = $testValue + ';' + $newTestValue

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $newTestValue `
                                         -Ensure 'Present' `
                                         -Path $true `
                                         -Target @('Machine') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $expectedValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context 'Should not remove environment variable when value is different than what is already set' {
            $configurationName = 'MSFT_EnvironmentResource_NonRemove_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            $expectedValue = $testValue + ';' + $newTestValue

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value 'otherValue' `
                                         -Ensure 'Absent' `
                                         -Path $true `
                                         -Target @('Machine') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $expectedValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should remove only one value from environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_PartialRemove_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $testValue `
                                         -Ensure 'Absent' `
                                         -Path $true `
                                         -Target @('Machine') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $newTestValue
               $currentConfig.Ensure | Should Be 'Present'
            }
        }

        Context "Should remove the environment variable $testPathEnvironmentVarName" {
            $configurationName = 'MSFT_EnvironmentResource_Remove_Path'
            $configurationPath = Join-Path -Path $TestDrive -ChildPath $configurationName

            It 'Should compile without throwing' {
                {
                    . $configFile -ConfigurationName $configurationName
                    & $configurationName -Name $testPathEnvironmentVarName `
                                         -Value $null `
                                         -Ensure 'Absent' `
                                         -Path $true `
                                         -Target @('Machine') `
                                         -OutputPath $configurationPath `
                                         -ErrorAction 'Stop'
                    Start-DscConfiguration -Path $configurationPath -ErrorAction 'Stop' -Wait -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -ErrorAction 'Stop' } | Should Not Throw
            }
        
            It 'Should return the correct configuration' {
               $currentConfig = Get-DscConfiguration -ErrorAction 'Stop'
               $currentConfig.Name | Should Be $testPathEnvironmentVarName
               $currentConfig.Value | Should Be $null
               $currentConfig.Ensure | Should Be 'Absent'
            }
        }
    }
}
finally
{
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
}
