#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Deployment Automation - Core automation engine
.DESCRIPTION
    Provides parallel execution, dependency resolution, and automated deployment capabilities
    Migrated from LabRunner with enhanced functionality for the domain-based architecture
#>

# Module initialization
$script:ModuleName = "DeploymentAutomation"
$script:ProjectRoot = Split-Path -Parent -Path $PSScriptRoot | Split-Path -Parent
$script:AutomationScriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
$script:DeploymentCache = @{}

# Module initialization - ensure logging is available
$script:LoggingAvailable = $false

try {
    # Try to import from our centralized logging in utilities domain
    $loggingPath = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    } elseif (Get-Module -Name 'Logging' -ListAvailable) {
        Import-Module Logging -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    Write-Warning "Failed to load centralized logging: $_"
}

# Wrapper to ensure we ALWAYS use centralized logging when available
function Write-AutomationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Information'
    )

    # ALWAYS use Write-CustomLog from our centralized logging if available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source $script:ModuleName
    } else {
        # Emergency fallback only
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Trace' = 'DarkGray'
            'Debug' = 'Gray'
            'Information' = 'White'
            'Warning' = 'Yellow'
            'Error' = 'Red'
            'Critical' = 'Magenta'
        }[$Level]
        
        Write-Host "[$timestamp] [$Level] [NOLOG] $Message" -ForegroundColor $color
    }
}

# Get current platform
function Get-DeploymentPlatform {
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) { 
        return 'Windows' 
    }
    elseif ($IsLinux) { 
        return 'Linux' 
    }
    elseif ($IsMacOS) { 
        return 'macOS' 
    }
    else { 
        return 'Unknown' 
    }
}

# Main deployment automation function
function Start-DeploymentAutomation {
    <#
    .SYNOPSIS
        Start automated deployment with parallel execution support
    
    .DESCRIPTION
        Enhanced deployment automation with dependency resolution, parallel execution,
        and comprehensive error handling. Successor to Invoke-ParallelLabRunner.
    
    .PARAMETER Configuration
        Configuration hashtable or path to configuration file
    
    .PARAMETER Scripts
        Array of scripts to execute (optional - will auto-discover if not provided)
    
    .PARAMETER MaxConcurrency
        Maximum number of concurrent executions
    
    .PARAMETER TimeoutMinutes
        Timeout for each script execution
    
    .PARAMETER Stage
        Run specific deployment stage only
    
    .PARAMETER DryRun
        Perform validation without execution
    
    .EXAMPLE
        Start-DeploymentAutomation -Configuration @{Profile="Developer"} -MaxConcurrency 4
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$Configuration,
        
        [Parameter()]
        [array]$Scripts,
        
        [Parameter()]
        [int]$MaxConcurrency = [Environment]::ProcessorCount,
        
        [Parameter()]
        [int]$TimeoutMinutes = 30,
        
        [Parameter()]
        [ValidateSet('Prepare', 'Core', 'Services', 'Configuration', 'Validation', 'All')]
        [string]$Stage = 'All',
        
        [Parameter()]
        [switch]$DryRun,
        
        [Parameter()]
        [switch]$Force
    )

    Write-AutomationLog "Starting AitherZero deployment automation" -Level Information
    Write-AutomationLog "Platform: $(Get-DeploymentPlatform)" -Level Debug
    Write-AutomationLog "Stage: $Stage | MaxConcurrency: $MaxConcurrency" -Level Debug
    
    try {
        # Load configuration
        $config = Resolve-DeploymentConfiguration -Configuration $Configuration
        
        # Discover or validate scripts
        if (-not $Scripts) {
            $Scripts = Get-AutomationScripts -Configuration $config -Stage $Stage
        }
        
        Write-AutomationLog "Found $($Scripts.Count) scripts to execute" -Level Information
        
        # Validate environment
        if (-not $DryRun) {
            Test-DeploymentEnvironment -Configuration $config
        }
        
        # Build execution plan
        $executionPlan = New-ExecutionPlan -Scripts $Scripts -Configuration $config
        
        if ($DryRun) {
            Write-AutomationLog "DRY RUN - Execution plan:" -Level Information
            $executionPlan | ForEach-Object {
                Write-AutomationLog "  - $($_.Name) (Priority: $($_.Priority))" -Level Information
            }
            return $executionPlan
        }
        
        # Execute deployment
        $results = if ($MaxConcurrency -gt 1) {
            Invoke-ParallelExecution -Plan $executionPlan -Configuration $config -MaxConcurrency $MaxConcurrency -Timeout $TimeoutMinutes
        } else {
            Invoke-SequentialExecution -Plan $executionPlan -Configuration $config -Timeout $TimeoutMinutes
        }
        
        # Process results
        $summary = Get-ExecutionSummary -Results $results
        Write-DeploymentSummary -Summary $summary
        
        if ($summary.Failed -gt 0 -and -not $Force) {
            throw "$($summary.Failed) scripts failed during execution"
        }
        
        return $results
        
    } catch {
        Write-AutomationLog "Deployment automation failed: $_" -Level Error
        throw
    }
}

# Resolve configuration
function Resolve-DeploymentConfiguration {
    param([object]$Configuration)

    if ($Configuration -is [string]) {
        if (Test-Path $Configuration) {
            Write-AutomationLog "Loading configuration from: $Configuration" -Level Debug
            return Get-Content $Configuration -Raw | ConvertFrom-Json -AsHashtable
        } else {
            throw "Configuration file not found: $Configuration"
        }
    } elseif ($Configuration -is [hashtable]) {
        return $Configuration
    } elseif ($null -eq $Configuration) {
        # Try to load from default location
        if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
            return Get-Configuration -Section 'Automation' -AsHashtable
        }
        return @{}
    } else {
        return $Configuration
    }
}

# Discover automation scripts
function Get-AutomationScripts {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration,
        [string]$Stage
    )

    $scripts = @()

    # Check configuration for script definitions
    if ($Configuration.Scripts) {
        foreach ($scriptDef in $Configuration.Scripts) {
            if ($Stage -eq 'All' -or $scriptDef.Stage -eq $Stage) {
                $scripts += $scriptDef
            }
        }
    }

    # Auto-discover scripts if none in config
    if ($scripts.Count -eq 0 -and (Test-Path $script:AutomationScriptsPath)) {
        Write-AutomationLog "Auto-discovering scripts from: $script:AutomationScriptsPath" -Level Debug
        
        $scriptFiles = Get-ChildItem -Path $script:AutomationScriptsPath -Filter "*.ps1" | 
            Where-Object { $_.Name -match '^\d{4}_' } |
            Sort-Object Name
        
        foreach ($file in $scriptFiles) {
            # Parse script metadata
            $metadata = Get-ScriptMetadata -Path $file.FullName

            if ($Stage -eq 'All' -or $metadata.Stage -eq $Stage) {
                $scripts += @{
                    Name = $metadata.Name
                    Path = $file.FullName
                    Priority = $metadata.Priority
                    Stage = $metadata.Stage
                    Dependencies = $metadata.Dependencies
                    Parameters = @{}
                }
            }
        }
    }
    
    return $scripts | Sort-Object { $_.Priority }
}

# Get script metadata
function Get-ScriptMetadata {
    param([string]$Path)
    
    $metadata = @{
        Name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        Priority = 50
        Stage = 'Core'
        Dependencies = @()
    }

    # Parse priority from filename (e.g., 0001_ScriptName.ps1)
    if ($metadata.Name -match '^(\d+)_(.+)$') {
        $metadata.Priority = [int]$Matches[1]
        $metadata.Name = $Matches[2].Replace('-', ' ')
    }

    # Try to read metadata from script comments
    $content = Get-Content $Path -First 20
    foreach ($line in $content) {
        if ($line -match '#\s*Stage:\s*(.+)') {
            $metadata.Stage = $Matches[1].Trim()
        }
        if ($line -match '#\s*Dependencies:\s*(.+)') {
            $metadata.Dependencies = $Matches[1].Split(',') | ForEach-Object { $_.Trim() }
        }
        if ($line -notmatch '^#') {
            break
        }
    }
    
    return $metadata
}

# Test deployment environment
function Test-DeploymentEnvironment {
    param([hashtable]$Configuration)
    
    Write-AutomationLog "Validating deployment environment" -Level Information

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-AutomationLog "PowerShell 7+ is recommended for optimal performance" -Level Warning
    }

    # Check required modules
    $requiredModules = @('ThreadJob')
    if ($Configuration.RequiredModules) {
        $requiredModules += $Configuration.RequiredModules
    }
    
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            Write-AutomationLog "Installing required module: $module" -Level Information
            Install-Module -Name $module -Force -Scope CurrentUser
        }
    }

    # Platform-specific checks
    $platform = Get-DeploymentPlatform
    switch ($platform) {
        'Windows' {
            # Check execution policy
            $policy = Get-ExecutionPolicy -Scope CurrentUser
            if ($policy -eq 'Restricted') {
                Write-AutomationLog "Execution policy is restricted, some scripts may fail" -Level Warning
            }
        }
        'Linux' {
            # Check for sudo without password for automation
            if ($Configuration.RequiresSudo) {
                $null = sudo -n true 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-AutomationLog "Sudo access may be required for some operations" -Level Warning
                }
            }
        }
    }
}

# Build execution plan
function New-ExecutionPlan {
    param(
        [array]$Scripts,
        [hashtable]$Configuration
    )

    Write-AutomationLog "Building execution plan with dependency resolution" -Level Debug

    # Build dependency graph
    $dependencyGraph = @{}
    foreach ($script in $Scripts) {
        $dependencyGraph[$script.Name] = $script.Dependencies
    }

    # Topological sort for dependency order
    $sorted = @()
    $visited = @{}
    $visiting = @{}
    
    function Test-DependencyNode {
        param([string]$Node)
        
        if ($visiting[$Node]) {
            throw "Circular dependency detected: $Node"
        }
        
        if (-not $visited[$Node]) {
            $visiting[$Node] = $true

            if ($dependencyGraph[$Node]) {
                foreach ($dep in $dependencyGraph[$Node]) {
                    if ($dependencyGraph.ContainsKey($dep)) {
                        Test-DependencyNode -Node $dep
                    }
                }
            }
            
            $visiting[$Node] = $false
            $visited[$Node] = $true
            
            $script = $Scripts | Where-Object { $_.Name -eq $Node }
            if ($script) {
                $sorted += $script
            }
        }
    }
    
    foreach ($script in $Scripts) {
        Test-DependencyNode -Node $script.Name
    }
    
    return $sorted
}

# Parallel execution engine
function Invoke-ParallelExecution {
    param(
        [array]$Plan,
        [hashtable]$Configuration,
        [int]$MaxConcurrency,
        [int]$Timeout
    )

    Import-Module ThreadJob -Force
    
    $results = @()
    $jobs = @{}
    $completed = @{}
    $startTime = Get-Date
    $timeoutTime = $startTime.AddMinutes($Timeout)
    
    Write-AutomationLog "Starting parallel execution with max concurrency: $MaxConcurrency" -Level Information
    
    while ($Plan.Count -gt 0 -or $jobs.Count -gt 0) {
        # Start new jobs if under concurrency limit
        while ($jobs.Count -lt $MaxConcurrency -and $Plan.Count -gt 0) {
            $script = $Plan[0]

            # Check dependencies
            $canStart = $true
            foreach ($dep in $script.Dependencies) {
                if (-not $completed[$dep]) {
                    $canStart = $false
                    break
                }
            }

            if ($canStart) {
                $Plan = $Plan[1..($Plan.Count-1)]
                
                Write-AutomationLog "Starting: $($script.Name)" -Level Information
                
                $job = Start-ThreadJob -Name $script.Name -ScriptBlock {
                    param($Script, $Configuration, $ProjectRoot)
                    
                    Set-Location $ProjectRoot
                    
                    $result = @{
                        Name = $Script.Name
                        StartTime = Get-Date
                        Success = $false
                        Output = ""
                        Error = ""
                    }
                    
                    try {
                        $params = @{}
                        if ($Configuration) { $params['Configuration'] = $Configuration }
                        if ($Script.Parameters) { 
                            foreach ($key in $Script.Parameters.Keys) {
                                $params[$key] = $Script.Parameters[$key]
                            }
                        }
                        
                        $output = & $Script.Path @params 2>&1
                        $result.Success = $?
                        $result.Output = $output -join "`n"
                    } catch {
                        $result.Error = $_.Exception.Message
                    } finally {
                        $result.EndTime = Get-Date
                        $result.Duration = $result.EndTime - $result.StartTime
                    }
                    
                    return $result
                    
                } -ArgumentList $script, $Configuration, $script:ProjectRoot
                
                $jobs[$job.Id] = @{
                    Job = $job
                    Script = $script
                }
            } else {
                # Move to end if dependencies not met
                $Plan = $Plan[1..($Plan.Count-1)] + $script
                
                # Prevent infinite loop
                if ($Plan.Count -eq 1 -and $jobs.Count -eq 0) {
                    throw "Cannot satisfy dependencies for: $($script.Name)"
                }
            }
        }
        
        # Check for completed jobs
        $completedJobs = $jobs.Values | Where-Object { $_.Job.State -ne 'Running' }
        
        foreach ($jobInfo in $completedJobs) {
            $job = $jobInfo.Job
            $script = $jobInfo.Script
            
            try {
                $result = Receive-Job -Job $job -ErrorAction Stop
                $results += $result
                $completed[$script.Name] = $result.Success
                
                if ($result.Success) {
                    Write-AutomationLog "Completed: $($script.Name) (Duration: $($result.Duration.TotalSeconds)s)" -Level Information
                } else {
                    Write-AutomationLog "Failed: $($script.Name) - $($result.Error)" -Level Error
                }
            } catch {
                Write-AutomationLog "Job failed: $($script.Name) - $_" -Level Error
                $results += @{
                    Name = $script.Name
                    Success = $false
                    Error = $_.Exception.Message
                }
                $completed[$script.Name] = $false
            } finally {
                Remove-Job -Job $job -Force
                $jobs.Remove($job.Id)
            }
        }
        
        # Check timeout
        if ((Get-Date) -gt $timeoutTime) {
            Write-AutomationLog "Execution timeout reached, stopping remaining jobs" -Level Warning
            $jobs.Values | ForEach-Object { Stop-Job -Job $_.Job -Force }
            break
        }
        
        if ($jobs.Count -gt 0) {
            Start-Sleep -Milliseconds 500
        }
    }
    
    return $results
}

# Sequential execution
function Invoke-SequentialExecution {
    param(
        [array]$Plan,
        [hashtable]$Configuration,
        [int]$Timeout
    )

    $results = @()
    $startTime = Get-Date
    $timeoutTime = $startTime.AddMinutes($Timeout)
    
    Write-AutomationLog "Starting sequential execution" -Level Information
    
    foreach ($script in $Plan) {
        Write-AutomationLog "Executing: $($script.Name)" -Level Information
        
        $result = @{
            Name = $script.Name
            StartTime = Get-Date
            Success = $false
            Output = ""
            Error = ""
        }
        
        try {
            $params = @{}
            if ($Configuration) { $params['Configuration'] = $Configuration }
            if ($script.Parameters) { 
                foreach ($key in $script.Parameters.Keys) {
                    $params[$key] = $script.Parameters[$key]
                }
            }
            
            $output = & $script.Path @params 2>&1
            $result.Success = $?
            $result.Output = $output -join "`n"
        } catch {
            $result.Error = $_.Exception.Message
            Write-AutomationLog "Script failed: $($script.Name) - $_" -Level Error
        } finally {
            $result.EndTime = Get-Date
            $result.Duration = $result.EndTime - $result.StartTime
        }
        
        $results += $result
        
        Write-AutomationLog "Completed: $($script.Name) (Duration: $($result.Duration.TotalSeconds)s)" -Level Information
        
        # Check timeout
        if ((Get-Date) -gt $timeoutTime) {
            Write-AutomationLog "Execution timeout reached" -Level Warning
            break
        }
    }
    
    return $results
}

# Get execution summary
function Get-ExecutionSummary {
    param([array]$Results)
    
    $summary = @{
        Total = $Results.Count
        Succeeded = ($Results | Where-Object { $_.Success }).Count
        Failed = ($Results | Where-Object { -not $_.Success }).Count
        TotalDuration = [TimeSpan]::Zero
    }
    
    foreach ($result in $Results) {
        if ($result.Duration) {
            $summary.TotalDuration += $result.Duration
        }
    }
    
    return $summary
}

# Write deployment summary
function Write-DeploymentSummary {
    param($Summary)
    
    Write-Host "`n$('='*70)" -ForegroundColor Cyan
    Write-Host "DEPLOYMENT AUTOMATION SUMMARY" -ForegroundColor Cyan
    Write-Host "$('='*70)" -ForegroundColor Cyan
    
    Write-Host "Total Scripts: $($Summary.Total)"
    Write-Host "Succeeded: $($Summary.Succeeded)" -ForegroundColor Green
    Write-Host "Failed: $($Summary.Failed)" -ForegroundColor $(if ($Summary.Failed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Total Duration: $([Math]::Round($Summary.TotalDuration.TotalMinutes, 2)) minutes"
    
    Write-Host "$('='*70)`n" -ForegroundColor Cyan
}

# Export functions
Export-ModuleMember -Function @(
    'Start-DeploymentAutomation',
    'Get-DeploymentPlatform',
    'Get-AutomationScripts',
    'Test-DeploymentEnvironment',
    'Write-AutomationLog'
)