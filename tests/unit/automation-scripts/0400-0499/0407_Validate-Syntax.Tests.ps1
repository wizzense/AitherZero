#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0407_Validate-Syntax.ps1
.DESCRIPTION
    Tests the PowerShell syntax validation script functionality using AST parser.
#>

BeforeAll {
    # Get script path
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0407_Validate-Syntax.ps1"
    
    # Create test files
    $testScriptValid = Join-Path $TestDrive "ValidScript.ps1"
    $testScriptInvalid = Join-Path $TestDrive "InvalidScript.ps1"
    
    # Valid PowerShell script
    Set-Content -Path $testScriptValid -Value @'
param([string]$Name = "World")
Write-Host "Hello, $Name\!"
function Get-Greeting { return "Hello" }
'@

    # Invalid PowerShell script with syntax error
    Set-Content -Path $testScriptInvalid -Value @'
param([string]$Name = "World"
Write-Host "Hello, $Name\!"  # Missing closing parenthesis above
function Get-Greeting { return "Hello"  # Missing closing brace
'@

    # Mock functions
    Mock Write-Host {}
}

Describe "0407_Validate-Syntax" -Tag @('Unit', 'Testing', 'Syntax') {
    
    Context "Script Metadata" {
        It "Should have correct metadata structure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '#Requires -Version 7.0'
            $scriptContent | Should -Match 'Stage.*Testing'
            $scriptContent | Should -Match 'Description.*PowerShell syntax validation'
        }
    }

    Context "Parameter Validation" {
        It "Should require FilePath parameter" {
            { & $scriptPath } | Should -Throw
        }

        It "Should validate that FilePath exists" {
            { & $scriptPath -FilePath "/nonexistent/file.ps1" } | Should -Throw
        }

        It "Should accept valid file path" {
            { & $scriptPath -FilePath $testScriptValid -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Valid Script Processing" {
        It "Should validate syntax successfully for valid script" {
            $result = & $scriptPath -FilePath $testScriptValid
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Script syntax is valid*" 
            }
        }

        It "Should show detailed statistics when Detailed is specified" {
            $result = & $scriptPath -FilePath $testScriptValid -Detailed
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Script Statistics*" 
            }
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Functions:*" 
            }
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Commands:*" 
            }
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Total Lines:*" 
            }
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Tokens:*" 
            }
        }

        It "Should not show statistics when Detailed is not specified" {
            $result = & $scriptPath -FilePath $testScriptValid
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Write-Host -Times 0 -ParameterFilter { 
                $Object -like "*Script Statistics*" 
            }
        }
    }

    Context "Invalid Script Processing" {
        It "Should detect syntax errors in invalid script" {
            $result = & $scriptPath -FilePath $testScriptInvalid 2>$null
            $LASTEXITCODE | Should -Be 1
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Syntax errors found*" 
            }
        }

        It "Should show error details for syntax errors" {
            $result = & $scriptPath -FilePath $testScriptInvalid 2>$null
            $LASTEXITCODE | Should -Be 1
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Line*Column*" 
            }
        }

        It "Should show error context when Detailed is specified" {
            $result = & $scriptPath -FilePath $testScriptInvalid -Detailed 2>$null
            $LASTEXITCODE | Should -Be 1
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Context:*" 
            }
        }

        It "Should not show error context when Detailed is not specified" {
            $result = & $scriptPath -FilePath $testScriptInvalid 2>$null
            $LASTEXITCODE | Should -Be 1
            
            Assert-MockCalled Write-Host -Times 0 -ParameterFilter { 
                $Object -like "*Context:*" 
            }
        }
    }

    Context "AST Processing" {
        It "Should successfully parse valid PowerShell syntax" {
            $result = & $scriptPath -FilePath $testScriptValid
            $LASTEXITCODE | Should -Be 0
        }

        It "Should detect function definitions in detailed mode" {
            $result = & $scriptPath -FilePath $testScriptValid -Detailed
            
            # Should find the Get-Greeting function
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Functions: 1*" 
            }
        }

        It "Should count commands in detailed mode" {
            $result = & $scriptPath -FilePath $testScriptValid -Detailed
            
            # Should count Write-Host and other commands
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Commands:*" 
            }
        }

        It "Should count total lines in detailed mode" {
            $result = & $scriptPath -FilePath $testScriptValid -Detailed
            
            # Should show line count
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Total Lines:*" 
            }
        }

        It "Should count tokens in detailed mode" {
            $result = & $scriptPath -FilePath $testScriptValid -Detailed
            
            # Should show token count
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Tokens:*" 
            }
        }
    }

    Context "Error Handling" {
        BeforeAll {
            # Create a file that exists but can't be parsed due to permissions or corruption
            $testScriptCorrupt = Join-Path $TestDrive "CorruptScript.ps1"
            # Create a file with null bytes that might cause parsing issues
            [System.IO.File]::WriteAllBytes($testScriptCorrupt, @(0x00, 0x00, 0x00))
        }

        It "Should handle file parsing errors gracefully" {
            $result = & $scriptPath -FilePath $testScriptCorrupt 2>$null
            $LASTEXITCODE | Should -Be 1
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Error parsing file*" 
            }
        }

        It "Should show parsing error message" {
            $result = & $scriptPath -FilePath $testScriptCorrupt 2>$null
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $ForegroundColor -eq 'Red' 
            }
        }
    }

    Context "Multiple File Types" {
        BeforeAll {
            # Create different PowerShell file types
            $testModule = Join-Path $TestDrive "TestModule.psm1"
            $testManifest = Join-Path $TestDrive "TestManifest.psd1"
            
            Set-Content -Path $testModule -Value @'
function Get-TestFunction {
    param([string]$Parameter)
    return "Test: $Parameter"
}
Export-ModuleMember -Function Get-TestFunction
'@

            Set-Content -Path $testManifest -Value @'
@{
    ModuleVersion = '1.0.0'
    GUID = 'test-guid-1234'
    Author = 'Test Author'
    Description = 'Test module manifest'
}
'@
        }

        It "Should validate .psm1 module files" {
            $result = & $scriptPath -FilePath $testModule
            $LASTEXITCODE | Should -Be 0
        }

        It "Should validate .psd1 manifest files" {
            $result = & $scriptPath -FilePath $testManifest
            $LASTEXITCODE | Should -Be 0
        }

        It "Should show module function count in detailed mode" {
            $result = & $scriptPath -FilePath $testModule -Detailed
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Functions: 1*" 
            }
        }
    }

    Context "Exit Codes" {
        It "Should exit with code 0 for valid syntax" {
            $result = & $scriptPath -FilePath $testScriptValid
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit with code 1 for syntax errors" {
            $result = & $scriptPath -FilePath $testScriptInvalid 2>$null
            $LASTEXITCODE | Should -Be 1
        }

        It "Should exit with code 1 for parsing errors" {
            $testScriptCorrupt = Join-Path $TestDrive "CorruptScript.ps1"
            [System.IO.File]::WriteAllBytes($testScriptCorrupt, @(0x00, 0x00, 0x00))
            
            $result = & $scriptPath -FilePath $testScriptCorrupt 2>$null
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        It "Should use green color for success messages" {
            $result = & $scriptPath -FilePath $testScriptValid
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $ForegroundColor -eq 'Green' -and $Object -like "*Script syntax is valid*"
            }
        }

        It "Should use red color for error messages" {
            $result = & $scriptPath -FilePath $testScriptInvalid 2>$null
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $ForegroundColor -eq 'Red' 
            }
        }

        It "Should use cyan color for statistics header" {
            $result = & $scriptPath -FilePath $testScriptValid -Detailed
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $ForegroundColor -eq 'Cyan' -and $Object -like "*Script Statistics*"
            }
        }

        It "Should use yellow color for syntax error details" {
            $result = & $scriptPath -FilePath $testScriptInvalid 2>$null
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $ForegroundColor -eq 'Yellow' 
            }
        }
    }
}
