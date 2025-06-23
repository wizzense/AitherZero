#Requires -Version 7.0

<#
.SYNOPSIS
    Standardized project module import function
    
.DESCRIPTION
    This function provides a standardized way to import modules within the project,
    ensuring cross-platform compatibility and consistent import patterns.
    
.PARAMETER ModuleName
    Name of the module to import (e.g. 'PatchManager', 'Logging')
    
.PARAMETER Force
    Force reimport of the module even if already loaded
    
.PARAMETER Verbose
    Enable verbose output
    
.EXAMPLE
    Import-ProjectModule -ModuleName "PatchManager"
    
.EXAMPLE
    Import-ProjectModule -ModuleName "Logging" -Force -Verbose
#>
function Import-ProjectModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
          [Parameter(Mandatory = $false)]
        [switch]$ShowDetails
    )
      begin {
        # Ensure PROJECT_ROOT environment variable is set
        if (-not $env:PROJECT_ROOT) {
            $env:PROJECT_ROOT = (Get-Location).Path
            if ($ShowDetails) {
                Write-Host "Setting PROJECT_ROOT to $(Get-Location)" -ForegroundColor Yellow
            }
        }
        
        # Set standard module path with forward slashes
        $modulePath = "$env:PROJECT_ROOT/core-runner/modules/$ModuleName"
        
        # Create hashtable for splatting import parameters
        $importParams = @{
            Name = $modulePath
            ErrorAction = 'Stop'
        }
          if ($Force) {
            $importParams['Force'] = $true
        }
        
        if ($ShowDetails) {
            $importParams['Verbose'] = $true
        }
    }
    
    process {
        try {            # Import the module with specified parameters
            Import-Module @importParams
            
            if ($ShowDetails) {
                Write-Host "✅ Successfully imported module: $ModuleName" -ForegroundColor Green
            }
            
            # Return true to indicate success
            return $true
        }
        catch {
            # Write an error message
            Write-Error "Failed to import module '$ModuleName': $_"
            
            # Return false to indicate failure
            return $false
        }
    }
}

Export-ModuleMember -Function Import-ProjectModule
