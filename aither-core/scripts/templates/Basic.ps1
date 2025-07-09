#Requires -Version 7.0

<#
.SYNOPSIS
    Basic PowerShell script template
.DESCRIPTION
    Template for creating basic PowerShell scripts with logging support
.PARAMETER ExampleParam
    Example parameter
.EXAMPLE
    .\Script.ps1 -ExampleParam "value"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ExampleParam = "default",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

try {
    Write-CustomLog -Level 'INFO' -Message "Script started with parameter: $ExampleParam"
    
    if ($WhatIf) {
        Write-CustomLog -Level 'INFO' -Message "WhatIf mode: Script would perform actions here"
        return
    }
    
    # Your script logic here
    Write-CustomLog -Level 'INFO' -Message "Performing script operations..."
    
    # Example operation
    Start-Sleep -Seconds 1
    
    Write-CustomLog -Level 'SUCCESS' -Message "Script completed successfully"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Script failed: $($_.Exception.Message)"
    throw
}
