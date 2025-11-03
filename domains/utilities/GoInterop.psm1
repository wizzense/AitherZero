#Requires -Version 7.0

<#
.SYNOPSIS
PowerShell interop layer for Go modules.

.DESCRIPTION
Provides functions to invoke Go module binaries from PowerShell with proper
error handling, JSON marshaling, and fallback mechanisms.

.NOTES
See docs/GO-CONVERSION-IMPLEMENTATION-GUIDE.md for detailed documentation.
#>

function Invoke-GoModule {
    <#
    .SYNOPSIS
    Invokes a Go module binary and returns the result.
    
    .DESCRIPTION
    Executes a Go binary from the go-modules/bin directory and parses the JSON output.
    Automatically falls back to PowerShell implementations if Go module is unavailable.
    
    .PARAMETER ModuleName
    Name of the Go module (e.g., 'config-parser', 'test-parser', 'validator', 'utils')
    
    .PARAMETER Arguments
    Arguments to pass to the Go binary
    
    .PARAMETER AsJson
    Parse output as JSON (default: true)
    
    .PARAMETER TimeoutSeconds
    Maximum execution time in seconds (default: 300)
    
    .EXAMPLE
    Invoke-GoModule -ModuleName 'config-parser' -Arguments @('--file', 'config.psd1')
    
    .EXAMPLE
    Invoke-GoModule -ModuleName 'test-parser' -Arguments @('--file', 'testResults.xml')
    
    .EXAMPLE
    Invoke-GoModule -ModuleName 'validator' -Arguments @('--path', './domains', '--recursive')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('config-parser', 'test-parser', 'validator', 'utils')]
        [string]$ModuleName,
        
        [Parameter()]
        [string[]]$Arguments = @(),
        
        [Parameter()]
        [bool]$AsJson = $true,
        
        [Parameter()]
        [int]$TimeoutSeconds = 300
    )
    
    # Placeholder implementation
    # Full implementation in docs/GO-CONVERSION-IMPLEMENTATION-GUIDE.md
    
    throw "Go interop not yet implemented. See docs/GO-CONVERSION-IMPLEMENTATION-GUIDE.md for setup instructions."
}

function Test-GoModuleAvailable {
    <#
    .SYNOPSIS
    Tests if Go modules are available.
    
    .PARAMETER ModuleName
    Specific module to test, or $null to test Go installation
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ModuleName
    )
    
    # Check Go installation
    $goAvailable = $null -ne (Get-Command go -ErrorAction SilentlyContinue)
    if (-not $goAvailable) {
        return $false
    }
    
    # Check specific module if requested
    if ($ModuleName) {
        $repoRoot = if ($env:AITHERZERO_ROOT) {
            $env:AITHERZERO_ROOT
        } else {
            Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        }
        
        $binPath = Join-Path $repoRoot "bin/go-modules/$ModuleName"
        
        if ($IsWindows) {
            $binPath += '.exe'
        }
        
        return Test-Path $binPath
    }
    
    return $true
}

function Get-GoModuleVersion {
    <#
    .SYNOPSIS
    Gets the version of a Go module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )
    
    if (-not (Test-GoModuleAvailable -ModuleName $ModuleName)) {
        return "Not installed"
    }
    
    try {
        $result = Invoke-GoModule -ModuleName $ModuleName -Arguments @('--version') -AsJson $false
        return $result.Trim()
    } catch {
        return "Unknown"
    }
}

Export-ModuleMember -Function @(
    'Invoke-GoModule',
    'Test-GoModuleAvailable',
    'Get-GoModuleVersion'
)
