#Requires -Version 7.0

<#
.SYNOPSIS
    Validate PowerShell Abstract Syntax Tree (AST) for AitherZero
.DESCRIPTION
    Performs deep syntax validation, parameter checking, and command verification

    Exit Codes:
    0   - All validations passed
    1   - Validation issues found
    2   - Validation error

.NOTES
    Stage: Testing
    Order: 0412
    Dependencies: 0400
    Tags: testing, ast, syntax, validation
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputPath,
    [switch]$DryRun,
    [switch]$CheckSyntax,
    [switch]$CheckParameters,
    [switch]$CheckCommands,
    [switch]$CheckModuleDependencies,
    [string[]]$ExcludePaths = @('tests', 'legacy-to-migrate')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata (kept as comment for documentation)
# Stage: Testing
# Order: 0412
# Dependencies: 0400
# Tags: testing, ast, syntax, validation
# RequiresAdmin: No
# SupportsWhatIf: Yes

# Import modules
$projectRoot = Split-Path $PSScriptRoot -Parent
$loggingModule = Join-Path $projectRoot "domains/utilities/Logging.psm1"

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0412_Validate-AST" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

# AST validation functions
function Test-PowerShellSyntax {
    param(
        [string]$FilePath
    )

    $issues = @()

    try {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $FilePath,
            [ref]$tokens,
            [ref]$parseErrors
        )

        if ($parseErrors.Count -gt 0) {
            foreach ($parseError in $parseErrors) {
                $issues += [PSCustomObject]@{
                    File = $FilePath
                    Line = $parseError.Extent.StartLineNumber
                    Column = $parseError.Extent.StartColumnNumber
                    Type = 'SyntaxError'
                    Severity = 'Error'
                    Message = $parseError.Message
                }
            }
        }

        return $issues
    }
    catch {
        return @([PSCustomObject]@{
            File = $FilePath
            Line = 0
            Column = 0
            Type = 'ParseError'
            Severity = 'Error'
            Message = "Failed to parse file: $_"
        })
    }
}

function Test-ParameterDefinitions {
    param(
        [string]$FilePath,
        [System.Management.Automation.Language.Ast]$Ast
    )

    $issues = @()

    # Find all parameter definitions
    $paramAsts = $Ast.FindAll({
        $arguments[0] -is [System.Management.Automation.Language.ParameterAst]
    }, $true)

    foreach ($param in $paramAsts) {
        # Check for missing parameter types
        if (-not $param.StaticType -and -not $param.Attributes -and $param.Name.VariablePath.UserPath -ne 'args') {
            $issues += [PSCustomObject]@{
                File = $FilePath
                Line = $param.Extent.StartLineNumber
                Column = $param.Extent.StartColumnNumber
                Type = 'MissingParameterType'
                Severity = 'Warning'
                Message = "Parameter '$($param.Name)' has no type declaration"
            }
        }

        # Check for ValidateScript without ErrorMessage
        $validateScript = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.AttributeAst] -and $_.TypeName.Name -eq 'ValidateScript' }
        if ($validateScript -and -not ($validateScript.NamedArguments | Where-Object { $_.ArgumentName -eq 'ErrorMessage' })) {
            $issues += [PSCustomObject]@{
                File = $FilePath
                Line = $param.Extent.StartLineNumber
                Column = $param.Extent.StartColumnNumber
                Type = 'ValidateScriptNoErrorMessage'
                Severity = 'Information'
                Message = "ValidateScript for parameter '$($param.Name)' should include ErrorMessage"
            }
        }
    }

    return $issues
}

function Test-CommandUsage {
    param(
        [string]$FilePath,
        [System.Management.Automation.Language.Ast]$Ast
    )

    $issues = @()
    $knownCommands = @{}  # Cache for command lookups

    # Find all command invocations
    $commandAsts = $Ast.FindAll({
        $arguments[0] -is [System.Management.Automation.Language.CommandAst]
    }, $true)

    foreach ($cmd in $commandAsts) {
        $cmdName = $cmd.GetCommandName()

        if ($cmdName -and $cmdName -notmatch '^\$' -and $cmdName -notmatch '^&' -and $cmdName -notmatch '^\[') {
            # Skip if already checked
            if ($knownCommands.ContainsKey($cmdName)) {
                if (-not $knownCommands[$cmdName]) {
                    $issues += [PSCustomObject]@{
                        File = $FilePath
                        Line = $cmd.Extent.StartLineNumber
                        Column = $cmd.Extent.StartColumnNumber
                        Type = 'UnknownCommand'
                        Severity = 'Warning'
                        Message = "Command '$cmdName' not found"
                    }
                }
                continue
            }

            # Check if command exists
            $exists = $null -ne (Get-Command $cmdName -ErrorAction SilentlyContinue)
            $knownCommands[$cmdName] = $exists

            if (-not $exists) {
                # Check if it's a function defined in the same file
                $functionDefs = $Ast.FindAll({
                    $arguments[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $arguments[0].Name -eq $cmdName
                }, $true)

                if ($functionDefs.Count -eq 0) {
                    $issues += [PSCustomObject]@{
                        File = $FilePath
                        Line = $cmd.Extent.StartLineNumber
                        Column = $cmd.Extent.StartColumnNumber
                        Type = 'UnknownCommand'
                        Severity = 'Warning'
                        Message = "Command '$cmdName' not found"
                    }
                }
            }
        }
    }

    return $issues
}

function Test-ModuleDependencies {
    param(
        [string]$FilePath,
        [System.Management.Automation.Language.Ast]$Ast
    )

    $issues = @()

    # Check #Requires statements
    $requiresStatements = $Ast.ScriptRequirements

    if ($requiresStatements -and $requiresStatements.RequiredModules) {
        foreach ($module in $requiresStatements.RequiredModules) {
            $moduleName = if ($module -is [hashtable]) { $module.ModuleName } else { $module }
            $moduleVersion = if ($module -is [hashtable]) { $module.ModuleVersion } else { $null }

            $availableModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1

            if (-not $availableModule) {
                $issues += [PSCustomObject]@{
                    File = $FilePath
                    Line = 1
                    Column = 1
                    Type = 'MissingModule'
                    Severity = 'Error'
                    Message = "Required module '$moduleName' not found"
                }
            } elseif ($moduleVersion -and $availableModule.Version -lt $moduleVersion) {
                $issues += [PSCustomObject]@{
                    File = $FilePath
                    Line = 1
                    Column = 1
                    Type = 'ModuleVersionMismatch'
                    Severity = 'Warning'
                    Message = "Module '$moduleName' version $($availableModule.Version) is less than required version $moduleVersion"
                }
            }
        }
    }

    # Check Import-Module statements
    $importModuleAsts = $Ast.FindAll({
        $arguments[0] -is [System.Management.Automation.Language.CommandAst] -and
        $arguments[0].GetCommandName() -eq 'Import-Module'
    }, $true)

    foreach ($import in $importModuleAsts) {
        $moduleArg = $import.CommandElements | Where-Object { $_ -isnot [System.Management.Automation.Language.CommandAst] } | Select-Object -First 1

        if ($moduleArg -and $moduleArg -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $modulePath = $moduleArg.Value

            # Check if it's a relative path
            if ($modulePath -notmatch '^[A-Z]:' -and $modulePath -notmatch '^\$' -and -not (Get-Module -ListAvailable -Name $modulePath)) {
                # Try to resolve relative path
                $resolvedPath = Join-Path (Split-Path $FilePath -Parent) $modulePath
                if (-not (Test-Path $resolvedPath)) {
                    $issues += [PSCustomObject]@{
                        File = $FilePath
                        Line = $import.Extent.StartLineNumber
                        Column = $import.Extent.StartColumnNumber
                        Type = 'ModuleNotFound'
                        Severity = 'Warning'
                        Message = "Module '$modulePath' not found"
                    }
                }
            }
        }
    }

    return $issues
}

try {
    Write-ScriptLog -Message "Starting AST validation"

    # Check if running in DryRun mode
    if ($DryRun) {
        Write-ScriptLog -Message "DRY RUN: Would perform AST validation"
        Write-ScriptLog -Message "Validation path: $Path"
        Write-ScriptLog -Message "Check syntax: $CheckSyntax"
        Write-ScriptLog -Message "Check parameters: $CheckParameters"
        Write-ScriptLog -Message "Check commands: $CheckCommands"
        Write-ScriptLog -Message "Check module dependencies: $CheckModuleDependencies"
        exit 0
    }

    # Get all PowerShell files
    Write-ScriptLog -Message "Scanning for PowerShell files..."
    $files = Get-ChildItem -Path $Path -Include "*.ps1", "*.psm1", "*.psd1" -Recurse |
        Where-Object {
            $file = $_
            -not ($ExcludePaths | Where-Object { $file.FullName -like "*\$_\*" })
        }

    Write-ScriptLog -Message "Found $($files.Count) PowerShell files to validate"

    if ($files.Count -eq 0) {
        Write-ScriptLog -Level Warning -Message "No PowerShell files found to validate"
        exit 0
    }

    # Performance tracking
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Start-PerformanceTrace -Name "ASTValidation" -Description "AST validation of PowerShell files"
    }

    $allIssues = @()
    $fileCount = 0

    # Process each file
    foreach ($file in $files) {
        $fileCount++
        Write-Progress -Activity "Validating AST" -Status "Processing $($file.Name)" -PercentComplete (($fileCount / $files.Count) * 100)

        Write-ScriptLog -Level Debug -Message "Validating: $($file.FullName)"

        # Parse the file
        $tokens = $null
        $parseErrors = $null
        $fileAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName,
            [ref]$tokens,
            [ref]$parseErrors
        )

        # Syntax check
        if ($CheckSyntax -or $parseErrors.Count -gt 0) {
            $syntaxIssues = Test-PowerShellSyntax -FilePath $file.FullName
            $allIssues += $syntaxIssues
        }

        # Skip other checks if there are syntax errors
        if ($parseErrors.Count -eq 0) {
            # Parameter checks
            if ($CheckParameters -or $PSBoundParameters.Count -eq 0) {
                $paramIssues = Test-ParameterDefinitions -FilePath $file.FullName -Ast $fileAst
                $allIssues += $paramIssues
            }

            # Command usage checks
            if ($CheckCommands -or $PSBoundParameters.Count -eq 0) {
                $cmdIssues = Test-CommandUsage -FilePath $file.FullName -Ast $fileAst
                $allIssues += $cmdIssues
            }

            # Module dependency checks
            if ($CheckModuleDependencies -or $PSBoundParameters.Count -eq 0) {
                $moduleIssues = Test-ModuleDependencies -FilePath $file.FullName -Ast $fileAst
                $allIssues += $moduleIssues
            }
        }
    }

    Write-Progress -Activity "Validating AST" -Completed

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        $duration = Stop-PerformanceTrace -Name "ASTValidation"
    }

    # Process results
    # Create grouped summaries
    $severityGroups = @{}
    $allIssues | Group-Object Severity | ForEach-Object {
        $severityGroups[$_.Name] = $_.Count
    }

    $typeGroups = @{}
    $allIssues | Group-Object Type | ForEach-Object {
        $typeGroups[$_.Name] = $_.Count
    }

    $summary = @{
        TotalFiles = $files.Count
        TotalIssues = $allIssues.Count
        BySeverity = $severityGroups
        ByType = $typeGroups
    }

    Write-ScriptLog -Message "AST validation completed" -Data $summary

    # Display results
    Write-Host "`nAST Validation Summary:" -ForegroundColor Cyan
    Write-Host "  Files Validated: $($files.Count)"
    Write-Host "  Total Issues: $($allIssues.Count)"

    if ($allIssues.Count -gt 0) {
        # By severity
        Write-Host "`n  By Severity:" -ForegroundColor Yellow
        foreach ($severity in @('Error', 'Warning', 'Information')) {
            $count = ($allIssues | Where-Object { $_.Severity -eq $severity }).Count
            if ($count -gt 0) {
                $color = @{ 'Error' = 'Red'; 'Warning' = 'Yellow'; 'Information' = 'Cyan' }[$severity]
                Write-Host "    $severity : $count" -ForegroundColor $color
            }
        }

        # By type
        Write-Host "`n  By Type:" -ForegroundColor Yellow
        $allIssues | Group-Object Type | Sort-Object Count -Descending | ForEach-Object {
            Write-Host "    $($_.Name): $($_.Count)"
        }

        # Show errors
        $errors = $allIssues | Where-Object { $_.Severity -eq 'Error' }
        if ($errors) {
            Write-Host "`nErrors:" -ForegroundColor Red
            $errors | Select-Object -First 10 | ForEach-Object {
                Write-Host "  $(Split-Path $_.File -Leaf):$($_.Line):$($_.Column)" -ForegroundColor Red
                Write-Host "    $($_.Message)" -ForegroundColor DarkRed
            }

            if ($errors.Count -gt 10) {
                Write-Host "  ... and $($errors.Count - 10) more errors" -ForegroundColor DarkRed
            }
        }
    } else {
        Write-Host "  All AST validations passed!" -ForegroundColor Green
    }

    # Save results
    if ($allIssues.Count -gt 0) {
        if (-not $OutputPath) {
            $OutputPath = Join-Path $projectRoot "tests/analysis"
        }

        if (-not (Test-Path $OutputPath)) {
            if ($PSCmdlet.ShouldProcess($OutputPath, "Create validation output directory")) {
                New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            }
        }

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $outputFile = Join-Path $OutputPath "AST-Validation-$timestamp.json"

        if ($PSCmdlet.ShouldProcess($outputFile, "Save AST validation results")) {
            @{
                Timestamp = Get-Date
                Summary = $summary
                Issues = $allIssues | ForEach-Object {
                    @{
                        File = $_.File -replace [regex]::Escape($projectRoot), '.'
                        Line = $_.Line
                        Column = $_.Column
                        Type = $_.Type
                        Severity = $_.Severity
                        Message = $_.Message
                    }
                }
            } | ConvertTo-Json -Depth 5 | Set-Content -Path $outputFile

            Write-ScriptLog -Message "Validation results saved to: $outputFile"
        }
    }

    # Exit based on results
    $errorCount = ($allIssues | Where-Object { $_.Severity -eq 'Error' }).Count
    if ($errorCount -eq 0) {
        if ($allIssues.Count -eq 0) {
            Write-ScriptLog -Message "All AST validations passed!"
        } else {
            Write-ScriptLog -Level Warning -Message "AST validation found $($allIssues.Count) non-critical issues"
        }
        exit 0
    } else {
        Write-ScriptLog -Level Error -Message "AST validation found $errorCount errors"
        exit 1
    }
}
catch {
    Write-ScriptLog -Level Error -Message "AST validation failed: $_" -Data @{
        Exception = $_.Exception.Message
        ScriptStackTrace = $_.ScriptStackTrace
    }
    exit 2
}

# Helper function
function Merge-Hashtables {
    $result = @{}
    foreach ($hashtable in $inputValue) {
        if ($hashtable -is [hashtable]) {
            foreach ($key in $hashtable.Keys) {
                $result[$key] = $hashtable[$key]
            }
        }
    }
    return $result
}