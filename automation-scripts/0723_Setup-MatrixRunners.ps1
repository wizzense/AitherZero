#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Setup Matrix of GitHub Actions Self-Hosted Runners
.DESCRIPTION
    Provisions a matrix of GitHub Actions runners across different platforms and configurations
.PARAMETER Organization
    GitHub organization/owner name
.PARAMETER Repository
    Repository name (optional, for repo-level runners)
.PARAMETER Matrix
    Runner matrix configuration file path or predefined matrix name
.PARAMETER Token
    GitHub Personal Access Token
.PARAMETER DryRun
    Validate configuration without making changes
.PARAMETER Parallel
    Setup runners in parallel (default: true)
.PARAMETER MaxConcurrency
    Maximum number of parallel operations (default: 4)
.PARAMETER CI
    Run in CI mode with minimal output
.EXAMPLE
    ./0723_Setup-MatrixRunners.ps1 -Organization "myorg" -Matrix "standard"
.EXAMPLE
    ./0723_Setup-MatrixRunners.ps1 -Organization "myorg" -Repository "myrepo" -Matrix "./custom-matrix.json"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Organization,
    [string]$Repository,
    [string]$Matrix = 'standard',
    [string]$Token,
    [switch]$DryRun,
    [bool]$Parallel = $true,
    [int]$MaxConcurrency = 4,
    [switch]$CI
)

#region Metadata
$script:Stage = "Infrastructure"
$script:Dependencies = @('0720', '0721', '0722')
$script:Tags = @('github', 'runners', 'matrix', 'parallel')
$script:Condition = '$IsAdmin -and (Get-Command gh -ErrorAction SilentlyContinue)'
#endregion

# Import required modules and functions
if (Test-Path "$PSScriptRoot/../domains/core/Logging.psm1") {
    Import-Module "$PSScriptRoot/../domains/core/Logging.psm1" -Force
}

function Write-MatrixLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "MatrixRunners"
    } else {
        Write-Host "[$Level] $Message"
    }
}

function Get-PredefinedMatrix {
    param([string]$MatrixName)

    $predefinedMatrices = @{
        'minimal' = @{
            Description = "Single runner on current platform"
            Runners = @(
                @{
                    Name = "minimal-runner"
                    Platform = "Auto"
                    Profile = "Minimal"
                    Labels = @("minimal")
                    Count = 1
                }
            )
        }
        'standard' = @{
            Description = "Standard cross-platform runners"
            Runners = @(
                @{
                    Name = "windows-runner"
                    Platform = "Windows"
                    Profile = "Standard"
                    Labels = @("windows", "standard")
                    Count = 2
                },
                @{
                    Name = "linux-runner"
                    Platform = "Linux"
                    Profile = "Standard"
                    Labels = @("linux", "standard")
                    Count = 2
                },
                @{
                    Name = "macos-runner"
                    Platform = "macOS"
                    Profile = "Standard"
                    Labels = @("macos", "standard")
                    Count = 1
                }
            )
        }
        'developer' = @{
            Description = "Development-focused runners with full toolchain"
            Runners = @(
                @{
                    Name = "dev-windows"
                    Platform = "Windows"
                    Profile = "Developer"
                    Labels = @("windows", "developer", "docker", "buildx")
                    Count = 2
                },
                @{
                    Name = "dev-linux"
                    Platform = "Linux"
                    Profile = "Developer"
                    Labels = @("linux", "developer", "docker", "buildx")
                    Count = 3
                },
                @{
                    Name = "dev-macos"
                    Platform = "macOS"
                    Profile = "Developer"
                    Labels = @("macos", "developer", "xcode")
                    Count = 1
                }
            )
        }
        'build-farm' = @{
            Description = "High-capacity build farm"
            Runners = @(
                @{
                    Name = "build-windows"
                    Platform = "Windows"
                    Profile = "Full"
                    Labels = @("windows", "build", "msbuild", "dotnet")
                    Count = 4
                },
                @{
                    Name = "build-linux"
                    Platform = "Linux"
                    Profile = "Full"
                    Labels = @("linux", "build", "docker", "kubernetes")
                    Count = 6
                },
                @{
                    Name = "test-linux"
                    Platform = "Linux"
                    Profile = "Standard"
                    Labels = @("linux", "test", "selenium")
                    Count = 3
                }
            )
        }
        'current-platform' = @{
            Description = "Multiple runners on current platform only"
            Runners = @(
                @{
                    Name = "current-platform"
                    Platform = "Auto"
                    Profile = "Developer"
                    Labels = @("current-platform")
                    Count = 3
                }
            )
        }
    }

    return $predefinedMatrices[$MatrixName]
}

function Read-MatrixConfiguration {
    param([string]$MatrixPath)

    Write-MatrixLog "Reading matrix configuration from: $MatrixPath" -Level Information

    if (Test-Path $MatrixPath) {
        try {
            $content = Get-Content $MatrixPath -Raw | ConvertFrom-Json
            Write-MatrixLog "Matrix configuration loaded from file" -Level Success
            return $content
        } catch {
            Write-MatrixLog "Failed to parse matrix file: $($_.Exception.Message)" -Level Error
            throw
        }
    } else {
        # Try predefined matrix
        $predefined = Get-PredefinedMatrix -MatrixName $MatrixPath
        if ($predefined) {
            Write-MatrixLog "Using predefined matrix: $MatrixPath" -Level Information
            return $predefined
        } else {
            throw "Matrix configuration not found: $MatrixPath"
        }
    }
}

function Test-MatrixConfiguration {
    param([hashtable]$MatrixConfig)

    Write-MatrixLog "Validating matrix configuration..." -Level Information

    $issues = @()

    # Check basic structure
    if (-not $MatrixConfig.Runners) {
        $issues += "Matrix configuration missing 'Runners' section"
    } elseif ($MatrixConfig.Runners.Count -eq 0) {
        $issues += "Matrix configuration contains no runners"
    }

    # Validate each runner configuration
    $totalRunners = 0
    foreach ($runner in $MatrixConfig.Runners) {
        if (-not $runner.Name) {
            $issues += "Runner missing required 'Name' property"
        }

        if (-not $runner.Platform) {
            $issues += "Runner '$($runner.Name)' missing required 'Platform' property"
        }

        if (-not $runner.Profile) {
            $runner.Profile = "Standard"  # Default profile
        }

        if (-not $runner.Count) {
            $runner.Count = 1  # Default count
        }

        $totalRunners += $runner.Count
    }

    # Check total runner count
    if ($totalRunners -gt 20) {
        $issues += "Total runner count ($totalRunners) exceeds recommended maximum (20)"
    }

    if ($issues.Count -gt 0) {
        Write-MatrixLog "Matrix validation issues:" -Level Error
        $issues | ForEach-Object { Write-MatrixLog "  - $_" -Level Error }
        return $false
    }

    Write-MatrixLog "Matrix configuration validated - $totalRunners total runners" -Level Success
    return $true
}

function Get-PlatformSupport {
    param([string]$Platform)

    $currentPlatform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }

    switch ($Platform) {
        'Auto' { return @{ Supported = $true; ActualPlatform = $currentPlatform } }
        'Windows' { return @{ Supported = $IsWindows; ActualPlatform = 'Windows' } }
        'Linux' { return @{ Supported = $IsLinux; ActualPlatform = 'Linux' } }
        'macOS' { return @{ Supported = $IsMacOS; ActualPlatform = 'macOS' } }
        default { return @{ Supported = $false; ActualPlatform = $null } }
    }
}

function Setup-RunnerConfiguration {
    param(
        [hashtable]$RunnerConfig,
        [string]$Organization,
        [string]$Repository,
        [string]$Token,
        [int]$Index
    )

    $runnerName = if ($Repository) {
        "$($RunnerConfig.Name)-$($Repository)-$Index"
    } else {
        "$($RunnerConfig.Name)-$Organization-$Index"
    }

    $platformSupport = Get-PlatformSupport -Platform $RunnerConfig.Platform

    if (-not $platformSupport.Supported) {
        Write-MatrixLog "Skipping runner $runnerName - platform $($RunnerConfig.Platform) not supported on current system" -Level Warning
        return @{ Success = $false; Reason = "Platform not supported"; Name = $runnerName }
    }

    Write-MatrixLog "Setting up runner: $runnerName" -Level Information

    try {
        # Build labels
        $labels = @($RunnerConfig.Labels)
        $labels += $platformSupport.ActualPlatform.ToLower()
        $labels += $RunnerConfig.Profile.ToLower()
        $allLabels = ($labels | Sort-Object -Unique) -join ','

        # Setup runner using 0720 script
        $setupArgs = @{
            Organization = $Organization
            RunnerCount = 1
            Platform = $platformSupport.ActualPlatform
            Labels = $allLabels
            Token = $Token
            DryRun = $DryRun
            CI = $CI
        }

        if ($Repository) {
            $setupArgs.Repository = $Repository
        }

        if ($DryRun) {
            Write-MatrixLog "[DRY RUN] Would setup runner $runnerName with labels: $allLabels" -Level Information
            $setupResult = @{ Success = $true }
        } else {
            # Execute runner setup script
            $setupScript = "$PSScriptRoot/0720_Setup-GitHubRunners.ps1"
            if (-not (Test-Path $setupScript)) {
                throw "Runner setup script not found: $setupScript"
            }

            & $setupScript @setupArgs
            $setupResult = @{ Success = ($LASTEXITCODE -eq 0) }
        }

        if ($setupResult.Success) {
            Write-MatrixLog "✓ Runner setup completed: $runnerName" -Level Success

            # Configure environment using 0721 script
            if (-not $DryRun) {
                $envArgs = @{
                    Profile = $RunnerConfig.Profile
                    Platform = $platformSupport.ActualPlatform
                    CI = $CI
                }

                $envScript = "$PSScriptRoot/0721_Configure-RunnerEnvironment.ps1"
                if (Test-Path $envScript) {
                    & $envScript @envArgs
                    Write-MatrixLog "✓ Runner environment configured: $runnerName" -Level Success
                } else {
                    Write-MatrixLog "Warning: Environment configuration script not found" -Level Warning
                }

                # Install as service using 0722 script
                $serviceArgs = @{
                    RunnerName = $runnerName
                    CI = $CI
                }

                $serviceScript = "$PSScriptRoot/0722_Install-RunnerServices.ps1"
                if (Test-Path $serviceScript) {
                    & $serviceScript @serviceArgs
                    Write-MatrixLog "✓ Runner service installed: $runnerName" -Level Success
                } else {
                    Write-MatrixLog "Warning: Service installation script not found" -Level Warning
                }
            }
        }

        return @{
            Success = $setupResult.Success
            Name = $runnerName
            Platform = $platformSupport.ActualPlatform
            Labels = $allLabels
            Profile = $RunnerConfig.Profile
        }

    } catch {
        Write-MatrixLog "Failed to setup runner $runnerName`: $($_.Exception.Message)" -Level Error
        return @{ Success = $false; Reason = $_.Exception.Message; Name = $runnerName }
    }
}

function Setup-RunnersParallel {
    param(
        [array]$RunnerJobs,
        [int]$MaxConcurrencyValue
    )

    Write-MatrixLog "Setting up $($RunnerJobs.Count) runners in parallel (max concurrency: $MaxConcurrencyValue)" -Level Information

    if ($DryRun) {
        Write-MatrixLog "[DRY RUN] Would setup runners in parallel" -Level Information
        return $RunnerJobs | ForEach-Object { @{ Success = $true; Name = $_.Name } }
    }

    # Import ThreadJob module if available
    if (-not (Get-Module ThreadJob -ErrorAction SilentlyContinue)) {
        try {
            Import-Module ThreadJob -Force
        } catch {
            Write-MatrixLog "ThreadJob module not available, falling back to sequential execution" -Level Warning
            return Setup-RunnersSequential -RunnerJobs $RunnerJobs
        }
    }

    $results = @()
    $jobBatches = @()

    # Split jobs into batches
    for ($i = 0; $i -lt $RunnerJobs.Count; $i += $MaxConcurrencyValue) {
        $end = [Math]::Min($i + $MaxConcurrencyValue - 1, $RunnerJobs.Count - 1)
        $jobBatches += ,@($RunnerJobs[$i..$end])
    }

    foreach ($batch in $jobBatches) {
        Write-MatrixLog "Processing batch of $($batch.Count) runners..." -Level Information

        $jobs = @()
        foreach ($runnerJob in $batch) {
            $job = Start-ThreadJob -ScriptBlock {
                param($RunnerConfig, $Organization, $Repository, $Token, $Index, $ScriptRoot)

                # Re-import functions in thread context
                . "$ScriptRoot/0723_Setup-MatrixRunners.ps1"

                Setup-RunnerConfiguration -RunnerConfig $RunnerConfig -Organization $Organization -Repository $Repository -Token $Token -Index $Index
            } -ArgumentList $runnerJob.Config, $Organization, $Repository, $Token, $runnerJob.Index, $PSScriptRoot

            $jobs += @{ Job = $job; Name = $runnerJob.Name }
        }

        # Wait for batch to complete
        $batchResults = $jobs | ForEach-Object {
            $result = Receive-Job -Job $_.Job -Wait
            Remove-Job -Job $_.Job -Force
            $result
        }

        $results += $batchResults

        # Brief pause between batches
        if ($jobBatches.IndexOf($batch) -lt $jobBatches.Count - 1) {
            Start-Sleep -Seconds 2
        }
    }

    return $results
}

function Setup-RunnersSequential {
    param([array]$RunnerJobs)

    Write-MatrixLog "Setting up $($RunnerJobs.Count) runners sequentially" -Level Information

    $results = @()
    foreach ($runnerJob in $RunnerJobs) {
        $result = Setup-RunnerConfiguration -RunnerConfig $runnerJob.Config -Organization $Organization -Repository $Repository -Token $Token -Index $runnerJob.Index
        $results += $result
    }

    return $results
}

# Main execution
try {
    Write-MatrixLog "Starting GitHub Actions matrix runner setup..." -Level Information
    Write-MatrixLog "Organization: $Organization" -Level Information
    if ($Repository) {
        Write-MatrixLog "Repository: $Repository" -Level Information
    }
    Write-MatrixLog "Matrix: $Matrix" -Level Information

    if ($DryRun) {
        Write-MatrixLog "Running in DRY RUN mode - no changes will be made" -Level Warning
    }

    # Read matrix configuration
    $matrixConfig = Read-MatrixConfiguration -MatrixPath $Matrix
    Write-MatrixLog "Matrix: $($matrixConfig.Description)" -Level Information

    # Validate matrix configuration
    if (-not (Test-MatrixConfiguration -MatrixConfig $matrixConfig)) {
        throw "Matrix configuration validation failed"
    }

    # Get GitHub token
    if (-not $Token) {
        if ($env:GITHUB_TOKEN) {
            $Token = $env:GITHUB_TOKEN
            Write-MatrixLog "Using GitHub token from environment variable" -Level Information
        } elseif (-not $CI) {
            $secureToken = Read-Host "Enter GitHub token" -AsSecureString
            $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
        } else {
            throw "GitHub token required. Set -Token parameter or GITHUB_TOKEN environment variable"
        }
    }

    # Build runner job list
    $runnerJobs = @()
    foreach ($runnerConfig in $matrixConfig.Runners) {
        for ($i = 1; $i -le $runnerConfig.Count; $i++) {
            $runnerJobs += @{
                Config = $runnerConfig
                Index = $i
                Name = "$($runnerConfig.Name)-$i"
            }
        }
    }

    Write-MatrixLog "Total runners to setup: $($runnerJobs.Count)" -Level Information

    # Setup runners
    $results = if ($Parallel -and $runnerJobs.Count -gt 1) {
        Setup-RunnersParallel -RunnerJobs $runnerJobs -MaxConcurrencyValue $MaxConcurrency
    } else {
        Setup-RunnersSequential -RunnerJobs $runnerJobs
    }

    # Analyze results
    $successful = @($results | Where-Object { $_.Success })
    $failed = @($results | Where-Object { -not $_.Success })

    Write-MatrixLog "Matrix runner setup completed:" -Level Information
    Write-MatrixLog "  Successful: $($successful.Count)" -Level Success
    Write-MatrixLog "  Failed: $($failed.Count)" -Level $(if ($failed.Count -gt 0) { 'Warning' } else { 'Success' })

    if ($successful.Count -gt 0) {
        Write-MatrixLog "Successfully configured runners:" -Level Success
        $successful | ForEach-Object {
            Write-MatrixLog "  - $($_.Name) [$($_.Platform)] {$($_.Labels)}" -Level Success
        }
    }

    if ($failed.Count -gt 0) {
        Write-MatrixLog "Failed runners:" -Level Warning
        $failed | ForEach-Object {
            Write-MatrixLog "  - $($_.Name): $($_.Reason)" -Level Warning
        }
    }

    if (-not $CI) {
        Write-Host "`nMatrix runner setup complete!" -ForegroundColor Green
        Write-Host "Matrix: $($matrixConfig.Description)" -ForegroundColor Cyan
        Write-Host "Successful: $($successful.Count) / $($results.Count)" -ForegroundColor $(if ($failed.Count -eq 0) { 'Green' } else { 'Yellow' })

        if ($successful.Count -gt 0) {
            Write-Host "`nUpdate your workflows to use these runners:" -ForegroundColor Yellow
            $successful | Group-Object Platform | ForEach-Object {
                $platform = $_.Name.ToLower()
                $labels = ($_.Group.Labels | Sort-Object -Unique) -join ', '
                Write-Host "  runs-on: [self-hosted, $platform]  # Available labels: $labels" -ForegroundColor White
            }
        }
    }

    exit $(if ($failed.Count -eq 0) { 0 } else { 1 })

} catch {
    Write-MatrixLog "Matrix runner setup failed: $($_.Exception.Message)" -Level Error
    exit 1
}
