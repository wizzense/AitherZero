#Requires -Version 7.0
<#
.SYNOPSIS
    Base component class for AitherZero UI system
.DESCRIPTION
    Provides the foundation for all UI components with lifecycle, state, and rendering
#>

# Component ID generator
$script:ComponentIdCounter = 0

function New-UIComponent {
    <#
    .SYNOPSIS
        Creates a new UI component
    .PARAMETER Name
        Component name
    .PARAMETER Id
        Optional component ID (auto-generated if not provided)
    .PARAMETER Properties
        Custom properties hashtable
    .PARAMETER X
        X position
    .PARAMETER Y
        Y position
    .PARAMETER Width
        Component width
    .PARAMETER Height
        Component height
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Id,
        
        [hashtable]$Properties = @{},
        
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 0,
        [int]$Height = 0
    )
    
    if (-not $Id) {
        $script:ComponentIdCounter++
        $Id = "component_$script:ComponentIdCounter"
    }
    
    $component = [PSCustomObject]@{
        # Identity
        Name = $Name
        Id = $Id
        Type = "UIComponent"
        
        # Hierarchy
        Parent = $null
        Children = [System.Collections.ArrayList]::new()
        
        # Position and Size
        X = $X
        Y = $Y
        Width = $Width
        Height = $Height
        
        # State
        State = "Created"
        ComponentState = @{}
        Context = $null
        
        # Visibility and Interaction
        IsVisible = $true
        IsEnabled = $true
        HasFocus = $false
        
        # Properties and Style
        Properties = $Properties
        Style = @{}
        ComputedStyle = @{}
        
        # Event Handlers
        OnInitialize = $null
        OnMount = $null
        OnUnmount = $null
        OnRender = $null
        OnKeyPress = $null
        OnFocus = $null
        OnBlur = $null
        OnChildEvent = $null
        CustomHandlers = @{}
        
        # Rendering
        IsDirty = $true
        BatchUpdates = $false
        PendingUpdates = @()
    }
    
    # Add methods
    Add-Member -InputObject $component -MemberType ScriptMethod -Name "Render" -Value {
        if ($this.OnRender) {
            & $this.OnRender $this
        }
    }
    
    Add-Member -InputObject $component -MemberType ScriptMethod -Name "HandleKeyPress" -Value {
        param($key)
        if ($this.OnKeyPress) {
            & $this.OnKeyPress $key
        }
    }
    
    return $component
}

function Initialize-UIComponent {
    <#
    .SYNOPSIS
        Initialize a component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        $Context
    )
    
    $Component.State = "Initialized"
    
    if ($Component.OnInitialize) {
        & $Component.OnInitialize $Component
    }
    
    # Record event
    if ($Context.Events) {
        [void]$Context.Events.Add("$($Component.Name):Initialize")
    }
}

function Mount-UIComponent {
    <#
    .SYNOPSIS
        Mount a component to the UI context
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        $Context
    )
    
    $Component.State = "Mounted"
    $Component.Context = $Context
    
    if ($Component.OnMount) {
        & $Component.OnMount $Component
    }
    
    # Mount children
    foreach ($child in $Component.Children) {
        Mount-UIComponent -Component $child -Context $Context
    }
}

function Unmount-UIComponent {
    <#
    .SYNOPSIS
        Unmount a component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component
    )
    
    # Unmount children first
    foreach ($child in $Component.Children) {
        Unmount-UIComponent -Component $child
    }
    
    if ($Component.OnUnmount) {
        & $Component.OnUnmount $Component
    }
    
    $Component.State = "Unmounted"
    $Component.Context = $null
}

function Add-UIComponentChild {
    <#
    .SYNOPSIS
        Add a child component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Parent,
        
        [Parameter(Mandatory)]
        $Child
    )
    
    [void]$Parent.Children.Add($Child)
    $Child.Parent = $Parent
    
    # If parent is mounted, mount child
    if ($Parent.State -eq "Mounted" -and $Parent.Context) {
        Mount-UIComponent -Component $Child -Context $Parent.Context
    }
}

function Remove-UIComponentChild {
    <#
    .SYNOPSIS
        Remove a child component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Parent,
        
        [Parameter(Mandatory)]
        $Child
    )
    
    if ($Parent.Children.Contains($Child)) {
        # Unmount if necessary
        if ($Child.State -eq "Mounted") {
            Unmount-UIComponent -Component $Child
        }
        
        $Parent.Children.Remove($Child)
        $Child.Parent = $null
    }
}

function Find-UIComponent {
    <#
    .SYNOPSIS
        Find a component by ID in the component tree
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Root,
        
        [Parameter(Mandatory)]
        [string]$Id
    )
    
    if ($Root.Id -eq $Id) {
        return $Root
    }
    
    foreach ($child in $Root.Children) {
        $found = Find-UIComponent -Root $child -Id $Id
        if ($found) {
            return $found
        }
    }
    
    return $null
}

function Invoke-UIComponentTraversal {
    <#
    .SYNOPSIS
        Traverse component tree and execute action
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Root,
        
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )
    
    & $Action $Root
    
    foreach ($child in $Root.Children) {
        Invoke-UIComponentTraversal -Root $child -Action $Action
    }
}

function Invoke-UIComponentRender {
    <#
    .SYNOPSIS
        Render a component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [switch]$RenderChildren,
        [switch]$Clear
    )
    
    if (-not $Component.IsVisible) {
        return
    }
    
    # Clear area if requested
    if ($Clear -and $Component.Context -and $Component.Context.Terminal) {
        for ($y = 0; $y -lt $Component.Height; $y++) {
            $clearText = " " * $Component.Width
            Write-MockTerminal -Terminal $Component.Context.Terminal `
                              -Text $clearText `
                              -X $Component.X `
                              -Y ($Component.Y + $y)
        }
    }
    
    # Render component
    if ($Component.OnRender) {
        & $Component.OnRender $Component
    } elseif ($Component.Properties.Text -and $Component.Context -and $Component.Context.Terminal) {
        # Default text rendering
        Write-MockTerminal -Terminal $Component.Context.Terminal `
                          -Text $Component.Properties.Text `
                          -X $Component.X `
                          -Y $Component.Y
    }
    
    # Record render event
    if ($Component.Context -and $Component.Context.Events) {
        [void]$Component.Context.Events.Add("$($Component.Name):Render")
    }
    
    # Render children
    if ($RenderChildren) {
        foreach ($child in $Component.Children) {
            # Calculate absolute position
            $child.X = $Component.X + $child.X
            $child.Y = $Component.Y + $child.Y
            Invoke-UIComponentRender -Component $child -RenderChildren
        }
    }
    
    $Component.IsDirty = $false
}

function Set-UIComponentFocus {
    <#
    .SYNOPSIS
        Set focus on a component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        $Context
    )
    
    $Component.HasFocus = $true
    
    if ($Component.OnFocus) {
        & $Component.OnFocus $Component
    }
    
    [void]$Context.Events.Add("$($Component.Name):Focus")
}

function Remove-UIComponentFocus {
    <#
    .SYNOPSIS
        Remove focus from a component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        $Context
    )
    
    $Component.HasFocus = $false
    
    if ($Component.OnBlur) {
        & $Component.OnBlur $Component
    }
    
    [void]$Context.Events.Add("$($Component.Name):Blur")
}

function Invoke-UIComponentInput {
    <#
    .SYNOPSIS
        Handle input for a component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        $Context
    )
    
    if ($Context.Keyboard.Queue.Count -gt 0) {
        $key = Get-MockKeyPress -Keyboard $Context.Keyboard
        
        if ($Component.OnKeyPress) {
            & $Component.OnKeyPress $key
        }
    }
}

function Invoke-UIComponentEvent {
    <#
    .SYNOPSIS
        Trigger a component event
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        [string]$EventNameName,
        
        [hashtable]$Data = @{},
        
        [switch]$Bubble
    )
    
    # Handle custom event
    if ($Component.CustomHandlers.ContainsKey($EventNameName)) {
        foreach ($handler in $Component.CustomHandlers[$EventNameName]) {
            & $handler $Component $Data
        }
    }
    
    # Bubble to parent
    if ($Bubble -and $Component.Parent) {
        if ($Component.Parent.OnChildEvent) {
            & $Component.Parent.OnChildEvent $Component @{ Event = $EventNameName; Data = $Data }
        }
        
        Invoke-UIComponentEvent -Component $Component.Parent -EventName $EventNameName -Data $Data -Bubble
    }
}

function Register-UIComponentHandler {
    <#
    .SYNOPSIS
        Register a custom event handler
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        [string]$EventNameName,
        
        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )
    
    if (-not $Component.CustomHandlers.ContainsKey($EventNameName)) {
        $Component.CustomHandlers[$EventNameName] = [System.Collections.ArrayList]::new()
    }
    
    [void]$Component.CustomHandlers[$EventNameName].Add($Handler)
}

function Set-UIComponentState {
    <#
    .SYNOPSIS
        Set component state and trigger re-render
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        [hashtable]$State
    )
    
    # Merge state
    foreach ($key in $State.Keys) {
        $Component.ComponentState[$key] = $State[$key]
    }
    
    if ($Component.BatchUpdates) {
        # Queue update
        $Component.PendingUpdates += $State
    } else {
        # Immediate render
        $Component.IsDirty = $true
        if ($Component.OnRender) {
            & $Component.OnRender $Component
        }
    }
}

function Start-UIComponentBatch {
    <#
    .SYNOPSIS
        Start batching state updates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component
    )
    
    $Component.BatchUpdates = $true
    $Component.PendingUpdates = @()
}

function Complete-UIComponentBatch {
    <#
    .SYNOPSIS
        Complete batch and render once
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component
    )
    
    $Component.BatchUpdates = $false
    
    if ($Component.PendingUpdates.Count -gt 0) {
        $Component.IsDirty = $true
        if ($Component.OnRender) {
            & $Component.OnRender $Component
        }
    }
    
    $Component.PendingUpdates = @()
}

function Set-UIComponentStyle {
    <#
    .SYNOPSIS
        Set component style
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component,
        
        [Parameter(Mandatory)]
        [hashtable]$Style
    )
    
    foreach ($key in $Style.Keys) {
        $Component.Style[$key] = $Style[$key]
    }
    
    # Recompute style
    $Component.ComputedStyle = Get-UIComponentComputedStyle -Component $Component
    $Component.IsDirty = $true
}

function Get-UIComponentComputedStyle {
    <#
    .SYNOPSIS
        Get computed style including inherited values
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component
    )
    
    $computed = @{}
    
    # Start with parent's computed style
    if ($Component.Parent -and $Component.Parent.ComputedStyle) {
        foreach ($key in $Component.Parent.ComputedStyle.Keys) {
            $computed[$key] = $Component.Parent.ComputedStyle[$key]
        }
    }
    
    # Override with component's own style
    foreach ($key in $Component.Style.Keys) {
        $computed[$key] = $Component.Style[$key]
    }
    
    return $computed
}

# Export functions
Export-ModuleMember -Function @(
    'New-UIComponent'
    'Initialize-UIComponent'
    'Mount-UIComponent'
    'Unmount-UIComponent'
    'Add-UIComponentChild'
    'Remove-UIComponentChild'
    'Find-UIComponent'
    'Invoke-UIComponentTraversal'
    'Invoke-UIComponentRender'
    'Set-UIComponentFocus'
    'Remove-UIComponentFocus'
    'Invoke-UIComponentInput'
    'Invoke-UIComponentEvent'
    'Register-UIComponentHandler'
    'Set-UIComponentState'
    'Start-UIComponentBatch'
    'Complete-UIComponentBatch'
    'Set-UIComponentStyle'
    'Get-UIComponentComputedStyle'
)