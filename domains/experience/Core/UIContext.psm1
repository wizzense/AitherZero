#Requires -Version 7.0
<#
.SYNOPSIS
    UI Context management for AitherZero
.DESCRIPTION
    Manages application context, terminal, keyboard, and component registry
#>

# Global context storage
$script:GlobalContext = $null

function New-UIContext {
    <#
    .SYNOPSIS
        Create a new UI context
    .PARAMETER Terminal
        Terminal interface (real or mock)
    .PARAMETER Keyboard
        Keyboard interface (real or mock)
    .PARAMETER Width
        Terminal width
    .PARAMETER Height
        Terminal height
    #>
    [CmdletBinding()]
    param(
        $Terminal,
        $Keyboard,
        [int]$Width = 80,
        [int]$Height = 24
    )
    
    # Create terminal if not provided
    if (-not $Terminal) {
        $Terminal = New-UITerminal -Width $Width -Height $Height
    }
    
    # Create keyboard if not provided
    if (-not $Keyboard) {
        $Keyboard = New-UIKeyboard
    }
    
    $context = [PSCustomObject]@{
        # Core interfaces
        Terminal = $Terminal
        Keyboard = $Keyboard
        EventBus = New-UIEventBus
        
        # Component management
        RootComponent = $null
        FocusedComponent = $null
        Components = @{}
        ComponentStack = [System.Collections.Stack]::new()
        
        # Rendering
        RenderQueue = [System.Collections.Queue]::new()
        IsRendering = $false
        FrameCount = 0
        LastRenderTime = [DateTime]::Now
        
        # Application state
        IsRunning = $false
        ExitRequested = $false
        Configuration = @{}
        Theme = @{}
        
        # Performance
        PerformanceMetrics = @{
            RenderTime = 0
            InputTime = 0
            EventTime = 0
        }
        
        # Debug
        DebugMode = $false
        Events = [System.Collections.ArrayList]::new()
    }
    
    # Add methods
    Add-Member -InputObject $context -MemberType ScriptMethod -Name "RegisterComponent" -Value {
        param($component)
        $this.Components[$component.Id] = $component
    }
    
    Add-Member -InputObject $context -MemberType ScriptMethod -Name "UnregisterComponent" -Value {
        param($componentId)
        $this.Components.Remove($componentId)
    }
    
    Add-Member -InputObject $context -MemberType ScriptMethod -Name "GetComponent" -Value {
        param($componentId)
        return $this.Components[$componentId]
    }
    
    return $context
}

function Get-UIContext {
    <#
    .SYNOPSIS
        Get the global UI context
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:GlobalContext) {
        $script:GlobalContext = New-UIContext
    }
    
    return $script:GlobalContext
}

function Set-UIContext {
    <#
    .SYNOPSIS
        Set the global UI context
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context
    )
    
    $script:GlobalContext = $Context
}

function Initialize-UIContext {
    <#
    .SYNOPSIS
        Initialize the UI context for application use
    #>
    [CmdletBinding()]
    param(
        $Context = (Get-UIContext),
        [hashtable]$Configuration = @{},
        [hashtable]$Theme = @{}
    )
    
    $Context.Configuration = $Configuration
    $Context.Theme = $Theme
    $Context.IsRunning = $true
    $Context.ExitRequested = $false
    
    # Initialize terminal
    if ($Context.Terminal.Initialize) {
        $Context.Terminal.Initialize()
    }
    
    # Initialize keyboard
    if ($Context.Keyboard.Initialize) {
        $Context.Keyboard.Initialize()
    }
    
    # Raise initialization event
    Invoke-UIEvent -Context $Context -EventName "ContextInitialized"
    
    return $Context
}

function Start-UIContext {
    <#
    .SYNOPSIS
        Start the UI context main loop
    #>
    [CmdletBinding()]
    param(
        $Context = (Get-UIContext),
        [scriptblock]$OnUpdate
    )
    
    $Context.IsRunning = $true
    
    try {
        while ($Context.IsRunning -and -not $Context.ExitRequested) {
            # Process input
            $inputValueStart = [DateTime]::Now
            Process-UIInput -Context $Context
            $Context.PerformanceMetrics.InputTime = ([DateTime]::Now - $inputValueStart).TotalMilliseconds
            
            # Process events
            $EventNameStart = [DateTime]::Now
            Process-UIEvents -Context $Context
            $Context.PerformanceMetrics.EventTime = ([DateTime]::Now - $EventNameStart).TotalMilliseconds
            
            # Custom update logic
            if ($OnUpdate) {
                & $OnUpdate $Context
            }
            
            # Render
            $renderStart = [DateTime]::Now
            Invoke-UIRender -Context $Context
            $Context.PerformanceMetrics.RenderTime = ([DateTime]::Now - $renderStart).TotalMilliseconds
            
            # Frame tracking
            $Context.FrameCount++
            $Context.LastRenderTime = [DateTime]::Now
            
            # Small delay to prevent CPU spinning
            Start-Sleep -Milliseconds 16  # ~60 FPS
        }
    }
    finally {
        Stop-UIContext -Context $Context
    }
}

function Stop-UIContext {
    <#
    .SYNOPSIS
        Stop the UI context
    #>
    [CmdletBinding()]
    param(
        $Context = (Get-UIContext)
    )
    
    $Context.IsRunning = $false
    
    # Cleanup terminal
    if ($Context.Terminal.Cleanup) {
        $Context.Terminal.Cleanup()
    }
    
    # Cleanup keyboard
    if ($Context.Keyboard.Cleanup) {
        $Context.Keyboard.Cleanup()
    }
    
    # Raise shutdown event
    Invoke-UIEvent -Context $Context -EventName "ContextShutdown"
}

function Process-UIInput {
    <#
    .SYNOPSIS
        Process keyboard input
    #>
    [CmdletBinding()]
    param(
        $Context = (Get-UIContext)
    )
    
    if ($Context.Keyboard.HasInput()) {
        $inputValue = $Context.Keyboard.ReadInput()
        
        # Global hotkeys
        if ($inputValue.Key -eq "Escape" -and $inputValue.Modifiers.Ctrl) {
            $Context.ExitRequested = $true
            return
        }
        
        # Send to focused component
        if ($Context.FocusedComponent) {
            Send-UIInput -Component $Context.FocusedComponent -Input $inputValue -Context $Context
        }
        
        # Raise input event
        Invoke-UIEvent -Context $Context -EventName "InputProcessed" -Data @{ Input = $inputValue }
    }
}

function Process-UIEvents {
    <#
    .SYNOPSIS
        Process queued events
    #>
    [CmdletBinding()]
    param(
        $Context = (Get-UIContext)
    )
    
    # Process event bus
    if ($Context.EventBus.Process) {
        $Context.EventBus.Process()
    }
}

function Invoke-UIRender {
    <#
    .SYNOPSIS
        Render the UI
    #>
    [CmdletBinding()]
    param(
        $Context = (Get-UIContext)
    )
    
    if ($Context.IsRendering) {
        return  # Prevent recursive rendering
    }
    
    try {
        $Context.IsRendering = $true
        
        # Clear screen if needed
        if ($Context.Terminal.Clear) {
            $Context.Terminal.Clear()
        }
        
        # Render root component and children
        if ($Context.RootComponent) {
            Render-UIComponent -Component $Context.RootComponent -Context $Context
        }
        
        # Process render queue
        while ($Context.RenderQueue.Count -gt 0) {
            $component = $Context.RenderQueue.Dequeue()
            if ($component.IsDirty) {
                Render-UIComponent -Component $component -Context $Context
            }
        }
        
        # Flush terminal buffer
        if ($Context.Terminal.Flush) {
            $Context.Terminal.Flush()
        }
    }
    finally {
        $Context.IsRendering = $false
    }
}

function Render-UIComponent {
    <#
    .SYNOPSIS
        Render a component and its children
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        $Context
    )
    
    if (-not $Component.IsVisible) {
        return
    }
    
    # Call component render
    if ($Component.Render) {
        $Component.Render()
    }
    
    # Render children
    foreach ($child in $Component.Children) {
        Render-UIComponent -Component $child -Context $Context
    }
    
    $Component.IsDirty = $false
}

function Set-UIFocus {
    <#
    .SYNOPSIS
        Set focus to a component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        $Context = (Get-UIContext)
    )
    
    # Remove focus from current
    if ($Context.FocusedComponent -and $Context.FocusedComponent -ne $Component) {
        $Context.FocusedComponent.HasFocus = $false
        if ($Context.FocusedComponent.OnBlur) {
            & $Context.FocusedComponent.OnBlur $Context.FocusedComponent
        }
    }
    
    # Set new focus
    $Context.FocusedComponent = $Component
    $Component.HasFocus = $true
    
    if ($Component.OnFocus) {
        & $Component.OnFocus $Component
    }
    
    # Raise focus event
    Invoke-UIEvent -Context $Context -EventName "FocusChanged" -Data @{ Component = $Component }
}

function Send-UIInput {
    <#
    .SYNOPSIS
        Send input to a component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        $inputValue,
        
        $Context = (Get-UIContext)
    )
    
    # Let component handle input
    $handled = $false
    if ($Component.HandleInput) {
        $handled = $Component.HandleInput($inputValue)
    } elseif ($Component.OnKeyPress) {
        $handled = & $Component.OnKeyPress $inputValue
    }
    
    # Bubble up if not handled
    if (-not $handled -and $Component.Parent) {
        Send-UIInput -Component $Component.Parent -Input $inputValue -Context $Context
    }
}

function Queue-UIRender {
    <#
    .SYNOPSIS
        Queue a component for rendering
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        $Context = (Get-UIContext)
    )
    
    $Component.IsDirty = $true
    
    if (-not $Context.RenderQueue.Contains($Component)) {
        $Context.RenderQueue.Enqueue($Component)
    }
}

# Terminal abstraction
function New-UITerminal {
    <#
    .SYNOPSIS
        Create a terminal interface
    #>
    [CmdletBinding()]
    param(
        [int]$Width = 80,
        [int]$Height = 24
    )
    
    return [PSCustomObject]@{
        Width = $Width
        Height = $Height
        CursorX = 0
        CursorY = 0
        Buffer = @()
        
        Initialize = {
            Clear-Host
        }
        
        Clear = {
            Clear-Host
        }
        
        SetCursor = {
            param($x, $y)
            [Console]::SetCursorPosition($x, $y)
        }
        
        Write = {
            param($text, $color)
            if ($color) {
                Write-Host $text -ForegroundColor $color -NoNewline
            } else {
                Write-Host $text -NoNewline
            }
        }
        
        Flush = {
            # Terminal operations are immediate in PowerShell
        }
        
        Cleanup = {
            Clear-Host
        }
    }
}

# Keyboard abstraction
function New-UIKeyboard {
    <#
    .SYNOPSIS
        Create a keyboard interface
    #>
    [CmdletBinding()]
    param()
    
    return [PSCustomObject]@{
        Initialize = {
            # Setup keyboard input
        }
        
        HasInput = {
            return [Console]::KeyAvailable
        }
        
        ReadInput = {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                return @{
                    Key = $key.Key.ToString()
                    Char = $key.KeyChar
                    Modifiers = @{
                        Ctrl = ($key.Modifiers -band [ConsoleModifiers]::Control) -ne 0
                        Alt = ($key.Modifiers -band [ConsoleModifiers]::Alt) -ne 0
                        Shift = ($key.Modifiers -band [ConsoleModifiers]::Shift) -ne 0
                    }
                }
            }
            return $null
        }
        
        Cleanup = {
            # Cleanup keyboard input
        }
    }
}

# Event Bus
function New-UIEventBus {
    <#
    .SYNOPSIS
        Create an event bus
    #>
    [CmdletBinding()]
    param()
    
    return [PSCustomObject]@{
        Handlers = @{}
        Queue = [System.Collections.Queue]::new()
        
        Subscribe = {
            param($EventNameName, $handler)
            if (-not $this.Handlers.ContainsKey($EventNameName)) {
                $this.Handlers[$EventNameName] = [System.Collections.ArrayList]::new()
            }
            [void]$this.Handlers[$EventNameName].Add($handler)
        }
        
        Unsubscribe = {
            param($EventNameName, $handler)
            if ($this.Handlers.ContainsKey($EventNameName)) {
                $this.Handlers[$EventNameName].Remove($handler)
            }
        }
        
        Emit = {
            param($EventNameName, $data)
            $this.Queue.Enqueue(@{
                Name = $EventNameName
                Data = $data
                Timestamp = [DateTime]::Now
            })
        }
        
        Process = {
            while ($this.Queue.Count -gt 0) {
                $EventName = $this.Queue.Dequeue()
                if ($this.Handlers.ContainsKey($EventName.Name)) {
                    foreach ($handler in $this.Handlers[$EventName.Name]) {
                        & $handler $EventName.Data
                    }
                }
            }
        }
    }
}

function Invoke-UIEvent {
    <#
    .SYNOPSIS
        Raise an event on the context
    #>
    [CmdletBinding()]
    param(
        $Context = (Get-UIContext),
        [string]$EventNameName,
        [hashtable]$Data = @{}
    )
    
    if ($Context.EventBus -and $Context.EventBus.Emit) {
        $Context.EventBus.Emit($EventNameName, $Data)
    }
    
    # Track in debug events
    if ($Context.DebugMode) {
        [void]$Context.Events.Add("$EventNameName")
    }
}

# Export functions
Export-ModuleMember -Function @(
    'New-UIContext'
    'Get-UIContext'
    'Set-UIContext'
    'Initialize-UIContext'
    'Start-UIContext'
    'Stop-UIContext'
    'Process-UIInput'
    'Process-UIEvents'
    'Invoke-UIRender'
    'Render-UIComponent'
    'Set-UIFocus'
    'Send-UIInput'
    'Queue-UIRender'
    'New-UITerminal'
    'New-UIKeyboard'
    'New-UIEventBus'
    'Invoke-UIEvent'
)