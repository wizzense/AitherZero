#Requires -Version 7.0
<#
.SYNOPSIS
    UI Test Framework for AitherZero
.DESCRIPTION
    Provides mocking and testing utilities for UI components
#>

# Mock Terminal Functions
function New-MockTerminal {
    param(
        [int]$Width = 80,
        [int]$Height = 24
    )

    $buffer = @()
    for ($i = 0; $i -lt $Height; $i++) {
        $buffer += ," " * $Width -join ""
    }

    return [PSCustomObject]@{
        Width = $Width
        Height = $Height
        Buffer = $buffer
        Attributes = @{}
        CursorX = 0
        CursorY = 0
        ForegroundColor = "White"
        BackgroundColor = "Black"
    }
}

function Set-MockCursorPosition {
    param(
        [Parameter(Mandatory)]$Terminal,
        [int]$X,
        [int]$Y
    )

    $Terminal.CursorX = [Math]::Max(0, [Math]::Min($X, $Terminal.Width - 1))
    $Terminal.CursorY = [Math]::Max(0, [Math]::Min($Y, $Terminal.Height - 1))
}

function Write-MockTerminal {
    param(
        [Parameter(Mandatory)]$Terminal,
        [Parameter(Mandatory)][string]$Text,
        [int]$X = -1,
        [int]$Y = -1,
        [string]$ForegroundColor = "White",
        [string]$BackgroundColor = "Black"
    )

    if ($X -ge 0) { $Terminal.CursorX = $X }
    if ($Y -ge 0) { $Terminal.CursorY = $Y }

    $line = $Terminal.Buffer[$Terminal.CursorY]
    $chars = $line.ToCharArray()

    for ($i = 0; $i -lt $Text.Length; $i++) {
        $pos = $Terminal.CursorX + $i
        if ($pos -lt $Terminal.Width) {
            $chars[$pos] = $Text[$i]

            # Store attributes
            $attrKey = "$($Terminal.CursorY),$pos"
            $Terminal.Attributes[$attrKey] = @{
                ForegroundColor = $ForegroundColor
                BackgroundColor = $BackgroundColor
            }
        }
    }

    $Terminal.Buffer[$Terminal.CursorY] = -join $chars
    $Terminal.CursorX += $Text.Length
}

function Get-MockTerminalLine {
    param(
        [Parameter(Mandatory)]$Terminal,
        [Parameter(Mandatory)][int]$Line
    )

    if ($Line -ge 0 -and $Line -lt $Terminal.Height) {
        return $Terminal.Buffer[$Line]
    }
    return ""
}

function Get-MockTerminalAttributes {
    param(
        [Parameter(Mandatory)]$Terminal,
        [int]$X,
        [int]$Y
    )

    $key = "$Y,$X"
    if ($Terminal.Attributes.ContainsKey($key)) {
        return $Terminal.Attributes[$key]
    }
    return @{
        ForegroundColor = "White"
        BackgroundColor = "Black"
    }
}

function Clear-MockTerminal {
    param([Parameter(Mandatory)]$Terminal)

    for ($i = 0; $i -lt $Terminal.Height; $i++) {
        $Terminal.Buffer[$i] = " " * $Terminal.Width
    }
    $Terminal.Attributes = @{}
    $Terminal.CursorX = 0
    $Terminal.CursorY = 0
}

# Mock Keyboard Functions
function New-MockKeyboard {
    return [PSCustomObject]@{
        Queue = [System.Collections.ArrayList]::new()
        IsBlocking = $false
        RecordedInput = [System.Collections.ArrayList]::new()
    }
}

function Add-MockKeyPress {
    param(
        [Parameter(Mandatory)]$Keyboard,
        [Parameter(Mandatory)][string]$Key,
        [switch]$Ctrl,
        [switch]$Alt,
        [switch]$Shift
    )

    $keyPress = @{
        Key = $Key
        Char = if ($Key.Length -eq 1) { $Key } else { $null }
        Modifiers = @{
            Ctrl = $Ctrl.IsPresent
            Alt = $Alt.IsPresent
            Shift = $Shift.IsPresent
        }
        Timestamp = [DateTime]::Now
    }

    [void]$Keyboard.Queue.Add($keyPress)
}

function Add-MockKeySequence {
    param(
        [Parameter(Mandatory)]$Keyboard,
        [Parameter(Mandatory)][string[]]$Sequence
    )

    foreach ($key in $Sequence) {
        Add-MockKeyPress -Keyboard $Keyboard -Key $key
    }
}

function Add-MockTextInput {
    param(
        [Parameter(Mandatory)]$Keyboard,
        [Parameter(Mandatory)][string]$Text
    )

    foreach ($char in $Text.ToCharArray()) {
        Add-MockKeyPress -Keyboard $Keyboard -Key $char.ToString()
    }
}

function Get-MockKeyPress {
    param([Parameter(Mandatory)]$Keyboard)

    if ($Keyboard.Queue.Count -gt 0) {
        $key = $Keyboard.Queue[0]
        $Keyboard.Queue.RemoveAt(0)
        [void]$Keyboard.RecordedInput.Add($key)
        return $key
    }
    return $null
}

# Component Test Context
function New-UITestContext {
    return [PSCustomObject]@{
        Terminal = New-MockTerminal
        Keyboard = New-MockKeyboard
        Events = [System.Collections.ArrayList]::new()
        EventBus = New-MockEventBus
        Components = @{}
        State = @{}
    }
}

function Invoke-UIComponentLifecycle {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Component,
        [Parameter(Mandatory)][string]$EventName
    )

    $eventName = "$($Component.Name):$EventName"
    [void]$Context.Events.Add($eventName)

    # Update component state
    if ($Component.PSObject.Properties["State"]) {
        $Component.State = $EventName
    }

    # Trigger event on bus
    Invoke-MockEvent -EventBus $Context.EventBus -EventName $eventName -Sender $Component
}

function Test-UIMenuNavigation {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][array]$Items
    )

    $selectedIndex = 0
    $done = $false

    while (-not $done -and $Context.Keyboard.Queue.Count -gt 0) {
        $key = Get-MockKeyPress -Keyboard $Context.Keyboard

        switch ($key.Key) {
            "UpArrow" {
                $selectedIndex = [Math]::Max(0, $selectedIndex - 1)
            }
            "DownArrow" {
                $selectedIndex = [Math]::Min($Items.Count - 1, $selectedIndex + 1)
            }
            "Enter" {
                $done = $true
            }
            "Escape" {
                $selectedIndex = -1
                $done = $true
            }
        }
    }

    return @{
        SelectedIndex = $selectedIndex
        SelectedItem = if ($selectedIndex -ge 0) { $Items[$selectedIndex] } else { $null }
    }
}

# Event Bus Mocking
function New-MockEventBus {
    return [PSCustomObject]@{
        Handlers = @{}
        History = [System.Collections.ArrayList]::new()
    }
}

function Register-MockEventHandler {
    param(
        [Parameter(Mandatory)]$EventBus,
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][scriptblock]$Handler
    )

    if (-not $EventBus.Handlers.ContainsKey($EventName)) {
        $EventBus.Handlers[$EventName] = [System.Collections.ArrayList]::new()
    }

    [void]$EventBus.Handlers[$EventName].Add($Handler)
}

function Invoke-MockEvent {
    param(
        [Parameter(Mandatory)]$EventBus,
        [Parameter(Mandatory)][string]$EventName,
        $Sender = $null,
        [hashtable]$Data = @{}
    )

    $event = @{
        Name = $EventName
        Sender = $Sender
        Data = $Data
        Timestamp = [DateTime]::Now
    }

    [void]$EventBus.History.Add($event)

    if ($EventBus.Handlers.ContainsKey($EventName)) {
        foreach ($handler in $EventBus.Handlers[$EventName]) {
            & $handler $Sender $Data
        }
    }
}

# Layout Testing
function Get-ComponentBounds {
    param(
        [Parameter(Mandatory)]$Container,
        [Parameter(Mandatory)]$Component,
        [string]$Alignment = "TopLeft"
    )

    $bounds = @{
        Width = $Component.PreferredWidth
        Height = $Component.PreferredHeight
    }

    switch ($Alignment) {
        "Center" {
            $bounds.X = [Math]::Floor(($Container.Width - $bounds.Width) / 2)
            $bounds.Y = [Math]::Floor(($Container.Height - $bounds.Height) / 2)
        }
        "TopLeft" {
            $bounds.X = 0
            $bounds.Y = 0
        }
        "TopRight" {
            $bounds.X = $Container.Width - $bounds.Width
            $bounds.Y = 0
        }
        "BottomLeft" {
            $bounds.X = 0
            $bounds.Y = $Container.Height - $bounds.Height
        }
        "BottomRight" {
            $bounds.X = $Container.Width - $bounds.Width
            $bounds.Y = $Container.Height - $bounds.Height
        }
    }

    return $bounds
}

function New-MockLayout {
    param(
        [string]$Type = "Flow",
        [int]$Columns = 1,
        [int]$Rows = 1,
        [int]$Gap = 0
    )

    return @{
        Type = $Type
        Columns = $Columns
        Rows = $Rows
        Gap = $Gap
    }
}

function Test-LayoutArrangement {
    param(
        [Parameter(Mandatory)]$Layout,
        [Parameter(Mandatory)][array]$Components,
        [int]$ContainerWidth,
        [int]$ContainerHeight
    )

    $result = @{
        Components = [System.Collections.ArrayList]::new()
    }

    switch ($Layout.Type) {
        "Grid" {
            $cellWidth = [Math]::Floor($ContainerWidth / $Layout.Columns)
            $cellHeight = [Math]::Floor($ContainerHeight / $Layout.Rows)

            for ($i = 0; $i -lt $Components.Count; $i++) {
                $row = [Math]::Floor($i / $Layout.Columns)
                $col = $i % $Layout.Columns

                $component = @{
                    Id = $Components[$i].Id
                    X = $col * $cellWidth + $Layout.Gap
                    Y = $row * $cellHeight + $Layout.Gap
                    Width = [Math]::Min($Components[$i].Width, $cellWidth - 2 * $Layout.Gap)
                    Height = [Math]::Min($Components[$i].Height, $cellHeight - 2 * $Layout.Gap)
                }

                [void]$result.Components.Add($component)
            }
        }
        "Flow" {
            $x = $Layout.Gap
            $y = $Layout.Gap
            $maxHeight = 0

            foreach ($comp in $Components) {
                if ($x + $comp.Width + $Layout.Gap > $ContainerWidth) {
                    $x = $Layout.Gap
                    $y += $maxHeight + $Layout.Gap
                    $maxHeight = 0
                }

                $component = @{
                    Id = $comp.Id
                    X = $x
                    Y = $y
                    Width = $comp.Width
                    Height = $comp.Height
                }

                [void]$result.Components.Add($component)

                $x += $comp.Width + $Layout.Gap
                $maxHeight = [Math]::Max($maxHeight, $comp.Height)
            }
        }
    }

    return $result
}

# Note: Custom assertions would be registered with Pester in a real implementation
# For now, use standard Pester assertions in tests

# Export all functions
Export-ModuleMember -Function @(
    # Terminal
    'New-MockTerminal'
    'Set-MockCursorPosition'
    'Write-MockTerminal'
    'Get-MockTerminalLine'
    'Get-MockTerminalAttributes'
    'Clear-MockTerminal'

    # Keyboard
    'New-MockKeyboard'
    'Add-MockKeyPress'
    'Add-MockKeySequence'
    'Add-MockTextInput'
    'Get-MockKeyPress'

    # Context
    'New-UITestContext'
    'Invoke-UIComponentLifecycle'
    'Test-UIMenuNavigation'

    # Events
    'New-MockEventBus'
    'Register-MockEventHandler'
    'Invoke-MockEvent'

    # Layout
    'Get-ComponentBounds'
    'New-MockLayout'
    'Test-LayoutArrangement'
)