function Update-BugzFile {
    <#
    .SYNOPSIS
        Creates or updates a .bugz file for tracking PSScriptAnalyzer findings
    
    .DESCRIPTION
        Creates a YAML-based bug tracking file that maintains a record of
        PSScriptAnalyzer findings, their status, and remediation information
    
    .PARAMETER Path
        Directory path to create/update .bugz file for
    
    .PARAMETER AnalysisResults
        PSScriptAnalyzer results to add to bug tracking
    
    .PARAMETER UpdateExisting
        Whether to update existing entries or create new ones
    
    .PARAMETER AutoResolve
        Automatically resolve entries that no longer appear in results
    
    .EXAMPLE
        Update-BugzFile -Path "./aither-core/modules/PatchManager" -AnalysisResults $results -UpdateExisting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [array]$AnalysisResults = @(),
        
        [Parameter(Mandatory = $false)]
        [switch]$UpdateExisting,
        
        [Parameter(Mandatory = $false)]
        [switch]$AutoResolve
    )
    
    try {
        $resolvedPath = Resolve-Path $Path -ErrorAction Stop
        $bugzFilePath = Join-Path $resolvedPath $script:DefaultSettings.BugzFileName
        
        # Load existing .bugz file if it exists
        $existingBugz = @{
            directory = $resolvedPath.Path
            created = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
            updated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
            findings = @()
            summary = @{
                open = 0
                resolved = 0
                ignored = 0
                total = 0
            }
            metadata = @{
                version = $script:ModuleVersion
                format = 'bugz-1.0'
            }
        }
        
        if (Test-Path $bugzFilePath) {
            try {
                if ($bugzFilePath.EndsWith('.yaml') -or $bugzFilePath.EndsWith('.yml')) {
                    # If YAML format is available
                    if (Get-Command 'ConvertFrom-Yaml' -ErrorAction SilentlyContinue) {
                        $existingContent = Get-Content $bugzFilePath -Raw | ConvertFrom-Yaml
                    } else {
                        # Fallback to JSON-like parsing
                        $existingContent = Get-Content $bugzFilePath | ConvertFrom-Json -AsHashtable
                    }
                } else {
                    # JSON format
                    $existingContent = Get-Content $bugzFilePath | ConvertFrom-Json -AsHashtable
                }
                
                if ($existingContent) {
                    $existingBugz = $existingContent
                    $existingBugz.updated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
                }
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to load existing .bugz file, creating new one: $($_.Exception.Message)"
                }
            }
        }
        
        # Create a map of existing findings for quick lookup
        $existingFindings = @{}
        foreach ($finding in $existingBugz.findings) {
            $key = "$($finding.file):$($finding.line):$($finding.ruleName)"
            $existingFindings[$key] = $finding
        }
        
        # Process new analysis results
        $newFindings = @()
        $currentKeys = @()
        
        foreach ($result in $AnalysisResults) {
            $fileName = if ($result.ScriptPath) {
                $relativePath = $result.ScriptPath -replace [regex]::Escape($resolvedPath.Path), ''
                $relativePath = $relativePath.TrimStart('\', '/')
                if ([string]::IsNullOrEmpty($relativePath)) {
                    Split-Path $result.ScriptPath -Leaf
                } else {
                    $relativePath
                }
            } else {
                'Unknown'
            }
            
            $key = "$fileName:$($result.Line):$($result.RuleName)"
            $currentKeys += $key
            
            if ($existingFindings.ContainsKey($key)) {
                # Update existing finding
                $existing = $existingFindings[$key]
                if ($UpdateExisting) {
                    $existing.lastSeen = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $existing.message = $result.Message
                    $existing.severity = $result.Severity
                    # Don't change status if manually set
                    if ($existing.status -eq 'auto-resolved') {
                        $existing.status = 'open'
                    }
                }
                $newFindings += $existing
            } else {
                # Create new finding
                $newFinding = @{
                    id = "PSSA-$(Get-Random -Minimum 1000 -Maximum 9999)"
                    file = $fileName
                    line = $result.Line
                    column = $result.Column
                    severity = $result.Severity
                    ruleName = $result.RuleName
                    message = $result.Message
                    status = 'open'
                    assignee = $null
                    priority = switch ($result.Severity) {
                        'Error' { 'high' }
                        'Warning' { 'medium' }
                        'Information' { 'low' }
                        default { 'low' }
                    }
                    ignored = $false
                    ignoreReason = $null
                    created = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
                    lastSeen = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
                    tags = @()
                    notes = @()
                }
                $newFindings += $newFinding
            }
        }
        
        # Handle auto-resolve for missing findings
        if ($AutoResolve) {
            foreach ($existing in $existingBugz.findings) {
                $key = "$($existing.file):$($existing.line):$($existing.ruleName)"
                if ($key -notin $currentKeys -and $existing.status -eq 'open') {
                    $existing.status = 'auto-resolved'
                    $existing.resolvedDate = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $existing.resolvedReason = 'No longer detected by PSScriptAnalyzer'
                    $newFindings += $existing
                }
            }
        } else {
            # Include all existing findings not seen in current analysis
            foreach ($existing in $existingBugz.findings) {
                $key = "$($existing.file):$($existing.line):$($existing.ruleName)"
                if ($key -notin $currentKeys) {
                    $newFindings += $existing
                }
            }
        }
        
        # Update summary
        $summary = @{
            open = ($newFindings | Where-Object { $_.status -eq 'open' }).Count
            resolved = ($newFindings | Where-Object { $_.status -in @('resolved', 'auto-resolved') }).Count
            ignored = ($newFindings | Where-Object { $_.ignored -eq $true }).Count
            total = $newFindings.Count
        }
        
        # Create final .bugz object
        $bugzObject = @{
            directory = $resolvedPath.Path
            created = $existingBugz.created
            updated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
            findings = $newFindings
            summary = $summary
            metadata = @{
                version = $script:ModuleVersion
                format = 'bugz-1.0'
                generator = 'PSScriptAnalyzerIntegration'
                lastAnalysis = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
        }
        
        # Write .bugz file in JSON format (YAML would be better but requires additional module)
        $bugzJson = $bugzObject | ConvertTo-Json -Depth 10 -Compress:$false
        Set-Content -Path $bugzFilePath -Value $bugzJson -Encoding UTF8
        
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Updated .bugz file: $bugzFilePath (Open: $($summary.open), Resolved: $($summary.resolved), Total: $($summary.total))"
        }
        
        return $bugzObject
    }
    catch {
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'ERROR' -Message "Failed to update .bugz file for $Path: $($_.Exception.Message)"
        }
        throw
    }
}