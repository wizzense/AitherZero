#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize progress tracking support for PatchManager operations
.DESCRIPTION
    This private function sets up progress tracking integration for PatchManager
    operations, making it available when the ProgressTracking module is loaded.
#>

function Initialize-ProgressTracking {
    [CmdletBinding()]
    param()
    
    # Check if ProgressTracking module is available
    $script:ProgressTrackingAvailable = $false
    $script:ProgressTrackingLoaded = $false
    
    try {
        # Try to find the ProgressTracking module
        $progressModulePath = Join-Path $PSScriptRoot '../../ProgressTracking'
        if (Test-Path $progressModulePath) {
            # Attempt to import the module
            Import-Module $progressModulePath -Force -ErrorAction SilentlyContinue
            
            # Verify it loaded successfully
            if (Get-Module -Name ProgressTracking) {
                $script:ProgressTrackingAvailable = $true
                $script:ProgressTrackingLoaded = $true
                
                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-CustomLog -Level 'INFO' -Message 'ProgressTracking module loaded successfully for PatchManager'
                }
            }
        }
    } catch {
        # Silently continue if progress tracking isn't available
        Write-Verbose "ProgressTracking module not available: $($_.Exception.Message)"
    }
}

function Test-ProgressTrackingAvailable {
    <#
    .SYNOPSIS
        Test if progress tracking is available and loaded
    #>
    [CmdletBinding()]
    param()
    
    return $script:ProgressTrackingLoaded -eq $true
}

function Start-PatchProgress {
    <#
    .SYNOPSIS
        Start progress tracking for a patch operation if available
    .PARAMETER OperationName
        Name of the patch operation
    .PARAMETER TotalSteps
        Total number of steps in the operation
    .PARAMETER ShowETA
        Show estimated time to completion
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationName,
        
        [Parameter(Mandatory)]
        [int]$TotalSteps,
        
        [switch]$ShowETA
    )
    
    if (Test-ProgressTrackingAvailable) {
        try {
            $progressId = Start-ProgressOperation -OperationName $OperationName `
                                                -TotalSteps $TotalSteps `
                                                -ShowTime `
                                                -ShowETA:$ShowETA `
                                                -Style 'Bar'
            return $progressId
        } catch {
            Write-Verbose "Failed to start progress tracking: $($_.Exception.Message)"
            return $null
        }
    }
    
    return $null
}

function Update-PatchProgress {
    <#
    .SYNOPSIS
        Update progress for a patch operation if tracking is active
    #>
    [CmdletBinding()]
    param(
        [string]$OperationId,
        
        [string]$StepName,
        
        [int]$CurrentStep,
        
        [switch]$IncrementStep
    )
    
    if ($OperationId -and (Test-ProgressTrackingAvailable)) {
        try {
            $params = @{
                OperationId = $OperationId
            }
            
            if ($StepName) {
                $params.StepName = $StepName
            }
            
            if ($PSBoundParameters.ContainsKey('CurrentStep')) {
                $params.CurrentStep = $CurrentStep
            }
            
            if ($IncrementStep) {
                $params.IncrementStep = $true
            }
            
            Update-ProgressOperation @params
        } catch {
            Write-Verbose "Failed to update progress: $($_.Exception.Message)"
        }
    }
}

function Complete-PatchProgress {
    <#
    .SYNOPSIS
        Complete progress tracking for a patch operation if active
    #>
    [CmdletBinding()]
    param(
        [string]$OperationId,
        
        [switch]$ShowSummary
    )
    
    if ($OperationId -and (Test-ProgressTrackingAvailable)) {
        try {
            Complete-ProgressOperation -OperationId $OperationId -ShowSummary:$ShowSummary
        } catch {
            Write-Verbose "Failed to complete progress tracking: $($_.Exception.Message)"
        }
    }
}

function Write-PatchProgressLog {
    <#
    .SYNOPSIS
        Write a log message that's compatible with progress tracking
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    if ((Test-ProgressTrackingAvailable) -and (Get-Command Write-ProgressLog -ErrorAction SilentlyContinue)) {
        Write-ProgressLog -Message $Message -Level $Level
    } elseif (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        # Map progress levels to custom log levels
        $logLevel = switch ($Level) {
            'Info' { 'INFO' }
            'Warning' { 'WARN' }
            'Error' { 'ERROR' }
            'Success' { 'SUCCESS' }
            default { 'INFO' }
        }
        Write-CustomLog -Level $logLevel -Message $Message
    } else {
        # Fallback to Write-Host
        $color = switch ($Level) {
            'Info' { 'White' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            'Success' { 'Green' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Initialize on module load
Initialize-ProgressTracking

# Export the functions for use within PatchManager
Export-ModuleMember -Function @(
    'Test-ProgressTrackingAvailable',
    'Start-PatchProgress',
    'Update-PatchProgress',
    'Complete-PatchProgress',
    'Write-PatchProgressLog'
)