# kick-git.ps1

<#+
.SYNOPSIS
    A script to quickly clone the AitherZero repository and set up the environment.
.DESCRIPTION
    This script automates the process of cloning the AitherZero repository and running the bootstrap script.
.EXAMPLE
    pwsh -File ./kick-git.ps1
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$RepositoryUrl = "https://github.com/wizzense/AitherZero.git",

    [Parameter(Mandatory=$false)]
    [string]$BootstrapScript = "bootstrap.ps1"
)

try {
    Write-Host "Cloning repository from $RepositoryUrl..." -ForegroundColor Cyan
    git clone $RepositoryUrl

    $repoName = Split-Path -Leaf $RepositoryUrl
    $repoName = $repoName -replace '\.git$', ''

    Write-Host "Entering repository directory: $repoName..." -ForegroundColor Cyan
    Set-Location -Path $repoName

    if (Test-Path -Path $BootstrapScript) {
        Write-Host "Running bootstrap script: $BootstrapScript..." -ForegroundColor Cyan
        pwsh -File ./$BootstrapScript
    } else {
        Write-Warning "Bootstrap script not found: $BootstrapScript"
    }
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
