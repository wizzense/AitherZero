#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    # Find project root
    $projectRoot = $PSScriptRoot
    while (-not (Test-Path (Join-Path $projectRoot "Start-AitherZero.ps1")) -and $projectRoot -ne "") {
        $projectRoot = Split-Path $projectRoot -Parent
    }
    
    # Mock the Logging module before importing ConfigurationCore
    New-Module -Name Logging -ScriptBlock {
        function Write-CustomLog {
            param($Level, $Message)
        }
        Export-ModuleMember -Function Write-CustomLog
    } | Import-Module -Force
    
    # Import the module
    $modulePath = Join-Path $projectRoot "aither-core/modules/ConfigurationCore"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe "ConfigurationCore Module" {
    Context "Module Loading" {
        It "Should load without syntax errors" {
            { Get-Module ConfigurationCore } | Should -Not -Throw
            Get-Module ConfigurationCore | Should -Not -BeNullOrEmpty
        }
        
        It "Should export expected public functions" {
            $module = Get-Module ConfigurationCore
            $module.ExportedFunctions.Keys | Should -Contain "Initialize-ConfigurationCore"
            $module.ExportedFunctions.Keys | Should -Contain "Get-ModuleConfiguration"
            $module.ExportedFunctions.Keys | Should -Contain "Set-ModuleConfiguration"
            $module.ExportedFunctions.Keys | Should -Contain "Register-ModuleConfiguration"
        }
    }
    
    Context "Validate-Configuration Function" {
        BeforeAll {
            # Get internal function for testing
            $module = Get-Module ConfigurationCore
            $validateFunc = & $module { Get-Command Validate-Configuration }
        }
        
        It "Should validate configuration without syntax errors" {
            $testConfig = @{
                TestProperty = "TestValue"
            }
            
            { & $validateFunc -ModuleName "TestModule" -Configuration $testConfig } | Should -Not -Throw
        }
        
        It "Should generate properly formatted error messages with colons" {
            # Register a test schema
            Register-ModuleConfiguration -ModuleName "TestModule" -DefaultConfiguration @{} -Schema @{
                Properties = @{
                    RequiredProp = @{
                        Required = $true
                        Type = "string"
                    }
                }
            }
            
            $result = & $validateFunc -ModuleName "TestModule" -Configuration @{}
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Required property missing: RequiredProp"
        }
        
        It "Should format type mismatch errors correctly" {
            Register-ModuleConfiguration -ModuleName "TestModule2" -DefaultConfiguration @{} -Schema @{
                Properties = @{
                    NumberProp = @{
                        Type = "int"
                    }
                }
            }
            
            $result = & $validateFunc -ModuleName "TestModule2" -Configuration @{NumberProp = "not a number"}
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "NumberProp: Expected type int"
        }
        
        It "Should format valid values errors correctly" {
            Register-ModuleConfiguration -ModuleName "TestModule3" -DefaultConfiguration @{} -Schema @{
                Properties = @{
                    ChoiceProp = @{
                        ValidValues = @("Option1", "Option2", "Option3")
                    }
                }
            }
            
            $result = & $validateFunc -ModuleName "TestModule3" -Configuration @{ChoiceProp = "InvalidOption"}
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "ChoiceProp: Value 'InvalidOption' not in valid values"
        }
        
        It "Should format range validation errors correctly" {
            Register-ModuleConfiguration -ModuleName "TestModule4" -DefaultConfiguration @{} -Schema @{
                Properties = @{
                    RangeProp = @{
                        Type = "int"
                        Min = 1
                        Max = 10
                    }
                }
            }
            
            $result = & $validateFunc -ModuleName "TestModule4" -Configuration @{RangeProp = 15}
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "RangeProp: Value 15 is greater than maximum 10"
        }
        
        It "Should format pattern validation errors correctly" {
            Register-ModuleConfiguration -ModuleName "TestModule5" -DefaultConfiguration @{} -Schema @{
                Properties = @{
                    PatternProp = @{
                        Type = "string"
                        Pattern = "^[A-Z][a-z]+$"
                    }
                }
            }
            
            $result = & $validateFunc -ModuleName "TestModule5" -Configuration @{PatternProp = "invalid"}
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "PatternProp: Value 'invalid' does not match pattern"
        }
    }
    
    Context "Invoke-ConfigurationReload Function" {
        BeforeAll {
            # Get internal function for testing
            $module = Get-Module ConfigurationCore
            $reloadFunc = & $module { Get-Command Invoke-ConfigurationReload }
        }
        
        It "Should handle reload errors with properly formatted messages" {
            # Mock a failing reload scenario
            Mock Get-Module { [PSCustomObject]@{Name = "TestModule"} }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "TestModule\Update-ModuleConfiguration" }
            
            { & $reloadFunc -ModuleName "TestModule" -Environment "test" } | Should -Not -Throw
        }
    }
    
    Context "Core Functionality" {
        It "Should initialize configuration store" {
            { Initialize-ConfigurationCore } | Should -Not -Throw
        }
        
        It "Should register module configuration" {
            $defaultConfig = @{
                Setting1 = "Value1"
                Setting2 = 42
            }
            
            { Register-ModuleConfiguration -ModuleName "TestModule" -DefaultConfiguration $defaultConfig } | Should -Not -Throw
        }
        
        It "Should get module configuration" {
            Register-ModuleConfiguration -ModuleName "TestModule" -DefaultConfiguration @{TestSetting = "TestValue"}
            
            $config = Get-ModuleConfiguration -ModuleName "TestModule"
            $config | Should -Not -BeNullOrEmpty
            $config.TestSetting | Should -Be "TestValue"
        }
        
        It "Should set module configuration" {
            Register-ModuleConfiguration -ModuleName "TestModule" -DefaultConfiguration @{TestSetting = "InitialValue"}
            
            Set-ModuleConfiguration -ModuleName "TestModule" -Configuration @{TestSetting = "UpdatedValue"}
            
            $config = Get-ModuleConfiguration -ModuleName "TestModule"
            $config.TestSetting | Should -Be "UpdatedValue"
        }
    }
    
    Context "Variable Expansion" {
        BeforeAll {
            # Get internal function for testing
            $module = Get-Module ConfigurationCore
            $expandFunc = & $module { Get-Command Expand-ConfigurationVariables }
        }
        
        It "Should expand variables in configuration" {
            $config = @{
                BaseDir = "C:/Test"
                SubDir = "`${BaseDir}/Sub"
            }
            
            $expanded = & $expandFunc -Configuration $config
            $expanded.SubDir | Should -Be "C:/Test/Sub"
        }
        
        It "Should handle nested variable expansion" {
            $config = @{
                Root = "C:/Root"
                Level1 = "`${Root}/L1"
                Level2 = "`${Level1}/L2"
            }
            
            $expanded = & $expandFunc -Configuration $config
            $expanded.Level2 | Should -Be "C:/Root/L1/L2"
        }
    }
}

Describe "Syntax Fix Verification" {
    It "Should not contain invalid variable syntax in error messages" {
        # This test specifically verifies our syntax fixes
        $moduleFiles = Get-ChildItem -Path (Join-Path $projectRoot "aither-core/modules/ConfigurationCore") -Filter "*.ps1" -Recurse
        
        foreach ($file in $moduleFiles) {
            $content = Get-Content $file.FullName -Raw
            
            # Check for the problematic pattern we fixed
            $content | Should -Not -Match '\$\w+:\s+\w+.*"'
            
            # Verify our fix is in place
            if ($file.Name -eq "Validate-Configuration.ps1") {
                $content | Should -Match '\$\{propName\}:'
            }
            if ($file.Name -eq "Invoke-ConfigurationReload.ps1") {
                $content | Should -Match '\$\{ModuleName\}:'
            }
        }
    }
}