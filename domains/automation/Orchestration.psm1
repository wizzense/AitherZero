#Requires -Version 7.0

<#
.SYNOPSIS
    Consolidated Automation and Orchestration for AitherZero
.DESCRIPTION
    Unified orchestration engine providing workflow execution, playbook management,
    and automated deployment capabilities.
.NOTES
    Consolidated from:
    - domains/automation/OrchestrationEngine.psm1
    - domains/automation/DeploymentAutomation.psm1
#>

# Script variables
$script:PlaybookCache = @{}
$script:ExecutionHistory = @()
$script:DefaultConfig = @{
    MaxConcurrency = 4
    TimeoutMinutes = 30
    ContinueOnError = $false
    LogLevel = 'Information'
}

function Invoke-OrchestrationSequence {
    <#
    .SYNOPSIS
        Execute a sequence of automation scripts in order
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string[]]$Sequence,
        
        [hashtable]$Configuration = @{},
        [hashtable]$Variables = @{},
        [switch]$DryRun,
        [switch]$Parallel,
        [int]$MaxJobs = 4,
        [int]$TimeoutMinutes = 30,
        [switch]$ContinueOnError,
        [string]$LogPath
    )

    $config = $script:DefaultConfig.Clone()
    foreach ($key in $Configuration.Keys) {
        $config[$key] = $Configuration[$key]
    }

    if ($LogPath) {
        $config.LogPath = $LogPath
    }

    Write-Host "🚀 Starting orchestration sequence..." -ForegroundColor Cyan
    Write-Host "Sequence: $($Sequence -join ' → ')" -ForegroundColor Gray

    $executionId = [Guid]::NewGuid().ToString()
    $startTime = Get-Date
    $results = @{}

    try {
        if ($Parallel -and $Sequence.Count -gt 1) {
            $results = Invoke-ParallelSequence -Sequence $Sequence -Configuration $config -Variables $Variables -MaxJobs $MaxJobs -DryRun:$DryRun
        } else {
            $results = Invoke-SequentialSequence -Sequence $Sequence -Configuration $config -Variables $Variables -DryRun:$DryRun -ContinueOnError:$ContinueOnError
        }

        $duration = (Get-Date) - $startTime
        Write-Host "✅ Orchestration completed in $($duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Green

        # Record execution history
        $execution = @{
            Id = $executionId
            Sequence = $Sequence
            StartTime = $startTime
            EndTime = Get-Date
            Duration = $duration
            Results = $results
            Success = ($results.Values | Where-Object { $_.ExitCode -ne 0 }).Count -eq 0
        }
        $script:ExecutionHistory += $execution

        return $results
    }
    catch {
        $duration = (Get-Date) - $startTime
        Write-Host "❌ Orchestration failed after $($duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Invoke-SequentialSequence {
    <#
    .SYNOPSIS
        Execute scripts sequentially
    #>
    [CmdletBinding()]
    param(
        [string[]]$Sequence,
        [hashtable]$Configuration,
        [hashtable]$Variables,
        [switch]$DryRun,
        [switch]$ContinueOnError
    )

    $results = @{}
    $scriptsPath = Join-Path $env:AITHERZERO_ROOT "automation-scripts"

    foreach ($scriptId in $Sequence) {
        Write-Host "📋 Executing: $scriptId" -ForegroundColor Cyan

        if ($DryRun) {
            Write-Host "   [DRY RUN] Would execute script $scriptId" -ForegroundColor Yellow
            $results[$scriptId] = @{
                ExitCode = 0
                Output = "DRY RUN - Not executed"
                Duration = [TimeSpan]::Zero
            }
            continue
        }

        $scriptFiles = Get-ChildItem -Path $scriptsPath -Filter "${scriptId}*.ps1" -ErrorAction SilentlyContinue
        
        if ($scriptFiles.Count -eq 0) {
            $errorMsg = "Script not found: ${scriptId}*.ps1"
            Write-Host "   ❌ $errorMsg" -ForegroundColor Red
            $results[$scriptId] = @{
                ExitCode = 1
                Output = $errorMsg
                Duration = [TimeSpan]::Zero
            }
            
            if (-not $ContinueOnError) {
                throw $errorMsg
            }
            continue
        }

        $scriptFile = $scriptFiles[0].FullName
        $startTime = Get-Date

        try {
            # Prepare parameters
            $scriptParams = @{}
            foreach ($key in $Variables.Keys) {
                $scriptParams[$key] = $Variables[$key]
            }

            # Execute script
            $output = & $scriptFile @scriptParams 2>&1
            $exitCode = $LASTEXITCODE

            $duration = (Get-Date) - $startTime
            
            $results[$scriptId] = @{
                ExitCode = $exitCode ?? 0
                Output = $output -join "`n"
                Duration = $duration
                ScriptPath = $scriptFile
            }

            if ($exitCode -eq 0) {
                Write-Host "   ✅ Completed in $($duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Green
            } else {
                Write-Host "   ❌ Failed with exit code $exitCode" -ForegroundColor Red
                if (-not $ContinueOnError) {
                    throw "Script $scriptId failed with exit code $exitCode"
                }
            }
        }
        catch {
            $duration = (Get-Date) - $startTime
            $results[$scriptId] = @{
                ExitCode = 1
                Output = $_.Exception.Message
                Duration = $duration
                ScriptPath = $scriptFile
            }

            Write-Host "   ❌ Exception: $($_.Exception.Message)" -ForegroundColor Red
            if (-not $ContinueOnError) {
                throw
            }
        }
    }

    return $results
}

function Invoke-ParallelSequence {
    <#
    .SYNOPSIS
        Execute scripts in parallel
    #>
    [CmdletBinding()]
    param(
        [string[]]$Sequence,
        [hashtable]$Configuration,
        [hashtable]$Variables,
        [int]$MaxJobs = 4,
        [switch]$DryRun
    )

    Write-Host "🔀 Running $($Sequence.Count) scripts in parallel (max $MaxJobs jobs)" -ForegroundColor Cyan

    $jobs = @{}
    $results = @{}
    $scriptsPath = Join-Path $env:AITHERZERO_ROOT "automation-scripts"

    # Start jobs
    foreach ($scriptId in $Sequence) {
        while ($jobs.Count -ge $MaxJobs) {
            # Wait for a job to complete
            $completedJob = $jobs.Values | Where-Object { $_.State -ne 'Running' } | Select-Object -First 1
            if ($completedJob) {
                $scriptId = $completedJob.Name
                $results[$scriptId] = Receive-Job $completedJob -Wait
                Remove-Job $completedJob
                $jobs.Remove($scriptId)
            } else {
                Start-Sleep -Milliseconds 100
            }
        }

        if ($DryRun) {
            $results[$scriptId] = @{
                ExitCode = 0
                Output = "DRY RUN - Not executed"
                Duration = [TimeSpan]::Zero
            }
            continue
        }

        $scriptFiles = Get-ChildItem -Path $scriptsPath -Filter "${scriptId}*.ps1" -ErrorAction SilentlyContinue
        if ($scriptFiles.Count -eq 0) {
            $results[$scriptId] = @{
                ExitCode = 1
                Output = "Script not found: ${scriptId}*.ps1"
                Duration = [TimeSpan]::Zero
            }
            continue
        }

        $scriptFile = $scriptFiles[0].FullName
        $job = Start-Job -Name $scriptId -ScriptBlock {
            param($ScriptPath, $Variables)
            $startTime = Get-Date
            try {
                $output = & $ScriptPath @Variables 2>&1
                $exitCode = $LASTEXITCODE
                return @{
                    ExitCode = $exitCode ?? 0
                    Output = $output -join "`n"
                    Duration = (Get-Date) - $startTime
                    ScriptPath = $ScriptPath
                }
            }
            catch {
                return @{
                    ExitCode = 1
                    Output = $_.Exception.Message
                    Duration = (Get-Date) - $startTime
                    ScriptPath = $ScriptPath
                }
            }
        } -ArgumentList $scriptFile, $Variables

        $jobs[$scriptId] = $job
    }

    # Wait for all jobs to complete
    while ($jobs.Count -gt 0) {
        $completedJob = $jobs.Values | Where-Object { $_.State -ne 'Running' } | Select-Object -First 1
        if ($completedJob) {
            $scriptId = $completedJob.Name
            $results[$scriptId] = Receive-Job $completedJob -Wait
            Remove-Job $completedJob
            $jobs.Remove($scriptId)
        } else {
            Start-Sleep -Milliseconds 100
        }
    }

    return $results
}

function Get-OrchestrationPlaybook {
    <#
    .SYNOPSIS
        Load and parse an orchestration playbook
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Profile,
        [string]$PlaybookPath
    )

    if (-not $PlaybookPath) {
        $PlaybookPath = Join-Path $env:AITHERZERO_ROOT "orchestration/playbooks"
    }

    # Try to find playbook file
    $possiblePaths = @(
        (Join-Path $PlaybookPath "$Name.json"),
        (Join-Path $PlaybookPath "*/$Name.json")
    )

    $playbookFile = $null
    foreach ($path in $possiblePaths) {
        $files = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        if ($files) {
            $playbookFile = $files[0].FullName
            break
        }
    }

    if (-not $playbookFile) {
        throw "Playbook not found: $Name"
    }

    # Load and parse playbook
    $playbookContent = Get-Content -Path $playbookFile -Raw | ConvertFrom-Json
    
    # Apply profile-specific settings if specified
    if ($Profile -and $playbookContent.profiles -and $playbookContent.profiles.$Profile) {
        $profileSettings = $playbookContent.profiles.$Profile
        foreach ($key in $profileSettings.PSObject.Properties.Name) {
            $playbookContent.$key = $profileSettings.$key
        }
    }

    # Cache the playbook
    $script:PlaybookCache[$Name] = $playbookContent

    return $playbookContent
}

function Save-OrchestrationPlaybook {
    <#
    .SYNOPSIS
        Save a playbook configuration
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [hashtable]$Configuration,
        
        [string]$PlaybookPath,
        [string]$Category = 'custom'
    )

    if (-not $PlaybookPath) {
        $PlaybookPath = Join-Path $env:AITHERZERO_ROOT "orchestration/playbooks/$Category"
    }

    if (-not (Test-Path $PlaybookPath)) {
        New-Item -ItemType Directory -Path $PlaybookPath -Force | Out-Null
    }

    $filePath = Join-Path $PlaybookPath "$Name.json"

    if ($PSCmdlet.ShouldProcess($filePath, "Save playbook")) {
        $Configuration | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
        Write-Host "Playbook saved: $filePath" -ForegroundColor Green
        return $filePath
    }
}

function Invoke-Sequence {
    <#
    .SYNOPSIS
        Alias for Invoke-OrchestrationSequence
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string[]]$Sequence,
        
        [hashtable]$Configuration = @{},
        [hashtable]$Variables = @{}
    )

    return Invoke-OrchestrationSequence -Sequence $Sequence -Configuration $Configuration -Variables $Variables
}

function Get-ExecutionHistory {
    <#
    .SYNOPSIS
        Get orchestration execution history
    #>
    [CmdletBinding()]
    param(
        [int]$Last = 10
    )

    return $script:ExecutionHistory | Sort-Object StartTime -Descending | Select-Object -First $Last
}

function New-SimplePlaybook {
    <#
    .SYNOPSIS
        Create a simple playbook quickly
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string[]]$Scripts,
        
        [string]$Description,
        [hashtable]$Variables = @{},
        [string]$Category = 'custom'
    )

    $playbook = @{
        name = $Name
        description = $Description
        category = $Category
        scripts = $Scripts
        variables = $Variables
        options = @{
            continueOnError = $false
            parallel = $false
            timeout = 300
        }
    }

    return Save-OrchestrationPlaybook -Name $Name -Configuration $playbook -Category $Category
}

# Create aliases
Set-Alias -Name 'seq' -Value 'Invoke-OrchestrationSequence' -Scope Global -Force

# Export functions
Export-ModuleMember -Function @(
    'Invoke-OrchestrationSequence',
    'Invoke-Sequence',
    'Get-OrchestrationPlaybook',
    'Save-OrchestrationPlaybook',
    'Get-ExecutionHistory',
    'New-SimplePlaybook'
) -Alias @('seq')