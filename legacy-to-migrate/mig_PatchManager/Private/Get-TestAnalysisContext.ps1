#Requires -Version 7.0

<#
.SYNOPSIS
    Intelligent test context analyzer for PatchManager.

.DESCRIPTION
    Analyzes test results, error messages, and system state to automatically 
    determine affected files, modules, capabilities, and detailed error context.
    
    This function replaces manual analysis with automated detection to provide
    comprehensive context for patch tracking issues.

.PARAMETER TestOutput
    Raw output from test execution

.PARAMETER ErrorDetails
    Error messages and exception details

.PARAMETER WorkingDirectory
    Current working directory for context

.PARAMETER TestType
    Type of test that was run (Unit, Integration, etc.)

.EXAMPLE
    $context = Get-TestAnalysisContext -TestOutput $testResults -ErrorDetails $errors
    
.NOTES
    Used internally by PatchManager to enhance issue tracking with automated context.
#>

function Get-TestAnalysisContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$TestOutput = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$ErrorDetails = @(),

        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [string]$TestType = "Unknown",

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalContext = @{}
    )

    begin {
        function Write-AnalysisLog {
            param($Message, $Level = "INFO")
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message $Message -Level $Level
            } else {
                Write-Verbose $Message
            }
        }

        Write-AnalysisLog "Starting intelligent test context analysis..." -Level "INFO"
    }

    process {
        try {
            $analysisResult = @{
                AffectedFiles = @()
                AffectedModules = @()
                AffectedCapabilities = @()
                ErrorCategories = @()
                FailureReasons = @()
                Recommendations = @()
                TechnicalDetails = @{}
                Confidence = "Unknown"
                AnalysisTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            }

            # 1. Analyze error patterns and extract file paths
            Write-AnalysisLog "Analyzing error patterns for file references..." -Level "INFO"
            
            $allText = ($TestOutput + $ErrorDetails) -join "`n"
            
            # Extract file paths from error messages using multiple patterns
            $filePatterns = @(
                # PowerShell file paths
                '(?i)([a-z]:\\[^:\s]+\.ps1?)',
                '(?i)(\./[^:\s]+\.ps1?)',
                '(?i)([^:\s]+\.ps1?)(?=\s|:|$)',
                # Generic file paths
                '(?i)([a-z]:\\[^:\s]+\.[a-z]{2,4})',
                '(?i)(\./[^:\s]+\.[a-z]{2,4})',
                # Unix-style paths
                '(?i)(/[^:\s]+\.[a-z]{2,4})',
                # Relative paths
                '(?i)([^/\s]+/[^:\s]+\.ps1?)'
            )

            foreach ($pattern in $filePatterns) {
                $fileMatches = [regex]::Matches($allText, $pattern)
                foreach ($match in $fileMatches) {
                    $filePath = $match.Groups[1].Value
                    
                    # Clean up the path
                    $filePath = $filePath.Trim(@('"', "'", ' ', ':', ';', ','))
                    
                    # Skip if it's just an extension or too short
                    if ($filePath.Length -lt 4 -or $filePath -match '^\.[a-z]+$') {
                        continue
                    }
                    
                    # Convert to relative path if it's in the project
                    if ($filePath -match [regex]::Escape($WorkingDirectory)) {
                        $filePath = $filePath -replace [regex]::Escape($WorkingDirectory), '.'
                        $filePath = $filePath -replace '\\', '/'
                    }
                    
                    # Add to affected files if it's not already there
                    if ($filePath -notin $analysisResult.AffectedFiles) {
                        $analysisResult.AffectedFiles += $filePath
                    }
                }
            }

            # 2. Analyze module references
            Write-AnalysisLog "Analyzing module references..." -Level "INFO"
            
            $modulePatterns = @(
                'Import-Module\s+([^\s]+)',
                'Module:\s+(\w+)',
                'module\s+(\w+)',
                '(\w+)\.psm1',
                '(\w+)\.psd1',
                'Get-Module.*?(\w+)',
                'Remove-Module.*?(\w+)'
            )

            foreach ($pattern in $modulePatterns) {
                $moduleMatches = [regex]::Matches($allText, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                foreach ($match in $moduleMatches) {
                    $moduleName = $match.Groups[1].Value
                    
                    # Clean up module name
                    $moduleName = $moduleName.Trim(@('"', "'", ' ', '.', '/', '\'))
                    
                    # Skip common false positives
                    if ($moduleName -in @('Force', 'ErrorAction', 'Verbose', 'Version', 'Global', 'Local') -or 
                        $moduleName.Length -lt 3) {
                        continue
                    }
                    
                    if ($moduleName -notin $analysisResult.AffectedModules) {
                        $analysisResult.AffectedModules += $moduleName
                    }
                }
            }

            # 3. Analyze error categories and classify failures
            Write-AnalysisLog "Classifying error categories..." -Level "INFO"
            
            $errorClassifications = @{
                'SyntaxError' = @('syntax error', 'parse error', 'unexpected token', 'missing closing')
                'ModuleError' = @('module not found', 'import-module', 'module loading', 'could not load')
                'FunctionError' = @('function not found', 'command not found', 'cmdlet not found')
                'PathError' = @('path not found', 'file not found', 'directory not found', 'cannot find path')
                'PermissionError' = @('access denied', 'permission denied', 'unauthorized', 'forbidden')
                'ConfigurationError' = @('configuration', 'config', 'setting', 'parameter')
                'NetworkError' = @('network', 'connection', 'timeout', 'unreachable', 'dns')
                'RuntimeError' = @('runtime error', 'execution', 'null reference', 'index out of range')
                'TestFrameworkError' = @('pester', 'should', 'it should', 'describe', 'context')
            }

            foreach ($category in $errorClassifications.Keys) {
                $keywords = $errorClassifications[$category]
                foreach ($keyword in $keywords) {
                    if ($allText -match [regex]::Escape($keyword)) {
                        if ($category -notin $analysisResult.ErrorCategories) {
                            $analysisResult.ErrorCategories += $category
                        }
                    }
                }
            }

            # 4. Extract capabilities and features affected
            Write-AnalysisLog "Identifying affected capabilities..." -Level "INFO"
            
            $capabilityPatterns = @{
                'Logging' = @('write-customlog', 'log', 'logging')
                'Testing' = @('pester', 'test', 'should', 'describe', 'context', 'it ')
                'Git Operations' = @('git ', 'commit', 'branch', 'merge', 'pull', 'push')
                'Module Management' = @('import-module', 'get-module', 'remove-module')
                'File Operations' = @('get-content', 'set-content', 'copy-item', 'remove-item')
                'Configuration' = @('config', 'setting', 'parameter', 'variable')
                'PowerShell Core' = @('powershell', 'pwsh', 'cmdlet', 'function')
                'Infrastructure' = @('opentofu', 'terraform', 'docker', 'container')
                'Automation' = @('workflow', 'pipeline', 'automation', 'script')
                'Validation' = @('validate', 'check', 'verify', 'analyze')
            }

            foreach ($capability in $capabilityPatterns.Keys) {
                $keywords = $capabilityPatterns[$capability]
                foreach ($keyword in $keywords) {
                    if ($allText -match [regex]::Escape($keyword)) {
                        if ($capability -notin $analysisResult.AffectedCapabilities) {
                            $analysisResult.AffectedCapabilities += $capability
                        }
                    }
                }
            }

            # 5. Generate specific failure reasons and recommendations
            Write-AnalysisLog "Generating failure analysis and recommendations..." -Level "INFO"
            
            # Analyze specific failure patterns
            if ($analysisResult.ErrorCategories -contains 'SyntaxError') {
                $analysisResult.FailureReasons += "PowerShell syntax errors detected in one or more files"
                $analysisResult.Recommendations += "Run PSScriptAnalyzer to identify and fix syntax issues"
                $analysisResult.Recommendations += "Use PowerShell ISE or VS Code for syntax highlighting"
            }

            if ($analysisResult.ErrorCategories -contains 'ModuleError') {
                $analysisResult.FailureReasons += "Module loading or import failures"
                $analysisResult.Recommendations += "Verify module paths and availability"
                $analysisResult.Recommendations += "Check module dependencies and prerequisites"
            }

            if ($analysisResult.ErrorCategories -contains 'PathError') {
                $analysisResult.FailureReasons += "File or path resolution issues"
                $analysisResult.Recommendations += "Verify file paths and working directory"
                $analysisResult.Recommendations += "Check file permissions and accessibility"
            }

            if ($analysisResult.ErrorCategories -contains 'TestFrameworkError') {
                $analysisResult.FailureReasons += "Test framework execution problems"
                $analysisResult.Recommendations += "Review test assertions and expectations"
                $analysisResult.Recommendations += "Validate test data and mock objects"
            }

            # 6. Calculate confidence level
            $confidenceScore = 0

            if ($analysisResult.AffectedFiles.Count -gt 0) { $confidenceScore += 30 }
            if ($analysisResult.AffectedModules.Count -gt 0) { $confidenceScore += 25 }
            if ($analysisResult.ErrorCategories.Count -gt 0) { $confidenceScore += 25 }
            if ($analysisResult.AffectedCapabilities.Count -gt 0) { $confidenceScore += 20 }

            $analysisResult.Confidence = switch ($true) {
                ($confidenceScore -ge 80) { "High"; break }
                ($confidenceScore -ge 60) { "Medium"; break }
                ($confidenceScore -ge 40) { "Low"; break }
                default { "Unknown" }
            }

            # 7. Add technical details
            $analysisResult.TechnicalDetails = @{
                TotalOutputLines = $TestOutput.Count
                TotalErrorLines = $ErrorDetails.Count
                TestType = $TestType
                WorkingDirectory = $WorkingDirectory
                AnalysisPatterns = @{
                    FilePatterns = $filePatterns.Count
                    ModulePatterns = $modulePatterns.Count
                    ErrorCategories = $errorClassifications.Keys.Count
                    CapabilityPatterns = $capabilityPatterns.Keys.Count
                }
                RawErrorSample = if ($ErrorDetails.Count -gt 0) { 
                    ($ErrorDetails | Select-Object -First 3) -join "; " 
                } else { 
                    "No errors captured" 
                }
            }

            Write-AnalysisLog "Analysis complete. Confidence: $($analysisResult.Confidence), Files: $($analysisResult.AffectedFiles.Count), Modules: $($analysisResult.AffectedModules.Count)" -Level "SUCCESS"

            return $analysisResult

        } catch {
            Write-AnalysisLog "Test analysis failed: $($_.Exception.Message)" -Level "ERROR"
            
            return @{
                AffectedFiles = @()
                AffectedModules = @()
                AffectedCapabilities = @()
                ErrorCategories = @("AnalysisError")
                FailureReasons = @("Automated analysis failed: $($_.Exception.Message)")
                Recommendations = @("Manual review required")
                TechnicalDetails = @{ AnalysisError = $_.Exception.Message }
                Confidence = "Unknown"
                AnalysisTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            }
        }
    }
}

Export-ModuleMember -Function Get-TestAnalysisContext
