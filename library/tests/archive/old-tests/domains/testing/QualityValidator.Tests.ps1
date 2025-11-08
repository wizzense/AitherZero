#Requires -Version 7.0

BeforeAll {
    # Import test helpers
    $testHelpersPath = Join-Path (Join-Path $PSScriptRoot '../..') 'tests/TestHelpers.psm1'
    if (Test-Path $testHelpersPath) {
        Import-Module $testHelpersPath -Force
    }
    
    # Initialize test environment
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $env:AITHERZERO_ROOT = $script:ProjectRoot
    $env:AITHERZERO_TEST_MODE = "1"
    
    # Import the quality validator module
    $qualityModulePath = Join-Path $script:ProjectRoot "domains/testing/QualityValidator.psm1"
    Import-Module $qualityModulePath -Force
}

Describe "QualityValidator Module" -Tag 'Unit', 'Quality' {
    
    Context "Module Import" {
        It "Should import successfully" {
            Get-Module QualityValidator | Should -Not -BeNullOrEmpty
        }
        
        It "Should export expected functions" {
            $module = Get-Module QualityValidator
            $exportedFunctions = $module.ExportedCommands.Keys
            
            $expectedFunctions = @(
                'Test-ErrorHandling'
                'Test-LoggingImplementation'
                'Test-TestCoverage'
                'Test-UIIntegration'
                'Test-GitHubActionsIntegration'
                'Test-PSScriptAnalyzerCompliance'
                'Invoke-QualityValidation'
                'Format-QualityReport'
            )
            
            foreach ($func in $expectedFunctions) {
                $exportedFunctions | Should -Contain $func
            }
        }
    }
    
    Context "Test-ErrorHandling" {
        BeforeAll {
            # Create test files
            $script:TestDir = Join-Path $TestDrive "quality-tests"
            New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
            
            # Good error handling
            $script:GoodErrorFile = Join-Path $script:TestDir "good-error.ps1"
            @'
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'

try {
    Invoke-RestMethod -Uri "https://api.example.com/data"
    New-Item -Path "./test" -ItemType Directory
} catch {
    Write-Error "Failed: $_"
    throw
} finally {
    # Cleanup
}
'@ | Set-Content -Path $script:GoodErrorFile
            
            # Poor error handling
            $script:PoorErrorFile = Join-Path $script:TestDir "poor-error.ps1"
            @'
#Requires -Version 7.0

Invoke-RestMethod -Uri "https://api.example.com/data"
Remove-Item -Path "./test" -Recurse -Force
'@ | Set-Content -Path $script:PoorErrorFile
        }
        
        It "Should pass for file with good error handling" {
            $result = Test-ErrorHandling -Path $script:GoodErrorFile
            $result | Should -Not -BeNullOrEmpty
            $result.CheckName | Should -Be 'ErrorHandling'
            $result.Status | Should -BeIn @('Passed', 'Warning')
            $result.Score | Should -BeGreaterThan 70
        }
        
        It "Should detect missing error handling" {
            $result = Test-ErrorHandling -Path $script:PoorErrorFile
            $result.Status | Should -BeIn @('Failed', 'Warning')
            $result.Score | Should -BeLessThan 90
        }
        
        It "Should detect try/catch blocks" {
            $result = Test-ErrorHandling -Path $script:GoodErrorFile
            $result.Details.TryCatchBlocks | Should -BeGreaterThan 0
        }
        
        It "Should check for ErrorActionPreference" {
            $result = Test-ErrorHandling -Path $script:GoodErrorFile
            $result.Details.HasErrorActionPreference | Should -Be $true
        }
    }
    
    Context "Test-LoggingImplementation" {
        BeforeAll {
            # Good logging
            $script:GoodLogFile = Join-Path $script:TestDir "good-log.ps1"
            @'
#Requires -Version 7.0

function Test-Something {
    Write-CustomLog -Level Information -Message "Starting test"
    
    try {
        Write-CustomLog -Level Information -Message "Processing"
        # Do work
        Write-CustomLog -Level Information -Message "Completed"
    } catch {
        Write-CustomLog -Level Error -Message "Failed: $_"
        throw
    }
}
'@ | Set-Content -Path $script:GoodLogFile
            
            # Poor logging
            $script:PoorLogFile = Join-Path $script:TestDir "poor-log.ps1"
            @'
#Requires -Version 7.0

function Test-Something {
    # Do work without logging
    $result = Get-Process
    return $result
}
'@ | Set-Content -Path $script:PoorLogFile
        }
        
        It "Should pass for file with good logging" {
            $result = Test-LoggingImplementation -Path $script:GoodLogFile
            $result.Status | Should -BeIn @('Passed', 'Warning')
            $result.Score | Should -BeGreaterThan 70
        }
        
        It "Should fail for file without logging" {
            $result = Test-LoggingImplementation -Path $script:PoorLogFile
            $result.Status | Should -Be 'Failed'
            $result.Score | Should -Be 0
        }
        
        It "Should count logging statements" {
            $result = Test-LoggingImplementation -Path $script:GoodLogFile
            $result.Details.TotalLoggingCalls | Should -BeGreaterThan 0
        }
        
        It "Should detect different logging levels" {
            $result = Test-LoggingImplementation -Path $script:GoodLogFile
            $result.Details.HasInfoLevel | Should -Be $true
            $result.Details.HasErrorLevel | Should -Be $true
        }
    }
    
    Context "Test-TestCoverage" {
        BeforeAll {
            # Create a module file
            $script:ModuleFile = Join-Path $script:TestDir "TestModule.psm1"
            @'
function Get-TestData {
    return "test"
}
Export-ModuleMember -Function Get-TestData
'@ | Set-Content -Path $script:ModuleFile
            
            # Create corresponding test file
            $script:TestFileDir = Join-Path $script:TestDir "tests"
            New-Item -Path $script:TestFileDir -ItemType Directory -Force | Out-Null
            
            $script:ModuleTestFile = Join-Path $script:TestFileDir "TestModule.Tests.ps1"
            @'
Describe "TestModule" {
    It "Should return test data" {
        $result = Get-TestData
        $result | Should -Be "test"
    }
    
    It "Should not be null" {
        Get-TestData | Should -Not -BeNullOrEmpty
    }
    
    It "Should be string type" {
        (Get-TestData).GetType().Name | Should -Be 'String'
    }
}
'@ | Set-Content -Path $script:ModuleTestFile
        }
        
        It "Should detect test file existence" {
            $result = Test-TestCoverage -Path $script:ModuleFile -TestsPath $script:TestFileDir
            $result.Details.TestFileExists | Should -Be $true
        }
        
        It "Should count test cases" {
            $result = Test-TestCoverage -Path $script:ModuleFile -TestsPath $script:TestFileDir
            $result.Details.ItBlocks | Should -BeGreaterThan 0
        }
        
        It "Should pass for module with tests" {
            $result = Test-TestCoverage -Path $script:ModuleFile -TestsPath $script:TestFileDir
            $result.Status | Should -BeIn @('Passed', 'Warning')
        }
        
        It "Should validate test file syntax" {
            $result = Test-TestCoverage -Path $script:ModuleFile -TestsPath $script:TestFileDir
            $result.Details.TestFileSyntaxValid | Should -Be $true
        }
    }
    
    Context "Test-UIIntegration" {
        BeforeAll {
            # Good UI integration
            $script:GoodUIFile = Join-Path $script:TestDir "good-ui.ps1"
            @'
<#
.SYNOPSIS
    Test script with good UI integration
.DESCRIPTION
    This script demonstrates proper UI integration
.PARAMETER Name
    The name parameter
.EXAMPLE
    ./good-ui.ps1 -Name "Test"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name
)

Write-Host "Processing: $Name"
'@ | Set-Content -Path $script:GoodUIFile
            
            # Poor UI integration
            $script:PoorUIFile = Join-Path $script:TestDir "poor-ui.ps1"
            @'
param($Name)
Write-Host $Name
'@ | Set-Content -Path $script:PoorUIFile
        }
        
        It "Should pass for file with good UI integration" {
            $result = Test-UIIntegration -Path $script:GoodUIFile
            $result.Status | Should -BeIn @('Passed', 'Warning')
            $result.Score | Should -BeGreaterThan 70
        }
        
        It "Should detect CmdletBinding" {
            $result = Test-UIIntegration -Path $script:GoodUIFile
            $result.Details.HasCmdletBinding | Should -Be $true
        }
        
        It "Should count parameters" {
            $result = Test-UIIntegration -Path $script:GoodUIFile
            $result.Details.ParameterCount | Should -BeGreaterThan 0
        }
        
        It "Should count help sections" {
            $result = Test-UIIntegration -Path $script:GoodUIFile
            $result.Details.HelpSections | Should -BeGreaterThan 2
        }
        
        It "Should warn for poor UI integration" {
            $result = Test-UIIntegration -Path $script:PoorUIFile
            $result.Status | Should -BeIn @('Failed', 'Warning')
        }
    }
    
    Context "Invoke-QualityValidation" {
        BeforeAll {
            # Create a comprehensive test file
            $script:ComprehensiveFile = Join-Path $script:TestDir "comprehensive.ps1"
            @'
<#
.SYNOPSIS
    Comprehensive test script
.DESCRIPTION
    This script has good quality practices
.PARAMETER Path
    The path parameter
.EXAMPLE
    ./comprehensive.ps1 -Path "test"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

function Process-Data {
    Write-CustomLog -Level Information -Message "Starting process"
    
    try {
        Invoke-RestMethod -Uri "https://api.example.com/data"
        Write-CustomLog -Level Information -Message "Data processed"
    } catch {
        Write-CustomLog -Level Error -Message "Failed: $_"
        throw
    } finally {
        Write-CustomLog -Level Information -Message "Cleanup complete"
    }
}
'@ | Set-Content -Path $script:ComprehensiveFile
        }
        
        It "Should run all checks" {
            $result = Invoke-QualityValidation -Path $script:ComprehensiveFile
            $result | Should -Not -BeNullOrEmpty
            $result.Checks | Should -Not -BeNullOrEmpty
            $result.Checks.Count | Should -BeGreaterThan 0
        }
        
        It "Should calculate overall score" {
            $result = Invoke-QualityValidation -Path $script:ComprehensiveFile
            $result.OverallScore | Should -BeGreaterOrEqual 0
            $result.OverallScore | Should -BeLessOrEqual 100
        }
        
        It "Should set overall status" {
            $result = Invoke-QualityValidation -Path $script:ComprehensiveFile
            $result.OverallStatus | Should -BeIn @('Passed', 'Warning', 'Failed')
        }
        
        It "Should support skipping checks" {
            $result = Invoke-QualityValidation -Path $script:ComprehensiveFile -SkipChecks @('GitHubActions')
            $skippedCheck = $result.Checks | Where-Object { $_.CheckName -eq 'GitHubActions' }
            $skippedCheck | Should -BeNullOrEmpty
        }
        
        It "Should generate summary" {
            $result = Invoke-QualityValidation -Path $script:ComprehensiveFile
            $result.Summary | Should -Not -BeNullOrEmpty
            $result.Summary.TotalChecks | Should -BeGreaterThan 0
        }
    }
    
    Context "Format-QualityReport" {
        BeforeAll {
            $script:TestReport = Invoke-QualityValidation -Path $script:ComprehensiveFile
        }
        
        It "Should format report as Text" {
            $formatted = Format-QualityReport -Report $script:TestReport -Format Text
            $formatted | Should -Not -BeNullOrEmpty
            $formatted | Should -BeOfType [string]
            $formatted | Should -Match "QUALITY VALIDATION REPORT"
        }
        
        It "Should format report as JSON" {
            $formatted = Format-QualityReport -Report $script:TestReport -Format JSON
            $formatted | Should -Not -BeNullOrEmpty
            { $formatted | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should format report as HTML" {
            $formatted = Format-QualityReport -Report $script:TestReport -Format HTML
            $formatted | Should -Not -BeNullOrEmpty
            $formatted | Should -Match "<html>"
            $formatted | Should -Match "</html>"
        }
    }
}

Describe "Quality Validation Integration" -Tag 'Integration', 'Quality' {
    
    Context "Real Module Validation" {
        BeforeAll {
            $script:ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
            $script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
        }
        
        It "Should validate existing Logging module" {
            if (Test-Path $script:LoggingModule) {
                $result = Invoke-QualityValidation -Path $script:LoggingModule
                $result | Should -Not -BeNullOrEmpty
                $result.OverallStatus | Should -BeIn @('Passed', 'Warning', 'Failed')
            }
        }
    }
}

AfterAll {
    # Cleanup
    Remove-Module QualityValidator -ErrorAction SilentlyContinue
}
