#Requires -Version 7.0

<#
.SYNOPSIS
    Test GitHub Actions workflows locally using act or similar tools
.DESCRIPTION
    Enables local testing of GitHub Actions workflows without pushing to GitHub:
    - Uses 'act' to emulate GitHub Actions environment
    - Supports custom secrets and environment variables
    - Can test specific jobs or events
    - Provides detailed execution logs
    - Mocks GitHub context variables
.PARAMETER WorkflowFile
    Path to the workflow file to test
.PARAMETER Event
    GitHub event to simulate (push, pull_request, workflow_dispatch, etc.)
.PARAMETER Job
    Specific job to run (if not specified, runs all jobs)
.PARAMETER Secrets
    Hashtable of secrets to use in the workflow
.PARAMETER EnvVars
    Hashtable of environment variables to set
.PARAMETER DryRun
    Show what would be executed without running
.PARAMETER InstallDependencies
    Install required dependencies (act, Docker)
.PARAMETER Platform
    Platform to emulate (ubuntu-latest, windows-latest, macos-latest)
.PARAMETER WhatIf
    Preview what would be tested without executing
.EXAMPLE
    ./0441_Test-WorkflowsLocally.ps1 -WorkflowFile .github/workflows/ci.yml -Event push
.EXAMPLE
    ./0441_Test-WorkflowsLocally.ps1 -WorkflowFile .github/workflows/pr.yml -Event pull_request -Secrets @{GITHUB_TOKEN="..."}
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string]$WorkflowFile,
    
    [ValidateSet('push', 'pull_request', 'pull_request_target', 'workflow_dispatch', 
                 'schedule', 'release', 'issue_comment', 'issues', 'workflow_call')]
    [string]$EventName = 'push',
    
    [string]$Job,
    
    [hashtable]$Secrets = @{},
    
    [hashtable]$EnvVars = @{},
    
    [switch]$DryRun,
    
    [switch]$InstallDependencies,
    
    [ValidateSet('ubuntu-latest', 'ubuntu-22.04', 'ubuntu-20.04', 
                 'windows-latest', 'windows-2022', 'windows-2019',
                 'macos-latest', 'macos-13', 'macos-12')]
    [string]$Platform = 'ubuntu-latest',
    
    [switch]$VerboseOutput,
    
    [switch]$NoCache,
    
    [switch]$CI,
    
    [string]$EventNamePayload,
    
    [string]$ActVersion = 'latest'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
if (Test-Path $script:LoggingModule) {
    Import-Module $script:LoggingModule -Force -ErrorAction SilentlyContinue
}

# Import Configuration module for auto-install settings
$script:ConfigModule = Join-Path $script:ProjectRoot "domains/configuration/Configuration.psm1"
if (Test-Path $script:ConfigModule) {
    Import-Module $script:ConfigModule -Force -ErrorAction SilentlyContinue
}

# Logging helper
function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "WorkflowTest"
    } else {
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Success' { 'Green' }
            'Debug' { 'Gray' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Test-ActInstalled {
    <#
    .SYNOPSIS
        Check if act is installed
    #>
    
    $actCommand = Get-Command act -ErrorAction SilentlyContinue
    if ($actCommand) {
        $version = & act --version 2>&1
        Write-TestLog "Found act: $version" -Level Debug
        return $true
    }
    return $false
}

function Install-Act {
    <#
    .SYNOPSIS
        Install act for local workflow testing
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-TestLog "Installing act..." -Level Information
    
    if ($IsWindows) {
        # Windows installation
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess("act", "Install via Chocolatey")) {
                choco install act-cli -y
            }
        } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess("act", "Install via winget")) {
                winget install nektos.act
            }
        } else {
            # Manual download
            Write-TestLog "Downloading act for Windows..." -Level Information
            $downloadUrl = if ($ActVersion -eq 'latest') {
                $release = Invoke-RestMethod "https://api.github.com/repos/nektos/act/releases/latest"
                $asset = $release.assets | Where-Object { $_.name -like "*Windows_x86_64.zip" } | Select-Object -First 1
                $asset.browser_download_url
            } else {
                "https://github.com/nektos/act/releases/download/v$ActVersion/act_Windows_x86_64.zip"
            }
            
            $tempFile = Join-Path $env:TEMP "act.zip"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
            
            $installPath = Join-Path $env:ProgramFiles "act"
            if (-not (Test-Path $installPath)) {
                New-Item -ItemType Directory -Path $installPath -Force | Out-Null
            }
            
            Expand-Archive -Path $tempFile -DestinationPath $installPath -Force
            Remove-Item $tempFile
            
            # Add to PATH
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($currentPath -notlike "*$installPath*") {
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installPath", "Machine")
                $env:Path = "$env:Path;$installPath"
            }
        }
    } elseif ($IsMacOS) {
        # macOS installation
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess("act", "Install via Homebrew")) {
                brew install act
            }
        } else {
            throw "Homebrew is required to install act on macOS. Please install Homebrew first."
        }
    } else {
        # Linux installation
        Write-TestLog "Downloading act for Linux..." -Level Information
        $downloadUrl = if ($ActVersion -eq 'latest') {
            $release = Invoke-RestMethod "https://api.github.com/repos/nektos/act/releases/latest"
            $asset = $release.assets | Where-Object { $_.name -like "*Linux_x86_64.tar.gz" } | Select-Object -First 1
            $asset.browser_download_url
        } else {
            "https://github.com/nektos/act/releases/download/v$ActVersion/act_Linux_x86_64.tar.gz"
        }
        
        $tempFile = "/tmp/act.tar.gz"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
        
        if ($PSCmdlet.ShouldProcess("/usr/local/bin", "Install act")) {
            sudo tar xf $tempFile -C /usr/local/bin act
            sudo chmod +x /usr/local/bin/act
        }
        
        Remove-Item $tempFile
    }
    
    # Verify installation
    if (Test-ActInstalled) {
        Write-TestLog "act installed successfully" -Level Success
        return $true
    } else {
        throw "Failed to install act"
    }
}

function Test-DockerInstalled {
    <#
    .SYNOPSIS
        Check if Docker is installed and running
    #>
    
    $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCommand) {
        try {
            $dockerVersion = & docker --version 2>&1
            Write-TestLog "Found Docker: $dockerVersion" -Level Debug
            
            # Check if Docker daemon is running
            $dockerInfo = & docker info 2>&1
            if ($LASTEXITCODE -eq 0) {
                return $true
            } else {
                Write-TestLog "Docker is installed but not running" -Level Warning
                return $false
            }
        } catch {
            Write-TestLog "Docker check failed: $_" -Level Warning
            return $false
        }
    }
    return $false
}

function New-ActSecretsFile {
    <#
    .SYNOPSIS
        Create a secrets file for act
    #>
    param(
        [hashtable]$Secrets
    )
    
    $secretsFile = Join-Path $env:TEMP "act-secrets-$(Get-Random).env"
    
    # Add default GITHUB_TOKEN if not provided
    if (-not $Secrets.ContainsKey('GITHUB_TOKEN')) {
        $Secrets['GITHUB_TOKEN'] = 'dummy-token-for-testing'
    }
    
    $secretsContent = @()
    foreach ($key in $Secrets.Keys) {
        $secretsContent += "$key=$($Secrets[$key])"
    }
    
    $secretsContent -join "`n" | Set-Content -Path $secretsFile
    Write-TestLog "Created secrets file: $secretsFile" -Level Debug
    
    return $secretsFile
}

function New-ActEnvFile {
    <#
    .SYNOPSIS
        Create an environment file for act
    #>
    param(
        [hashtable]$EnvVars
    )
    
    $envFile = Join-Path $env:TEMP "act-env-$(Get-Random).env"
    
    # Add default environment variables
    $defaultEnv = @{
        CI = 'true'
        GITHUB_ACTIONS = 'true'
        GITHUB_ACTOR = 'act-user'
        GITHUB_REPOSITORY = 'local/test'
        GITHUB_WORKFLOW = 'Local Test'
        GITHUB_RUN_ID = Get-Random
        GITHUB_RUN_NUMBER = 1
        GITHUB_SHA = 'abcdef1234567890'
        GITHUB_REF = 'refs/heads/main'
    }
    
    foreach ($key in $defaultEnv.Keys) {
        if (-not $EnvVars.ContainsKey($key)) {
            $EnvVars[$key] = $defaultEnv[$key]
        }
    }
    
    $envContent = @()
    foreach ($key in $EnvVars.Keys) {
        $envContent += "$key=$($EnvVars[$key])"
    }
    
    $envContent -join "`n" | Set-Content -Path $envFile
    Write-TestLog "Created environment file: $envFile" -Level Debug
    
    return $envFile
}

function New-EventPayload {
    <#
    .SYNOPSIS
        Create an event payload file for act
    #>
    param(
        [string]$EventName,
        [string]$CustomPayload
    )
    
    if ($CustomPayload -and (Test-Path $CustomPayload)) {
        return $CustomPayload
    }
    
    $payloadFile = Join-Path $env:TEMP "act-event-$(Get-Random).json"
    
    $payload = switch ($EventName) {
        'push' {
            @{
                ref = "refs/heads/main"
                before = "0000000000000000000000000000000000000000"
                after = "abcdef1234567890abcdef1234567890abcdef12"
                repository = @{
                    name = "test-repo"
                    full_name = "user/test-repo"
                    owner = @{
                        name = "user"
                        email = "user@example.com"
                    }
                }
                pusher = @{
                    name = "user"
                    email = "user@example.com"
                }
                commits = @(
                    @{
                        id = "abcdef1234567890"
                        message = "Test commit"
                        author = @{
                            name = "user"
                            email = "user@example.com"
                        }
                    }
                )
            }
        }
        'pull_request' {
            @{
                action = "opened"
                number = 1
                pull_request = @{
                    id = 1
                    number = 1
                    state = "open"
                    title = "Test PR"
                    body = "Test pull request"
                    head = @{
                        ref = "feature-branch"
                        sha = "abcdef1234567890"
                    }
                    base = @{
                        ref = "main"
                        sha = "1234567890abcdef"
                    }
                }
            }
        }
        'workflow_dispatch' {
            @{
                inputs = @{}
                ref = "refs/heads/main"
                repository = @{
                    name = "test-repo"
                    full_name = "user/test-repo"
                }
            }
        }
        'schedule' {
            @{
                schedule = "0 2 * * *"
                repository = @{
                    name = "test-repo"
                    full_name = "user/test-repo"
                }
            }
        }
        default {
            @{
                repository = @{
                    name = "test-repo"
                    full_name = "user/test-repo"
                }
            }
        }
    }
    
    $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $payloadFile
    Write-TestLog "Created event payload file: $payloadFile" -Level Debug
    
    return $payloadFile
}

function Invoke-ActTest {
    <#
    .SYNOPSIS
        Run act to test the workflow
    #>
    param(
        [string]$WorkflowFile,
        [string]$EventName,
        [string]$Job,
        [string]$Platform,
        [string]$SecretsFile,
        [string]$EnvFile,
        [string]$EventNameFile,
        [bool]$DryRun,
        [bool]$VerboseOutput,
        [bool]$NoCache
    )
    
    $actArgs = @()
    
    # Event type
    $actArgs += $EventName
    
    # Workflow file
    if ($WorkflowFile) {
        $actArgs += "-W", $WorkflowFile
    }
    
    # Specific job
    if ($Job) {
        $actArgs += "-j", $Job
    }
    
    # Platform
    $actArgs += "-P", "$Platform=node:16-buster-slim"
    
    # Secrets file
    if ($SecretsFile) {
        $actArgs += "--secret-file", $SecretsFile
    }
    
    # Environment file
    if ($EnvFile) {
        $actArgs += "--env-file", $EnvFile
    }
    
    # Event payload
    if ($EventNameFile) {
        $actArgs += "-e", $EventNameFile
    }
    
    # Dry run
    if ($DryRun) {
        $actArgs += "-n"
    }
    
    # Verbose
    if ($VerboseOutput) {
        $actArgs += "-v"
    }
    
    # No cache
    if ($NoCache) {
        $actArgs += "--no-cache"
    }
    
    # Run act
    Write-TestLog "Running: act $($actArgs -join ' ')" -Level Information
    
    $process = Start-Process -FilePath "act" -ArgumentList $actArgs -NoNewWindow -PassThru -Wait
    
    return $process.ExitCode -eq 0
}

# Main execution
try {
    Write-TestLog "Starting local workflow testing..." -Level Information
    
    # Install dependencies if requested
    if ($InstallDependencies) {
        Write-TestLog "Installing dependencies..." -Level Information
        
        if (-not (Test-ActInstalled)) {
            Install-Act
        } else {
            Write-TestLog "act is already installed" -Level Information
        }
        
        if (-not (Test-DockerInstalled)) {
            Write-TestLog "Docker is required but not installed or not running" -Level Error
            Write-TestLog "Please install Docker Desktop from https://www.docker.com/products/docker-desktop" -Level Information
            throw "Docker is required for local workflow testing"
        }
        
        Write-TestLog "Dependencies installed successfully" -Level Success
        if (-not $WorkflowFile) {
            exit 0
        }
    }
    
    # Check prerequisites and auto-install if configured
    if (-not (Test-ActInstalled)) {
        # Check if we should auto-install dependencies
        $autoInstall = if (Get-Command Get-ConfiguredValue -ErrorAction SilentlyContinue) {
            Get-ConfiguredValue -Name "AutoInstallDependencies" -Section "Automation" -Default $true
        } else {
            $false
        }
        
        if ($autoInstall -or $InstallDependencies) {
            if ($WhatIfPreference) {
                Write-TestLog "What if: Would auto-install act" -Level Information
                Write-TestLog "To actually install, run without -WhatIf or use: ./az 0442" -Level Warning
                return
            }
            
            Write-TestLog "act is not installed. Auto-installing..." -Level Information
            
            # Install using the dedicated script
            $installScript = Join-Path $PSScriptRoot "0442_Install-Act.ps1"
            if (Test-Path $installScript) {
                try {
                    & $installScript -CI:$CI -Force
                    
                    # Verify installation succeeded (only if not in WhatIf mode)
                    if (-not (Test-ActInstalled)) {
                        Write-TestLog "Installation completed but act not found in PATH" -Level Warning
                        Write-TestLog "You may need to restart your shell or add act to PATH manually" -Level Information
                        
                        # Check common locations
                        $possiblePaths = @(
                            "$HOME/.local/bin/act",
                            "/usr/local/bin/act",
                            "$env:LOCALAPPDATA\Microsoft\WindowsApps\act.exe"
                        )
                        
                        foreach ($path in $possiblePaths) {
                            if (Test-Path $path) {
                                Write-TestLog "Found act at: $path" -Level Information
                                Write-TestLog "Add this directory to your PATH to use act" -Level Information
                                break
                            }
                        }
                        
                        throw "act installed but not in PATH. Please restart your shell or add to PATH manually."
                    }
                    
                    Write-TestLog "act installed successfully" -Level Success
                } catch {
                    Write-TestLog "Failed to install act: $_" -Level Error
                    throw "Failed to install act automatically: $_"
                }
            } else {
                throw "Installation script not found: 0442_Install-Act.ps1"
            }
        } else {
            throw "act is not installed. Enable AutoInstallDependencies in config or use -InstallDependencies parameter"
        }
    }
    
    if (-not (Test-DockerInstalled)) {
        if ($WhatIfPreference) {
            Write-TestLog "What if: Would check Docker installation" -Level Information
            Write-TestLog "Docker is required for act to run containers" -Level Warning
            return
        }
        
        # Docker can't be auto-installed easily, but provide better guidance
        $autoInstall = if (Get-Command Get-ConfiguredValue -ErrorAction SilentlyContinue) {
            Get-ConfiguredValue -Name "AutoInstallDependencies" -Section "Automation" -Default $true
        } else {
            $false
        }
        
        if ($autoInstall -or $InstallDependencies) {
            Write-TestLog "Docker is required but not installed or not running" -Level Warning
            Write-TestLog "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop" -Level Information
            Write-TestLog "Or if Docker is installed, ensure Docker Desktop is running" -Level Information
        }
        
        throw "Docker is not installed or not running. Please start Docker Desktop"
    }
    
    # If no workflow specified, list available workflows
    if (-not $WorkflowFile) {
        Write-TestLog "No workflow specified. Available workflows:" -Level Information
        
        $workflowPath = Join-Path $script:ProjectRoot ".github/workflows"
        if (Test-Path $workflowPath) {
            $workflows = Get-ChildItem -Path $workflowPath -Filter "*.yml"
            $workflows += Get-ChildItem -Path $workflowPath -Filter "*.yaml"
            
            foreach ($wf in $workflows) {
                Write-Host "  - $($wf.Name)"
            }
            
            Write-Host ""
            Write-Host "Usage: $($MyInvocation.MyCommand.Name) -WorkflowFile <path> -Event <event>"
        } else {
            Write-TestLog "No .github/workflows directory found" -Level Warning
        }
        exit 0
    }
    
    # Validate workflow file exists
    if (-not (Test-Path $WorkflowFile)) {
        # Try to find it in .github/workflows
        $altPath = Join-Path $script:ProjectRoot ".github/workflows" $WorkflowFile
        if (Test-Path $altPath) {
            $WorkflowFile = $altPath
        } else {
            throw "Workflow file not found: $WorkflowFile"
        }
    }
    
    Write-TestLog "Testing workflow: $WorkflowFile" -Level Information
    Write-TestLog "Event: $EventName" -Level Information
    if ($Job) {
        Write-TestLog "Job: $Job" -Level Information
    }
    Write-TestLog "Platform: $Platform" -Level Information
    
    # Create temporary files
    $secretsFile = $null
    $envFile = $null
    $EventNameFile = $null
    
    try {
        if ($PSCmdlet.ShouldProcess($WorkflowFile, "Test workflow locally")) {
            # Create secrets file
            if ($Secrets.Count -gt 0 -or -not $Secrets.ContainsKey('GITHUB_TOKEN')) {
                $secretsFile = New-ActSecretsFile -Secrets $Secrets
            }
            
            # Create environment file
            $envFile = New-ActEnvFile -EnvVars $EnvVars
            
            # Create event payload
            $EventNameFile = New-EventPayload -Event $EventName -CustomPayload $EventNamePayload
            
            # Run act
            $success = Invoke-ActTest `
                -WorkflowFile $WorkflowFile `
                -Event $EventName `
                -Job $Job `
                -Platform $Platform `
                -SecretsFile $secretsFile `
                -EnvFile $envFile `
                -EventFile $EventNameFile `
                -DryRun $DryRun `
                -VerboseOutput $VerboseOutput `
                -NoCache $NoCache
            
            if ($success) {
                Write-TestLog "Workflow test completed successfully" -Level Success
                if ($CI) {
                    exit 0
                }
                return $true
            } else {
                Write-TestLog "Workflow test failed" -Level Error
                if ($CI) {
                    exit 1
                }
                return $false
            }
        }
    }
    finally {
        # Clean up temporary files
        if ($secretsFile -and (Test-Path $secretsFile)) {
            Remove-Item $secretsFile -Force
        }
        if ($envFile -and (Test-Path $envFile)) {
            Remove-Item $envFile -Force
        }
        if ($EventNameFile -and (Test-Path $EventNameFile)) {
            Remove-Item $EventNameFile -Force
        }
    }
}
catch {
    Write-TestLog "Workflow test failed: $_" -Level Error
    if ($CI) {
        exit 1
    }
    throw
}