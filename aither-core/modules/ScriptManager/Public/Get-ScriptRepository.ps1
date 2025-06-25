function Get-ScriptRepository {
    <#
    .SYNOPSIS
    Gets information about the script repository

    .DESCRIPTION
    Returns information about the configured script repository, including path, available scripts, and status

    .PARAMETER Path
    Optional path to a specific script repository

    .EXAMPLE
    Get-ScriptRepository

    .EXAMPLE
    Get-ScriptRepository -Path "C:\Scripts"
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Getting script repository information"
    }

    process {
        try {
            if (-not $Path) {
                # Use default repository path from project root
                $projectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else { Get-Location }
                $Path = Join-Path -Path $projectRoot -ChildPath "aither-core/scripts"
            }

            if (-not (Test-Path $Path)) {
                Write-CustomLog -Level 'WARN' -Message "Script repository path does not exist: $Path"
                return @{
                    Path = $Path
                    Exists = $false
                    Scripts = @()
                    Status = "Not Found"
                }
            }

            $scripts = Get-ChildItem -Path $Path -Filter "*.ps1" -Recurse

            $result = @{
                Path = $Path
                Exists = $true
                Scripts = $scripts | ForEach-Object {
                    @{
                        Name = $_.Name
                        FullPath = $_.FullName
                        Size = $_.Length
                        LastModified = $_.LastWriteTime
                    }
                }
                Status = "Available"
                Count = $scripts.Count
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Found $($scripts.Count) scripts in repository: $Path"
            return $result
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get script repository: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Script repository query completed"
    }
}