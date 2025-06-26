#Requires -Version 7.0

<#
.SYNOPSIS
    Upgrades scripts to use the standardized parameter handling system
.DESCRIPTION
    This utility script scans the specified directory for PowerShell scripts
    and upgrades them to use the standardized parameter handling system.
.PARAMETER Path
    The path to scan for scripts to upgrade
.PARAMETER Force
    Apply changes without prompting
.PARAMETER WhatIf
    Show what would be changed without making actual changes
.EXAMPLE
    .\Update-ScriptParameters.ps1 -Path "c:\scripts" -WhatIf
    Show which scripts would be updated without making changes.
.EXAMPLE
    .\Update-ScriptParameters.ps1 -Path "c:\scripts" -Force
    Update all scripts in the specified directory without prompting.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter()]
    [switch]$Force
)

# Import shared utilities and logging
. "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force

# Import required modules
Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force -ErrorAction SilentlyContinue
Import-Module "$env:PWSH_MODULES_PATH/LabRunner" -Force -ErrorAction SilentlyContinue

# Initialize
$stdParamsImportLine = '# Initialize standardized parameters
$params = Initialize-StandardParameters -InputParameters $PSBoundParameters -ScriptName $MyInvocation.MyCommand.Name'

$stdParamsTemplate = @'
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [object]$Config,

    [Parameter()]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',

    [Parameter()]
    [switch]$Auto,

    [Parameter()]
    [switch]$Force
)
'@

$upgradeCount = 0
$errorCount = 0
$skippedCount = 0

# Get all PS1 files in the specified directory
$scripts = Get-ChildItem -Path $Path -Filter *.ps1 -Recurse

Write-CustomLog -Level 'INFO' -Message "Found $($scripts.Count) scripts to analyze for parameter upgrades"

foreach ($script in $scripts) {
    try {
        $content = Get-Content -Path $script.FullName -Raw
        $needsUpdate = $false
        $modified = $false

        # Check if script already uses the standardized parameter system
        if ($content -match 'Initialize-StandardParameters') {
            Write-CustomLog -Level 'WARN' -Message "  [SKIP] $($script.Name) - Already uses standardized parameters"
            $skippedCount++
            continue
        }

        # Check if script has a param block
        if ($content -match '\s*param\s*\(') {
            # Extract param block
            $paramStartIndex = $content.IndexOf('param')
            $paramEndIndex = $content.IndexOf(')', $paramStartIndex)
            if ($paramEndIndex -gt $paramStartIndex) {
                $paramBlock = $content.Substring($paramStartIndex, $paramEndIndex - $paramStartIndex + 1)

                # Check if param block already has standard parameters                $hasVerbosity = $paramBlock -match '\[string\]\s*\$Verbosity'
                $hasConfig = $paramBlock -match '\[object\]\s*\$Config'
                $hasAuto = $paramBlock -match '\[switch\]\s*\$Auto'
                $hasForce = $paramBlock -match '\[switch\]\s*\$Force'
                $supportsShouldProcess = $paramBlock -match '\[switch\]\s*\$WhatIf' -or $content -match '\[CmdletBinding\([^\)]*SupportsShouldProcess[^\)]*\)\]'
                $hasStdParams = $hasVerbosity -and $hasConfig -and $hasAuto -and $hasForce -and $supportsShouldProcess

                if (-not $hasStdParams) {
                    $needsUpdate = $true
                }
            }
        } else {
            $needsUpdate = $true
        }

        # Check if script needs update and proper CmdletBinding
        $hasCmdletBinding = $content -match '\[CmdletBinding\(SupportsShouldProcess\)\]'
        if ($needsUpdate -or -not $hasCmdletBinding) {
            if ($PSCmdlet.ShouldProcess($script.Name, 'Update to standardized parameters')) {
                # Create modified content
                $newContent = $content

                # Handle CmdletBinding
                if (-not $hasCmdletBinding) {
                    if ($content -match '\[CmdletBinding\([^\)]*\)\]') {
                        $newContent = $newContent -replace '\[CmdletBinding\([^\)]*\)\]', '[CmdletBinding(SupportsShouldProcess)]'
                        $modified = $true
                    }
                }

                # Handle param block
                if ($content -match '\s*param\s*\(') {
                    # Replace param block with standardized one
                    $newContent = $newContent -replace 'param\s*\([^)]*\)', $stdParamsTemplate
                    $modified = $true
                } else {
                    # Add param block if none exists
                    $importModuleMatch = $newContent -match 'Import-Module'
                    if ($importModuleMatch) {
                        $firstImportIndex = $newContent.IndexOf('Import-Module')
                        $insertPosition = $newContent.LastIndexOf('#', $firstImportIndex)
                        if ($insertPosition -lt 0) {
                            $insertPosition = 0
                        }

                        $newContent = $newContent.Insert($insertPosition, $stdParamsTemplate + "`n`n")
                        $modified = $true
                    }
                }

                # Add StandardParameters initialization line after module imports
                if ($newContent -match 'Import-Module') {
                    $lastImportIndex = $newContent.LastIndexOf('Import-Module')
                    $nextLineBreak = $newContent.IndexOf("`n", $lastImportIndex)
                    if ($nextLineBreak -gt 0) {
                        $newContent = $newContent.Insert($nextLineBreak + 1, "`n" + $stdParamsImportLine + "`n")
                        $modified = $true
                    }
                }

                # Only write file if changes were made
                if ($modified) {
                    Set-Content -Path $script.FullName -Value $newContent -Force
                    Write-CustomLog -Level 'SUCCESS' -Message "  [UPDATED] $($script.Name)"
                    $upgradeCount++
                } else {
                    Write-CustomLog -Level 'WARN' -Message "  [SKIPPED] $($script.Name) - No changes needed"
                    $skippedCount++
                }
            } else {
                Write-CustomLog -Level 'WARN' -Message "  [WHATIF] Would update $($script.Name)"
            }
        } else {
            Write-CustomLog -Level 'SUCCESS' -Message "  [OK] $($script.Name) - Already has required parameters"
            $skippedCount++
        }
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "  [ERROR] $($script.Name) - $($_.Exception.Message)"
        $errorCount++
    }
}

# Summary
Write-CustomLog -Level 'INFO' -Message "`nParameter upgrade completed:"
Write-CustomLog -Level 'INFO' -Message "  Updated: $upgradeCount scripts"
Write-CustomLog -Level 'INFO' -Message "  Skipped: $skippedCount scripts"
if ($errorCount -gt 0) {
    Write-CustomLog -Level 'ERROR' -Message "  Errors:  $errorCount scripts"
} else {
    Write-CustomLog -Level 'INFO' -Message "  Errors:  $errorCount scripts"
}

if ($PSCmdlet.ShouldProcess('Documentation', 'Show help')) {
    Write-CustomLog -Level 'INFO' -Message "`nNext Steps:"
    Write-CustomLog -Level 'INFO' -Message '  1. Review the updated scripts for any issues'
    Write-CustomLog -Level 'INFO' -Message "  2. Update ShouldProcess calls in scripts to use `$params.IsWhatIfMode"
    Write-CustomLog -Level 'INFO' -Message '  3. Read the documentation at docs/StandardizedParameters.md'
}
