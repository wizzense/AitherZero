#Requires -Version 7.0
<#
.SYNOPSIS
    Layout management system for UI components
.DESCRIPTION
    Provides layout algorithms for arranging components in containers
#>

# Layout types
$script:LayoutTypes = @{
    Flow = "Flow"           # Components flow left-to-right, top-to-bottom
    Grid = "Grid"           # Components in fixed grid
    Stack = "Stack"         # Vertical or horizontal stacking
    Absolute = "Absolute"   # Absolute positioning
    Flex = "Flex"          # Flexible box layout
}

function New-UILayout {
    <#
    .SYNOPSIS
        Create a new layout definition
    .PARAMETER Type
        Layout type (Flow, Grid, Stack, Absolute, Flex)
    .PARAMETER Direction
        Layout direction (Horizontal, Vertical)
    .PARAMETER Columns
        Number of columns (for Grid)
    .PARAMETER Rows
        Number of rows (for Grid)
    .PARAMETER Gap
        Gap between components
    .PARAMETER Padding
        Container padding
    .PARAMETER Alignment
        Component alignment
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("Flow", "Grid", "Stack", "Absolute", "Flex")]
        [string]$Type = "Flow",
        
        [ValidateSet("Horizontal", "Vertical")]
        [string]$Direction = "Horizontal",
        
        [int]$Columns = 1,
        [int]$Rows = 0,  # 0 = auto
        
        [int]$Gap = 1,
        
        [hashtable]$Padding = @{ Top = 0; Right = 0; Bottom = 0; Left = 0 },
        
        [ValidateSet("TopLeft", "TopCenter", "TopRight", "MiddleLeft", "Center", "MiddleRight", "BottomLeft", "BottomCenter", "BottomRight")]
        [string]$Alignment = "TopLeft"
    )
    
    return [PSCustomObject]@{
        Type = $Type
        Direction = $Direction
        Columns = $Columns
        Rows = $Rows
        Gap = $Gap
        Padding = $Padding
        Alignment = $Alignment
        Constraints = @{}
    }
}

function Calculate-UILayout {
    <#
    .SYNOPSIS
        Calculate component positions based on layout
    .PARAMETER Layout
        Layout definition
    .PARAMETER Container
        Container bounds
    .PARAMETER Components
        Array of components to layout
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Layout,
        
        [Parameter(Mandatory)]
        [hashtable]$Container,  # @{ X, Y, Width, Height }
        
        [Parameter(Mandatory)]
        [array]$Components
    )
    
    # Calculate content area (container minus padding)
    $contentArea = @{
        X = $Container.X + $Layout.Padding.Left
        Y = $Container.Y + $Layout.Padding.Top
        Width = $Container.Width - $Layout.Padding.Left - $Layout.Padding.Right
        Height = $Container.Height - $Layout.Padding.Top - $Layout.Padding.Bottom
    }
    
    # Apply layout algorithm
    switch ($Layout.Type) {
        "Flow" {
            return Calculate-FlowLayout -Layout $Layout -ContentArea $contentArea -Components $Components
        }
        "Grid" {
            return Calculate-GridLayout -Layout $Layout -ContentArea $contentArea -Components $Components
        }
        "Stack" {
            return Calculate-StackLayout -Layout $Layout -ContentArea $contentArea -Components $Components
        }
        "Absolute" {
            return Calculate-AbsoluteLayout -Layout $Layout -ContentArea $contentArea -Components $Components
        }
        "Flex" {
            return Calculate-FlexLayout -Layout $Layout -ContentArea $contentArea -Components $Components
        }
    }
}

function Calculate-FlowLayout {
    param($Layout, $ContentArea, $Components)
    
    $positions = @()
    $x = $ContentArea.X
    $y = $ContentArea.Y
    $rowHeight = 0
    
    foreach ($component in $Components) {
        $width = if ($component.Width) { $component.Width } else { 10 }
        $height = if ($component.Height) { $component.Height } else { 1 }
        
        # Check if component fits in current row
        if (($x + $width) -gt ($ContentArea.X + $ContentArea.Width)) {
            # Move to next row
            $x = $ContentArea.X
            $y += $rowHeight + $Layout.Gap
            $rowHeight = 0
        }
        
        # Position component
        $positions += @{
            Component = $component
            X = $x
            Y = $y
            Width = $width
            Height = $height
        }
        
        # Update position
        $x += $width + $Layout.Gap
        $rowHeight = [Math]::Max($rowHeight, $height)
    }
    
    return $positions
}

function Calculate-GridLayout {
    param($Layout, $ContentArea, $Components)
    
    $positions = @()
    
    # Calculate cell dimensions
    $cellWidth = [Math]::Floor(($ContentArea.Width - ($Layout.Columns - 1) * $Layout.Gap) / $Layout.Columns)
    $cellHeight = if ($Layout.Rows -gt 0) {
        [Math]::Floor(($ContentArea.Height - ($Layout.Rows - 1) * $Layout.Gap) / $Layout.Rows)
    } else {
        # Auto-calculate row height based on components
        10  # Default height
    }
    
    for ($i = 0; $i -lt $Components.Count; $i++) {
        $component = $Components[$i]
        
        # Calculate grid position
        $col = $i % $Layout.Columns
        $row = [Math]::Floor($i / $Layout.Columns)
        
        # Calculate pixel position
        $x = $ContentArea.X + ($col * ($cellWidth + $Layout.Gap))
        $y = $ContentArea.Y + ($row * ($cellHeight + $Layout.Gap))
        
        $positions += @{
            Component = $component
            X = $x
            Y = $y
            Width = [Math]::Min($component.Width, $cellWidth)
            Height = [Math]::Min($component.Height, $cellHeight)
        }
    }
    
    return $positions
}

function Calculate-StackLayout {
    param($Layout, $ContentArea, $Components)
    
    $positions = @()
    $offset = 0
    
    foreach ($component in $Components) {
        if ($Layout.Direction -eq "Vertical") {
            $positions += @{
                Component = $component
                X = $ContentArea.X
                Y = $ContentArea.Y + $offset
                Width = [Math]::Min($component.Width, $ContentArea.Width)
                Height = $component.Height
            }
            $offset += $component.Height + $Layout.Gap
        }
        else {
            $positions += @{
                Component = $component
                X = $ContentArea.X + $offset
                Y = $ContentArea.Y
                Width = $component.Width
                Height = [Math]::Min($component.Height, $ContentArea.Height)
            }
            $offset += $component.Width + $Layout.Gap
        }
    }
    
    return $positions
}

function Calculate-AbsoluteLayout {
    param($Layout, $ContentArea, $Components)
    
    $positions = @()
    
    foreach ($component in $Components) {
        # Use component's absolute position
        $positions += @{
            Component = $component
            X = if ($component.X -ne $null) { $ContentArea.X + $component.X } else { $ContentArea.X }
            Y = if ($component.Y -ne $null) { $ContentArea.Y + $component.Y } else { $ContentArea.Y }
            Width = $component.Width
            Height = $component.Height
        }
    }
    
    return $positions
}

function Calculate-FlexLayout {
    param($Layout, $ContentArea, $Components)
    
    $positions = @()
    
    # Calculate flex weights
    $totalFlex = 0
    $fixedSize = 0
    
    foreach ($component in $Components) {
        if ($component.Flex) {
            $totalFlex += $component.Flex
        } else {
            $fixedSize += if ($Layout.Direction -eq "Horizontal") { $component.Width } else { $component.Height }
        }
    }
    
    # Calculate available space for flex items
    $availableSpace = if ($Layout.Direction -eq "Horizontal") { 
        $ContentArea.Width - $fixedSize - (($Components.Count - 1) * $Layout.Gap)
    } else { 
        $ContentArea.Height - $fixedSize - (($Components.Count - 1) * $Layout.Gap)
    }
    
    $flexUnit = if ($totalFlex -gt 0) { $availableSpace / $totalFlex } else { 0 }
    
    # Position components
    $offset = 0
    
    foreach ($component in $Components) {
        if ($Layout.Direction -eq "Horizontal") {
            $width = if ($component.Flex) { 
                [Math]::Floor($flexUnit * $component.Flex) 
            } else { 
                $component.Width 
            }
            
            $positions += @{
                Component = $component
                X = $ContentArea.X + $offset
                Y = $ContentArea.Y
                Width = $width
                Height = [Math]::Min($component.Height, $ContentArea.Height)
            }
            
            $offset += $width + $Layout.Gap
        }
        else {
            $height = if ($component.Flex) { 
                [Math]::Floor($flexUnit * $component.Flex) 
            } else { 
                $component.Height 
            }
            
            $positions += @{
                Component = $component
                X = $ContentArea.X
                Y = $ContentArea.Y + $offset
                Width = [Math]::Min($component.Width, $ContentArea.Width)
                Height = $height
            }
            
            $offset += $height + $Layout.Gap
        }
    }
    
    return $positions
}

function Apply-UILayout {
    <#
    .SYNOPSIS
        Apply calculated layout to components
    .PARAMETER Positions
        Array of position calculations
    .PARAMETER UpdateComponents
        Update component positions directly
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Positions,
        
        [switch]$UpdateComponents
    )
    
    foreach ($pos in $Positions) {
        if ($UpdateComponents -and $pos.Component) {
            $pos.Component.X = $pos.X
            $pos.Component.Y = $pos.Y
            $pos.Component.Width = $pos.Width
            $pos.Component.Height = $pos.Height
        }
    }
    
    return $Positions
}

function Get-UILayoutBounds {
    <#
    .SYNOPSIS
        Calculate the bounding box of laid out components
    .PARAMETER Positions
        Array of position calculations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Positions
    )
    
    if ($Positions.Count -eq 0) {
        return @{ X = 0; Y = 0; Width = 0; Height = 0 }
    }
    
    $minX = $Positions[0].X
    $minY = $Positions[0].Y
    $maxX = $Positions[0].X + $Positions[0].Width
    $maxY = $Positions[0].Y + $Positions[0].Height
    
    foreach ($pos in $Positions[1..($Positions.Count - 1)]) {
        $minX = [Math]::Min($minX, $pos.X)
        $minY = [Math]::Min($minY, $pos.Y)
        $maxX = [Math]::Max($maxX, $pos.X + $pos.Width)
        $maxY = [Math]::Max($maxY, $pos.Y + $pos.Height)
    }
    
    return @{
        X = $minX
        Y = $minY
        Width = $maxX - $minX
        Height = $maxY - $minY
    }
}

function Test-UILayoutFit {
    <#
    .SYNOPSIS
        Test if components fit within container with given layout
    .PARAMETER Layout
        Layout definition
    .PARAMETER Container
        Container bounds
    .PARAMETER Components
        Array of components
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Layout,
        
        [Parameter(Mandatory)]
        [hashtable]$Container,
        
        [Parameter(Mandatory)]
        [array]$Components
    )
    
    $positions = Calculate-UILayout -Layout $Layout -Container $Container -Components $Components
    $bounds = Get-UILayoutBounds -Positions $positions
    
    $fits = ($bounds.Width -le $Container.Width) -and ($bounds.Height -le $Container.Height)
    
    return @{
        Fits = $fits
        Bounds = $bounds
        Container = $Container
        Overflow = @{
            Horizontal = [Math]::Max(0, $bounds.Width - $Container.Width)
            Vertical = [Math]::Max(0, $bounds.Height - $Container.Height)
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'New-UILayout'
    'Calculate-UILayout'
    'Apply-UILayout'
    'Get-UILayoutBounds'
    'Test-UILayoutFit'
)