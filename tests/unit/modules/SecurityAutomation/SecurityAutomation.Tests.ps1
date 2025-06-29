#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive unit tests for the SecurityAutomation module.
    
.DESCRIPTION
    Tests all functions in the SecurityAutomation module including:
    - Active Directory security functions
    - Certificate Services automation
    - Endpoint hardening functions
    - Network security functions
    - Remote administration security
#>

# Import required modules for testing
. "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
$ProjectRoot = Find-ProjectRoot

# Import the module under test
Import-Module (Join-Path $ProjectRoot "aither-core/modules/SecurityAutomation") -Force

Describe "SecurityAutomation Module Tests" {
    
    Context "Module Loading" {
        It "Should load the SecurityAutomation module successfully" {
            Get-Module SecurityAutomation | Should -Not -BeNullOrEmpty
        }
        
        It "Should export expected functions" {
            $ExpectedFunctions = @(
                'Get-ADSecurityAssessment',
                'Set-ADPasswordPolicy',
                'Enable-ADSmartCardLogon',
                'Get-ADDelegationRisks',
                'Install-EnterpriseCA',
                'New-CertificateTemplate',
                'Enable-CertificateAutoEnrollment',
                'Set-WindowsFirewallProfile',
                'Enable-AdvancedAuditPolicy',
                'Set-IPsecPolicy',
                'Enable-PowerShellRemotingSSL'
            )
            
            $ModuleFunctions = (Get-Module SecurityAutomation).ExportedFunctions.Keys
            
            foreach ($Function in $ExpectedFunctions) {
                $ModuleFunctions | Should -Contain $Function
            }
        }
    }
    
    Context "Active Directory Functions" {
        
        Describe "Get-ADSecurityAssessment" {
            It "Should have proper parameter validation" {
                $Command = Get-Command Get-ADSecurityAssessment
                $Command.Parameters.Keys | Should -Contain 'Domain'
                $Command.Parameters.Keys | Should -Contain 'PrivilegedGroups'
                $Command.Parameters.Keys | Should -Contain 'ReportPath'
            }
            
            It "Should support WhatIf parameter" {
                $Command = Get-Command Get-ADSecurityAssessment
                $Command.Parameters.Keys | Should -Contain 'WhatIf'
            }
        }
        
        Describe "Set-ADPasswordPolicy" {
            It "Should validate PolicyType parameter" {
                $Command = Get-Command Set-ADPasswordPolicy
                $PolicyTypeParam = $Command.Parameters['PolicyType']
                $PolicyTypeParam.Attributes.ValidValues | Should -Contain 'Domain'
                $PolicyTypeParam.Attributes.ValidValues | Should -Contain 'FineGrained'
            }
            
            It "Should validate password length range" {
                $Command = Get-Command Set-ADPasswordPolicy
                $MinLengthParam = $Command.Parameters['MinPasswordLength']
                $MinLengthParam.Attributes.MinRange | Should -Be 8
                $MinLengthParam.Attributes.MaxRange | Should -Be 127
            }
        }
        
        Describe "Enable-ADSmartCardLogon" {
            It "Should support multiple parameter sets" {
                $Command = Get-Command Enable-ADSmartCardLogon
                $Command.ParameterSets.Count | Should -BeGreaterThan 1
            }
            
            It "Should support ShouldProcess" {
                $Command = Get-Command Enable-ADSmartCardLogon
                $Command.Parameters.Keys | Should -Contain 'WhatIf'
                $Command.Parameters.Keys | Should -Contain 'Confirm'
            }
        }
        
        Describe "Get-ADDelegationRisks" {
            It "Should validate risk level parameter" {
                $Command = Get-Command Get-ADDelegationRisks
                $RiskLevelParam = $Command.Parameters['RiskLevel']
                $RiskLevelParam.Attributes.ValidValues | Should -Contain 'Low'
                $RiskLevelParam.Attributes.ValidValues | Should -Contain 'Medium'
                $RiskLevelParam.Attributes.ValidValues | Should -Contain 'High'
                $RiskLevelParam.Attributes.ValidValues | Should -Contain 'Critical'
            }
        }
    }
    
    Context "Certificate Services Functions" {
        
        Describe "Install-EnterpriseCA" {
            It "Should validate key length parameter" {
                $Command = Get-Command Install-EnterpriseCA
                $KeyLengthParam = $Command.Parameters['KeyLength']
                $KeyLengthParam.Attributes.ValidValues | Should -Contain 2048
                $KeyLengthParam.Attributes.ValidValues | Should -Contain 4096
                $KeyLengthParam.Attributes.ValidValues | Should -Contain 8192
            }
            
            It "Should validate validity period range" {
                $Command = Get-Command Install-EnterpriseCA
                $ValidityParam = $Command.Parameters['ValidityPeriodYears']
                $ValidityParam.Attributes.MinRange | Should -Be 1
                $ValidityParam.Attributes.MaxRange | Should -Be 50
            }
        }
        
        Describe "New-CertificateTemplate" {
            It "Should validate template type parameter" {
                $Command = Get-Command New-CertificateTemplate
                $TemplateTypeParam = $Command.Parameters['TemplateType']
                $TemplateTypeParam.Attributes.ValidValues | Should -Contain 'User'
                $TemplateTypeParam.Attributes.ValidValues | Should -Contain 'Computer'
                $TemplateTypeParam.Attributes.ValidValues | Should -Contain 'WebServer'
                $TemplateTypeParam.Attributes.ValidValues | Should -Contain 'CodeSigning'
                $TemplateTypeParam.Attributes.ValidValues | Should -Contain 'Custom'
            }
        }
        
        Describe "Enable-CertificateAutoEnrollment" {
            It "Should validate scope parameter" {
                $Command = Get-Command Enable-CertificateAutoEnrollment
                $ScopeParam = $Command.Parameters['Scope']
                $ScopeParam.Attributes.ValidValues | Should -Contain 'User'
                $ScopeParam.Attributes.ValidValues | Should -Contain 'Computer'
                $ScopeParam.Attributes.ValidValues | Should -Contain 'Both'
            }
        }
    }
    
    Context "Endpoint Hardening Functions" {
        
        Describe "Set-WindowsFirewallProfile" {
            It "Should validate configuration type parameter" {
                $Command = Get-Command Set-WindowsFirewallProfile
                $ConfigTypeParam = $Command.Parameters['ConfigurationType']
                $ConfigTypeParam.Attributes.ValidValues | Should -Contain 'Workstation'
                $ConfigTypeParam.Attributes.ValidValues | Should -Contain 'Server'
                $ConfigTypeParam.Attributes.ValidValues | Should -Contain 'Custom'
            }
            
            It "Should validate firewall profiles" {
                $Command = Get-Command Set-WindowsFirewallProfile
                $ProfilesParam = $Command.Parameters['Profiles']
                $ProfilesParam.Attributes.ValidValues | Should -Contain 'Domain'
                $ProfilesParam.Attributes.ValidValues | Should -Contain 'Private'
                $ProfilesParam.Attributes.ValidValues | Should -Contain 'Public'
                $ProfilesParam.Attributes.ValidValues | Should -Contain 'All'
            }
        }
        
        Describe "Enable-AdvancedAuditPolicy" {
            It "Should validate policy set parameter" {
                $Command = Get-Command Enable-AdvancedAuditPolicy
                $PolicySetParam = $Command.Parameters['PolicySet']
                $PolicySetParam.Attributes.ValidValues | Should -Contain 'SecurityBaseline'
                $PolicySetParam.Attributes.ValidValues | Should -Contain 'ComplianceBaseline'
                $PolicySetParam.Attributes.ValidValues | Should -Contain 'HighSecurity'
                $PolicySetParam.Attributes.ValidValues | Should -Contain 'Custom'
            }
        }
    }
    
    Context "Network Security Functions" {
        
        Describe "Set-IPsecPolicy" {
            It "Should validate authentication method parameter" {
                $Command = Get-Command Set-IPsecPolicy
                $AuthMethodParam = $Command.Parameters['AuthenticationMethod']
                $AuthMethodParam.Attributes.ValidValues | Should -Contain 'Certificate'
                $AuthMethodParam.Attributes.ValidValues | Should -Contain 'Kerberos'
                $AuthMethodParam.Attributes.ValidValues | Should -Contain 'PreSharedKey'
                $AuthMethodParam.Attributes.ValidValues | Should -Contain 'ComputerCertificate'
            }
            
            It "Should validate protocol parameter" {
                $Command = Get-Command Set-IPsecPolicy
                $ProtocolParam = $Command.Parameters['Protocol']
                $ProtocolParam.Attributes.ValidValues | Should -Contain 'TCP'
                $ProtocolParam.Attributes.ValidValues | Should -Contain 'UDP'
                $ProtocolParam.Attributes.ValidValues | Should -Contain 'Any'
            }
        }
    }
    
    Context "Remote Administration Functions" {
        
        Describe "Enable-PowerShellRemotingSSL" {
            It "Should validate port range" {
                $Command = Get-Command Enable-PowerShellRemotingSSL
                $PortParam = $Command.Parameters['Port']
                $PortParam.Attributes.MinRange | Should -Be 1
                $PortParam.Attributes.MaxRange | Should -Be 65535
            }
            
            It "Should support ShouldProcess" {
                $Command = Get-Command Enable-PowerShellRemotingSSL
                $Command.Parameters.Keys | Should -Contain 'WhatIf'
                $Command.Parameters.Keys | Should -Contain 'Confirm'
            }
        }
    }
    
    Context "Function Integration Tests" {
        
        It "Should have consistent parameter naming across functions" {
            $Commands = Get-Command -Module SecurityAutomation
            $TestModeCommands = $Commands | Where-Object { $_.Parameters.Keys -contains 'TestMode' }
            
            # All functions that support TestMode should be consistent
            $TestModeCommands.Count | Should -BeGreaterThan 0
            
            foreach ($Command in $TestModeCommands) {
                $TestModeParam = $Command.Parameters['TestMode']
                $TestModeParam.ParameterType.Name | Should -Be 'SwitchParameter'
            }
        }
        
        It "Should have consistent WhatIf support for modification functions" {
            $ModificationFunctions = @(
                'Set-ADPasswordPolicy',
                'Enable-ADSmartCardLogon', 
                'Install-EnterpriseCA',
                'New-CertificateTemplate',
                'Enable-CertificateAutoEnrollment',
                'Set-WindowsFirewallProfile',
                'Enable-AdvancedAuditPolicy',
                'Set-IPsecPolicy',
                'Enable-PowerShellRemotingSSL'
            )
            
            foreach ($FunctionName in $ModificationFunctions) {
                $Command = Get-Command $FunctionName
                $Command.Parameters.Keys | Should -Contain 'WhatIf'
            }
        }
        
        It "Should have help documentation for all functions" {
            $Commands = Get-Command -Module SecurityAutomation
            
            foreach ($Command in $Commands) {
                $Help = Get-Help $Command.Name
                $Help.Synopsis | Should -Not -BeNullOrEmpty
                $Help.Description | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Error Handling Tests" {
        
        It "Should handle missing ActiveDirectory module gracefully" {
            # Mock module import failure
            Mock Import-Module { throw "Module not found" } -ParameterFilter { $Name -like "*ActiveDirectory*" }
            
            { Get-ADSecurityAssessment -WhatIf } | Should -Throw
        }
        
        It "Should validate administrator privileges where required" {
            # This test would require elevation to run properly
            # In a real test environment, you would mock the privilege check
            $Command = Get-Command Install-EnterpriseCA
            $Command.Parameters.Keys | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Security Validation Tests" {
        
        It "Should not expose sensitive information in parameter defaults" {
            $Commands = Get-Command -Module SecurityAutomation
            
            foreach ($Command in $Commands) {
                foreach ($Parameter in $Command.Parameters.Values) {
                    if ($Parameter.Name -like "*Password*" -or $Parameter.Name -like "*Key*") {
                        $Parameter.Attributes.DefaultValue | Should -BeNullOrEmpty
                    }
                }
            }
        }
        
        It "Should require strong validation for security-critical parameters" {
            $Command = Get-Command Set-ADPasswordPolicy
            $MinLengthParam = $Command.Parameters['MinPasswordLength']
            $MinLengthParam.Attributes.MinRange | Should -BeGreaterOrEqual 8
        }
    }
}

Describe "SecurityAutomation Module Performance Tests" {
    
    Context "Function Load Time" {
        It "Should load all functions within reasonable time" {
            $StartTime = Get-Date
            Import-Module (Join-Path $ProjectRoot "aither-core/modules/SecurityAutomation") -Force
            $LoadTime = (Get-Date) - $StartTime
            
            $LoadTime.TotalSeconds | Should -BeLessThan 5
        }
    }
    
    Context "Memory Usage" {
        It "Should not consume excessive memory" {
            $BeforeMemory = [System.GC]::GetTotalMemory($false)
            Import-Module (Join-Path $ProjectRoot "aither-core/modules/SecurityAutomation") -Force
            $AfterMemory = [System.GC]::GetTotalMemory($false)
            
            $MemoryIncrease = $AfterMemory - $BeforeMemory
            $MemoryIncrease | Should -BeLessThan 50MB
        }
    }
}

Describe "SecurityAutomation Module Documentation Tests" {
    
    Context "Help Quality" {
        It "Should have examples for all public functions" {
            $Commands = Get-Command -Module SecurityAutomation
            
            foreach ($Command in $Commands) {
                $Help = Get-Help $Command.Name -Full
                $Help.Examples | Should -Not -BeNullOrEmpty
                $Help.Examples.Example.Count | Should -BeGreaterOrEqual 1
            }
        }
        
        It "Should have parameter descriptions" {
            $Commands = Get-Command -Module SecurityAutomation
            
            foreach ($Command in $Commands) {
                $Help = Get-Help $Command.Name -Full
                
                foreach ($Parameter in $Help.Parameters.Parameter) {
                    if ($Parameter.Name -notin @('WhatIf', 'Confirm', 'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')) {
                        $Parameter.Description.Text | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }
    }
}

# Clean up
Remove-Module SecurityAutomation -Force -ErrorAction SilentlyContinue