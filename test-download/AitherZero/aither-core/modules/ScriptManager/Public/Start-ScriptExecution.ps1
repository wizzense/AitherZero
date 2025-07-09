function Start-ScriptExecution {
    <#
    .SYNOPSIS
    Starts execution of a script from the repository

    .DESCRIPTION
    Executes a script from the configured script repository with proper error handling and logging

    .PARAMETER ScriptName
    Name of the script to execute

    .PARAMETER Arguments
    Arguments to pass to the script

    .PARAMETER WorkingDirectory
    Working directory for script execution

    .EXAMPLE
    Start-ScriptExecution -ScriptName "setup-environment.ps1"

    .EXAMPLE
    Start-ScriptExecution -ScriptName "deploy.ps1" -Arguments @("-Environment", "Test")
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName,

        [Parameter()]
        [string[]]$Arguments = @(),

        [Parameter()]
        [string]$WorkingDirectory
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting script execution: $ScriptName"
    }

    process {
        try {
            # Get script repository information
            $repository = Get-ScriptRepository

            if (-not $repository.Exists) {
                throw "Script repository not found: $($repository.Path)"
            }

            # Find the requested script
            $script = $repository.Scripts | Where-Object { $_.Name -eq $ScriptName } | Select-Object -First 1

            if (-not $script) {
                throw "Script not found in repository: $ScriptName"
            }

            Write-CustomLog -Level 'INFO' -Message "Found script: $($script.FullPath)"

            if ($PSCmdlet.ShouldProcess($script.FullPath, "Execute Script")) {
                # Set working directory if specified
                $originalLocation = Get-Location
                if ($WorkingDirectory) {
                    Set-Location -Path $WorkingDirectory
                    Write-CustomLog -Level 'INFO' -Message "Changed working directory to: $WorkingDirectory"
                }

                try {
                    # Build execution arguments
                    $executeArgs = @($script.FullPath) + $Arguments

                    Write-CustomLog -Level 'INFO' -Message "Executing: pwsh -File $($executeArgs -join ' ')"

                    # Execute the script
                    $result = & pwsh -File $executeArgs

                    Write-CustomLog -Level 'SUCCESS' -Message "Script execution completed successfully"

                    return @{
                        ScriptName = $ScriptName
                        ScriptPath = $script.FullPath
                        Arguments = $Arguments
                        Success = $true
                        Output = $result
                        ExecutionTime = (Get-Date)
                    }
                }
                finally {
                    # Restore original location
                    Set-Location -Path $originalLocation
                }
            }
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Script execution failed: $($_.Exception.Message)"

            return @{
                ScriptName = $ScriptName
                Success = $false
                Error = $_.Exception.Message
                ExecutionTime = (Get-Date)
            }
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Script execution process completed"
    }
}
