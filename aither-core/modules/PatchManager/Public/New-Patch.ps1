#Requires -Version 7.0

<#
.SYNOPSIS
    Simple, reliable patch creation - the main entry point for PatchManager v3.0

.DESCRIPTION
    This function replaces the complex Invoke-PatchWorkflow with a simplified, atomic approach
    that eliminates git stashing issues and provides predictable behavior.

    Features:
    - Automatic smart mode detection (Simple/Standard/Advanced)
    - Atomic operations with automatic rollback
    - No more git stashing conflicts
    - Clear, predictable behavior
    - Safe defaults with intelligent recommendations

.PARAMETER Description
    Clear description of what this patch does

.PARAMETER Changes
    Script block containing the changes to apply

.PARAMETER Mode
    Operation mode (auto-detected if not specified):
    - Simple: Direct changes without branches (for minor fixes)
    - Standard: Full branch workflow (recommended)
    - Advanced: Cross-fork and enterprise features

.PARAMETER CreatePR
    Create a pull request (auto-determined if not specified)

.PARAMETER CreateIssue
    Create a GitHub issue for tracking (default: auto-determined)

.PARAMETER TargetFork
    For cross-fork PRs: 'current', 'upstream', or 'root'

.PARAMETER DryRun
    Preview what would be done without making changes

.PARAMETER Force
    Override safety checks and recommendations

.PARAMETER AutoTag
    Automatically create version tag after successful operations (v3.1 feature)

.PARAMETER FastTrack  
    Skip PR creation and merge directly for critical fixes (v3.1 feature)

.EXAMPLE
    New-Patch -Description "Fix typo in README" -Changes {
        $content = Get-Content "README.md"
        $content = $content -replace "teh", "the"
        Set-Content "README.md" -Value $content
    }
    # Smart mode will detect this as Simple mode (no PR/issue needed)

.EXAMPLE
    New-Patch -Description "Add user authentication feature" -Changes {
        # Implementation here
        Add-AuthenticationModule
    }
    # Smart mode will detect this as Standard mode with PR creation

.EXAMPLE
    New-Patch -Description "Security fix" -CreatePR -Mode "Standard"
    # Explicitly request Standard mode with PR

.EXAMPLE
    New-Patch -Description "Cross-fork feature" -TargetFork "upstream" -CreatePR
    # Advanced mode for cross-fork operations

.NOTES
    PatchManager v3.0 - Eliminates stashing issues and provides atomic operations
#>

function New-Patch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Alias("PatchDescription")]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [Alias("PatchOperation")]
        [scriptblock]$Changes,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Simple", "Standard", "Advanced", "Auto")]
        [string]$Mode = "Auto",

        [Parameter(Mandatory = $false)]
        [switch]$CreatePR,

        [Parameter(Mandatory = $false)]
        [object]$CreateIssue = $null,

        [Parameter(Mandatory = $false)]
        [ValidateSet("current", "upstream", "root")]
        [string]$TargetFork = "current",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [ValidateSet('QuickFix', 'Feature', 'Hotfix', 'Patch', 'Release')]
        [string]$OperationType = 'Patch',

        [Parameter(Mandatory = $false)]
        [switch]$AutoTag,

        [Parameter(Mandatory = $false)]
        [switch]$FastTrack
    )

    begin {
        # Initialize logging
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Host "[$Level] $Message"
            }
        }

        Write-CustomLog "PatchManager v3.0: Starting patch creation" -Level "INFO"
        Write-CustomLog "Description: $Description" -Level "INFO"

        if ($DryRun) {
            Write-CustomLog "DRY RUN MODE: No actual changes will be made" -Level "WARN"
        }
    }

    process {
        try {
            # Step 1: Smart mode detection if needed
            if ($Mode -eq "Auto") {
                Write-CustomLog "Performing smart analysis to determine optimal approach..." -Level "INFO"

                $smartAnalysis = Get-SmartOperationMode -PatchDescription $Description -HasPatchOperation ($null -ne $Changes) -CreatePR $CreatePR -CreateIssue $CreateIssue -TargetFork $TargetFork

                $Mode = $smartAnalysis.RecommendedMode

                # Apply smart recommendations if user didn't explicitly set them
                if (-not $CreatePR.IsPresent) {
                    $CreatePR = $smartAnalysis.ShouldCreatePR
                }
                if ($null -eq $CreateIssue) {
                    $CreateIssue = $smartAnalysis.ShouldCreateIssue
                }

                Write-CustomLog "Smart analysis recommends: $Mode mode" -Level "INFO"
                Write-CustomLog "Confidence: $($smartAnalysis.Confidence * 100)%, Risk: $($smartAnalysis.RiskLevel)" -Level "INFO"

                # Show warnings if any
                foreach ($warning in $smartAnalysis.Warnings) {
                    Write-CustomLog $warning -Level "WARN"
                }

                # Ask for confirmation if high risk and not forced
                if ($smartAnalysis.RiskLevel -eq "High" -and -not $Force -and -not $DryRun) {
                    Write-CustomLog "High-risk operation detected. Recommended: Create PR for review" -Level "WARN"
                    if (-not $CreatePR) {
                        Write-CustomLog "Consider using -CreatePR flag for safer operation" -Level "WARN"
                    }
                }
            }

            # Step 1.5: Apply v3.1 performance optimizations
            if ($FastTrack) {
                Write-CustomLog "FastTrack mode enabled - bypassing PR creation for direct merge" -Level "WARN"
                $CreatePR = $false
                $CreateIssue = $false
                if ($Mode -eq "Simple") {
                    Write-CustomLog "FastTrack optimized for Simple mode - maximum speed" -Level "INFO"
                }
            }

            if ($AutoTag) {
                Write-CustomLog "AutoTag enabled - version tag will be created automatically" -Level "INFO"
            }

            Write-CustomLog "Using $Mode mode (CreatePR: $CreatePR, CreateIssue: $CreateIssue)" -Level "INFO"

            # Step 2: Execute multi-mode operation
            $result = Invoke-MultiModeOperation -Mode $Mode -PatchDescription $Description -PatchOperation $Changes -CreatePR:$CreatePR -CreateIssue $CreateIssue -TargetFork $TargetFork -DryRun:$DryRun -OperationType $OperationType

            if ($result.Success) {
                Write-CustomLog "Patch creation completed successfully!" -Level "SUCCESS"

                # Provide user guidance based on what was created
                if ($result.Result.BranchCreated) {
                    Write-CustomLog "Branch created: $($result.Result.BranchCreated)" -Level "INFO"
                }

                # Step 3: Apply AutoTag if requested (v3.1 feature)
                if ($AutoTag -and -not $DryRun) {
                    try {
                        Write-CustomLog "Creating automatic version tag..." -Level "INFO"
                        
                        if (Test-Path "VERSION") {
                            $version = (Get-Content "VERSION").Trim()
                            $tagName = "v$version"
                            
                            git tag -a "$tagName" -m "Automatic tag: $Description"
                            git push origin "$tagName"
                            
                            Write-CustomLog "Created and pushed tag: $tagName" -Level "SUCCESS"
                        } else {
                            Write-CustomLog "VERSION file not found - skipping AutoTag" -Level "WARN"
                        }
                    } catch {
                        Write-CustomLog "AutoTag failed: $($_.Exception.Message)" -Level "ERROR"
                    }
                }

                if ($CreatePR -and -not $DryRun) {
                    Write-CustomLog "Next steps: PR will be created for review and merge" -Level "INFO"
                } elseif ($result.Result.CommittedDirectly) {
                    Write-CustomLog "Changes have been committed directly" -Level "INFO"
                } else {
                    Write-CustomLog "Changes are ready in branch for manual review" -Level "INFO"
                }

                return @{
                    Success = $true
                    Mode = $Mode
                    Description = $Description
                    DryRun = $DryRun.IsPresent
                    Result = $result.Result
                    Duration = $result.Duration
                    Message = "Patch created successfully"
                }
            } else {
                throw "Operation failed: $($result.Error)"
            }

        } catch {
            $errorMessage = "Patch creation failed: $($_.Exception.Message)"
            Write-CustomLog $errorMessage -Level "ERROR"

            return @{
                Success = $false
                Mode = $Mode
                Description = $Description
                DryRun = $DryRun.IsPresent
                Error = $_.Exception.Message
                Message = $errorMessage
            }
        }
    }

    end {
        Write-CustomLog "Patch operation completed" -Level "INFO"
    }
}

# Provide legacy compatibility alias
Set-Alias -Name "Invoke-PatchWorkflow" -Value "New-Patch"

Export-ModuleMember -Function New-Patch -Alias Invoke-PatchWorkflow
