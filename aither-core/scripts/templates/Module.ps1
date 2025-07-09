#Requires -Version 7.0

<#
.SYNOPSIS
    Module function script template
.DESCRIPTION
    Template for creating scripts that use AitherZero modules
.PARAMETER ModuleName
    Name of the module to work with
.EXAMPLE
    .\ModuleScript.ps1 -ModuleName "LabRunner"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

try {
    Write-CustomLog -Level 'INFO' -Message "Module script started for: $ModuleName"
    
    # Import required modules
    $moduleAvailable = Get-Module -Name $ModuleName -ListAvailable
    if (-not $moduleAvailable) {
        throw "Module $ModuleName is not available"
    }
    
    Import-Module $ModuleName -Force
    Write-CustomLog -Level 'INFO' -Message "Module $ModuleName imported successfully"
    
    if ($WhatIf) {
        Write-CustomLog -Level 'INFO' -Message "WhatIf mode: Would execute module operations"
        return
    }
    
    # Your module-specific logic here
    Write-CustomLog -Level 'INFO' -Message "Executing module operations..."
    
    Write-CustomLog -Level 'SUCCESS' -Message "Module script completed successfully"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Module script failed: $($_.Exception.Message)"
    throw
}
