function New-StatusFile {
    <#
    .SYNOPSIS
        Creates or updates a PSScriptAnalyzer status file for a directory

    .DESCRIPTION
        Creates a JSON status file that tracks PSScriptAnalyzer analysis results,
        configuration used, and metadata for a specific directory

    .PARAMETER Path
        Directory path to create status file for

    .PARAMETER AnalysisResults
        PSScriptAnalyzer results to include in status

    .PARAMETER Configuration
        Configuration used for analysis

    .PARAMETER Force
        Overwrite existing status file

    .EXAMPLE
        New-StatusFile -Path "./aither-core/modules/PatchManager" -AnalysisResults $results -Configuration $config
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [array]$AnalysisResults = @(),

        [Parameter(Mandatory = $false)]
        [hashtable]$Configuration = @{},

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    try {
        $resolvedPath = Resolve-Path $Path -ErrorAction Stop
        $statusFilePath = Join-Path $resolvedPath $script:DefaultSettings.StatusFileName

        # Check if file exists and Force not specified
        if ((Test-Path $statusFilePath) -and -not $Force) {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'WARN' -Message "Status file already exists at $statusFilePath. Use -Force to overwrite."
            }
            return $false
        }

        # Analyze results if provided
        $findings = @{
            errors = 0
            warnings = 0
            information = 0
            total = 0
        }

        $ruleFindings = @{}
        $fileFindings = @{}

        if ($AnalysisResults -and $AnalysisResults.Count -gt 0) {
            foreach ($result in $AnalysisResults) {
                $findings.total++

                switch ($result.Severity) {
                    'Error' { $findings.errors++ }
                    'Warning' { $findings.warnings++ }
                    'Information' { $findings.information++ }
                }

                # Track by rule
                if ($ruleFindings.ContainsKey($result.RuleName)) {
                    $ruleFindings[$result.RuleName]++
                } else {
                    $ruleFindings[$result.RuleName] = 1
                }

                # Track by file
                $fileName = if ($result.ScriptPath) {
                    Split-Path $result.ScriptPath -Leaf
                } else {
                    'Unknown'
                }

                if ($fileFindings.ContainsKey($fileName)) {
                    $fileFindings[$fileName]++
                } else {
                    $fileFindings[$fileName] = 1
                }
            }
        }

        # Determine overall status
        $status = if ($findings.errors -gt 0) {
            'critical'
        } elseif ($findings.warnings -gt $script:QualityThresholds.WarningThreshold) {
            'needs-attention'
        } elseif ($findings.warnings -gt 0) {
            'warnings'
        } elseif ($findings.information -gt $script:QualityThresholds.InfoThreshold) {
            'review-recommended'
        } else {
            'good'
        }

        # Get PowerShell files in directory
        $psFiles = Get-ChildItem -Path $resolvedPath -Include *.ps1,*.psm1,*.psd1 -Recurse -ErrorAction SilentlyContinue
        $totalFiles = $psFiles.Count
        $analyzedFiles = if ($AnalysisResults) {
            ($AnalysisResults | Select-Object -Property ScriptPath -Unique).Count
        } else {
            0
        }

        # Create status object
        $statusObject = [PSCustomObject]@{
            directory = $resolvedPath.Path
            lastAnalysis = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
            totalFiles = $totalFiles
            analyzedFiles = $analyzedFiles
            findings = $findings
            status = $status
            ruleBreakdown = $ruleFindings
            fileBreakdown = $fileFindings
            qualityScore = [math]::Max(0, 100 - ($findings.errors * 10) - ($findings.warnings * 2) - ($findings.information * 0.5))
            configuration = @{
                profile = if ($Configuration.ContainsKey('Profile')) { $Configuration.Profile } else { 'Default' }
                rulesApplied = if ($Configuration.ContainsKey('IncludeRules')) { $Configuration.IncludeRules.Count } else { 0 }
                rulesExcluded = if ($Configuration.ContainsKey('ExcludeRules')) { $Configuration.ExcludeRules.Count } else { 0 }
                severityLevels = if ($Configuration.ContainsKey('Severity')) { $Configuration.Severity } else { @('Error', 'Warning', 'Information') }
            }
            metadata = @{
                moduleVersion = $script:ModuleVersion
                psVersion = $PSVersionTable.PSVersion.ToString()
                platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
                analysisEngine = 'PSScriptAnalyzer'
            }
        }

        # Write status file
        $statusJson = $statusObject | ConvertTo-Json -Depth 10 -Compress:$false
        Set-Content -Path $statusFilePath -Value $statusJson -Encoding UTF8

        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Created status file: $statusFilePath (Status: $status, Score: $($statusObject.qualityScore))"
        }

        return $true
    }
    catch {
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create status file for ${Path}: $($_.Exception.Message)"
        }
        throw
    }
}
