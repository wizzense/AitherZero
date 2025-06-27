#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

$projectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else { "/workspaces/AitherZero" }
Import-Module "$projectRoot/aither-core/modules/LabRunner" -Force
Import-Module "$projectRoot/aither-core/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    <#
    .SYNOPSIS
        Removes the cloned repo and infra directories.
    .DESCRIPTION
        Deletes the repository directory derived from RepoUrl under LocalPath
        and the InfraRepoPath directory if they exist.
    #>

    $tempPath = Get-CrossPlatformTempPath
    Push-Location -Path $tempPath

    try {
        $localBase = if ($Config.LocalPath) {
            $Config.LocalPath
        } else {
            Get-CrossPlatformTempPath
        }
        
        $localBase = [System.Environment]::ExpandEnvironmentVariables($localBase)
        
        # Only proceed with repo cleanup if RepoUrl is provided
        if ($Config.RepoUrl) {
            $repoName = ($Config.RepoUrl -split '/')[-1] -replace '\.git$', ''
            if ($repoName) {
                $repoPath = Join-Path $localBase $repoName
                
                if (Test-Path $repoPath) {
                    Write-CustomLog "Removing repo path '$repoPath'..."
                    Remove-Item -Recurse -Force -Path $repoPath -ErrorAction Stop
                } else {
                    Write-CustomLog "Repo path '$repoPath' not found; skipping."
                }
            } else {
                Write-CustomLog "Could not determine repo name from RepoUrl; skipping repo cleanup."
            }
        } else {
            Write-CustomLog "No RepoUrl provided; skipping repo cleanup."
        }
        
        $infraPath = if ($Config.InfraRepoPath) { $Config.InfraRepoPath } else { 'C:/Temp/base-infra' }
        if (Test-Path $infraPath) {
            Write-CustomLog "Removing infra path '$infraPath'..."
            Remove-Item -Recurse -Force -Path $infraPath -ErrorAction Stop
        } else {
            Write-CustomLog "Infra path '$infraPath' not found; skipping."
        }
        
        Write-CustomLog 'Cleanup completed successfully.'
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Cleanup failed: $($_.Exception.Message)"
        throw
    } finally {
        try {
            Pop-Location -ErrorAction Stop
        } catch {
            Set-Location $tempPath
        }
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
