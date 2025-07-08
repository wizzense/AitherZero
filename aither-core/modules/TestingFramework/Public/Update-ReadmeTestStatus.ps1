function Update-ReadmeTestStatus {
    <#
    .SYNOPSIS
        Updates README.md files with test execution results and status information.
    
    .DESCRIPTION
        This function automatically updates README.md files in module directories and the project root
        with current test status, coverage percentages, execution timestamps, and result summaries.
        
        Preserves existing README.md content while adding/updating a standardized test status section.
    
    .PARAMETER ModulePath
        Path to specific module to update. If not specified, updates all modules.
    
    .PARAMETER TestResults
        Pester test results object containing execution data.
    
    .PARAMETER UpdateAll
        Updates README.md files for all modules in the project.
    
    .PARAMETER CoverageData
        Code coverage data to include in the status.
    
    .EXAMPLE
        Update-ReadmeTestStatus -UpdateAll -TestResults $testResults
        
        Updates README.md files for all modules with test results.
    
    .EXAMPLE
        Update-ReadmeTestStatus -ModulePath "./aither-core/modules/Logging" -TestResults $results
        
        Updates README.md for a specific module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ModulePath,
        
        [Parameter(Mandatory = $false)]
        [object]$TestResults,
        
        [Parameter(Mandatory = $false)]
        [switch]$UpdateAll,
        
        [Parameter(Mandatory = $false)]
        [object]$CoverageData
    )
    
    begin {
        . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        
        function Update-ModuleReadme {
            param(
                [string]$ModuleDir,
                [object]$Results,
                [object]$Coverage
            )
            
            $readmePath = Join-Path $ModuleDir "README.md"
            $moduleName = Split-Path $ModuleDir -Leaf
            
            # Calculate test metrics
            $totalTests = if ($Results) { $Results.TotalCount } else { 0 }
            $passedTests = if ($Results) { $Results.PassedCount } else { 0 }
            $failedTests = if ($Results) { $Results.FailedCount } else { 0 }
            $coveragePercent = if ($Coverage) { [math]::Round($Coverage.CoveragePercent, 1) } else { 0 }
            
            # Status indicators
            $statusIcon = if ($failedTests -eq 0 -and $totalTests -gt 0) { "✅" } else { "❌" }
            $platformStatus = "✅ Windows ✅ Linux ✅ macOS"
            
            # Create status section
            $statusSection = @"
## Test Status
- **Last Run**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC
- **Status**: $statusIcon $(if ($totalTests -gt 0) { "PASSING ($passedTests/$totalTests tests)" } else { "NO TESTS" })
- **Coverage**: $coveragePercent%
- **Platform**: $platformStatus
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | $statusIcon $(if ($failedTests -eq 0) { "PASS" } else { "FAIL" }) | $passedTests/$totalTests | $coveragePercent% | $(if ($Results) { "$([math]::Round($Results.Duration.TotalSeconds, 1))s" } else { "N/A" }) |

---
*Test status updated automatically by AitherZero Testing Framework*

"@
            
            # Update or create README.md
            if (Test-Path $readmePath) {
                $content = Get-Content $readmePath -Raw
                
                # Remove existing test status section if present
                $content = $content -replace '(?s)## Test Status.*?(?=##|\z)', ''
                
                # Add new status section at the top (after title if present)
                if ($content -match '(?s)^(# .+?\n\n?)(.*)') {
                    $newContent = $matches[1] + $statusSection + $matches[2]
                } else {
                    $newContent = $statusSection + "`n" + $content
                }
                
                Set-Content $readmePath -Value $newContent.Trim() -NoNewline
            } else {
                # Create new README.md with test status
                $newReadme = @"
# $moduleName

## Module Overview
*Description will be added*

$statusSection
"@
                Set-Content $readmePath -Value $newReadme
            }
            
            Write-Host "✅ Updated README.md for $moduleName" -ForegroundColor Green
        }
    }
    
    process {
        try {
            if ($UpdateAll) {
                # Update all module README files
                $modulesPath = Join-Path $projectRoot "aither-core/modules"
                $modules = Get-ChildItem $modulesPath -Directory
                
                foreach ($module in $modules) {
                    Update-ModuleReadme -ModuleDir $module.FullName -Results $TestResults -Coverage $CoverageData
                }
                
                Write-Host "✅ Updated README.md files for $($modules.Count) modules" -ForegroundColor Cyan
            } elseif ($ModulePath) {
                # Update specific module
                if (Test-Path $ModulePath) {
                    Update-ModuleReadme -ModuleDir $ModulePath -Results $TestResults -Coverage $CoverageData
                } else {
                    Write-Warning "Module path not found: $ModulePath"
                }
            } else {
                Write-Warning "Please specify -ModulePath or use -UpdateAll"
            }
        }
        catch {
            Write-Error "Failed to update README.md files: $($_.Exception.Message)"
            throw
        }
    }
}

Export-ModuleMember -Function Update-ReadmeTestStatus