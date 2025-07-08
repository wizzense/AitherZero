# AitherZero Progress Tracking Module
# Provides visual progress indicators and operation tracking

$script:ActiveOperations = @{}
$script:ProgressBarCache = @{}

function Start-ProgressOperation {
    <#
    .SYNOPSIS
        Start tracking a new operation with progress visualization
    .DESCRIPTION
        Creates a new progress tracking session with visual indicators
    .PARAMETER OperationName
        Name of the operation to track
    .PARAMETER TotalSteps
        Total number of steps in the operation
    .PARAMETER ShowTime
        Show elapsed time in progress display
    .PARAMETER ShowETA
        Calculate and show estimated time to completion
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationName,

        [Parameter(Mandatory)]
        [int]$TotalSteps,

        [switch]$ShowTime,
        [switch]$ShowETA,

        [ValidateSet('Bar', 'Spinner', 'Percentage', 'Detailed')]
        [string]$Style = 'Bar'
    )

    $operationId = [Guid]::NewGuid().ToString()

    $script:ActiveOperations[$operationId] = @{
        Name = $OperationName
        TotalSteps = $TotalSteps
        CurrentStep = 0
        StartTime = Get-Date
        ShowTime = $ShowTime
        ShowETA = $ShowETA
        Style = $Style
        SubOperations = @{}
        Errors = @()
        Warnings = @()
    }

    # Display initial progress
    Update-ProgressDisplay -OperationId $operationId

    return $operationId
}

function Update-ProgressOperation {
    <#
    .SYNOPSIS
        Update progress for an active operation
    .PARAMETER OperationId
        ID of the operation to update
    .PARAMETER CurrentStep
        Current step number
    .PARAMETER StepName
        Optional name for the current step
    .PARAMETER IncrementStep
        Increment the current step by 1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId,

        [int]$CurrentStep,

        [string]$StepName,

        [switch]$IncrementStep
    )

    if (-not $script:ActiveOperations.ContainsKey($OperationId)) {
        Write-Warning "Operation $OperationId not found"
        return
    }

    $operation = $script:ActiveOperations[$OperationId]

    if ($IncrementStep) {
        $operation.CurrentStep++
    } elseif ($PSBoundParameters.ContainsKey('CurrentStep')) {
        $operation.CurrentStep = $CurrentStep
    }

    if ($StepName) {
        $operation.CurrentStepName = $StepName
    }

    # Update display
    Update-ProgressDisplay -OperationId $OperationId
}

function Complete-ProgressOperation {
    <#
    .SYNOPSIS
        Complete and remove a progress operation
    .PARAMETER OperationId
        ID of the operation to complete
    .PARAMETER ShowSummary
        Show a summary of the completed operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId,

        [switch]$ShowSummary
    )

    if (-not $script:ActiveOperations.ContainsKey($OperationId)) {
        return
    }

    $operation = $script:ActiveOperations[$OperationId]
    $operation.EndTime = Get-Date
    $duration = $operation.EndTime - $operation.StartTime

    # Final update showing 100%
    $operation.CurrentStep = $operation.TotalSteps
    Update-ProgressDisplay -OperationId $OperationId

    if ($ShowSummary) {
        Write-Host ""
        Write-Host "✅ Operation Complete: $($operation.Name)" -ForegroundColor Green
        Write-Host "   Duration: $([math]::Round($duration.TotalSeconds, 2))s" -ForegroundColor White
        Write-Host "   Steps Completed: $($operation.TotalSteps)" -ForegroundColor White

        if ($operation.Warnings.Count -gt 0) {
            Write-Host "   ⚠️ Warnings: $($operation.Warnings.Count)" -ForegroundColor Yellow
        }

        if ($operation.Errors.Count -gt 0) {
            Write-Host "   ❌ Errors: $($operation.Errors.Count)" -ForegroundColor Red
        }
    }

    # Clean up
    $script:ActiveOperations.Remove($OperationId)
}

function Update-ProgressDisplay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId
    )

    $operation = $script:ActiveOperations[$OperationId]
    if (-not $operation) { return }

    $percentage = if ($operation.TotalSteps -gt 0) {
        [math]::Round(($operation.CurrentStep / $operation.TotalSteps) * 100)
    } else { 0 }

    switch ($operation.Style) {
        'Bar' {
            Show-ProgressBar -Operation $operation -Percentage $percentage
        }
        'Spinner' {
            Show-ProgressSpinner -Operation $operation -Percentage $percentage
        }
        'Percentage' {
            Show-ProgressPercentage -Operation $operation -Percentage $percentage
        }
        'Detailed' {
            Show-ProgressDetailed -Operation $operation -Percentage $percentage
        }
    }
}

function Show-ProgressBar {
    param($Operation, $Percentage)

    $barWidth = 30
    $filledWidth = [math]::Floor($barWidth * ($Percentage / 100))
    $emptyWidth = $barWidth - $filledWidth

    $bar = "[" + ("█" * $filledWidth) + ("░" * $emptyWidth) + "]"

    $status = "$bar $Percentage% - $($Operation.Name)"

    if ($Operation.CurrentStepName) {
        $status += " - $($Operation.CurrentStepName)"
    }

    if ($Operation.ShowTime) {
        $elapsed = (Get-Date) - $Operation.StartTime
        $status += " - $([math]::Round($elapsed.TotalSeconds, 1))s"
    }

    if ($Operation.ShowETA -and $Operation.CurrentStep -gt 0) {
        $avgTimePerStep = ((Get-Date) - $Operation.StartTime).TotalSeconds / $Operation.CurrentStep
        $remainingSteps = $Operation.TotalSteps - $Operation.CurrentStep
        $eta = [math]::Round($avgTimePerStep * $remainingSteps, 1)
        $status += " - ETA: ${eta}s"
    }

    # Use carriage return to update the same line
    Write-Host "`r$status" -NoNewline -ForegroundColor Cyan

    if ($Percentage -eq 100) {
        Write-Host "" # New line when complete
    }
}

function Show-ProgressSpinner {
    param($Operation, $Percentage)

    $spinners = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $spinnerIndex = $Operation.CurrentStep % $spinners.Count

    $status = "$($spinners[$spinnerIndex]) $($Operation.Name) - $Percentage%"

    if ($Operation.CurrentStepName) {
        $status += " - $($Operation.CurrentStepName)"
    }

    Write-Host "`r$status" -NoNewline -ForegroundColor Yellow

    if ($Percentage -eq 100) {
        Write-Host "`r✅ $($Operation.Name) - Complete!" -ForegroundColor Green
    }
}

function Show-ProgressPercentage {
    param($Operation, $Percentage)

    $status = "$Percentage% - $($Operation.Name)"

    if ($Operation.CurrentStepName) {
        $status += ": $($Operation.CurrentStepName)"
    }

    Write-Host $status -ForegroundColor Cyan
}

function Show-ProgressDetailed {
    param($Operation, $Percentage)

    # Clear previous lines (approximate)
    $linesToClear = 5
    for ($i = 0; $i -lt $linesToClear; $i++) {
        Write-Host "`r$(' ' * 80)" -NoNewline
        if ($i -lt $linesToClear - 1) {
            Write-Host ""
        }
    }

    # Move cursor back up (with error handling for non-interactive environments)
    try {
        if ([Console]::IsInputRedirected -eq $false -and [Console]::IsOutputRedirected -eq $false) {
            [Console]::SetCursorPosition(0, [Math]::Max(0, [Console]::CursorTop - $linesToClear + 1))
        }
    } catch {
        # Silently ignore cursor positioning errors in non-interactive terminals
        Write-Verbose "Could not set cursor position: $_"
    }

    # Display detailed progress
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor DarkGray
    Write-Host "║ $($Operation.Name.PadRight(54)) ║" -ForegroundColor White
    Write-Host "╠════════════════════════════════════════════════════════╣" -ForegroundColor DarkGray

    # Progress bar
    $barWidth = 50
    $filledWidth = [math]::Floor($barWidth * ($Percentage / 100))
    $emptyWidth = $barWidth - $filledWidth
    $bar = ("█" * $filledWidth) + ("░" * $emptyWidth)
    Write-Host "║ [$bar] $($Percentage.ToString().PadLeft(3))% ║" -ForegroundColor Cyan

    # Current step
    $stepText = if ($Operation.CurrentStepName) {
        "Step $($Operation.CurrentStep)/$($Operation.TotalSteps): $($Operation.CurrentStepName)"
    } else {
        "Step $($Operation.CurrentStep) of $($Operation.TotalSteps)"
    }
    Write-Host "║ $($stepText.PadRight(54)) ║" -ForegroundColor Gray

    # Time info
    if ($Operation.ShowTime -or $Operation.ShowETA) {
        $elapsed = (Get-Date) - $Operation.StartTime
        $timeText = "Elapsed: $([math]::Round($elapsed.TotalSeconds, 1))s"

        if ($Operation.ShowETA -and $Operation.CurrentStep -gt 0) {
            $avgTimePerStep = $elapsed.TotalSeconds / $Operation.CurrentStep
            $remainingSteps = $Operation.TotalSteps - $Operation.CurrentStep
            $eta = [math]::Round($avgTimePerStep * $remainingSteps, 1)
            $timeText += " | ETA: ${eta}s"
        }

        Write-Host "║ $($timeText.PadRight(54)) ║" -ForegroundColor DarkYellow
    }

    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor DarkGray
}

function Add-ProgressWarning {
    <#
    .SYNOPSIS
        Add a warning to the current operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId,

        [Parameter(Mandatory)]
        [string]$Warning
    )

    if ($script:ActiveOperations.ContainsKey($OperationId)) {
        $script:ActiveOperations[$OperationId].Warnings += $Warning
    }
}

function Add-ProgressError {
    <#
    .SYNOPSIS
        Add an error to the current operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationId,

        [Parameter(Mandatory)]
        [string]$Error
    )

    if ($script:ActiveOperations.ContainsKey($OperationId)) {
        $script:ActiveOperations[$OperationId].Errors += $Error
    }
}

function Write-ProgressLog {
    <#
    .SYNOPSIS
        Write a log message without disrupting progress display
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    # Clear current line
    Write-Host "`r$(' ' * 80)`r" -NoNewline

    # Write the log message
    switch ($Level) {
        'Info' { Write-Host "ℹ️ $Message" -ForegroundColor White }
        'Warning' { Write-Host "⚠️ $Message" -ForegroundColor Yellow }
        'Error' { Write-Host "❌ $Message" -ForegroundColor Red }
        'Success' { Write-Host "✅ $Message" -ForegroundColor Green }
    }

    # Redraw active progress bars
    foreach ($operationId in $script:ActiveOperations.Keys) {
        Update-ProgressDisplay -OperationId $operationId
    }
}

function Get-ActiveOperations {
    <#
    .SYNOPSIS
        Get list of currently active operations
    #>
    [CmdletBinding()]
    param()

    return $script:ActiveOperations.Values | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Progress = if ($_.TotalSteps -gt 0) {
                [math]::Round(($_.CurrentStep / $_.TotalSteps) * 100)
            } else { 0 }
            CurrentStep = $_.CurrentStep
            TotalSteps = $_.TotalSteps
            Duration = ((Get-Date) - $_.StartTime).TotalSeconds
            Warnings = $_.Warnings.Count
            Errors = $_.Errors.Count
        }
    }
}

# Multi-operation progress tracking
function Start-MultiProgress {
    <#
    .SYNOPSIS
        Start tracking multiple parallel operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [hashtable[]]$Operations
    )

    Write-Host ""
    Write-Host "🚀 $Title" -ForegroundColor Cyan
    Write-Host ""

    $operationIds = @{}

    foreach ($op in $Operations) {
        $id = Start-ProgressOperation -OperationName $op.Name -TotalSteps $op.Steps -Style 'Bar'
        $operationIds[$op.Name] = $id
    }

    return $operationIds
}

# Simple progress display function for compatibility
function Show-SimpleProgress {
    <#
    .SYNOPSIS
        Simple progress display for startup and basic operations
    .DESCRIPTION
        Provides a lightweight progress display function for use during
        module loading and basic operations. Compatible with existing
        aither-core startup sequence.
    .PARAMETER Message
        Message to display with the progress indicator
    .PARAMETER Type
        Type of progress: Start, Update, or Complete
    .EXAMPLE
        Show-SimpleProgress -Message "Loading modules..." -Type Start
    .EXAMPLE
        Show-SimpleProgress -Message "Modules loaded" -Type Complete
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Start', 'Update', 'Complete')]
        [string]$Type = 'Update'
    )

    $prefix = switch ($Type) {
        'Start' { '🚀' }
        'Update' { '⚡' }
        'Complete' { '✅' }
    }

    $color = switch ($Type) {
        'Start' { 'Cyan' }
        'Update' { 'Yellow' }
        'Complete' { 'Green' }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

# Export functions
Export-ModuleMember -Function @(
    'Start-ProgressOperation',
    'Update-ProgressOperation',
    'Complete-ProgressOperation',
    'Add-ProgressWarning',
    'Add-ProgressError',
    'Write-ProgressLog',
    'Get-ActiveOperations',
    'Start-MultiProgress',
    'Show-SimpleProgress'
)
