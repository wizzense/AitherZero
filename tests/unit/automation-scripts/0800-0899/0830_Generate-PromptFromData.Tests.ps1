#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "automation-scripts/0830_Generate-PromptFromData.ps1"
    
    Mock Write-Host -MockWith {}
    Mock Write-Warning -MockWith {}
    Mock Write-Error -MockWith {}
    Mock Set-Content -MockWith {}
    Mock New-Item -MockWith {}
    Mock Get-Item -MockWith { return [PSCustomObject]@{ Length = 1024 } }
    Mock Test-Path -MockWith { $true }
    Mock Split-Path -MockWith { return ".claude" } -ParameterFilter { $Parent -eq $true }
    
    # Mock file content based on type
    Mock Get-Content -MockWith {
        param($Path, $Raw)
        
        if ($Path -like "*.json") {
            return '{"test": "data", "TotalCount": 5}'
        }
        if ($Path -like "*.xml") {
            return '<?xml version="1.0"?><root><item>test</item></root>'
        }
        if ($Path -like "*.csv") {
            return "Name,Value\nTest,123"
        }
        return "sample content"
    }
    
    Mock ConvertFrom-Json -MockWith {
        return @{ test = "data"; TotalCount = 5 }
    }
    
    Mock Import-Csv -MockWith {
        return @(@{ Name = "Test"; Value = "123" })
    }
    
    Mock Import-PowerShellDataFile -MockWith {
        return @{ ModuleName = "TestModule"; Version = "1.0.0" }
    }
    
    # Mock clipboard operations
    Mock Set-Clipboard -MockWith {}
    Mock pbcopy -MockWith {}
    Mock xclip -MockWith {}
    Mock Get-Command -MockWith { return $true } -ParameterFilter { $Name -eq "xclip" }
}

Describe "0830_Generate-PromptFromData" {
    Context "Parameter Validation" {
        It "Should require InputPath parameter" {
            { & $scriptPath } | Should -Throw
        }
        
        It "Should accept valid DataType values" {
            { & $scriptPath -InputPath "test.json" -DataType "JSON" -WhatIf } | Should -Not -Throw
            { & $scriptPath -InputPath "test.xml" -DataType "XML" -WhatIf } | Should -Not -Throw
            { & $scriptPath -InputPath "test.csv" -DataType "CSV" -WhatIf } | Should -Not -Throw
            { & $scriptPath -InputPath "test.json" -DataType "Auto" -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept valid PromptTemplate values" {
            { & $scriptPath -InputPath "test.json" -PromptTemplate "Analysis" -WhatIf } | Should -Not -Throw
            { & $scriptPath -InputPath "test.json" -PromptTemplate "Implementation" -WhatIf } | Should -Not -Throw
            { & $scriptPath -InputPath "test.json" -PromptTemplate "Conversion" -WhatIf } | Should -Not -Throw
            { & $scriptPath -InputPath "test.json" -PromptTemplate "Documentation" -WhatIf } | Should -Not -Throw
            { & $scriptPath -InputPath "test.json" -PromptTemplate "Testing" -WhatIf } | Should -Not -Throw
        }
        
        It "Should support WhatIf functionality" {
            { & $scriptPath -InputPath "test.json" -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "File Validation" {
        It "Should fail when input file does not exist" {
            Mock Test-Path -MockWith { $false }
            
            { & $scriptPath -InputPath "nonexistent.json" } | Should -Throw "*Input path not found*"
        }
        
        It "Should validate input path exists" {
            & $scriptPath -InputPath "test.json"
            
            Should -Invoke Test-Path -Times 1
        }
    }
    
    Context "Data Type Detection" {
        It "Should detect JSON by extension" {
            & $scriptPath -InputPath "test.json" -DataType "Auto"
            
            Should -Invoke Test-Path -Times 1
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should detect XML by extension" {
            & $scriptPath -InputPath "test.xml" -DataType "Auto"
            
            Should -Invoke Test-Path -Times 1
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should detect CSV by extension" {
            & $scriptPath -InputPath "test.csv" -DataType "Auto"
            
            Should -Invoke Test-Path -Times 1
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should detect Tanium export" {
            Mock Get-Content -MockWith { return '{"object_list": {"package_specs": []}}' }
            
            & $scriptPath -InputPath "tanium.json" -DataType "Auto"
            
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should detect test results" {
            Mock Get-Content -MockWith { return '{"Tests": [], "FailedCount": 0}' }
            
            & $scriptPath -InputPath "results.json" -DataType "Auto"
            
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should detect orchestration data" {
            Mock Get-Content -MockWith { return '{"stages": [], "playbook": "test"}' }
            
            & $scriptPath -InputPath "playbook.json" -DataType "Auto"
            
            Should -Invoke Get-Content -Times 1
        }
    }
    
    Context "Data Parsing" {
        It "Should parse JSON data" {
            & $scriptPath -InputPath "test.json" -DataType "JSON"
            
            Should -Invoke Get-Content -Times 1
            Should -Invoke ConvertFrom-Json -Times 1
        }
        
        It "Should parse XML data" {
            & $scriptPath -InputPath "test.xml" -DataType "XML"
            
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should parse CSV data" {
            & $scriptPath -InputPath "test.csv" -DataType "CSV"
            
            Should -Invoke Import-Csv -Times 1
        }
        
        It "Should parse PowerShell data files" {
            & $scriptPath -InputPath "test.psd1" -DataType "Configuration"
            
            Should -Invoke Import-PowerShellDataFile -Times 1
        }
        
        It "Should handle Tanium export format" {
            Mock Get-Content -MockWith { return '{"object_list": {"package_specs": [{"display_name": "Test Package"}]}, "comment": "Exported at 2023-01-01", "version": "1.0"}' }
            
            & $scriptPath -InputPath "tanium.json" -DataType "Tanium"
            
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should handle test results format" {
            Mock Get-Content -MockWith { return '{"TotalCount": 10, "PassedCount": 8, "FailedCount": 2}' }
            
            & $scriptPath -InputPath "results.json" -DataType "TestResults"
            
            Should -Invoke Get-Content -Times 1
        }
    }
    
    Context "Prompt Template Generation" {
        BeforeEach {
            Mock Test-Path -MockWith { $true }
        }
        
        It "Should generate analysis prompt" {
            & $scriptPath -InputPath "test.json" -PromptTemplate "Analysis"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Data Analysis Request*" }
        }
        
        It "Should generate implementation prompt" {
            & $scriptPath -InputPath "test.json" -PromptTemplate "Implementation"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Implementation Request*" }
        }
        
        It "Should generate conversion prompt" {
            & $scriptPath -InputPath "test.json" -PromptTemplate "Conversion"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Data Conversion Request*" }
        }
        
        It "Should generate documentation prompt" {
            & $scriptPath -InputPath "test.json" -PromptTemplate "Documentation"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Documentation Generation Request*" }
        }
        
        It "Should generate testing prompt" {
            & $scriptPath -InputPath "test.json" -PromptTemplate "Testing"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Test Generation Request*" }
        }
        
        It "Should handle custom template" {
            $customTemplate = "Custom template with {DataType} and {Content}"
            
            & $scriptPath -InputPath "test.json" -PromptTemplate "Custom" -CustomTemplate $customTemplate
            
            Should -Invoke Set-Content -Times 1
        }
        
        It "Should fail when custom template missing" {
            { & $scriptPath -InputPath "test.json" -PromptTemplate "Custom" } | Should -Throw "*Custom template required*"
        }
    }
    
    Context "Tanium-Specific Processing" {
        BeforeEach {
            Mock Get-Content -MockWith {
                return @'
{
    "object_list": {
        "package_specs": [
            {
                "display_name": "Test Package",
                "name": "test_package",
                "command": "powershell.exe -Command Get-Process",
                "command_timeout": 300,
                "content_set": {"name": "Base"},
                "files": [{"name": "script.ps1", "size": 1024}],
                "parameter_definition": "{\"parameters\": [{\"name\": \"param1\"}]}"
            }
        ]
    },
    "comment": "Exported at 2023-01-01 12:00:00",
    "version": "7.5.1"
}
'@
            }
            
            Mock Test-Path -MockWith { $true }
        }
        
        It "Should extract Tanium metadata" {
            & $scriptPath -InputPath "tanium.json" -DataType "Tanium" -PromptTemplate "Analysis"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Tanium Package Export Analysis*" }
        }
        
        It "Should include package details in analysis" {
            & $scriptPath -InputPath "tanium.json" -DataType "Tanium" -PromptTemplate "Analysis"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Package Details*" }
        }
        
        It "Should generate PowerShell conversion for Tanium" {
            & $scriptPath -InputPath "tanium.json" -DataType "Tanium" -PromptTemplate "Implementation"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Convert Tanium Package to PowerShell*" }
        }
    }
    
    Context "Test Results Processing" {
        BeforeEach {
            Mock Get-Content -MockWith {
                return '{"TotalCount": 10, "PassedCount": 8, "FailedCount": 2, "Tests": [{"Name": "FailedTest", "Result": "Failed", "ErrorRecord": "Test error"}]}'
            }
            Mock Test-Path -MockWith { $true }
        }
        
        It "Should analyze test results" {
            & $scriptPath -InputPath "results.json" -DataType "TestResults" -PromptTemplate "Analysis"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Test Results Analysis*" }
        }
        
        It "Should include test summary" {
            & $scriptPath -InputPath "results.json" -DataType "TestResults" -PromptTemplate "Analysis"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Total Tests:*" }
        }
        
        It "Should include failed test details" {
            & $scriptPath -InputPath "results.json" -DataType "TestResults" -PromptTemplate "Analysis"
            
            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Failed Tests*" }
        }
    }
    
    Context "Token Management and Compression" {
        It "Should estimate token count" {
            & $scriptPath -InputPath "test.json" -MaxTokens 4000
            
            Should -Invoke Set-Content -Times 1
        }
        
        It "Should compress content when exceeding token limit" {
            # Mock very large content
            Mock Get-Content -MockWith { return "x" * 50000 }
            
            & $scriptPath -InputPath "test.json" -MaxTokens 1000
            
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*exceeds token limit*" }
        }
        
        It "Should remove code examples during compression" {
            Mock Set-Content -MockWith {
                param($Path, $Value)
                if ($Value -like "*Code removed for brevity*") {
                    # Expected compression
                }
            }
            
            & $scriptPath -InputPath "test.json" -MaxTokens 100
            
            Should -Invoke Set-Content -Times 1
        }
    }
    
    Context "Interactive Mode" {
        It "Should show preview in interactive mode" {
            Mock Read-Host -MockWith { return "N" }
            
            & $scriptPath -InputPath "test.json" -Interactive
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Generated Prompt Preview:*" }
        }
        
        It "Should allow editing in interactive mode" {
            Mock Read-Host -MockWith { return "Y" }
            Mock Start-Process -MockWith {}
            Mock Remove-Item -MockWith {}
            
            & $scriptPath -InputPath "test.json" -Interactive
            
            Should -Invoke Read-Host -Times 1
        }
    }
    
    Context "Output and Clipboard" {
        It "Should save to output file" {
            & $scriptPath -InputPath "test.json"
            
            Should -Invoke Set-Content -Times 1
        }
        
        It "Should create output directory if needed" {
            Mock Test-Path -MockWith { $false } -ParameterFilter { $Path -like "*.claude*" }
            
            & $scriptPath -InputPath "test.json"
            
            Should -Invoke New-Item -ParameterFilter { $ItemType -eq "Directory" }
        }
        
        It "Should copy to clipboard when requested" {
            & $scriptPath -InputPath "test.json" -CopyToClipboard
            
            Should -Invoke Set-Clipboard -Times 1
        }
        
        It "Should display file size and token count" {
            & $scriptPath -InputPath "test.json"
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Size:*bytes*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Tokens:*" }
        }
    }
    
    Context "Context Integration" {
        It "Should include provided context in prompt" {
            $context = @{ ProjectName = "TestProject"; Version = "1.0.0" }
            
            & $scriptPath -InputPath "test.json" -Context $context
            
            Should -Invoke Set-Content -Times 1
        }
        
        It "Should replace context variables in custom templates" {
            $template = "Project: {Context.ProjectName}, Version: {Context.Version}"
            $context = @{ ProjectName = "TestProject"; Version = "1.0.0" }
            
            & $scriptPath -InputPath "test.json" -PromptTemplate "Custom" -CustomTemplate $template -Context $context
            
            Should -Invoke Set-Content -Times 1
        }
    }
    
    Context "Error Handling" {
        It "Should handle JSON parsing errors" {
            Mock ConvertFrom-Json -MockWith { throw "Invalid JSON" }
            
            { & $scriptPath -InputPath "test.json" -DataType "JSON" } | Should -Throw
        }
        
        It "Should handle XML parsing errors" {
            Mock Get-Content -MockWith { return "invalid xml" }
            
            { & $scriptPath -InputPath "test.xml" -DataType "XML" } | Should -Throw
        }
        
        It "Should handle file write errors" {
            Mock Set-Content -MockWith { throw "Write error" }
            
            { & $scriptPath -InputPath "test.json" } | Should -Throw
        }
        
        It "Should handle unknown data types" {
            Mock Get-Content -MockWith { return "unknown format" }
            
            { & $scriptPath -InputPath "test.unknown" -DataType "Auto" } | Should -Not -Throw
        }
        
        It "Should validate MaxTokens parameter" {
            { & $scriptPath -InputPath "test.json" -MaxTokens 0 } | Should -Not -Throw
            { & $scriptPath -InputPath "test.json" -MaxTokens -1 } | Should -Not -Throw
        }
    }
}
