#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

Import-Module "$env:PROJECT_ROOT/aither-core/modules/LabRunner" -Force
Import-Module "$env:PROJECT_ROOT/aither-core/modules/Logging" -Force

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
        $repoName = ($Config.RepoUrl -split '/')[-1] -replace '\.git$', ''
        $repoPath = Join-Path $localBase $repoName
        
        if (Test-Path $repoPath) {
            Write-CustomLog "Removing repo path '$repoPath'..."
            Remove-Item -Recurse -Force -Path $repoPath -ErrorAction Stop
        } else {
            Write-CustomLog "Repo path '$repoPath' not found; skipping."
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