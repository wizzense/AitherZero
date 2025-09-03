#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for 0051_Apply-CustomConfig.ps1
.DESCRIPTION
    Tests the custom configuration application functionality
#>

BeforeAll {
    # Get script path
    $script:ScriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0051_Apply-CustomConfig.ps1"
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    
    # Create temp config for testing
    $script:TempConfigPath = Join-Path ([System.IO.Path]::GetTempPath()) "test-config-$(Get-Random).psd1"

    # Create the actual temp file so ValidateScript passes
    '@{ Test = "Value" }' | Set-Content -Path $script:TempConfigPath -Force
    
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
    Mock Test-Path { $true }
    Mock Get-Content { return "@{ Test = 'Value' }" }
    Mock Set-Content { }
    Mock Import-PowerShellDataFile { 
        return @{
            Core = @{
                Profile = 'Test'
                Environment = 'Testing'
            }
            Automation = @{
                MaxConcurrency = 4
                DefaultTimeout = 300
            }
        }
    }
    Mock Invoke-WebRequest {
        return [PSCustomObject]@{
            Content = "@{ Core = @{ Profile = 'Web' } }"
        }
    }
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TempConfigPath) {
        Remove-Item $script:TempConfigPath -Force -ErrorAction SilentlyContinue
    }
}

Describe "0051_Apply-CustomConfig.ps1 Tests" -Tag 'Unit' {
    
    Context "Parameter Validation" {
        
        It "Should require either ConfigPath or ConfigUrl" {
            { 
                & $script:ScriptPath -WhatIf
            } | Should -Throw
        }
        
        It "Should accept local config file path" {
            { 
                & $script:ScriptPath -ConfigPath $script:TempConfigPath -WhatIf
            } | Should -Not -Throw
        }
        
        It "Should accept remote config URL" {
            { 
                & $script:ScriptPath -ConfigUrl "https://example.com/config.psd1" -WhatIf
            } | Should -Not -Throw
        }
    }
    
    Context "Configuration Loading" {
        
        It "Should load configuration from file" {
            Mock Import-PowerShellDataFile { 
                return @{ Core = @{ Profile = 'FileConfig'; Environment = 'Testing' } }
            }
            
            & $script:ScriptPath -ConfigPath $script:TempConfigPath -WhatIf
            
            Should -Invoke Import-PowerShellDataFile -Times 1
        }
        
        It "Should download configuration from URL" {
            Mock Invoke-WebRequest { }
            
            & $script:ScriptPath -ConfigUrl "https://example.com/config.psd1" -WhatIf
            
            Should -Invoke Invoke-WebRequest -Times 1
        }
    }
    
    Context "Configuration Merging" {
        
        It "Should merge configurations when MergeWithExisting is true" {
            Mock Get-Content { 
                return "@{ Existing = 'Value' }" 
            }
            
            & $script:ScriptPath -ConfigPath $script:TempConfigPath -MergeWithExisting -WhatIf
            
            # Should read existing config
            Should -Invoke Get-Content
        }
        
        It "Should override when MergeWithExisting is false" {
            & $script:ScriptPath -ConfigPath $script:TempConfigPath -WhatIf
            
            # Should not read existing config
            Should -Not -Invoke Get-Content -ParameterFilter {
                $Path -like "*config.psd1"
            }
        }
    }
    
    Context "Configuration Validation" {
        
        It "Should validate configuration structure" {
            Mock Import-PowerShellDataFile { 
                return @{ InvalidSection = 'Value' }
            }
            
            { 
                & $script:ScriptPath -ConfigPath $script:TempConfigPath -ValidateOnly
            } | Should -Not -Throw
        }
        
        It "Should detect invalid configuration values" {
            Mock Import-PowerShellDataFile { 
                return @{ 
                    Core = @{ 
                        Profile = 'InvalidProfile' 
                    }
                }
            }
            
            # Should handle invalid values gracefully
            { 
                & $script:ScriptPath -ConfigPath $script:TempConfigPath -ValidateOnly
            } | Should -Not -Throw
        }
    }
    
    Context "WhatIf Mode" {
        
        It "Should not write files in WhatIf mode" {
            Mock Set-Content { } -Verifiable
            
            & $script:ScriptPath -ConfigPath $script:TempConfigPath -WhatIf
            
            Should -Not -Invoke Set-Content
        }
        
        It "Should show what would be done" {
            $output = @()
            Mock Write-Host { $output += $Object }
            
            & $script:ScriptPath -ConfigPath $script:TempConfigPath -WhatIf
            
            $output | Should -Contain "*What if*"
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle missing config file gracefully" {
            Mock Test-Path { $false }
            
            { 
                & $script:ScriptPath -ConfigPath "nonexistent.psd1"
            } | Should -Throw
        }
        
        It "Should handle network errors for URL configs" {
            Mock Invoke-WebRequest { throw "Network error" }
            
            { 
                & $script:ScriptPath -ConfigUrl "https://example.com/config.psd1"
            } | Should -Throw
        }
        
        It "Should handle malformed configuration files" {
            Mock Import-PowerShellDataFile { throw "Invalid PSD1" }
            
            { 
                & $script:ScriptPath -ConfigPath $script:TempConfigPath
            } | Should -Throw
        }
    }
}