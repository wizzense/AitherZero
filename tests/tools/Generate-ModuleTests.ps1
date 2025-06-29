#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates baseline Pester tests for PowerShell modules
.DESCRIPTION
    Automatically generates comprehensive test files for modules that lack test coverage.
    Creates tests for:
    - Module loading and manifest validation
    - Function parameter validation
    - Basic functionality tests
    - Error handling scenarios
.PARAMETER ModuleName
    Name of the module to generate tests for
.PARAMETER ModulePath
    Path to the module directory
.PARAMETER OutputPath
    Path where test files should be created
.PARAMETER Force
    Overwrite existing test files
#>

param(
    [Parameter(Mandatory)]
    [string]$ModuleName,
    
    [Parameter(Mandatory)]
    [string]$ModulePath,
    
    [string]$OutputPath,
    
    [switch]$Force
)

# Import required modules
. "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force

# Set default output path
if (-not $OutputPath) {
    $OutputPath = Join-Path $projectRoot "tests/unit/modules" $ModuleName
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-CustomLog -Level 'INFO' -Message "Created test directory: $OutputPath"
}

# Check if test file already exists
$testFilePath = Join-Path $OutputPath "$ModuleName.Tests.ps1"
if ((Test-Path $testFilePath) -and -not $Force) {
    Write-CustomLog -Level 'WARNING' -Message "Test file already exists: $testFilePath. Use -Force to overwrite."
    return
}

# Load module to analyze
try {
    Import-Module $ModulePath -Force -ErrorAction Stop
    $moduleInfo = Get-Module $ModuleName
    Write-CustomLog -Level 'SUCCESS' -Message "Module loaded successfully: $ModuleName"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Failed to load module: $_"
    throw
}

# Get module manifest info
$manifestPath = Join-Path $ModulePath "$ModuleName.psd1"
$manifest = $null
if (Test-Path $manifestPath) {
    $manifest = Import-PowerShellDataFile $manifestPath
}

# Get exported functions
$exportedFunctions = Get-Command -Module $ModuleName -CommandType Function

# Generate test content
$testContent = @'
#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for MODULE_NAME module
.DESCRIPTION
    Automated tests generated for MODULE_NAME module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/MODULE_NAME"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "MODULE_NAME Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "MODULE_NAME.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module MODULE_NAME
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
MODULE_FUNCTIONS
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module MODULE_NAME
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
MODULE_FUNCTION_TESTS
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module MODULE_NAME
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module MODULE_NAME -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module MODULE_NAME | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module MODULE_NAME | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "MODULE_NAME Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "MODULE_NAME-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "MODULE_NAME test" } | Should -Not -Throw
        }
    }
}

Describe "MODULE_NAME Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module MODULE_NAME
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}
'@

# Replace placeholders
$testContent = $testContent -replace 'MODULE_NAME', $ModuleName

# Generate function list
$functionList = $exportedFunctions | ForEach-Object {
    "                '$($_.Name)'"
} | Join-String -Separator ",`n"
$testContent = $testContent -replace 'MODULE_FUNCTIONS', $functionList

# Generate individual function tests
$functionTests = @()
foreach ($function in $exportedFunctions) {
    $params = $function.Parameters
    $functionTest = @"
    Context "$($function.Name) Function Tests" {
        
        It "Should have proper parameter definitions" {
            `$command = Get-Command $($function.Name)
            `$command | Should -Not -BeNullOrEmpty
            `$command.CommandType | Should -Be 'Function'
        }
"@
    
    # Add parameter validation tests
    foreach ($param in $params.GetEnumerator()) {
        if ($param.Key -notin @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')) {
            $paramInfo = $param.Value
            
            if ($paramInfo.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }) {
                $validateSet = $paramInfo.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                $validValues = $validateSet.ValidValues -join '", "'
                $functionTest += @"
        
        It "Should validate $($param.Key) parameter values" {
            `$validValues = @("$validValues")
            { $($function.Name) -$($param.Key) "InvalidValue" -ErrorAction Stop } | Should -Throw
        }
"@
            }
        }
    }
    
    # Add basic functionality test
    $functionTest += @"
        
        It "Should execute without errors when given valid parameters" {
            # This is a basic smoke test - implement specific logic based on function purpose
            `$command = Get-Command $($function.Name)
            
            # Skip if function has mandatory parameters (would need specific test data)
            `$mandatoryParams = `$command.Parameters.Values | 
                Where-Object { `$_.Attributes.Mandatory -eq `$true }
            
            if (-not `$mandatoryParams) {
                { & `$command.Name -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
"@
    
    $functionTests += $functionTest
}

$testContent = $testContent -replace 'MODULE_FUNCTION_TESTS', ($functionTests -join "`n")

# Write test file
Set-Content -Path $testFilePath -Value $testContent -Encoding UTF8
Write-CustomLog -Level 'SUCCESS' -Message "Generated test file: $testFilePath"

# Return summary
@{
    Module = $ModuleName
    TestFile = $testFilePath
    FunctionsFound = $exportedFunctions.Count
    TestsGenerated = $exportedFunctions.Count * 3  # Approximate number of tests per function
}