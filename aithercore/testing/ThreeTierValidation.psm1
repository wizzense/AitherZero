#Requires -Version 7.0

<#
.SYNOPSIS
    Three-Tier Validation Framework for AitherZero
.DESCRIPTION
    Comprehensive validation system combining:
    
    **Tier 1: AST Parsing** - Static analysis of script structure
    - Parse script without execution
    - Extract functions, parameters, variables
    - Validate syntax and structure
    - Detect patterns and anti-patterns
    - No execution risk
    
    **Tier 2: PSScriptAnalyzer** - Code quality and best practices
    - Rule-based static analysis
    - PowerShell best practices
    - Security vulnerability detection
    - Performance recommendations
    - Compatibility analysis
    
    **Tier 3: Pester Testing** - Functional validation
    - Execute with mocking
    - Validate behavior
    - Test edge cases
    - Integration testing
    - Performance benchmarking
    
.NOTES
    This framework ensures COMPREHENSIVE validation at multiple levels.
    Each tier complements the others for defense-in-depth testing.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Tier 1: AST Parsing Validation

function Invoke-ASTValidation {
    <#
    .SYNOPSIS
        Tier 1: AST-based static analysis
    .DESCRIPTION
        Parse and validate script structure using PowerShell AST:
        - Syntax validation (parse errors)
        - Structure analysis (functions, parameters, variables)
        - Pattern detection (best practices, anti-patterns)
        - Dependency extraction
        - Complexity metrics
        
    .PARAMETER ScriptPath
        Path to script to validate
    
    .EXAMPLE
        $astResult = Invoke-ASTValidation -ScriptPath './script.ps1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )
    
    $result = @{
        Tier = 'AST'
        Success = $false
        Errors = @()
        Warnings = @()
        Info = @{}
        Metrics = @{}
    }
    
    # Parse script
    $tokens = $null
    $errors = $null
    try {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $ScriptPath, [ref]$tokens, [ref]$errors
        )
        
        # Check for parse errors
        if ($errors.Count -gt 0) {
            $result.Errors += $errors | ForEach-Object {
                @{
                    Message = $_.Message
                    Line = if ($_.Extent) { $_.Extent.StartLineNumber } else { 0 }
                    Column = if ($_.Extent) { $_.Extent.StartColumnNumber } else { 0 }
                    Severity = 'Error'
                }
            }
            return $result
        }
        
        # Extract functions
        $functions = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)
        
        # Extract parameters
        $paramBlocks = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.ParamBlockAst]
        }, $true)
        
        # Extract variables
        $variables = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.VariableExpressionAst]
        }, $true)
        
        # Extract command calls
        $commands = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true)
        
        # Build info
        $result.Info = @{
            Functions = $functions | ForEach-Object {
                @{
                    Name = $_.Name
                    Parameters = $_.Parameters.Count
                    Line = $_.Extent.StartLineNumber
                    HasHelpBlock = $null -ne $_.GetHelpContent()
                    IsAdvanced = $null -ne $_.Body.ParamBlock
                }
            }
            Parameters = $paramBlocks | ForEach-Object {
                $_.Parameters | ForEach-Object {
                    @{
                        Name = $_.Name.VariablePath.UserPath
                        Type = if ($_.StaticType) { $_.StaticType.Name } else { 'Object' }
                        IsMandatory = $_.Attributes | Where-Object { 
                            $_ -is [System.Management.Automation.Language.AttributeAst] -and 
                            $_.TypeName.Name -eq 'Parameter' -and
                            $_.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' }
                        }
                        HasValidation = ($_.Attributes | Where-Object { 
                            $_.TypeName.Name -match '^Validate'
                        }).Count -gt 0
                    }
                }
            }
            Variables = ($variables | Select-Object -Unique -ExpandProperty VariablePath | 
                        Where-Object { $_ } | Select-Object -ExpandProperty UserPath | 
                        Sort-Object -Unique)
            Commands = ($commands | Select-Object -ExpandProperty CommandElements | 
                       Select-Object -First 1 -ExpandProperty Value | 
                       Where-Object { $_ } | Sort-Object -Unique)
        }
        
        # Calculate metrics
        $result.Metrics = @{
            TotalLines = (Get-Content $ScriptPath).Count
            FunctionCount = $functions.Count
            ParameterCount = ($paramBlocks | ForEach-Object { $_.Parameters.Count } | Measure-Object -Sum).Sum
            VariableCount = $result.Info.Variables.Count
            CommandCount = $commands.Count
            CyclomaticComplexity = Get-CyclomaticComplexity -AST $ast
            NestingDepth = Get-MaxNestingDepth -AST $ast
        }
        
        # Pattern detection
        $result.Warnings += Find-ASTAntiPatterns -AST $ast
        
        $result.Success = $true
        
    } catch {
        $result.Errors += @{
            Message = "AST parsing failed: $_"
            Severity = 'Error'
        }
    }
    
    return $result
}

function Get-CyclomaticComplexity {
    <#
    .SYNOPSIS
        Calculate cyclomatic complexity from AST
    #>
    param([System.Management.Automation.Language.Ast]$AST)
    
    $complexity = 1  # Base complexity
    
    # Count decision points
    $decisionPoints = $AST.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.IfStatementAst] -or
        $node -is [System.Management.Automation.Language.SwitchStatementAst] -or
        $node -is [System.Management.Automation.Language.WhileStatementAst] -or
        $node -is [System.Management.Automation.Language.ForStatementAst] -or
        $node -is [System.Management.Automation.Language.ForEachStatementAst] -or
        $node -is [System.Management.Automation.Language.TryStatementAst]
    }, $true)
    
    $complexity += $decisionPoints.Count
    
    # Add for switch cases
    $switchCases = $AST.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.SwitchStatementAst]
    }, $true) | ForEach-Object { $_.Clauses.Count } | Measure-Object -Sum
    
    $complexity += $switchCases.Sum
    
    return $complexity
}

function Get-MaxNestingDepth {
    <#
    .SYNOPSIS
        Calculate maximum nesting depth from AST
    #>
    param([System.Management.Automation.Language.Ast]$AST)
    
    $maxDepth = 0
    
    $scriptBlocks = $AST.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.ScriptBlockAst]
    }, $true)
    
    foreach ($block in $scriptBlocks) {
        $depth = 0
        $current = $block
        while ($current = $current.Parent) {
            if ($current -is [System.Management.Automation.Language.ScriptBlockAst]) {
                $depth++
            }
        }
        $maxDepth = [Math]::Max($maxDepth, $depth)
    }
    
    return $maxDepth
}

function Find-ASTAntiPatterns {
    <#
    .SYNOPSIS
        Detect anti-patterns using AST analysis
    #>
    param([System.Management.Automation.Language.Ast]$AST)
    
    $warnings = @()
    
    # Anti-pattern: Using Write-Host (should use Write-Output or Write-Information)
    $writeHostCalls = $AST.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Write-Host'
    }, $true)
    
    if ($writeHostCalls.Count -gt 0) {
        $warnings += @{
            Pattern = 'Write-Host'
            Message = "Found $($writeHostCalls.Count) Write-Host calls. Consider Write-Output or Write-Information"
            Severity = 'Information'
            Locations = $writeHostCalls | ForEach-Object { $_.Extent.StartLineNumber }
        }
    }
    
    # Anti-pattern: Positional parameters
    $positionalParams = $AST.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.CommandElements.Count -gt 1 -and
        $node.CommandElements[1] -isnot [System.Management.Automation.Language.CommandParameterAst]
    }, $true)
    
    if ($positionalParams.Count -gt 5) {
        $warnings += @{
            Pattern = 'PositionalParameters'
            Message = "Heavy use of positional parameters ($($positionalParams.Count)). Consider named parameters"
            Severity = 'Information'
        }
    }
    
    # Anti-pattern: Empty catch blocks
    $tryCatchBlocks = $AST.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.TryStatementAst]
    }, $true)
    
    foreach ($tryBlock in $tryCatchBlocks) {
        foreach ($catch in $tryBlock.CatchClauses) {
            if ($catch.Body.Statements.Count -eq 0) {
                $warnings += @{
                    Pattern = 'EmptyCatchBlock'
                    Message = "Empty catch block at line $($catch.Extent.StartLineNumber)"
                    Severity = 'Warning'
                    Location = $catch.Extent.StartLineNumber
                }
            }
        }
    }
    
    return $warnings
}

#endregion

#region Tier 2: PSScriptAnalyzer Validation

function Invoke-PSScriptAnalyzerValidation {
    <#
    .SYNOPSIS
        Tier 2: PSScriptAnalyzer code quality analysis
    .DESCRIPTION
        Run PSScriptAnalyzer for best practices and quality:
        - PowerShell best practices
        - Security vulnerabilities
        - Performance issues
        - Compatibility problems
        - Code smells
        
    .PARAMETER ScriptPath
        Path to script to analyze
    
    .PARAMETER Severity
        Severity levels to include
    
    .PARAMETER ExcludeRules
        Rules to exclude
    
    .EXAMPLE
        $pssaResult = Invoke-PSScriptAnalyzerValidation -ScriptPath './script.ps1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [string[]]$Severity = @('Error', 'Warning'),
        
        [string[]]$ExcludeRules = @()
    )
    
    $result = @{
        Tier = 'PSScriptAnalyzer'
        Success = $false
        Errors = @()
        Warnings = @()
        Information = @()
        Findings = @()
    }
    
    try {
        # Check if PSScriptAnalyzer is available
        if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            $result.Errors += @{
                Message = 'PSScriptAnalyzer module not found'
                Severity = 'Error'
            }
            return $result
        }
        
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        
        # Run analysis
        $findings = Invoke-ScriptAnalyzer -Path $ScriptPath -Severity $Severity -ExcludeRule $ExcludeRules
        
        # Categorize findings
        foreach ($finding in $findings) {
            $entry = @{
                RuleName = $finding.RuleName
                Message = $finding.Message
                Severity = $finding.Severity
                Line = $finding.Line
                Column = $finding.Column
                ScriptName = $finding.ScriptName
            }
            
            $result.Findings += $entry
            
            switch ($finding.Severity) {
                'Error' { $result.Errors += $entry }
                'Warning' { $result.Warnings += $entry }
                'Information' { $result.Information += $entry }
            }
        }
        
        $result.Success = $result.Errors.Count -eq 0
        
    } catch {
        $result.Errors += @{
            Message = "PSScriptAnalyzer validation failed: $_"
            Severity = 'Error'
        }
    }
    
    return $result
}

#endregion

#region Tier 3: Pester Testing Validation

function Invoke-PesterValidation {
    <#
    .SYNOPSIS
        Tier 3: Pester functional testing
    .DESCRIPTION
        Execute Pester tests for functional validation:
        - Unit tests
        - Integration tests
        - Mocking and isolation
        - Behavior validation
        - Edge case testing
        
    .PARAMETER TestPath
        Path to Pester tests
    
    .PARAMETER Tag
        Tags to filter tests
    
    .EXAMPLE
        $pesterResult = Invoke-PesterValidation -TestPath './tests/script.Tests.ps1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestPath,
        
        [string[]]$Tag = @()
    )
    
    $result = @{
        Tier = 'Pester'
        Success = $false
        Passed = 0
        Failed = 0
        Skipped = 0
        Total = 0
        Duration = 0
        Tests = @()
    }
    
    try {
        # Check if Pester is available
        if (-not (Get-Module -ListAvailable -Name Pester)) {
            throw 'Pester module not found'
        }
        
        Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
        
        # Configure Pester
        $config = New-PesterConfiguration
        $config.Run.Path = $TestPath
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Detailed'
        
        if ($Tag.Count -gt 0) {
            $config.Filter.Tag = $Tag
        }
        
        # Run tests
        $testResult = Invoke-Pester -Configuration $config
        
        # Extract results
        $result.Passed = $testResult.PassedCount
        $result.Failed = $testResult.FailedCount
        $result.Skipped = $testResult.SkippedCount
        $result.Total = $testResult.TotalCount
        $result.Duration = $testResult.Duration.TotalSeconds
        $result.Success = $testResult.FailedCount -eq 0
        
        # Extract individual tests
        foreach ($test in $testResult.Tests) {
            $result.Tests += @{
                Name = $test.Name
                Result = $test.Result
                Duration = $test.Duration.TotalSeconds
                ErrorRecord = if ($test.ErrorRecord) { $test.ErrorRecord.Exception.Message } else { $null }
            }
        }
        
    } catch {
        $result.Tests += @{
            Name = 'Pester Execution'
            Result = 'Failed'
            ErrorRecord = $_.Exception.Message
        }
    }
    
    return $result
}

#endregion

#region Three-Tier Comprehensive Validation

function Invoke-ThreeTierValidation {
    <#
    .SYNOPSIS
        Execute complete three-tier validation
    .DESCRIPTION
        Runs all three validation tiers in sequence:
        1. AST Parsing - Static structure analysis
        2. PSScriptAnalyzer - Code quality analysis  
        3. Pester Testing - Functional validation
        
        Each tier builds on the previous one for comprehensive validation.
        
    .PARAMETER ScriptPath
        Path to script to validate
    
    .PARAMETER TestPath
        Path to Pester tests (optional, generates if missing)
    
    .PARAMETER StopOnError
        Stop at first tier failure
    
    .EXAMPLE
        $validation = Invoke-ThreeTierValidation -ScriptPath './script.ps1'
        
    .EXAMPLE
        $validation = Invoke-ThreeTierValidation -ScriptPath './script.ps1' -TestPath './tests/script.Tests.ps1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [string]$TestPath,
        
        [switch]$StopOnError,
        
        [string[]]$PSScriptAnalyzerSeverity = @('Error', 'Warning'),
        
        [string[]]$PSScriptAnalyzerExcludeRules = @(),
        
        [string[]]$PesterTag = @()
    )
    
    $overallResult = @{
        ScriptPath = $ScriptPath
        Timestamp = Get-Date -Format 'o'
        OverallSuccess = $false
        Tiers = @{}
        Summary = @{}
    }
    
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     Three-Tier Validation Framework                        ║" -ForegroundColor Cyan
    Write-Host "║     AST → PSScriptAnalyzer → Pester                        ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Tier 1: AST Validation
    Write-Host "🔍 Tier 1: AST Parsing Validation..." -ForegroundColor Yellow
    $astResult = Invoke-ASTValidation -ScriptPath $ScriptPath
    $overallResult.Tiers.AST = $astResult
    
    if ($astResult.Success) {
        Write-Host "  ✅ AST validation passed" -ForegroundColor Green
        Write-Host "  📊 Metrics:" -ForegroundColor White
        Write-Host "     - Functions: $($astResult.Metrics.FunctionCount)" -ForegroundColor Gray
        Write-Host "     - Parameters: $($astResult.Metrics.ParameterCount)" -ForegroundColor Gray
        Write-Host "     - Complexity: $($astResult.Metrics.CyclomaticComplexity)" -ForegroundColor Gray
        Write-Host "     - Nesting: $($astResult.Metrics.NestingDepth)" -ForegroundColor Gray
    } else {
        Write-Host "  ❌ AST validation failed: $($astResult.Errors.Count) errors" -ForegroundColor Red
        foreach ($error in $astResult.Errors) {
            $lineInfo = if ($error.Line) { "Line $($error.Line): " } else { "" }
            Write-Host "     - $lineInfo$($error.Message)" -ForegroundColor Red
        }
        if ($StopOnError) {
            return $overallResult
        }
    }
    
    # Tier 2: PSScriptAnalyzer Validation
    Write-Host "`n🔎 Tier 2: PSScriptAnalyzer Validation..." -ForegroundColor Yellow
    $pssaResult = Invoke-PSScriptAnalyzerValidation -ScriptPath $ScriptPath -Severity $PSScriptAnalyzerSeverity -ExcludeRules $PSScriptAnalyzerExcludeRules
    $overallResult.Tiers.PSScriptAnalyzer = $pssaResult
    
    if ($pssaResult.Success) {
        Write-Host "  ✅ PSScriptAnalyzer passed" -ForegroundColor Green
        if ($pssaResult.Warnings.Count -gt 0) {
            Write-Host "  ⚠️  $($pssaResult.Warnings.Count) warnings found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ PSScriptAnalyzer failed: $($pssaResult.Errors.Count) errors" -ForegroundColor Red
        foreach ($error in $pssaResult.Errors | Select-Object -First 5) {
            $lineInfo = if ($error.Line) { " Line $($error.Line)" } else { "" }
            $ruleInfo = if ($error.RuleName) { "[$($error.RuleName)]" } else { "" }
            Write-Host "     - $ruleInfo$lineInfo: $($error.Message)" -ForegroundColor Red
        }
        if ($StopOnError) {
            return $overallResult
        }
    }
    
    # Tier 3: Pester Testing Validation
    if ($TestPath -and (Test-Path $TestPath)) {
        Write-Host "`n🧪 Tier 3: Pester Functional Validation..." -ForegroundColor Yellow
        $pesterResult = Invoke-PesterValidation -TestPath $TestPath -Tag $PesterTag
        $overallResult.Tiers.Pester = $pesterResult
        
        if ($pesterResult.Success) {
            Write-Host "  ✅ All Pester tests passed ($($pesterResult.Passed)/$($pesterResult.Total))" -ForegroundColor Green
            Write-Host "  ⏱️  Duration: $([Math]::Round($pesterResult.Duration, 2))s" -ForegroundColor Gray
        } else {
            Write-Host "  ❌ Pester tests failed: $($pesterResult.Failed) failures" -ForegroundColor Red
            foreach ($test in ($pesterResult.Tests | Where-Object { $_.Result -eq 'Failed' } | Select-Object -First 5)) {
                Write-Host "     - $($test.Name): $($test.ErrorRecord)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "`n⚠️  Tier 3: No Pester tests found at $TestPath" -ForegroundColor Yellow
        $overallResult.Tiers.Pester = @{ Success = $null; Message = 'Tests not found' }
    }
    
    # Overall summary
    $overallResult.OverallSuccess = $astResult.Success -and $pssaResult.Success -and 
                                     ($null -eq $overallResult.Tiers.Pester.Success -or $overallResult.Tiers.Pester.Success)
    
    $overallResult.Summary = @{
        TotalErrors = $astResult.Errors.Count + $pssaResult.Errors.Count + 
                     (if ($overallResult.Tiers.Pester.Failed) { $overallResult.Tiers.Pester.Failed } else { 0 })
        TotalWarnings = $astResult.Warnings.Count + $pssaResult.Warnings.Count
        Complexity = $astResult.Metrics.CyclomaticComplexity
        QualityScore = Get-QualityScore -ValidationResult $overallResult
    }
    
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Validation Summary                       ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "Overall Status:  $(if ($overallResult.OverallSuccess) { '✅ PASSED' } else { '❌ FAILED' })" -ForegroundColor $(if ($overallResult.OverallSuccess) { 'Green' } else { 'Red' })
    Write-Host "Quality Score:   $($overallResult.Summary.QualityScore)/100" -ForegroundColor White
    Write-Host "Total Errors:    $($overallResult.Summary.TotalErrors)" -ForegroundColor $(if ($overallResult.Summary.TotalErrors -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Total Warnings:  $($overallResult.Summary.TotalWarnings)" -ForegroundColor $(if ($overallResult.Summary.TotalWarnings -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host ""
    
    return $overallResult
}

function Get-QualityScore {
    <#
    .SYNOPSIS
        Calculate overall quality score (0-100)
    #>
    param($ValidationResult)
    
    $score = 100
    
    # Deduct for errors
    $score -= $ValidationResult.Summary.TotalErrors * 10
    
    # Deduct for warnings
    $score -= $ValidationResult.Summary.TotalWarnings * 2
    
    # Deduct for complexity
    if ($ValidationResult.Summary.Complexity -gt 20) {
        $score -= ($ValidationResult.Summary.Complexity - 20) * 2
    }
    
    # Ensure score is between 0 and 100
    return [Math]::Max(0, [Math]::Min(100, $score))
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Invoke-ASTValidation'
    'Invoke-PSScriptAnalyzerValidation'
    'Invoke-PesterValidation'
    'Invoke-ThreeTierValidation'
    'Get-CyclomaticComplexity'
    'Get-MaxNestingDepth'
    'Find-ASTAntiPatterns'
)
