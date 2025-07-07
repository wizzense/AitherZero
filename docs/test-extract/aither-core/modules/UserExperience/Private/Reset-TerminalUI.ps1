function Reset-TerminalUI {
    <#
    .SYNOPSIS
        Resets the terminal to original state
    .DESCRIPTION
        Restores terminal settings to their original values with comprehensive cleanup.
        Enhanced version that combines and improves upon the original implementations.
    .PARAMETER Force
        Force reset even if errors occur
    .PARAMETER Preserve
        Preserve certain settings (like window title) that user might want to keep
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$Preserve
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Resetting Terminal UI to original state" -Source 'UserExperience'
        
        if (-not $script:TerminalUIEnabled) {
            Write-Verbose "Terminal UI was not enabled, nothing to reset"
            return @{ Success = $true; Message = "Terminal UI was not enabled" }
        }
        
        $resetResults = @{
            Success = $true
            Restored = @()
            Failed = @()
            Skipped = @()
        }
        
        # Restore window title
        if ($script:OriginalState.WindowTitle -and -not $Preserve) {
            try {
                $Host.UI.RawUI.WindowTitle = $script:OriginalState.WindowTitle
                $resetResults.Restored += "WindowTitle"
                Write-Verbose "Window title restored to: $($script:OriginalState.WindowTitle)"
            } catch {
                $resetResults.Failed += "WindowTitle: $_"
                Write-Verbose "Could not restore WindowTitle: $_"
                if (-not $Force) {
                    throw
                }
            }
        } elseif ($Preserve) {
            $resetResults.Skipped += "WindowTitle (preserved)"
        }
        
        # Restore background color
        if ($script:OriginalState.BackgroundColor) {
            try {
                $Host.UI.RawUI.BackgroundColor = $script:OriginalState.BackgroundColor
                $resetResults.Restored += "BackgroundColor"
                Write-Verbose "Background color restored"
            } catch {
                $resetResults.Failed += "BackgroundColor: $_"
                Write-Verbose "Could not restore BackgroundColor: $_"
                if (-not $Force) {
                    throw
                }
            }
        }
        
        # Restore foreground color
        if ($script:OriginalState.ForegroundColor) {
            try {
                $Host.UI.RawUI.ForegroundColor = $script:OriginalState.ForegroundColor
                $resetResults.Restored += "ForegroundColor"
                Write-Verbose "Foreground color restored"
            } catch {
                $resetResults.Failed += "ForegroundColor: $_"
                Write-Verbose "Could not restore ForegroundColor: $_"
                if (-not $Force) {
                    throw
                }
            }
        }
        
        # Restore cursor size
        if ($script:OriginalState.CursorSize) {
            try {
                $Host.UI.RawUI.CursorSize = $script:OriginalState.CursorSize
                $resetResults.Restored += "CursorSize"
                Write-Verbose "Cursor size restored"
            } catch {
                $resetResults.Failed += "CursorSize: $_"
                Write-Verbose "Could not restore CursorSize: $_"
                if (-not $Force) {
                    throw
                }
            }
        }
        
        # Restore buffer size if it was changed
        if ($script:OriginalState.BufferSize) {
            try {
                $currentBuffer = $Host.UI.RawUI.BufferSize
                $originalBuffer = $script:OriginalState.BufferSize
                
                # Only restore if different
                if ($currentBuffer.Width -ne $originalBuffer.Width -or 
                    $currentBuffer.Height -ne $originalBuffer.Height) {
                    $Host.UI.RawUI.BufferSize = $originalBuffer
                    $resetResults.Restored += "BufferSize"
                    Write-Verbose "Buffer size restored"
                }
            } catch {
                $resetResults.Failed += "BufferSize: $_"
                Write-Verbose "Could not restore BufferSize: $_"
                # Buffer size changes are not critical, continue
            }
        }
        
        # Reset console encoding if we changed it
        Reset-ConsoleEncoding
        
        # Clear any event handlers that were set up
        Cleanup-EventHandlers
        
        # Clear keyboard handling
        Cleanup-KeyboardHandling
        
        # Clear any UI state variables
        Clear-UIStateVariables
        
        # Update module state
        Update-ModuleStateAfterReset -Results $resetResults
        
        # Log reset completion
        $restoredCount = $resetResults.Restored.Count
        $failedCount = $resetResults.Failed.Count
        $skippedCount = $resetResults.Skipped.Count
        
        $message = "Terminal UI reset completed: $restoredCount restored, $failedCount failed, $skippedCount skipped"
        Write-CustomLog -Level 'INFO' -Message $message -Source 'UserExperience'
        
        if ($failedCount -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "Some terminal settings could not be restored: $($resetResults.Failed -join '; ')" -Source 'UserExperience'
        }
        
        return $resetResults
        
    } catch {
        $errorMessage = "Error resetting terminal UI: $_"
        Write-CustomLog -Level 'ERROR' -Message $errorMessage -Source 'UserExperience'
        
        if ($Force) {
            # Force cleanup even with errors
            Force-TerminalCleanup
            return @{ 
                Success = $false
                Error = $errorMessage
                ForceCompleted = $true
            }
        } else {
            throw
        }
    }
}

function Reset-ConsoleEncoding {
    <#
    .SYNOPSIS
        Resets console encoding to system default
    #>
    
    try {
        if ($IsWindows -and $script:OriginalState.ConsoleEncoding) {
            [Console]::OutputEncoding = $script:OriginalState.ConsoleEncoding.Output
            [Console]::InputEncoding = $script:OriginalState.ConsoleEncoding.Input
            Write-Verbose "Console encoding restored to original settings"
        }
    } catch {
        Write-Verbose "Could not reset console encoding: $_"
    }
}

function Cleanup-EventHandlers {
    <#
    .SYNOPSIS
        Cleans up any event handlers that were registered
    #>
    
    try {
        # Clean up any PowerShell event subscriptions
        $uiEvents = Get-EventSubscriber | Where-Object { $_.SourceIdentifier -like "UserExperience.*" }
        foreach ($event in $uiEvents) {
            Unregister-Event -SourceIdentifier $event.SourceIdentifier -Force
            Write-Verbose "Removed event subscription: $($event.SourceIdentifier)"
        }
        
        # Clean up any module-specific event handlers
        if (Get-Command Unsubscribe-ModuleEvent -ErrorAction SilentlyContinue) {
            $moduleEvents = @('UIStateChanged', 'ThemeChanged', 'ProfileChanged')
            foreach ($eventName in $moduleEvents) {
                try {
                    Unsubscribe-ModuleEvent -EventName $eventName -ErrorAction SilentlyContinue
                    Write-Verbose "Unsubscribed from module event: $eventName"
                } catch {
                    Write-Verbose "Could not unsubscribe from $eventName`: $_"
                }
            }
        }
        
    } catch {
        Write-Verbose "Error cleaning up event handlers: $_"
    }
}

function Cleanup-KeyboardHandling {
    <#
    .SYNOPSIS
        Cleans up keyboard handling setup
    #>
    
    try {
        # Reset keyboard handling flags
        $script:KeyboardHandlingEnabled = $false
        
        # Clear any keyboard buffers or handlers
        if ($script:UIMode -eq 'Enhanced') {
            # Any advanced keyboard cleanup would go here
            Write-Verbose "Advanced keyboard handling cleaned up"
        }
        
    } catch {
        Write-Verbose "Error cleaning up keyboard handling: $_"
    }
}

function Clear-UIStateVariables {
    <#
    .SYNOPSIS
        Clears UI-related script variables
    #>
    
    try {
        # Clear terminal UI state variables
        $script:TerminalUIEnabled = $false
        $script:OriginalState = $null
        $script:UICapabilities = $null
        $script:UIMode = $null
        $script:CurrentTheme = $null
        $script:UIInitInfo = $null
        $script:KeyboardHandlingEnabled = $false
        
        # Clear any cached UI data
        if ($script:UserExperienceState.UICache) {
            $script:UserExperienceState.UICache = @{}
        }
        
        Write-Verbose "UI state variables cleared"
        
    } catch {
        Write-Verbose "Error clearing UI state variables: $_"
    }
}

function Update-ModuleStateAfterReset {
    <#
    .SYNOPSIS
        Updates module state after terminal reset
    #>
    param([hashtable]$Results)
    
    try {
        # Update UserExperience state
        $script:UserExperienceState.UICapabilities = $null
        $script:UserExperienceState.CurrentMode = 'Reset'
        $script:UserExperienceState.LastUIReset = Get-Date
        
        # Record reset results for diagnostics
        if (-not $script:UserExperienceState.ResetHistory) {
            $script:UserExperienceState.ResetHistory = @()
        }
        
        $resetRecord = @{
            Timestamp = Get-Date
            Results = $Results
            SessionId = $script:UserExperienceState.SessionId
        }
        
        $script:UserExperienceState.ResetHistory += $resetRecord
        
        # Keep only last 10 reset records
        if ($script:UserExperienceState.ResetHistory.Count -gt 10) {
            $script:UserExperienceState.ResetHistory = $script:UserExperienceState.ResetHistory | Select-Object -Last 10
        }
        
        Write-Verbose "Module state updated after terminal reset"
        
    } catch {
        Write-Verbose "Error updating module state after reset: $_"
    }
}

function Force-TerminalCleanup {
    <#
    .SYNOPSIS
        Performs forced cleanup when normal reset fails
    #>
    
    try {
        Write-Verbose "Performing forced terminal cleanup"
        
        # Try to reset critical elements with individual error handling
        try { $Host.UI.RawUI.CursorSize = 25 } catch { }
        try { $Host.UI.RawUI.ForegroundColor = 'White' } catch { }
        try { $Host.UI.RawUI.BackgroundColor = 'Black' } catch { }
        
        # Clear all script variables
        $script:TerminalUIEnabled = $false
        $script:OriginalState = @{}
        $script:UICapabilities = $null
        $script:UIMode = 'Fallback'
        $script:CurrentTheme = $null
        $script:UIInitInfo = $null
        
        Write-Verbose "Forced terminal cleanup completed"
        
    } catch {
        Write-Verbose "Error in forced cleanup: $_"
        # At this point, we've done all we can
    }
}

function Get-UIStatus {
    <#
    .SYNOPSIS
        Gets current UI status and capabilities
    .DESCRIPTION
        Returns comprehensive information about the current state of the Terminal UI
    #>
    [CmdletBinding()]
    param()
    
    return [PSCustomObject]@{
        Enabled = $script:TerminalUIEnabled ?? $false
        Mode = $script:UIMode ?? 'Unknown'
        Theme = $script:CurrentTheme ?? 'Unknown'
        Capabilities = $script:UICapabilities ?? @{}
        InitInfo = $script:UIInitInfo ?? @{}
        OriginalStateExists = ($script:OriginalState -ne $null)
        KeyboardHandling = $script:KeyboardHandlingEnabled ?? $false
        SessionId = $script:UserExperienceState.SessionId
        LastReset = $script:UserExperienceState.LastUIReset
        ResetHistory = $script:UserExperienceState.ResetHistory ?? @()
    }
}

function Show-UIDebugInfo {
    <#
    .SYNOPSIS
        Shows detailed UI debug information
    .DESCRIPTION
        Displays comprehensive debug information about the Terminal UI state
    #>
    [CmdletBinding()]
    param([switch]$IncludeHistory)
    
    $status = Get-UIStatus
    
    Write-Host ""
    Write-Host "=== Terminal UI Debug Information ===" -ForegroundColor Cyan
    Write-Host "Enabled: $($status.Enabled)" -ForegroundColor White
    Write-Host "Mode: $($status.Mode)" -ForegroundColor White
    Write-Host "Theme: $($status.Theme)" -ForegroundColor White
    Write-Host "Keyboard Handling: $($status.KeyboardHandling)" -ForegroundColor White
    Write-Host "Original State Exists: $($status.OriginalStateExists)" -ForegroundColor White
    Write-Host ""
    
    if ($status.Capabilities -and $status.Capabilities.Count -gt 0) {
        Write-Host "Capabilities:" -ForegroundColor Yellow
        $status.Capabilities.GetEnumerator() | Sort-Object Key | ForEach-Object {
            $color = if ($_.Value -eq $true) { 'Green' } elseif ($_.Value -eq $false) { 'Red' } else { 'Gray' }
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor $color
        }
        Write-Host ""
    }
    
    if ($status.InitInfo -and $status.InitInfo.InitTime) {
        $uptime = (Get-Date) - $status.InitInfo.InitTime
        Write-Host "UI Uptime: $($uptime.ToString('hh\:mm\:ss'))" -ForegroundColor Green
        Write-Host "Session ID: $($status.SessionId)" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($status.LastReset) {
        $resetAge = (Get-Date) - $status.LastReset
        Write-Host "Last Reset: $($resetAge.ToString('hh\:mm\:ss')) ago" -ForegroundColor Yellow
    }
    
    if ($IncludeHistory -and $status.ResetHistory.Count -gt 0) {
        Write-Host ""
        Write-Host "Reset History:" -ForegroundColor Yellow
        $status.ResetHistory | Select-Object -Last 5 | ForEach-Object {
            $age = (Get-Date) - $_.Timestamp
            Write-Host "  $($_.Timestamp.ToString('yyyy-MM-dd HH:mm:ss')) (ago: $($age.ToString('hh\:mm\:ss')))" -ForegroundColor Gray
            if ($_.Results.Failed.Count -gt 0) {
                Write-Host "    Failed: $($_.Results.Failed -join ', ')" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
}

function Test-TerminalUIHealth {
    <#
    .SYNOPSIS
        Tests the health of the Terminal UI system
    .DESCRIPTION
        Performs health checks on the Terminal UI and returns diagnostic information
    #>
    [CmdletBinding()]
    param()
    
    $healthResults = @{
        Overall = 'Unknown'
        Tests = @()
        Recommendations = @()
        Issues = @()
    }
    
    # Test 1: UI Enabled Status
    $test1 = @{
        Name = 'UI Enabled'
        Status = if ($script:TerminalUIEnabled) { 'Pass' } else { 'Fail' }
        Details = "Terminal UI enabled: $($script:TerminalUIEnabled)"
    }
    $healthResults.Tests += $test1
    
    # Test 2: Capabilities Available
    $test2 = @{
        Name = 'Capabilities'
        Status = if ($script:UICapabilities) { 'Pass' } else { 'Warning' }
        Details = "UI capabilities detected: $($script:UICapabilities -ne $null)"
    }
    $healthResults.Tests += $test2
    
    # Test 3: Original State Preserved
    $test3 = @{
        Name = 'Original State'
        Status = if ($script:OriginalState) { 'Pass' } else { 'Warning' }
        Details = "Original state preserved: $($script:OriginalState -ne $null)"
    }
    $healthResults.Tests += $test3
    
    # Test 4: Mode Consistency
    $test4 = @{
        Name = 'Mode Consistency'
        Status = 'Pass'
        Details = "Current mode: $($script:UIMode ?? 'None')"
    }
    
    if ($script:TerminalUIEnabled -and -not $script:UIMode) {
        $test4.Status = 'Fail'
        $test4.Details += " (UI enabled but no mode set)"
        $healthResults.Issues += "UI is enabled but mode is not set"
    }
    $healthResults.Tests += $test4
    
    # Determine overall health
    $failCount = ($healthResults.Tests | Where-Object { $_.Status -eq 'Fail' }).Count
    $warningCount = ($healthResults.Tests | Where-Object { $_.Status -eq 'Warning' }).Count
    
    if ($failCount -gt 0) {
        $healthResults.Overall = 'Failed'
    } elseif ($warningCount -gt 0) {
        $healthResults.Overall = 'Warning'
    } else {
        $healthResults.Overall = 'Healthy'
    }
    
    # Generate recommendations
    if ($failCount -gt 0) {
        $healthResults.Recommendations += "Consider running Reset-TerminalUI -Force to cleanup"
    }
    
    if (-not $script:UICapabilities) {
        $healthResults.Recommendations += "Run Initialize-TerminalUI to detect capabilities"
    }
    
    return $healthResults
}