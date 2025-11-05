#Requires -Version 7.0
<#
.SYNOPSIS
    Breadcrumb navigation component for AitherZero UI
.DESCRIPTION
    Displays navigation path (e.g., Main > Testing > Run Tests)
    Tracks navigation history and supports back navigation
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Creates a new breadcrumb navigation stack
#>
function New-BreadcrumbStack {
    [CmdletBinding()]
    param()
    
    return [PSCustomObject]@{
        Items = [System.Collections.Generic.Stack[PSCustomObject]]::new()
        Current = $null
        PSTypeName = 'AitherZero.BreadcrumbStack'
    }
}

<#
.SYNOPSIS
    Pushes a new breadcrumb onto the stack
#>
function Push-Breadcrumb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Stack,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [hashtable]$Context = @{}
    )
    
    $crumb = [PSCustomObject]@{
        Name = $Name
        Context = $Context
        Timestamp = Get-Date
        PSTypeName = 'AitherZero.Breadcrumb'
    }
    
    $Stack.Items.Push($crumb)
    $Stack.Current = $crumb
    
    return $Stack
}

<#
.SYNOPSIS
    Pops the current breadcrumb from the stack
#>
function Pop-Breadcrumb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Stack
    )
    
    if ($Stack.Items.Count -gt 0) {
        $Stack.Items.Pop() | Out-Null
        $Stack.Current = if ($Stack.Items.Count -gt 0) { $Stack.Items.Peek() } else { $null }
    }
    
    return $Stack
}

<#
.SYNOPSIS
    Gets the full breadcrumb path as a string
#>
function Get-BreadcrumbPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Stack,
        
        [string]$Separator = ' > ',
        
        [switch]$IncludeRoot
    )
    
    if ($Stack.Items.Count -eq 0) {
        if ($IncludeRoot) {
            return "AitherZero"
        } else {
            return ""
        }
    }
    
    # Get items in order (oldest to newest)
    $items = @($Stack.Items.ToArray())
    [Array]::Reverse($items)
    
    $path = if ($IncludeRoot) { @("AitherZero") + $items.Name } else { $items.Name }
    
    return $path -join $Separator
}

<#
.SYNOPSIS
    Renders the breadcrumb navigation
#>
function Show-Breadcrumb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Stack,
        
        [string]$Separator = ' > ',
        
        [switch]$IncludeRoot,
        
        [string]$Color = 'Cyan',
        
        [string]$SeparatorColor = 'DarkGray',
        
        [string]$CurrentColor = 'Yellow'
    )
    
    if ($Stack.Items.Count -eq 0) {
        if ($IncludeRoot) {
            Write-Host "AitherZero" -ForegroundColor $CurrentColor -NoNewline
        }
        Write-Host ""
        return
    }
    
    # Get items in order (oldest to newest)
    $items = @($Stack.Items.ToArray())
    [Array]::Reverse($items)
    
    # Print root if requested
    if ($IncludeRoot) {
        Write-Host "AitherZero" -ForegroundColor $Color -NoNewline
        Write-Host $Separator -ForegroundColor $SeparatorColor -NoNewline
    }
    
    # Print all items except the last
    for ($i = 0; $i -lt $items.Count - 1; $i++) {
        Write-Host $items[$i].Name -ForegroundColor $Color -NoNewline
        Write-Host $Separator -ForegroundColor $SeparatorColor -NoNewline
    }
    
    # Print the current item in a different color
    Write-Host $items[-1].Name -ForegroundColor $CurrentColor
}

<#
.SYNOPSIS
    Gets the current breadcrumb context
#>
function Get-CurrentBreadcrumb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Stack
    )
    
    return $Stack.Current
}

<#
.SYNOPSIS
    Clears all breadcrumbs (returns to root)
#>
function Clear-BreadcrumbStack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Stack
    )
    
    $Stack.Items.Clear()
    $Stack.Current = $null
    
    return $Stack
}

<#
.SYNOPSIS
    Gets the breadcrumb depth (how many levels deep)
#>
function Get-BreadcrumbDepth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Stack
    )
    
    return $Stack.Items.Count
}

# Export functions
Export-ModuleMember -Function @(
    'New-BreadcrumbStack'
    'Push-Breadcrumb'
    'Pop-Breadcrumb'
    'Get-BreadcrumbPath'
    'Show-Breadcrumb'
    'Get-CurrentBreadcrumb'
    'Clear-BreadcrumbStack'
    'Get-BreadcrumbDepth'
)
