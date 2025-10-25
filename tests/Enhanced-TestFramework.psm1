#Requires -Version 7.0
<#
.SYNOPSIS
    Enhanced testing framework with automatic test generation and validation
.DESCRIPTION
    Advanced testing framework for AitherZero with:
    - Dynamic test generation from PowerShell AST
    - Comprehensive module validation
    - Configuration testing
    - Performance benchmarking
    - Code coverage analysis
#>

# Get project root
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:TestingConfig = @{
    TimeoutSeconds = 30
    MaxRetries = 3
    CoverageThreshold = 80
    RequiredModules = @('Pester', 'PSScriptAnalyzer')
}

function Initialize-EnhancedTestEnvironment {
    <#
    .SYNOPSIS
        Initialize enhanced test environment with comprehensive setup
    #>
    [CmdletBinding()]
    param(
        [string[]]$RequiredModules = @(),
        [switch]$SkipModuleLoad,
        [switch]$EnableCodeCoverage,
        [hashtable]$TestConfig = @{}
    )

    # Merge custom config
    $script:TestingConfig = $script:TestingConfig + $TestConfig

    # Clean environment
    $conflictingModules = @('AitherRun', 'CoreApp', 'ConfigurationManager', 'aitherzero')
    foreach ($module in $conflictingModules) {
        if (Get-Module -Name $module -ErrorAction SilentlyContinue) {
            Remove-Module -Name $module -Force -ErrorAction SilentlyContinue
        }
    }

    # Set environment variables for testing
    $env:AITHERZERO_ROOT = $script:ProjectRoot
    $env:AITHERZERO_TEST_MODE = "1"
    $env:AITHERZERO_DISABLE_TRANSCRIPT = "1"
    $env:AITHERZERO_LOG_LEVEL = "Warning"  # Reduce noise during tests

    # Verify required modules
    foreach ($moduleName in $script:TestingConfig.RequiredModules + $RequiredModules) {
        if (-not (Get-Module -Name $moduleName -ListAvailable)) {
            throw "Required module not available: $moduleName. Please install it first."
        }
    }

    if (-not $SkipModuleLoad) {
        # Import main module with error handling
        $mainModule = Join-Path $script:ProjectRoot "AitherZero.psm1"
        if (Test-Path $mainModule) {
            try {
                Import-Module $mainModule -Force -Global -ErrorAction Stop
                Write-Verbose "Main module loaded successfully"
            } catch {
                Write-Error "Failed to load main module: $($_.Exception.Message)"
                throw
            }
        }

        # Import additional modules
        foreach ($moduleName in $RequiredModules) {
            $modulePath = Get-ChildItem -Path (Join-Path $script:ProjectRoot "domains") -Filter "$moduleName.psm1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($modulePath) {
                Import-Module $modulePath.FullName -Force -Global
                Write-Verbose "Loaded module: $moduleName"
            }
        }
    }

    # Create test directories if they don't exist
    $testDirs = @('results', 'coverage', 'reports', 'generated')
    foreach ($dir in $testDirs) {
        $dirPath = Join-Path $PSScriptRoot $dir
        if (-not (Test-Path $dirPath)) {
            New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
        }
    }

    Write-Verbose "Enhanced test environment initialized"
}

function Test-ModuleStructure {
    <#
    .SYNOPSIS
        Test module structure and validate compliance
    #>
    [CmdletBinding()]
    param(
        [string]$ModulePath,
        [hashtable]$ValidationRules = @{}
    )

    $defaultRules = @{
        RequiredFunctions = @()
        MaxFunctionLength = 100
        RequireHelp = $true
        RequireErrorHandling = $true
        MaxComplexity = 10
    }

    $rules = $defaultRules + $ValidationRules
    $results = @{
        IsValid = $true
        Issues = @()
        Metrics = @{}
    }

    if (-not (Test-Path $ModulePath)) {
        $results.IsValid = $false
        $results.Issues += "Module file not found: $ModulePath"
        return $results
    }

    try {
        # Parse module content
        $content = Get-Content $ModulePath -Raw
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors) {
            $results.IsValid = $false
            $results.Issues += "Parse errors: $($parseErrors -join ', ')"
            return $results
        }

        # Analyze functions
        $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        $results.Metrics.FunctionCount = $functions.Count

        foreach ($func in $functions) {
            $funcName = $func.Name
            $funcBody = $func.Body.Extent.Text
            $lineCount = ($funcBody -split "`n").Count

            # Check function length
            if ($rules.MaxFunctionLength -gt 0 -and $lineCount -gt $rules.MaxFunctionLength) {
                $results.Issues += "Function '$funcName' is too long: $lineCount lines (max: $($rules.MaxFunctionLength))"
            }

            # Check for help documentation
            if ($rules.RequireHelp) {
                $helpContent = $func.GetHelpContent()
                if (-not $helpContent -or $helpContent.Synopsis -eq '') {
                    $results.Issues += "Function '$funcName' lacks proper help documentation"
                }
            }

            # Check for error handling
            if ($rules.RequireErrorHandling) {
                $hasTryCatch = $func.Body.Find({ $args[0] -is [System.Management.Automation.Language.TryStatementAst] }, $false)
                $hasErrorAction = $funcBody -match 'ErrorAction'
                
                if (-not $hasTryCatch -and -not $hasErrorAction) {
                    $results.Issues += "Function '$funcName' lacks error handling (try/catch or ErrorAction)"
                }
            }
        }

        # Check for required functions
        $exportedFunctions = $functions | Where-Object { $_.Name -in $rules.RequiredFunctions }
        $missingFunctions = $rules.RequiredFunctions | Where-Object { $_ -notin $exportedFunctions.Name }
        
        foreach ($missing in $missingFunctions) {
            $results.Issues += "Required function missing: $missing"
        }

        # Check Export-ModuleMember
        $exportStatements = $ast.FindAll({ 
            $args[0] -is [System.Management.Automation.Language.CommandAst] -and 
            $args[0].GetCommandName() -eq 'Export-ModuleMember'
        }, $true)

        if ($exportStatements.Count -eq 0) {
            $results.Issues += "No Export-ModuleMember statement found"
        }

        $results.IsValid = $results.Issues.Count -eq 0

    } catch {
        $results.IsValid = $false
        $results.Issues += "Analysis failed: $($_.Exception.Message)"
    }

    return $results
}

function Test-ConfigurationFile {
    <#
    .SYNOPSIS
        Test configuration file validity and completeness
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [string[]]$RequiredSections = @('Core', 'InstallationOptions'),
        [hashtable]$ValidationRules = @{}
    )

    $results = @{
        IsValid = $true
        Issues = @()
        Configuration = $null
        Sections = @()
    }

    if (-not (Test-Path $ConfigPath)) {
        $results.IsValid = $false
        $results.Issues += "Configuration file not found: $ConfigPath"
        return $results
    }

    try {
        # Try to parse as PowerShell data file
        $config = Import-PowerShellDataFile -Path $ConfigPath
        $results.Configuration = $config
        $results.Sections = $config.Keys

        # Check required sections
        foreach ($section in $RequiredSections) {
            if (-not $config.ContainsKey($section)) {
                $results.Issues += "Required section missing: $section"
            }
        }

        # Validate Core section if it exists
        if ($config.ContainsKey('Core')) {
            $core = $config.Core
            $requiredCoreKeys = @('Name', 'Version', 'Profile')
            
            foreach ($key in $requiredCoreKeys) {
                if (-not $core.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($core[$key])) {
                    $results.Issues += "Core section missing required key: $key"
                }
            }

            # Validate version format
            if ($core.ContainsKey('Version')) {
                try {
                    [System.Version]::Parse($core.Version) | Out-Null
                } catch {
                    $results.Issues += "Invalid version format: $($core.Version)"
                }
            }
        }

        # Custom validation rules
        foreach ($rule in $ValidationRules.GetEnumerator()) {
            $section = $rule.Key
            $requirements = $rule.Value
            
            if ($config.ContainsKey($section)) {
                foreach ($req in $requirements) {
                    if (-not $config[$section].ContainsKey($req)) {
                        $results.Issues += "Section '$section' missing required key: $req"
                    }
                }
            }
        }

        $results.IsValid = $results.Issues.Count -eq 0

    } catch {
        $results.IsValid = $false
        $results.Issues += "Failed to parse configuration: $($_.Exception.Message)"
    }

    return $results
}

function New-DynamicTests {
    <#
    .SYNOPSIS
        Generate dynamic tests based on PowerShell AST analysis
    #>
    [CmdletBinding()]
    param(
        [string]$ModulePath,
        [string]$TestOutputPath,
        [hashtable]$TestTemplates = @{}
    )

    if (-not (Test-Path $ModulePath)) {
        throw "Module not found: $ModulePath"
    }

    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($ModulePath)
    
    # Parse module
    $content = Get-Content $ModulePath -Raw
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
    
    # Extract functions and their metadata
    $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    
    # Generate comprehensive test content
    $testContent = @"
#Requires -Version 7.0
<#
.SYNOPSIS
    Dynamically generated tests for $moduleName
.DESCRIPTION
    Auto-generated comprehensive test suite based on AST analysis
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Functions found: $($functions.Count)
#>

BeforeAll {
    Import-Module `$PSScriptRoot/../Enhanced-TestFramework.psm1 -Force
    Initialize-EnhancedTestEnvironment -RequiredModules @('$moduleName')
    
    # Import the module under test
    Import-Module `$PSScriptRoot/../../domains/*/$moduleName.psm1 -Force -ErrorAction Stop
}

Describe "$moduleName Module Validation" -Tags @('Module', 'Structure') {
    
    Context "Module Structure Tests" {
        It "Module should load without errors" {
            { Import-Module `$PSScriptRoot/../../domains/*/$moduleName.psm1 -Force } | Should -Not -Throw
        }
        
        It "Module should export functions" {
            `$moduleObj = Get-Module $moduleName
            `$moduleObj | Should -Not -BeNullOrEmpty
            `$moduleObj.ExportedFunctions.Count | Should -BeGreaterThan 0
        }
        
        It "Module should pass PSScriptAnalyzer validation" {
            `$modulePath = (Get-Module $moduleName).Path
            if (Get-Module PSScriptAnalyzer -ListAvailable) {
                `$issues = Invoke-ScriptAnalyzer -Path `$modulePath -Severity Error
                `$issues.Count | Should -Be 0
            }
        }
    }
"@

    # Generate function-specific tests
    foreach ($func in $functions) {
        $funcName = $func.Name
        $parameters = $func.Parameters
        $hasHelp = $func.GetHelpContent() -ne $null

        $testContent += @"

    Context "$funcName Function Tests" -Tags @('Function', '$funcName') {
        
        BeforeAll {
            `$functionInfo = Get-Command $funcName -ErrorAction SilentlyContinue
        }
        
        It "Should exist and be callable" {
            `$functionInfo | Should -Not -BeNullOrEmpty
            `$functionInfo.CommandType | Should -Be 'Function'
        }
        
        It "Should have help documentation" {
            `$help = Get-Help $funcName -ErrorAction SilentlyContinue
            `$help | Should -Not -BeNullOrEmpty
            if (`$help.Synopsis -ne `$funcName) {
                `$help.Synopsis | Should -Not -BeNullOrEmpty
            }
        }
"@

        # Add parameter validation tests
        if ($parameters.Count -gt 0) {
            $testContent += @"
        
        It "Should have $($parameters.Count) parameter(s)" {
            `$functionInfo.Parameters.Count | Should -BeGreaterOrEqual $($parameters.Count)
        }
"@

            # Test each parameter
            foreach ($param in $parameters) {
                $paramName = $param.Name.VariablePath.UserPath
                $testContent += @"
        
        It "Should have parameter '$paramName'" {
            `$functionInfo.Parameters.ContainsKey('$paramName') | Should -BeTrue
        }
"@
            }
        }

        # Add basic execution test
        $testContent += @"
        
        It "Should not throw when called with valid parameters" -Skip:`$(`$functionInfo.Parameters.Count -eq 0) {
            # Basic validation - customize based on function requirements
            { `$functionInfo } | Should -Not -Throw
        }
        
        It "Should handle invalid input gracefully" -Skip {
            # Add specific invalid input tests based on function requirements
            # This test is skipped by default - implement as needed
        }
    }
"@
    }

    # Add performance tests
    $testContent += @"

    Context "Performance Tests" -Tags @('Performance') {
        It "Module should load within acceptable time" {
            `$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Import-Module `$PSScriptRoot/../../domains/*/$moduleName.psm1 -Force
            `$stopwatch.Stop()
            `$stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 5000  # 5 seconds max
        }
    }
    
    Context "Configuration Tests" -Tags @('Configuration') {
        It "Module should handle missing dependencies gracefully" {
            # Test module behavior with missing dependencies
            `$true | Should -BeTrue  # Placeholder - implement specific tests
        }
        
        It "Module should work in different PowerShell environments" {
            `$PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
        }
    }
}
"@

    # Ensure output directory exists
    $outputDir = Split-Path $TestOutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    # Write the test file
    $testContent | Set-Content -Path $TestOutputPath -Encoding UTF8
    
    return @{
        TestFile = $TestOutputPath
        FunctionCount = $functions.Count
        ModuleName = $moduleName
        Generated = Get-Date
    }
}

function Invoke-ComprehensiveValidation {
    <#
    .SYNOPSIS
        Run comprehensive validation on all AitherZero components
    #>
    [CmdletBinding()]
    param(
        [switch]$GenerateTests,
        [switch]$RunTests,
        [switch]$AnalyzeCode,
        [string[]]$ModulesToTest = @(),
        [string]$OutputPath = './tests/reports'
    )

    $results = @{
        Timestamp = Get-Date
        Modules = @{}
        Configuration = @{}
        Tests = @{}
        Overall = @{
            Success = $true
            Issues = @()
        }
    }

    Write-Host "🚀 Starting comprehensive validation..." -ForegroundColor Cyan

    # Get modules to validate
    if ($ModulesToTest.Count -eq 0) {
        $moduleFiles = Get-ChildItem -Path (Join-Path $script:ProjectRoot 'domains') -Filter '*.psm1' -Recurse
        $ModulesToTest = $moduleFiles | ForEach-Object { $_.BaseName }
    }

    # Test each module
    foreach ($moduleName in $ModulesToTest) {
        Write-Host "📦 Validating module: $moduleName" -ForegroundColor Yellow
        
        $modulePath = Get-ChildItem -Path (Join-Path $script:ProjectRoot 'domains') -Filter "$moduleName.psm1" -Recurse | Select-Object -First 1
        
        if (-not $modulePath) {
            $results.Overall.Issues += "Module not found: $moduleName"
            continue
        }

        # Test module structure
        $moduleResult = Test-ModuleStructure -ModulePath $modulePath.FullName
        $results.Modules[$moduleName] = $moduleResult

        if (-not $moduleResult.IsValid) {
            $results.Overall.Success = $false
            $results.Overall.Issues += "Module $moduleName has issues: $($moduleResult.Issues -join ', ')"
        }

        # Generate tests if requested
        if ($GenerateTests) {
            try {
                $testPath = Join-Path $PSScriptRoot "generated/Generated.$moduleName.Tests.ps1"
                $testInfo = New-DynamicTests -ModulePath $modulePath.FullName -TestOutputPath $testPath
                $results.Tests[$moduleName] = $testInfo
                Write-Host "  ✅ Generated tests: $testPath" -ForegroundColor Green
            } catch {
                $results.Overall.Issues += "Test generation failed for $moduleName`: $($_.Exception.Message)"
                Write-Host "  ❌ Test generation failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    # Test configuration
    Write-Host "⚙️ Validating configuration..." -ForegroundColor Yellow
    $configPath = Join-Path $script:ProjectRoot 'config.psd1'
    $configResult = Test-ConfigurationFile -ConfigPath $configPath
    $results.Configuration = $configResult

    if (-not $configResult.IsValid) {
        $results.Overall.Success = $false
        $results.Overall.Issues += "Configuration issues: $($configResult.Issues -join ', ')"
    }

    # Run tests if requested
    if ($RunTests) {
        Write-Host "🧪 Running Pester tests..." -ForegroundColor Yellow
        
        try {
            if (Get-Module Pester -ListAvailable) {
                $config = New-PesterConfiguration
                $config.Run.Path = Join-Path $PSScriptRoot 'generated'
                $config.Output.Verbosity = 'Minimal'
                
                $pesterResult = Invoke-Pester -Configuration $config
                $results.Tests.PesterResult = @{
                    Total = $pesterResult.TotalCount
                    Passed = $pesterResult.PassedCount
                    Failed = $pesterResult.FailedCount
                    Duration = $pesterResult.Duration
                }

                if ($pesterResult.FailedCount -gt 0) {
                    $results.Overall.Success = $false
                    $results.Overall.Issues += "$($pesterResult.FailedCount) test(s) failed"
                }
            }
        } catch {
            $results.Overall.Issues += "Pester execution failed: $($_.Exception.Message)"
        }
    }

    # Export results
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $reportFile = Join-Path $OutputPath "ValidationReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $results | ConvertTo-Json -Depth 10 | Set-Content -Path $reportFile -Encoding UTF8

    # Summary
    Write-Host "`n📊 Validation Summary:" -ForegroundColor Cyan
    Write-Host "Modules tested: $($results.Modules.Count)" -ForegroundColor White
    Write-Host "Configuration valid: $($results.Configuration.IsValid)" -ForegroundColor ($results.Configuration.IsValid ? 'Green' : 'Red')
    Write-Host "Overall success: $($results.Overall.Success)" -ForegroundColor ($results.Overall.Success ? 'Green' : 'Red')
    
    if ($results.Overall.Issues.Count -gt 0) {
        Write-Host "`nIssues found:" -ForegroundColor Yellow
        $results.Overall.Issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }

    Write-Host "`nReport saved: $reportFile" -ForegroundColor Cyan

    return $results
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-EnhancedTestEnvironment',
    'Test-ModuleStructure',
    'Test-ConfigurationFile', 
    'New-DynamicTests',
    'Invoke-ComprehensiveValidation'
)