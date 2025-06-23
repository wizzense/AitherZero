#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [object]$Config
)

Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force

Write-CustomLog "Starting $($MyInvocation.MyCommand.Name)"

Invoke-LabStep -Config $Config -Body {
    Write-CustomLog "Running $($MyInvocation.MyCommand.Name)"

    # Determine InfraPath
    $InfraPath = if ($Config.InfraRepoPath) { $Config.InfraRepoPath } else { 'C:/Temp/base-infra' }

    # Ensure the local directory exists; create if it does not
    Write-CustomLog "Ensuring local path '$InfraPath' exists..."
    if (-not (Test-Path $InfraPath)) {
        Write-CustomLog 'Path not found. Creating directory...'
        New-Item -ItemType Directory -Path $InfraPath -Force | Out-Null

        # Clone or update repo
        if (-not (Test-Path (Join-Path $InfraPath '.git'))) {
            Write-CustomLog 'Directory is not a git repository. Cloning repository...'
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                gh auth status 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "GitHub CLI is not authenticated. Please run 'gh auth login' and re-run this script."
                    exit 1
                }
                gh repo clone $config.InfraRepoUrl $InfraPath
            } else {
                git clone $config.InfraRepoUrl $InfraPath
            }
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $InfraPath '.git'))) {
                Write-Error "Failed to clone repository from $($config.InfraRepoUrl)"
                throw "Failed to clone repository"
            }
            Write-CustomLog 'Clone completed successfully.'
        } else {
            Write-CustomLog 'Git repository found. Updating repository...'
            Push-Location $InfraPath
            try {
                Write-CustomLog 'git reset --hard'
                git reset --hard
                Write-CustomLog 'git clean -fd'
                git clean -fd
                Write-CustomLog 'git pull'
                git pull
            } catch {
                Write-Error "An error occurred while updating the repository: $_"
            } finally {
                Pop-Location
            }
        }
    }

    Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
}

Write-CustomLog "Completed $($MyInvocation.MyCommand.Name)"
