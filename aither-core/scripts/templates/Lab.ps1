#Requires -Version 7.0

<#
.SYNOPSIS
    Lab automation script template
.DESCRIPTION
    Template for creating lab automation scripts with comprehensive error handling
.PARAMETER LabName
    Name of the lab environment
.PARAMETER Operation
    Operation to perform
.EXAMPLE
    .\LabScript.ps1 -LabName "TestLab" -Operation "Deploy"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$LabName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Deploy', 'Destroy', 'Status', 'Validate')]
    [string]$Operation = 'Status',
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

try {
    Write-CustomLog -Level 'INFO' -Message "Lab automation script started: $LabName ($Operation)"
    
    # Validate prerequisites
    if (-not $env:PROJECT_ROOT) {
        throw "PROJECT_ROOT environment variable not set"
    }
    
    if ($WhatIf) {
        Write-CustomLog -Level 'INFO' -Message "WhatIf mode: Would perform $Operation on $LabName"
        return
    }
    
    # Lab operation logic
    switch ($Operation) {
        'Deploy' {
            Write-CustomLog -Level 'INFO' -Message "Deploying lab: $LabName"
            # Deployment logic here
        }
        'Destroy' {
            Write-CustomLog -Level 'INFO' -Message "Destroying lab: $LabName"
            # Destruction logic here
        }
        'Status' {
            Write-CustomLog -Level 'INFO' -Message "Checking lab status: $LabName"
            # Status check logic here
        }
        'Validate' {
            Write-CustomLog -Level 'INFO' -Message "Validating lab: $LabName"
            # Validation logic here
        }
    }
    
    Write-CustomLog -Level 'SUCCESS' -Message "Lab automation completed successfully"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Lab automation failed: $($_.Exception.Message)"
    throw
}
