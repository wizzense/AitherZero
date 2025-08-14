#Requires -Version 7.0

<#
.SYNOPSIS
    OrchestrationEngine.psm1 - Number-based orchestration for AitherZero
.DESCRIPTION
    Aitherium™ Enterprise Infrastructure Automation Platform
    Orchestration Engine - Execute complex workflows using simple number sequences
.NOTES
    Copyright © 2025 Aitherium Corporation
#>

# Initialize module
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:ScriptsPath = Join-Path $script:ProjectRoot 'automation-scripts'
$script:OrchestrationPath = Join-Path $script:ProjectRoot 'orchestration'

# Import logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output
}

function Write-OrchestrationLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )

    # Check if Write-CustomLog is available (more reliable than static variable)
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "[Orchestration] $Message" -Level $Level -Source "OrchestrationEngine" -Data $Data
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$timestamp] [ORCH] $Message"
    }
}

function Invoke-OrchestrationSequence {
    <#
    .SYNOPSIS
    Execute automation scripts based on number sequences
    
    .DESCRIPTION
    A high-level orchestration language using numbers to execute complex workflows.
    Supports ranges, wildcards, exclusions, and conditional execution.
    
    .PARAMETER Sequence
    Number sequence(s) to execute. Supports multiple formats:
    - Single: "0001"
    - Range: "0001-0099"
    - List: "0001,0002,0005"
    - Wildcard: "02*" (all 0200-0299)
    - Exclusion: "0001-0099,!0050"
    - Stage prefix: "stage:Core"
    - Tag prefix: "tag:database"
    
    .PARAMETER Configuration
    Configuration hashtable or path to configuration file
    
    .PARAMETER Variables
    Variables to pass to scripts for conditional execution
    
    .PARAMETER DryRun
    Show what would be executed without running
    
    .PARAMETER Parallel
    Enable parallel execution (default: true)
    
    .PARAMETER MaxConcurrency
    Maximum concurrent executions
    
    .PARAMETER ContinueOnError
    Continue executing sequence even if a script fails
    
    .PARAMETER Profile
    Execution profile (Minimal, Standard, Developer, Full, Custom)
    
    .PARAMETER SavePlaybook
    Save the execution sequence as a reusable playbook
    
    .PARAMETER LoadPlaybook
    Load and execute a saved playbook
    
    .EXAMPLE
    # Run environment setup
    Invoke-OrchestrationSequence -Sequence "0000-0099"
    
    .EXAMPLE
    # Run specific tools installation
    Invoke-OrchestrationSequence -Sequence "0201,0207,0208"
    
    .EXAMPLE
    # Run all development tools except Docker
    Invoke-OrchestrationSequence -Sequence "02*,!0208"
    
    .EXAMPLE
    # Run by stage
    Invoke-OrchestrationSequence -Sequence "stage:Infrastructure,stage:Development"
    
    .EXAMPLE
    # Complex orchestration with variables
    Invoke-OrchestrationSequence -Sequence "0000-0299" -Variables @{
        Environment = "Production"
        SkipTests = $false
        Features = @("HyperV", "Kubernetes")
    }
    
    .EXAMPLE
    # Save as playbook
    Invoke-OrchestrationSequence -Sequence "0001,0207,0201,0105" -SavePlaybook "dev-setup"
    
    .EXAMPLE
    # Execute saved playbook
    Invoke-OrchestrationSequence -LoadPlaybook "dev-setup"
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Sequence')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Sequence')]
        [string[]]$Sequence,
        
        [Parameter(Mandatory, ParameterSetName = 'Playbook')]
        [string]$LoadPlaybook,
        
        [Parameter(ParameterSetName = 'Playbook')]
        [string]$PlaybookProfile,
        
        [Parameter()]
        [object]$Configuration,
        
        [Parameter()]
        [hashtable]$Variables = @{},
        
        [Parameter()]
        [switch]$DryRun,
        
        [Parameter()]
        [bool]$Parallel,
        
        [Parameter()]
        [int]$MaxConcurrency,
        
        [Parameter()]
        [switch]$ContinueOnError,
        
        [Parameter()]
        [ValidateSet('Minimal', 'Standard', 'Developer', 'Full', 'Custom')]
        [string]$ExecutionProfile,
        
        [Parameter(ParameterSetName = 'Sequence')]
        [string]$SavePlaybook,
        
        [Parameter()]
        [switch]$Interactive,
        
        [Parameter()]
        [hashtable]$Conditions = @{},
        
        [Parameter()]
        [int]$Timeout = 300,
        
        [Parameter()]
        [switch]$ValidateFirst,
        
        [Parameter()]
        [int]$MaxRetries = 3
    )

    begin {
        Write-OrchestrationLog "Starting orchestration engine"
        
        # Load configuration
        $config = Get-OrchestrationConfiguration -Configuration $Configuration
        
        # Apply default from config if not specified
        if (-not $PSBoundParameters.ContainsKey('Parallel')) {
            $Parallel = $config.Automation.DefaultMode -eq 'Parallel'
        }
        
        # Override with parameters
        if ($PSBoundParameters.ContainsKey('MaxConcurrency')) {
            $config.Automation.MaxConcurrency = $MaxConcurrency
        }
        
        # Handle SkipConfirmation from config
        if ($config.Automation.SkipConfirmation -and -not $Interactive) {
            $Interactive = $false
        }
        
        # Apply ValidateBeforeRun from config
        if ($config.Automation.ValidateBeforeRun -and -not $DryRun) {
            Write-OrchestrationLog "Running validation before execution (ValidateBeforeRun is enabled)"
            # Could add validation logic here
        }
        
        # Load playbook if specified
        if ($LoadPlaybook) {
            $playbook = Get-OrchestrationPlaybook -Name $LoadPlaybook
            if (-not $playbook) {
                throw "Playbook not found: $LoadPlaybook"
            }

            # Handle playbook profiles
            if ($PlaybookProfile -and $playbook.options -and $playbook.options.profiles) {
                if ($playbook.options.profiles.$PlaybookProfile) {
                    $ProfileNameConfig = $playbook.options.profiles[$PlaybookProfile]
                    Write-OrchestrationLog "Applying playbook profile: $PlaybookProfile - $($ProfileNameConfig.description)"
                    
                    # Apply profile variables
                    if ($ProfileNameConfig.variables) {
                        foreach ($key in $ProfileNameConfig.variables.Keys) {
                            $Variables[$key] = $ProfileNameConfig.variables[$key]
                        }
                    }
                } else {
                    $availableProfiles = $playbook.options.profiles.Keys -join ', '
                    throw "Invalid playbook profile: $PlaybookProfile. Available profiles: $availableProfiles"
                }
            }

            # Handle both direct sequences and staged playbooks
            # Use property checks instead of ContainsKey for PSD1 compatibility
            if ($playbook.Sequence) {
                $Sequence = $playbook.Sequence
            }
            
            # Also check for stages (playbook can have both Sequence and Stages)
            if ($playbook.stages -or $playbook.Stages) {
                # Store stages for proper variable handling (check both cases)
                $script:PlaybookStages = if ($playbook.Stages) { $playbook.Stages } else { $playbook.stages }
                
                # Flatten all stage sequences for compatibility - only if Sequence wasn't already set
                if (-not $Sequence) {
                    $Sequence = @()
                    foreach ($stage in $script:PlaybookStages) {
                        $stageSeq = if ($stage.Sequence) { $stage.Sequence } elseif ($stage.sequence) { $stage.sequence } else { @() }
                        if ($stageSeq) {
                            $Sequence += $stageSeq
                        }
                    }
                }
                Write-OrchestrationLog "Loaded $($script:PlaybookStages.Count) stages from playbook" -Level 'Information'
                Write-OrchestrationLog "Stages: $($script:PlaybookStages | ConvertTo-Json -Compress)" -Level 'Information'
            }
            
            # If still no sequence, this is an error
            if (-not $Sequence) {
                throw "Playbook '$LoadPlaybook' has no executable sequences defined"
            }

            # First, merge playbook default variables (without expansion)
            $defaultVars = @{}
            if ($playbook.variables) {
                foreach ($key in $playbook.variables.Keys) {
                    $defaultVars[$key] = $playbook.variables[$key]
                }
            }
            if ($playbook.Variables) {
                foreach ($key in $playbook.Variables.Keys) {
                    $defaultVars[$key] = $playbook.Variables[$key]
                }
            }
            
            # Debug: Show what we have before merging
            Write-OrchestrationLog "User Variables before merge: $($Variables | ConvertTo-Json -Compress)" -Level 'Information'
            Write-OrchestrationLog "Playbook default variables: $($defaultVars | ConvertTo-Json -Compress)" -Level 'Information'
            
            # Apply defaults only if not provided by user
            foreach ($key in $defaultVars.Keys) {
                if (-not $Variables.ContainsKey($key)) {
                    $Variables[$key] = $defaultVars[$key]
                }
            }
            
            Write-OrchestrationLog "Variables after merge: $($Variables | ConvertTo-Json -Compress)" -Level 'Information'
            
            # Now expand any variable references in the merged variables
            $expandedVars = @{}
            foreach ($key in $Variables.Keys) {
                $value = $Variables[$key]
                if ($value -is [string]) {
                    $expandedVars[$key] = Expand-PlaybookVariables -Value $value -Variables $Variables
                } else {
                    $expandedVars[$key] = $value
                }
            }
            $Variables = $expandedVars
            if ($playbook.Profile) {
                $ExecutionProfile = $playbook.Profile
            }
            
            Write-OrchestrationLog "Loaded playbook: $LoadPlaybook with sequences: $($Sequence -join ', ')"
            
            # Force sequential for playbooks with stages to maintain stage order
            if ($script:PlaybookStages) {
                Write-OrchestrationLog "Forcing sequential execution for staged playbook"
                $Parallel = $false
            }
        }
    }
    
    process {
        # Parse sequences into script numbers
        $scriptNumbers = ConvertTo-ScriptNumbers -Sequence $Sequence -Profile $ExecutionProfile -Configuration $config
        
        if ($scriptNumbers.Count -eq 0) {
            Write-OrchestrationLog "No scripts match the specified sequence" -Level 'Warning'
            return
        }
        
        Write-OrchestrationLog "Resolved to $($scriptNumbers.Count) scripts: $($scriptNumbers -join ', ')"
        
        # Validate scripts first if requested
        if ($ValidateFirst) {
            Write-OrchestrationLog "Validating scripts before execution..."
            $validationErrors = @()
            
            foreach ($scriptNum in $scriptNumbers) {
                $scriptPath = Join-Path $script:ScriptsPath "${scriptNum}_*.ps1"
                $scriptFile = Get-ChildItem -Path $scriptPath -ErrorAction SilentlyContinue | Select-Object -First 1
                
                if (-not $scriptFile) {
                    $validationErrors += "Script $scriptNum not found"
                    continue
                }
                
                # Basic syntax check
                try {
                    $null = [System.Management.Automation.Language.Parser]::ParseFile(
                        $scriptFile.FullName, [ref]$null, [ref]$null
                    )
                    Write-OrchestrationLog "  ✓ Script $scriptNum validated" -Level 'Debug'
                } catch {
                    $validationErrors += "Script $scriptNum has syntax errors: $_"
                }
            }
            
            if ($validationErrors.Count -gt 0) {
                Write-OrchestrationLog "Validation failed with $($validationErrors.Count) error(s)" -Level 'Error'
                foreach ($error in $validationErrors) {
                    Write-OrchestrationLog "  - $error" -Level 'Error'
                }
                
                if (-not $ContinueOnError) {
                    throw "Script validation failed. Use -ContinueOnError to proceed anyway."
                }
            } else {
                Write-OrchestrationLog "All scripts validated successfully"
            }
        }
        
        # Get script metadata
        $scripts = Get-OrchestrationScripts -Numbers $scriptNumbers -Variables $Variables -Conditions $Conditions
        
        # Save playbook if requested
        if ($SavePlaybook) {
            Save-OrchestrationPlaybook -Name $SavePlaybook -Sequence $Sequence -Variables $Variables -Profile $ExecutionProfile
            Write-OrchestrationLog "Saved playbook: $SavePlaybook"
        }
        
        # Dry run mode
        if ($DryRun) {
            Write-OrchestrationLog "DRY RUN MODE - No scripts will be executed"
            Show-OrchestrationPlan -Scripts $scripts
            return
        }
        
        # Interactive confirmation
        if ($Interactive -and -not $PSCmdlet.ShouldProcess("Execute $($scripts.Count) scripts", "Orchestration")) {
            Write-OrchestrationLog "Execution cancelled by user"
            return
        }
        
        # Execute orchestration
        $result = if ($Parallel) {
            Invoke-ParallelOrchestration -Scripts $scripts -Configuration $config -Variables $Variables -ContinueOnError:$ContinueOnError
        } else {
            Invoke-SequentialOrchestration -Scripts $scripts -Configuration $config -Variables $Variables -ContinueOnError:$ContinueOnError
        }
        
        # Return execution result
        $result
    }
}

function ConvertTo-ScriptNumbers {
    param(
        [string[]]$Sequence,
        [string]$ExecutionProfile,
        [hashtable]$Configuration
    )

    $numbers = @()
    $exclusions = @()

    # Handle profile-based sequences
    if ($ExecutionProfile -and $Configuration.Automation.Profiles.$ExecutionProfile) {
        $ProfileNameScripts = $Configuration.Automation.Profiles.$ExecutionProfile.Scripts
        $Sequence = $ProfileNameScripts
    }
    
    foreach ($seq in $Sequence) {
        if ($seq.StartsWith('!')) {
            # Exclusion
            $exclusions += ConvertTo-ScriptNumbers -Sequence @($seq.Substring(1)) -Configuration $Configuration
        }
        elseif ($seq -match '^\d{4}$') {
            # Single number
            $numbers += $seq
        }
        elseif ($seq -match '^(\d{4})-(\d{4})$') {
            # Range - only include scripts that actually exist
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            
            # Get all scripts in range that actually exist
            $existingScripts = Get-ChildItem -Path $script:ScriptsPath -Filter "*.ps1" -File | 
                Where-Object { 
                    $_.Name -match '^(\d{4})_' | Out-Null
                    $num = [int]$Matches[1]
                    $num -ge $start -and $num -le $end
                } | ForEach-Object { 
                    $_.Name -match '^(\d{4})_' | Out-Null
                    $Matches[1] 
                }
            
            $numbers += $existingScripts
        }
        elseif ($seq -match '^(\d{1,2})\*$') {
            # Wildcard (e.g., "02*" for all 0200-0299)
            $prefix = $Matches[1].PadLeft(2, '0')
            $pattern = "$prefix*"
            
            $matchingScripts = Get-ChildItem -Path $script:ScriptsPath -Filter "${pattern}_*.ps1" -File |
                ForEach-Object { $_.Name -match '^(\d{4})_' | Out-Null; $Matches[1] }
            
            $numbers += $matchingScripts
        }
        elseif ($seq.StartsWith('stage:')) {
            # Stage-based selection
            $stage = $seq.Substring(6)
            
            $stageScripts = Get-ChildItem -Path $script:ScriptsPath -Filter "*.ps1" -File | Where-Object {
                $content = Get-Content $_.FullName -First 10
                $content -match "# Stage: $stage"
            } | ForEach-Object { $_.Name -match '^(\d{4})_' | Out-Null; $Matches[1] }
            
            $numbers += $stageScripts
        }
        elseif ($seq.StartsWith('tag:')) {
            # Tag-based selection
            $tag = $seq.Substring(4)
            
            $taggedScripts = Get-ChildItem -Path $script:ScriptsPath -Filter "*.ps1" -File | Where-Object {
                $content = Get-Content $_.FullName -First 20
                $content -match "# Tags:.*\b$tag\b"
            } | ForEach-Object { $_.Name -match '^(\d{4})_' | Out-Null; $Matches[1] }
            
            $numbers += $taggedScripts
        }
        elseif ($seq -match ',') {
            # Comma-separated list
            $numbers += ConvertTo-ScriptNumbers -Sequence ($seq -split ',') -Configuration $Configuration
        }
    }

    # Remove duplicates and exclusions
    $numbers = $numbers | Select-Object -Unique | Where-Object { $_ -notin $exclusions } | Sort-Object
    
    return $numbers
}

function Expand-PlaybookVariables {
    param(
        [string]$Value,
        [hashtable]$Variables
    )
    
    if (-not $Value) { return $Value }
    
    # Replace {{variable}} patterns with actual values
    $pattern = '\{\{([^}:]+)(?::=([^}]+))?\}\}'
    $result = [regex]::Replace($Value, $pattern, {
        param($match)
        $varName = $match.Groups[1].Value
        $defaultValue = $match.Groups[2].Value
        
        if ($Variables.ContainsKey($varName)) {
            return $Variables[$varName]
        } elseif ($defaultValue) {
            return $defaultValue
        } else {
            return ''  # Return empty string for undefined variables without defaults
        }
    })
    
    return $result
}

function Get-OrchestrationScripts {
    param(
        [string[]]$Numbers,
        [hashtable]$Variables,
        [hashtable]$Conditions
    )

    $scripts = @()
    
    foreach ($number in $Numbers) {
        $scriptFile = Get-ChildItem -Path $script:ScriptsPath -Filter "${number}_*.ps1" -File | Select-Object -First 1
        
        if (-not $scriptFile) {
            Write-OrchestrationLog "Script not found for number: $number" -Level 'Warning'
            continue
        }
        
        # Parse script metadata
        $metadata = Get-ScriptMetadata -Path $scriptFile.FullName
        
        # Check if this script has stage-specific variables
        # Use stage-specific variables if defined, otherwise use global variables
        $stageVariables = @{}
        $foundStageVars = $false
        
        if ($script:PlaybookStages) {
            foreach ($stage in $script:PlaybookStages) {
                # Check both lowercase and uppercase for compatibility
                $stageSequence = if ($stage.Sequence) { $stage.Sequence } else { $stage.sequence }
                $stageVars = if ($stage.Variables) { $stage.Variables } else { $stage.variables }
                if ($stageSequence -contains $number -and $stageVars) {
                    # Use ONLY stage-specific variables (don't merge with global)
                    foreach ($key in $stageVars.Keys) {
                        $value = $stageVars[$key]
                        # Expand variable references in the value using global variables for lookups
                        if ($value -is [string]) {
                            $value = Expand-PlaybookVariables -Value $value -Variables $Variables
                        }
                        $stageVariables[$key] = $value
                    }
                    Write-OrchestrationLog "Applied stage variables for script $number - Variables: $($stageVariables | ConvertTo-Json -Compress)" -Level 'Information'
                    $foundStageVars = $true
                    break
                }
            }
        }
        
        # Only use global variables if no stage-specific variables were defined
        if (-not $foundStageVars) {
            $stageVariables = $Variables.Clone()
        }
        
        # Check conditions
        if ($metadata.Condition -and $Conditions.Count -gt 0) {
            $shouldRun = Test-OrchestrationCondition -Condition $metadata.Condition -Variables $Variables -Conditions $Conditions
            if (-not $shouldRun) {
                Write-OrchestrationLog "Skipping $($scriptFile.Name) due to condition: $($metadata.Condition)" -Level 'Debug'
                continue
            }
        }
        
        $scripts += [PSCustomObject]@{
            Number = $number
            Name = $scriptFile.Name
            Path = $scriptFile.FullName
            Stage = $metadata.Stage
            Dependencies = $metadata.Dependencies
            Description = $metadata.Description
            Condition = $metadata.Condition
            Tags = $metadata.Tags
            Priority = [int]$number
            Variables = $stageVariables  # Include stage-specific variables
        }
    }
    
    return $scripts
}

function Get-ScriptMetadata {
    param(
        [string]$Path
    )

    $metadata = @{
        Stage = 'Default'
        Dependencies = @()
        Description = ''
        Condition = $null
        Tags = @()
    }

    # Read first 20 lines for metadata
    $content = Get-Content $Path -First 20
    
    foreach ($line in $content) {
        if ($line -match '^# Stage:\s*(.+)$') {
            $metadata.Stage = $Matches[1].Trim()
        }
        elseif ($line -match '^# Dependencies:\s*(.+)$') {
            $metadata.Dependencies = $Matches[1].Trim() -split ',\s*'
        }
        elseif ($line -match '^# Description:\s*(.+)$') {
            $metadata.Description = $Matches[1].Trim()
        }
        elseif ($line -match '^# Condition:\s*(.+)$') {
            $metadata.Condition = $Matches[1].Trim()
        }
        elseif ($line -match '^# Tags:\s*(.+)$') {
            $metadata.Tags = $Matches[1].Trim() -split ',\s*'
        }
    }
    
    return $metadata
}

function Test-OrchestrationCondition {
    param(
        [string]$Condition,
        [hashtable]$Variables,
        [hashtable]$Conditions
    )

    # Simple condition evaluation
    # Examples:
    # - "Environment -eq 'Production'"
    # - "Features -contains 'HyperV'"
    # - "SkipTests -ne $true"
    
    try {
        $combinedVars = $Variables + $Conditions
        
        # Create a safe evaluation context
        $scriptBlock = [ScriptBlock]::Create($Condition)
        
        # Inject variables into scope
        foreach ($key in $combinedVars.Keys) {
            Set-Variable -Name $key -Value $combinedVars[$key] -Scope Local
        }
        
        # Evaluate condition
        $result = & $scriptBlock
        
        return [bool]$result
    } catch {
        Write-OrchestrationLog "Failed to evaluate condition: $Condition - $_" -Level 'Warning'
        return $true  # Default to running if condition fails
    }
}

function Show-OrchestrationPlan {
    param(
        [array]$Scripts
    )

    Write-Host "`nOrchestration Plan:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan

    # Group by stage
    $stages = $Scripts | Group-Object Stage | Sort-Object Name
    
    foreach ($stage in $stages) {
        Write-Host "`nStage: $($stage.Name)" -ForegroundColor Yellow
        
        foreach ($script in $stage.Group | Sort-Object Priority) {
            $status = "  [$($script.Number)] $($script.Name)"
            if ($script.Description) {
                $status += " - $($script.Description)"
            }
            Write-Host $status

            if ($script.Dependencies.Count -gt 0) {
                Write-Host "       Dependencies: $($script.Dependencies -join ', ')" -ForegroundColor DarkGray
            }

            if ($script.Condition) {
                Write-Host "       Condition: $($script.Condition)" -ForegroundColor DarkGray
            }
        }
    }
    
    Write-Host "`nTotal scripts: $($Scripts.Count)" -ForegroundColor Green
}

function Invoke-ParallelOrchestration {
    param(
        [array]$Scripts,
        [hashtable]$Configuration,
        [hashtable]$Variables = @{},
        [switch]$ContinueOnError
    )

    Write-OrchestrationLog "Starting parallel orchestration with max concurrency: $($Configuration.Automation.MaxConcurrency)"

    # Build dependency graph
    $graph = Build-DependencyGraph -Scripts $Scripts

    # Execute in parallel with dependency resolution
    $jobs = @{}
    $completed = @{}
    $failed = @{}
    $startTime = Get-Date  # Initialize start time for duration calculation
    
    while ($completed.Count -lt $Scripts.Count -and (-not $failed.Count -or $ContinueOnError)) {
        # Find scripts ready to run
        $ready = $Scripts | Where-Object {
            $_.Number -notin $completed.Keys -and
            $_.Number -notin $failed.Keys -and
            $_.Number -notin $jobs.Keys -and
            (Test-DependenciesMet -Script $_ -Completed $completed -Graph $graph)
        }
        
        # Start new jobs up to concurrency limit
        foreach ($script in $ready) {
            if ($jobs.Count -ge $Configuration.Automation.MaxConcurrency) {
                break
            }
            
            Write-OrchestrationLog "Starting: [$($script.Number)] $($script.Name)" -Level 'Information' -Data @{
                ScriptPath = $script.Path
                Stage = $script.Stage
                Dependencies = ($script.Dependencies -join ', ')
                HasVariables = ($scriptVars.Count -gt 0)
            }
            
            # Use script-specific variables if available, otherwise use global variables
            $scriptVars = if ($script.Variables) { $script.Variables } else { $Variables }
            
            $job = Start-ThreadJob -ScriptBlock {
                param($ScriptPath, $Config, $Vars)
                
                try {
                    # Validate script path exists
                    if (-not $ScriptPath -or -not (Test-Path $ScriptPath)) {
                        throw "Script path is invalid or does not exist: $ScriptPath"
                    }
                    
                    $params = @{}
                    
                    # Only add Configuration if the script accepts it
                    $scriptInfo = Get-Command $ScriptPath -ErrorAction SilentlyContinue
                    if ($scriptInfo -and $scriptInfo.Parameters.ContainsKey('Configuration')) {
                        if ($Config) { $params['Configuration'] = $Config }
                    }
                    
                    # Add any variables as individual parameters, but only if the script accepts them
                    foreach ($key in $Vars.Keys) {
                        # Skip null or empty values
                        if ($null -ne $Vars[$key] -and $Vars[$key] -ne '') {
                            # Check if the script has this parameter
                            if ($scriptInfo -and $scriptInfo.Parameters.ContainsKey($key)) {
                                $params[$key] = $Vars[$key]
                            }
                        }
                    }
                    
                    # Set non-interactive environment flag for child scripts
                    $env:AITHERZERO_NONINTERACTIVE = 'true'
                    
                    try {
                        # Execute the script
                        $result = & $ScriptPath @params
                        return @{ Success = $true; ExitCode = $LASTEXITCODE; Output = $result }
                    } finally {
                        # Clean up environment variable
                        $env:AITHERZERO_NONINTERACTIVE = $null
                    }
                } catch {
                    return @{ Success = $false; Error = $_.ToString(); ExitCode = 1 }
                }
            } -ArgumentList $script.Path, $Configuration, $scriptVars
            
            $jobs[$script.Number] = @{
                Job = $job
                Script = $script
                StartTime = Get-Date
            }
        }
        
        # Check for completed jobs
        $completedJobs = $jobs.GetEnumerator() | Where-Object { $_.Value.Job.State -eq 'Completed' }
        
        foreach ($entry in $completedJobs) {
            $number = $entry.Key
            $jobInfo = $entry.Value
            $result = Receive-Job -Job $jobInfo.Job
            
            $duration = New-TimeSpan -Start $jobInfo.StartTime -End (Get-Date)

            if ($result.Success -and $result.ExitCode -eq 0) {
                Write-OrchestrationLog "Completed: [$number] $($jobInfo.Script.Name) (Duration: $($duration.TotalSeconds)s)"
                $completed[$number] = $result
            } else {
                Write-OrchestrationLog "Failed: [$number] $($jobInfo.Script.Name) - $($result.Error)" -Level 'Error'
                $failed[$number] = $result
                
                if (-not $ContinueOnError) {
                    # Cancel remaining jobs
                    foreach ($activeJob in $jobs.Values) {
                        Stop-Job -Job $activeJob.Job -PassThru | Remove-Job
                    }
                    break
                }
            }
            
            Remove-Job -Job $jobInfo.Job
            $jobs.Remove($number)
        }
        
        # Brief pause to prevent CPU spinning
        if ($jobs.Count -gt 0) {
            Start-Sleep -Milliseconds 100
        }
    }

    # Return execution summary
    return [PSCustomObject]@{
        Total = $Scripts.Count
        Completed = $completed.Count
        Failed = $failed.Count
        Duration = New-TimeSpan -Start $startTime -End (Get-Date)
        Results = @{
            Completed = $completed
            Failed = $failed
        }
    }
}

function Invoke-SequentialOrchestration {
    param(
        [array]$Scripts,
        [hashtable]$Configuration,
        [hashtable]$Variables = @{},
        [switch]$ContinueOnError
    )

    Write-OrchestrationLog "Starting sequential orchestration"
    
    $completed = @{}
    $failed = @{}
    $startTime = Get-Date
    
    foreach ($script in $Scripts | Sort-Object Priority) {
        Write-OrchestrationLog "Executing: [$($script.Number)] $($script.Name)"
        
        $retryCount = 0
        # Use MaxRetries parameter if provided, otherwise default to 0 (no retries)
        $scriptMaxRetries = if ($PSBoundParameters.ContainsKey('MaxRetries')) { 
            $MaxRetries 
        } else { 
            0  # Default: no retries
        }
        $retryDelay = 0
        $succeeded = $false
        $scriptStart = Get-Date  # Initialize before the try block to avoid null reference
        
        # Execute at least once, then retry up to maxRetries times
        while ($retryCount -eq 0 -or ($retryCount -le $maxRetries -and -not $succeeded)) {
            try {
                if ($retryCount -gt 0) {
                    Write-OrchestrationLog "Retry attempt $retryCount/$maxRetries for [$($script.Number)] $($script.Name)"
                    Start-Sleep -Seconds $retryDelay
                }
                
                $scriptStart = Get-Date  # Update for each retry
                
                # Write audit log for script execution
                if ($script:LoggingAvailable -and (Get-Command Write-AuditLog -ErrorAction SilentlyContinue)) {
                    Write-AuditLog -EventNameType 'ScriptExecution' -Action 'StartScript' -Target $script.Path -Details @{
                        ScriptName = $script.Name
                        ScriptNumber = $script.Number
                        Configuration = $Configuration
                        DryRun = $DryRun
                        RetryAttempt = $retryCount
                    }
                }
                
                # Use script-specific variables if available, otherwise use global variables
                $scriptVars = if ($script.Variables) { $script.Variables } else { $Variables }
                
                # Validate script path exists
                if (-not $script.Path -or -not (Test-Path $script.Path)) {
                    throw "Script path is invalid or does not exist: $($script.Path)"
                }
                
                # Filter variables to only include parameters the script accepts
                $scriptInfo = Get-Command $script.Path -ErrorAction SilentlyContinue
                $params = @{}
                
                # Debug logging
                Write-OrchestrationLog "Script: $($script.Number) - Variables available: $($scriptVars.Keys -join ', ')" -Level 'Debug'
                
                if ($scriptInfo) {
                    # Only add Configuration if the script accepts it
                    if ($scriptInfo.Parameters.ContainsKey('Configuration')) {
                        if ($Configuration) { $params['Configuration'] = $Configuration }
                    }
                    
                    # Only add variables that match script parameters
                    foreach ($key in $scriptVars.Keys) {
                        if ($scriptInfo.Parameters.ContainsKey($key)) {
                            # Skip null or empty values
                            if ($null -ne $scriptVars[$key] -and $scriptVars[$key] -ne '') {
                                $params[$key] = $scriptVars[$key]
                            }
                        }
                    }
                } else {
                    # Fallback if Get-Command fails - pass all non-empty variables
                    Write-OrchestrationLog "Warning: Could not get script info for $($script.Path), passing all variables" -Level 'Warning'
                    foreach ($key in $scriptVars.Keys) {
                        if ($null -ne $scriptVars[$key] -and $scriptVars[$key] -ne '') {
                            $params[$key] = $scriptVars[$key]
                        }
                    }
                }
                
                Write-OrchestrationLog "Script: $($script.Number) - Parameters being passed: $($params.Keys -join ', ')" -Level 'Debug'
                & $script.Path @params
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Script exited with code: $LASTEXITCODE"
                }
                
                $succeeded = $true
                
                $duration = New-TimeSpan -Start $scriptStart -End (Get-Date)
                Write-OrchestrationLog "Completed: [$($script.Number)] $($script.Name) (Duration: $($duration.TotalSeconds)s)"
                
                # Write audit log for successful completion
                if ($script:LoggingAvailable -and (Get-Command Write-AuditLog -ErrorAction SilentlyContinue)) {
                    Write-AuditLog -EventNameType 'ScriptExecution' -Action 'CompleteScript' -Target $script.Path -Result 'Success' -Details @{
                        ScriptName = $script.Name
                        ScriptNumber = $script.Number
                        Duration = $duration.TotalSeconds
                        ExitCode = $LASTEXITCODE
                        RetryAttempt = $retryCount
                    }
                }
                
                $completed[$script.Number] = @{
                    Success = $true
                    ExitCode = 0
                    Duration = $duration
                    RetryCount = $retryCount
                }
                
            } catch {
                $retryCount++
                if ($retryCount -gt $scriptMaxRetries) {
                    Write-OrchestrationLog "Failed: [$($script.Number)] $($script.Name) - $_ (after $scriptMaxRetries retries)" -Level 'Error'
                    
                    # Write audit log for failure
                    if ($script:LoggingAvailable -and (Get-Command Write-AuditLog -ErrorAction SilentlyContinue)) {
                        Write-AuditLog -EventNameType 'ScriptExecution' -Action 'FailScript' -Target $script.Path -Result 'Failure' -Details @{
                            ScriptName = $script.Name
                            ScriptNumber = $script.Number
                            Error = $_.ToString()
                            ExitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
                            RetryAttempts = $maxRetries
                        }
                    }
                    
                    $failed[$script.Number] = @{
                        Success = $false
                        Error = $_.ToString()
                        ExitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
                        RetryAttempts = $maxRetries
                    }
                    
                    if (-not $ContinueOnError) {
                        break
                    }
                } else {
                    Write-OrchestrationLog "Script failed, will retry: [$($script.Number)] $($script.Name) - $_" -Level 'Warning'
                }
            }
        }
    }
    
    return [PSCustomObject]@{
        Total = $Scripts.Count
        Completed = $completed.Count
        Failed = $failed.Count
        Duration = New-TimeSpan -Start $startTime -End (Get-Date)
        Results = @{
            Completed = $completed
            Failed = $failed
        }
    }
}

function Build-DependencyGraph {
    param([array]$Scripts)
    
    $graph = @{}
    
    foreach ($script in $Scripts) {
        $graph[$script.Number] = @{
            Script = $script
            Dependencies = @()
            Dependents = @()
        }
    }

    # Build dependency relationships
    foreach ($script in $Scripts) {
        foreach ($dep in $script.Dependencies) {
            # Check if dependency is a script number
            $depScript = $Scripts | Where-Object { $_.Number -eq $dep -or $_.Name -like "*$dep*" } | Select-Object -First 1

            if ($depScript) {
                $graph[$script.Number].Dependencies += $depScript.Number
                $graph[$depScript.Number].Dependents += $script.Number
            }
        }
    }
    
    return $graph
}

function Test-DependenciesMet {
    param(
        $Script,
        $Completed,
        $Graph
    )

    $node = $Graph[$Script.Number]
    if (-not $node) { return $true }
    
    foreach ($dep in $node.Dependencies) {
        if ($dep -notin $Completed.Keys) {
            return $false
        }
    }
    
    return $true
}

function Get-OrchestrationConfiguration {
    param([object]$Configuration)

    if (-not $Configuration) {
        # Load default configuration
        $configPath = Join-Path $script:ProjectRoot 'config.psd1'
        if (Test-Path $configPath) {
            $Configuration = Import-PowerShellDataFile $configPath
        } else {
            $Configuration = @{}
        }
    } elseif ($Configuration -is [string]) {
        # Load from file path
        if (Test-Path $Configuration) {
            $Configuration = Import-PowerShellDataFile $Configuration
        } else {
            throw "Configuration file not found: $Configuration"
        }
    }

    # Ensure required sections exist
    if (-not $Configuration.Automation) {
        $Configuration.Automation = @{}
    }

    # Also check for Orchestration section (from config.psd1)
    if ($Configuration.Orchestration) {
        # Merge Orchestration settings into Automation for backward compatibility
        if (-not $Configuration.Automation.DefaultMode -and $Configuration.Orchestration.DefaultMode) {
            $Configuration.Automation.DefaultMode = $Configuration.Orchestration.DefaultMode
        }
        if (-not $Configuration.Automation.MaxRetries -and $Configuration.Orchestration.MaxRetries) {
            $Configuration.Automation.MaxRetries = $Configuration.Orchestration.MaxRetries
        }
        if (-not $Configuration.Automation.RetryDelay -and $Configuration.Orchestration.RetryDelay) {
            $Configuration.Automation.RetryDelay = $Configuration.Orchestration.RetryDelay
        }
        if ($null -eq $Configuration.Automation.SkipConfirmation -and $null -ne $Configuration.Orchestration.SkipConfirmation) {
            $Configuration.Automation.SkipConfirmation = $Configuration.Orchestration.SkipConfirmation
        }
        if ($null -eq $Configuration.Automation.ShowDependencies -and $null -ne $Configuration.Orchestration.ShowDependencies) {
            $Configuration.Automation.ShowDependencies = $Configuration.Orchestration.ShowDependencies
        }
        if ($null -eq $Configuration.Automation.ValidateBeforeRun -and $null -ne $Configuration.Orchestration.ValidateBeforeRun) {
            $Configuration.Automation.ValidateBeforeRun = $Configuration.Orchestration.ValidateBeforeRun
        }
        if ($null -eq $Configuration.Automation.CacheExecutionPlans -and $null -ne $Configuration.Orchestration.CacheExecutionPlans) {
            $Configuration.Automation.CacheExecutionPlans = $Configuration.Orchestration.CacheExecutionPlans
        }
        if ($null -eq $Configuration.Automation.ExecutionHistory -and $null -ne $Configuration.Orchestration.ExecutionHistory) {
            $Configuration.Automation.ExecutionHistory = $Configuration.Orchestration.ExecutionHistory
        }
        if (-not $Configuration.Automation.HistoryRetentionDays -and $Configuration.Orchestration.HistoryRetentionDays) {
            $Configuration.Automation.HistoryRetentionDays = $Configuration.Orchestration.HistoryRetentionDays
        }
        if ($null -eq $Configuration.Automation.EnableRollback -and $null -ne $Configuration.Orchestration.EnableRollback) {
            $Configuration.Automation.EnableRollback = $Configuration.Orchestration.EnableRollback
        }
        if (-not $Configuration.Automation.CheckpointInterval -and $Configuration.Orchestration.CheckpointInterval) {
            $Configuration.Automation.CheckpointInterval = $Configuration.Orchestration.CheckpointInterval
        }
        if ($null -eq $Configuration.Automation.NotifyOnMilestone -and $null -ne $Configuration.Orchestration.NotifyOnMilestone) {
            $Configuration.Automation.NotifyOnMilestone = $Configuration.Orchestration.NotifyOnMilestone
        }
    }

    # Set defaults
    if (-not $Configuration.Automation.MaxConcurrency) {
        $Configuration.Automation.MaxConcurrency = 4
    }

    if (-not $Configuration.Automation.DefaultMode) {
        $Configuration.Automation.DefaultMode = 'Parallel'
    }

    if (-not $Configuration.Automation.MaxRetries) {
        $Configuration.Automation.MaxRetries = 3
    }

    if (-not $Configuration.Automation.RetryDelay) {
        $Configuration.Automation.RetryDelay = 5
    }

    if (-not $Configuration.Automation.Profiles) {
        $Configuration.Automation.Profiles = @{}
    }
    
    return $Configuration
}

function Save-OrchestrationPlaybook {
    param(
        [string]$Name,
        [string[]]$Sequence,
        [hashtable]$Variables,
        [string]$ExecutionProfile,
        [string]$Description,
        [ValidateSet('PSD1', 'JSON')]
        [string]$Format = 'PSD1'
    )

    # Use new PSD1 directory for PSD1 format
    $playbookDir = if ($Format -eq 'PSD1') {
        Join-Path $script:OrchestrationPath 'playbooks-psd1'
    } else {
        Join-Path $script:OrchestrationPath 'playbooks'
    }
    
    if (-not (Test-Path $playbookDir)) {
        New-Item -ItemType Directory -Path $playbookDir -Force | Out-Null
    }
    
    # Extract description from Variables if passed there (for backward compatibility)
    if (-not $Description -and $Variables -and $Variables.ContainsKey('Description')) {
        $Description = $Variables['Description']
        $Variables.Remove('Description')
    }
    
    # Use default description if none provided
    if (-not $Description) {
        $Description = "Orchestration playbook created $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
    
    if ($Format -eq 'PSD1') {
        $playbookPath = Join-Path $playbookDir "$Name.psd1"
        
        # Build PSD1 content
        $psd1Content = @"
#Requires -Version 7.0
<#
.SYNOPSIS
    $Name - AitherZero Orchestration Playbook
.DESCRIPTION
    $Description
#>

@{
    # Metadata
    Name = '$Name'
    Description = '$Description'
    Version = '2.0.0'
    Author = 'AitherZero Orchestration Engine'
    Created = '$(Get-Date -Format 'o')'
    
    # Execution Profile
    Profile = '$(if ($ExecutionProfile) { $ExecutionProfile } else { 'Standard' })'
    
    # Sequence
    Sequence = @($(($Sequence | ForEach-Object { "'$_'" }) -join ', '))
    
    # Variables
    Variables = @{
$(
    if ($Variables -and $Variables.Count -gt 0) {
        ($Variables.GetEnumerator() | ForEach-Object {
            $value = if ($_.Value -is [string]) { "'$($_.Value)'" } 
            elseif ($_.Value -is [bool]) { if ($_.Value) { '$true' } else { '$false' } }
            elseif ($_.Value -is [array]) { "@($(($_.Value | ForEach-Object { "'$_'" }) -join ', '))" }
            elseif ($null -eq $_.Value) { '$null' }
            else { $_.Value }
            "        $($_.Key) = $value"
        }) -join "`n"
    } else {
        "        # No variables defined"
    }
)
    }
}
"@
        
        Set-Content -Path $playbookPath -Value $psd1Content -Encoding UTF8
        Write-OrchestrationLog "Saved PSD1 playbook: $playbookPath"
    } else {
        # Save as JSON for backward compatibility
        $playbook = @{
            Name = $Name
            Description = $Description
            Sequence = $Sequence
            Variables = $Variables
            Profile = $ExecutionProfile
            Created = Get-Date -Format 'o'
            Version = '1.0'
        }
        
        $playbookPath = Join-Path $playbookDir "$Name.json"
        $playbook | ConvertTo-Json -Depth 10 | Set-Content -Path $playbookPath
        Write-OrchestrationLog "Saved JSON playbook: $playbookPath"
    }
}

function Get-OrchestrationPlaybook {
    param([string]$Name)
    
    # Check for PSD1 format first (preferred)
    $psd1Paths = @(
        Join-Path $script:OrchestrationPath "playbooks-psd1/$Name.psd1"
        Join-Path $script:OrchestrationPath "playbooks/$Name.psd1"
    )
    
    foreach ($psd1Path in $psd1Paths) {
        if (Test-Path $psd1Path) {
            Write-OrchestrationLog "Loading PSD1 playbook: $psd1Path"
            return Import-PowerShellDataFile -Path $psd1Path
        }
    }
    
    # Search for PSD1 in subdirectories
    $playbooksDir = Join-Path $script:OrchestrationPath "playbooks-psd1"
    if (Test-Path $playbooksDir) {
        $foundPsd1 = Get-ChildItem -Path $playbooksDir -Filter "$Name.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundPsd1) {
            Write-OrchestrationLog "Loading PSD1 playbook: $($foundPsd1.FullName)"
            return Import-PowerShellDataFile -Path $foundPsd1.FullName
        }
    }
    
    # Fall back to JSON format for backward compatibility
    $jsonPath = Join-Path $script:OrchestrationPath "playbooks/$Name.json"
    
    if (Test-Path $jsonPath) {
        Write-OrchestrationLog "Loading JSON playbook (legacy): $jsonPath"
        return Get-Content $jsonPath -Raw | ConvertFrom-Json -AsHashtable
    }
    
    # Search for JSON in subdirectories
    $playbooksDir = Join-Path $script:OrchestrationPath "playbooks"
    $foundJson = Get-ChildItem -Path $playbooksDir -Filter "$Name.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($foundJson) {
        Write-OrchestrationLog "Loading JSON playbook (legacy): $($foundJson.FullName)"
        return Get-Content $foundJson.FullName -Raw | ConvertFrom-Json -AsHashtable
    }
    
    return $null
}

# Simplified number sequence functions for direct use
function Invoke-Sequence {
    <#
    .SYNOPSIS
    Simplified orchestration using number sequences
    
    .EXAMPLE
    # Quick setup
    seq 0000-0099

    # Install specific tools
    seq 0201,0207,0208

    # Run stage
    seq stage:Core
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Numbers
    )

    Invoke-OrchestrationSequence -Sequence $Numbers
}

# Create alias for seq
Set-Alias -Name 'seq' -Value 'Invoke-OrchestrationSequence' -Scope Global -Force

# Export functions
Export-ModuleMember -Function @(
    'Invoke-OrchestrationSequence'
    'Invoke-Sequence'
    'Get-OrchestrationPlaybook'
    'Save-OrchestrationPlaybook'
) -Alias @('seq')