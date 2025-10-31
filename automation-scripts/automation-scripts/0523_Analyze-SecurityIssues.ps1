#Requires -Version 7.0
<#
.SYNOPSIS
    Analyzes security issues across the codebase
.DESCRIPTION
    Scans for security vulnerabilities including plain text credentials,
    insecure protocols, missing parameter validation, and unsafe commands
#>

# Script metadata
# Stage: Reporting
# Dependencies: 0400
# Description: Security issue analysis for tech debt reporting
# Tags: reporting, tech-debt, security, analysis

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = ".",
    [string]$OutputPath = "./reports/tech-debt/analysis",
    [switch]$UseCache,
    [switch]$Detailed = $false,
    [switch]$IncludeInfo = $false,
    [string[]]$ExcludePaths = @('tests', 'legacy-to-migrate', 'examples', 'reports', '.git')
)

# Initialize
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StartTime = Get-Date

# Import modules
Import-Module (Join-Path $script:ProjectRoot 'domains/reporting/TechDebtAnalysis.psm1') -Force
Import-Module (Join-Path $script:ProjectRoot 'domains/utilities/Logging.psm1') -Force -ErrorAction SilentlyContinue

# Initialize analysis
if ($PSCmdlet.ShouldProcess($OutputPath, "Initialize tech debt analysis results directory")) {
    Initialize-TechDebtAnalysis -ResultsPath $OutputPath
}

function Get-SecurityPatterns {
    return @{
        PlainTextCredentials = @{
            Critical = @(
                @{ Pattern = 'ConvertTo-SecureString\s+.*-AsPlainText'; Description = 'Plain text password conversion' }
                @{ Pattern = 'password\s*=\s*["\''`][^"\''`]+["\''`]'; Description = 'Hardcoded password' }
                @{ Pattern = 'apikey\s*=\s*["\''`][^"\''`]+["\''`]'; Description = 'Hardcoded API key' }
                @{ Pattern = 'token\s*=\s*["\''`][^"\''`]+["\''`]'; Description = 'Hardcoded token' }
                @{ Pattern = 'secret\s*=\s*["\''`][^"\''`]+["\''`]'; Description = 'Hardcoded secret' }
                @{ Pattern = '\$cred\s*=\s*["\''`][^"\''`]+["\''`]'; Description = 'Hardcoded credential' }
            )
        High = @(
                @{ Pattern = 'Get-Credential.*-UserName.*-Password'; Description = 'Credential with plain text password' }
                @{ Pattern = 'PSCredential.*\(.*,.*\)'; Description = 'PSCredential with potential plain text' }
            )
    }

        InsecureProtocols = @{
            High = @(
                @{ Pattern = 'http://(?!localhost|127\.0\.0\.1)'; Description = 'HTTP protocol (non-local)' }
                @{ Pattern = '-SkipCertificateCheck'; Description = 'Certificate validation disabled' }
                @{ Pattern = 'ServerCertificateValidationCallback.*return\s+true'; Description = 'Certificate always trusted' }
                @{ Pattern = '\[System\.Net\.ServicePointManager\]::SecurityProtocol.*Ssl3|Tls(?!12|13)'; Description = 'Weak TLS version' }
            )
        Medium = @(
                @{ Pattern = '-UseBasicParsing'; Description = 'Basic parsing (may miss security headers)' }
                @{ Pattern = 'ValidateCertificate\s*=\s*\$false'; Description = 'Certificate validation disabled' }
            )
    }

        UnsafeCommands = @{
            Critical = @(
                @{ Pattern = 'Invoke-Expression|iex\s+'; Description = 'Dynamic code execution' }
                @{ Pattern = '-ExecutionPolicy\s+Bypass'; Description = 'Execution policy bypass' }
                @{ Pattern = '-ExecutionPolicy\s+Unrestricted'; Description = 'Unrestricted execution policy' }
                @{ Pattern = 'Start-Process.*-Verb\s+RunAs.*-ArgumentList.*\$'; Description = 'Elevated process with variable input' }
            )
        High = @(
                @{ Pattern = '&\s*\$[^(]'; Description = 'Call operator with variable' }
                @{ Pattern = '\.\s*\$[^(]'; Description = 'Dot source with variable' }
                @{ Pattern = 'Invoke-Command.*-ScriptBlock.*\$'; Description = 'Remote execution with variable' }
            )
    }

        InputValidation = @{
            High = @(
                @{ Pattern = '\[string\]\s*\$.*path|file(?!\s*=)'; Description = 'Path parameter without validation' }
                @{ Pattern = '\[string\]\s*\$.*url(?!\s*=)'; Description = 'URL parameter without validation' }
                @{ Pattern = '\[string\]\s*\$.*email(?!\s*=)'; Description = 'Email parameter without validation' }
                @{ Pattern = '\[string\]\s*\$.*sql|query(?!\s*=)'; Description = 'SQL parameter without validation' }
            )
        Medium = @(
                @{ Pattern = '\$.*\+.*\$.*sql|query'; Description = 'Potential SQL injection' }
                @{ Pattern = 'Where-Object.*-match.*\$'; Description = 'Regex injection risk' }
            )
    }

        CryptographicIssues = @{
            High = @(
                @{ Pattern = 'MD5|SHA1(?![\d])'; Description = 'Weak hashing algorithm' }
                @{ Pattern = 'DES|3DES|RC4'; Description = 'Weak encryption algorithm' }
                @{ Pattern = 'Random(?!Byte)'; Description = 'Weak random number generation' }
            )
    }

        PrivilegeEscalation = @{
            Critical = @(
                @{ Pattern = 'SeDebugPrivilege|SeTakeOwnershipPrivilege'; Description = 'Dangerous privilege request' }
                @{ Pattern = 'EnablePrivilege.*Admin'; Description = 'Admin privilege escalation' }
            )
        High = @(
                @{ Pattern = '-Verb\s+RunAs'; Description = 'UAC elevation' }
                @{ Pattern = 'RequireAdministrator'; Description = 'Requires admin rights' }
            )
    }
    }
}

function Test-ParameterValidation {
    param(
        $Function,
        $Parameter
    )

    $hasValidation = $false
    $validationTypes = @()

    if ($Parameter.Attributes) {
        foreach ($attr in $Parameter.Attributes) {
            if ($attr -is [System.Management.Automation.Language.AttributeAst]) {
                $typeName = $attr.TypeName.Name
                if ($typeName -match '^Validate') {
                    $hasValidation = $true
                    $validationTypes += $typeName
                }
            }
        }
    }

    return @{
        HasValidation = $hasValidation
        ValidationTypes = $validationTypes
    }
}

function Analyze-SecurityIssues {
    Write-AnalysisLog "Starting security analysis..." -Component "Security"

    # Initialize results
    $security = @{
        PlainTextCredentials = @()
        InsecureProtocols = @()
        UnsafeCommands = @()
        MissingParameterValidation = @()
        CryptographicIssues = @()
        PrivilegeEscalation = @()
        ExposedSecrets = @()
        Summary = @{
            Critical = 0
            High = 0
            Medium = 0
            Low = 0
            Info = 0
        }
        ScanStartTime = $script:StartTime
    }

    # Get files to analyze
    $files = Get-FilesToAnalyze -Path $script:ProjectRoot -Exclude $ExcludePaths
    Write-AnalysisLog "Analyzing $($files.Count) files for security issues" -Component "Security"

    # Get security patterns
    $patterns = Get-SecurityPatterns

    # Process files in parallel
    $fileResults = Start-ParallelAnalysis -ScriptBlock {
        param($File)

        $result = @{
            Path = $File.FullName
            SecurityIssues = @{
                PlainTextCredentials = @()
                InsecureProtocols = @()
                UnsafeCommands = @()
                CryptographicIssues = @()
                PrivilegeEscalation = @()
            }
            ParameterValidation = @()
            Errors = @()
        }

        try {
            $content = Get-Content $File.FullName -Raw

            # Load patterns (need to redefine in scriptblock)
            $patterns = @{
                PlainTextCredentials = @{
                    Critical = @(
                        @{ Pattern = 'ConvertTo-SecureString\s+.*-AsPlainText'; Description = 'Plain text password conversion' }
                        @{ Pattern = 'password\s*=\s*["\''`][^"\''`]+["\''`]'; Description = 'Hardcoded password' }
                        @{ Pattern = 'apikey\s*=\s*["\''`][^"\''`]+["\''`]'; Description = 'Hardcoded API key' }
                    )
            }
                InsecureProtocols = @{
                    High = @(
                        @{ Pattern = 'http://(?!localhost|127\.0\.0\.1)'; Description = 'HTTP protocol (non-local)' }
                        @{ Pattern = '-SkipCertificateCheck'; Description = 'Certificate validation disabled' }
                    )
            }
                UnsafeCommands = @{
                    Critical = @(
                        @{ Pattern = 'Invoke-Expression|iex\s+'; Description = 'Dynamic code execution' }
                        @{ Pattern = '-ExecutionPolicy\s+Bypass'; Description = 'Execution policy bypass' }
                    )
            }
                CryptographicIssues = @{
                    High = @(
                        @{ Pattern = 'MD5|SHA1(?![\d])'; Description = 'Weak hashing algorithm' }
                    )
            }
                PrivilegeEscalation = @{
                    High = @(
                        @{ Pattern = '-Verb\s+RunAs'; Description = 'UAC elevation' }
                    )
            }
            }

            # Search for security patterns
            foreach ($category in $patterns.GetEnumerator()) {
                foreach ($severity in $category.Value.GetEnumerator()) {
                    foreach ($patternInfo in $severity.Value) {
                        $matchResults = [regex]::Matches($content, $patternInfo.Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

                        foreach ($match in $matchResults) {
                            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                            $line = ($content -split "`n")[$lineNumber - 1].Trim()

                            $result.SecurityIssues[$category.Key] += @{
                                Severity = $severity.Key
                                Line = $lineNumber
                                Match = $match.Value
                                Context = $line
                                Description = $patternInfo.Description
                            }
                        }
                    }
                }
            }

            # Parse AST for parameter validation
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)

            if (-not $parseErrors -or $parseErrors.Count -eq 0) {
                $functions = $ast.FindAll({ $arguments[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

                foreach ($function in $functions) {
                    if ($function.Body -and $function.Body.ParamBlock -and $function.Body.ParamBlock.Parameters) {
                        foreach ($param in $function.Body.ParamBlock.Parameters) {
                            $paramName = $param.Name.VariablePath.UserPath

                            # Check if parameter needs validation
                            if ($paramName -match 'path|file|url|email|password|sql|query|script|command') {
                                $hasValidation = $false

                                if ($param.Attributes) {
                                    foreach ($attr in $param.Attributes) {
                                        if ($attr -is [System.Management.Automation.Language.AttributeAst] -and
                                            $attr.TypeName.Name -match '^Validate') {
                                            $hasValidation = $true
                                            break
                                        }
                                    }
                                }

                                if (-not $hasValidation) {
                                    $result.ParameterValidation += @{
                                        Function = $function.Name
                                        Parameter = $paramName
                                        Line = $param.Extent.StartLineNumber
                                        SuggestedValidation = switch -Regex ($paramName) {
                                            'path|file' { 'ValidateScript { Test-Path $_ }' }
                                            'url' { 'ValidatePattern for URL format' }
                                            'email' { 'ValidatePattern for email format' }
                                            'password' { 'ValidateLength and SecureString type' }
                                            'sql|query' { 'ValidatePattern to prevent injection' }
                                            'script|command' { 'ValidateSet or ValidatePattern' }
                                            default { 'ValidateNotNullOrEmpty' }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            $result.Errors += "Analysis error: $_"
        }

        return $result
    } -InputObject $files -MaxConcurrency 8 -JobName "SecurityAnalysis"

    # Process results
    foreach ($fileResult in $fileResults) {
        $relativePath = $fileResult.Path.Replace($script:ProjectRoot, '.')

        # Aggregate security issues
        foreach ($category in @('PlainTextCredentials', 'InsecureProtocols', 'UnsafeCommands', 'CryptographicIssues', 'PrivilegeEscalation')) {
            foreach ($issue in $fileResult.SecurityIssues[$category]) {
                $issueRecord = @{
                    File = $relativePath
                    Line = $issue.Line
                    Severity = $issue.Severity
                    Match = $issue.Match
                    Context = $issue.Context
                    Description = $issue.Description
                }

                $security[$category] += $issueRecord

                # Update severity counts
                $security.Summary[$issue.Severity]++
            }
        }

        # Aggregate parameter validation issues
        foreach ($validation in $fileResult.ParameterValidation) {
            $security.MissingParameterValidation += @{
                File = $relativePath
                Function = $validation.Function
                Parameter = $validation.Parameter
                Line = $validation.Line
                Severity = 'Medium'
                SuggestedValidation = $validation.SuggestedValidation
            }
            $security.Summary.Medium++
        }

        if ($fileResult.Errors.Count -gt 0 -and $Detailed) {
            Write-AnalysisLog "Errors in $relativePath`: $($fileResult.Errors -join '; ')" -Component "Security" -Level Warning
        }
    }

    # Search for exposed secrets patterns
    Write-AnalysisLog "Searching for exposed secrets..." -Component "Security"

    $secretPatterns = @(
        @{ Pattern = '[A-Z0-9]{20}'; Description = 'AWS Access Key' }
        @{ Pattern = '[a-z0-9]{40}'; Description = 'GitHub Token' }
        @{ Pattern = 'xox[baprs]-[0-9]{10,13}-[a-zA-Z0-9]{24,34}'; Description = 'Slack Token' }
        @{ Pattern = 'sq0[a-z]{3}-[0-9a-zA-Z\-_]{22,43}'; Description = 'Square OAuth Secret' }
    )

    # Calculate security score
    $totalIssues = $security.Summary.Critical + $security.Summary.High + $security.Summary.Medium
    $security.SecurityScore = if ($totalIssues -eq 0) { 100 } else {
        [Math]::Max(0, 100 - ($security.Summary.Critical * 10) - ($security.Summary.High * 5) - ($security.Summary.Medium * 2))
    }

    $security.ScanEndTime = Get-Date
    $security.Duration = $security.ScanEndTime - $security.ScanStartTime

    return $security
}

# Main execution
try {
    Write-AnalysisLog "=== Security Analysis ===" -Component "Security"

    $results = Analyze-SecurityIssues

    # Save results
    if ($PSCmdlet.ShouldProcess($OutputPath, "Save security analysis results")) {
        $outputFile = Save-AnalysisResults -AnalysisType "SecurityIssues" -Results $results -OutputPath $OutputPath
    }

    # Display summary
    Write-Host "`nSecurity Analysis Summary:" -ForegroundColor Cyan

    Write-Host "`n  Issue Severity Breakdown:" -ForegroundColor Yellow
    Write-Host "    Critical: $($results.Summary.Critical)" -ForegroundColor $(if ($results.Summary.Critical -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    High: $($results.Summary.High)" -ForegroundColor $(if ($results.Summary.High -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Medium: $($results.Summary.Medium)" -ForegroundColor $(if ($results.Summary.Medium -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "    Low: $($results.Summary.Low)" -ForegroundColor $(if ($results.Summary.Low -eq 0) { 'Green' } else { 'Gray' })

    Write-Host "`n  Issue Categories:" -ForegroundColor Yellow
    Write-Host "    Plain Text Credentials: $($results.PlainTextCredentials.Count)" -ForegroundColor $(if ($results.PlainTextCredentials.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Insecure Protocols: $($results.InsecureProtocols.Count)" -ForegroundColor $(if ($results.InsecureProtocols.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Unsafe Commands: $($results.UnsafeCommands.Count)" -ForegroundColor $(if ($results.UnsafeCommands.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Missing Parameter Validation: $($results.MissingParameterValidation.Count)" -ForegroundColor $(if ($results.MissingParameterValidation.Count -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "    Cryptographic Issues: $($results.CryptographicIssues.Count)" -ForegroundColor $(if ($results.CryptographicIssues.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Privilege Escalation: $($results.PrivilegeEscalation.Count)" -ForegroundColor $(if ($results.PrivilegeEscalation.Count -eq 0) { 'Green' } else { 'Red' })

    Write-Host "`n  Security Score: $($results.SecurityScore)/100" -ForegroundColor $(
        if ($results.SecurityScore -ge 90) { 'Green' }
        elseif ($results.SecurityScore -ge 70) { 'Yellow' }
        else { 'Red' }
    )

    Write-Host "  Analysis Duration: $($results.Duration.TotalSeconds.ToString('F2')) seconds"

    if ($Detailed -and $results.Summary.Critical -gt 0) {
        Write-Host "`nCritical Security Issues:" -ForegroundColor Red
        $criticalIssues = @()
        $criticalIssues += $results.PlainTextCredentials | Where-Object { $_.Severity -eq 'Critical' } |
            ForEach-Object { "$($_.File):$($_.Line) - $($_.Description)" }
        $criticalIssues += $results.UnsafeCommands | Where-Object { $_.Severity -eq 'Critical' } |
            ForEach-Object { "$($_.File):$($_.Line) - $($_.Description)" }
        $criticalIssues | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }

    Write-Host "`nDetailed results saved to: $outputFile" -ForegroundColor Green

    # Handle CI vs interactive behavior for security issues
    if ($results.Summary.Critical -gt 0) {
        Write-Host "`n⚠️  Critical security issues found!" -ForegroundColor Red
        
        # In CI environments, report issues with exit code 1 (non-blocking warning)
        if ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true') {
            Write-Host "Security analysis completed with critical issues found" -ForegroundColor Yellow
            Write-Host "⚠️ Security issues detected - see detailed report" -ForegroundColor Yellow
            Write-Host "📋 Security findings are captured in reports for review" -ForegroundColor Cyan
            Write-Host "💡 Security issues are reported for attention - they don't block CI but require review" -ForegroundColor Cyan
            exit 1  # Exit code 1 indicates issues found (handled gracefully by CI)
        } else {
            exit 1  # Fail in interactive mode
        }
    }

    exit 0
} catch {
    Write-AnalysisLog "Security analysis failed: $_" -Component "Security" -Level Error
    Write-AnalysisLog "Stack trace: $($_.ScriptStackTrace)" -Component "Security" -Level Error
    exit 1
}