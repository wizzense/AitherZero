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

function Get-NormalizedExitCode {
    <#
    .SYNOPSIS
        Normalize exit code, treating null as success (0)
    .DESCRIPTION
        Helper function to handle null $LASTEXITCODE or exit codes from job results.
        Treats null values as success (exit code 0) to ensure consistent exit code handling.
    .PARAMETER ExitCode
        The exit code to normalize (can be null)
    .EXAMPLE
        $exitCode = Get-NormalizedExitCode -ExitCode $LASTEXITCODE
    #>
    param(
        [Parameter(Mandatory = $false)]
        [object]$ExitCode
    )
    
    if ($null -eq $ExitCode) { 
        return 0 
    } else { 
        return $ExitCode 
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
        [hashtable]$Conditions = @{}
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

            # Check if this is a v3.0 job-based playbook
            if ($playbook.IsJobBased) {
                Write-OrchestrationLog "Detected v3.0 job-based playbook - routing to job orchestration engine" -Level 'Information'
                
                # Route to job-based orchestration
                $result = Invoke-JobBasedOrchestration -Playbook $playbook -Variables $Variables -Configuration $config -DryRun:$DryRun
                
                return $result
            }

            # Handle playbook profiles (support both v1 and v2 formats)
            $profilesSource = $null
            if ($playbook.Profiles) {
                $profilesSource = $playbook.Profiles  # v2.0 format
            } elseif ($playbook.options -and $playbook.options.profiles) {
                $profilesSource = $playbook.options.profiles  # v1 format
            }
            
            if ($PlaybookProfile -and $profilesSource) {
                if ($profilesSource.ContainsKey($PlaybookProfile)) {
                    $ProfileNameConfig = $profilesSource[$PlaybookProfile]
                    Write-OrchestrationLog "Applying playbook profile: $PlaybookProfile - $($ProfileNameConfig.description)"

                    # Apply profile variables
                    if ($ProfileNameConfig.variables) {
                        foreach ($key in $ProfileNameConfig.variables.Keys) {
                            $Variables[$key] = $ProfileNameConfig.variables[$key]
                        }
                    }
                    
                    # Apply profile overrides (v2.0 feature)
                    if ($ProfileNameConfig.overrides) {
                        foreach ($key in $ProfileNameConfig.overrides.Keys) {
                            $Variables[$key] = $ProfileNameConfig.overrides[$key]
                        }
                    }
                } else {
                    $availableProfiles = $profilesSource.Keys -join ', '
                    throw "Invalid playbook profile: $PlaybookProfile. Available profiles: $availableProfiles"
                }
            }

            # Handle both direct sequences and staged playbooks
            if ($playbook.Sequence) {
                $Sequence = $playbook.Sequence
            }

            # Also check for stages (playbook can have both Sequence and Stages)
            if ($playbook.stages -or $playbook.Stages) {
                # Store stages for proper variable handling (check both cases)
                $script:PlaybookStages = if ($playbook.Stages) { $playbook.Stages } else { $playbook.stages }

                # Flatten all stage sequences for compatibility
                $Sequence = @()
                foreach ($stage in $script:PlaybookStages) {
                    $stageSeq = if ($stage.Sequence) { $stage.Sequence } else { $stage.sequence }
                    if ($stageSeq) {
                        $Sequence += $stageSeq
                    }
                }
                Write-OrchestrationLog "Loaded $($script:PlaybookStages.Count) stages from playbook" -Level 'Information'
                Write-OrchestrationLog "Stages: $($script:PlaybookStages | ConvertTo-Json -Compress)" -Level 'Information'
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

        # Pre-execution validation for v2.0 playbooks
        if ($LoadPlaybook -and $playbook.Validation -and $playbook.Validation.preConditions) {
            Write-OrchestrationLog "Running pre-condition validation..." -Level 'Information'
            
            if (-not (Test-PlaybookConditions -Conditions $playbook.Validation.preConditions -Type 'pre-condition' -Variables $Variables)) {
                $errorMsg = "Pre-condition validation failed. Aborting execution."
                Write-OrchestrationLog $errorMsg -Level 'Error'
                
                # Send failure notification
                if ($playbook.Notifications) {
                    Send-PlaybookNotification -NotificationConfig $playbook.Notifications -Type 'onFailure' -Context @{
                        reason = 'Pre-condition validation failed'
                        playbook = $playbook.Name
                    }
                }
                
                throw $errorMsg
            }
        }

        # Send start notification
        if ($LoadPlaybook -and $playbook.Notifications) {
            Send-PlaybookNotification -NotificationConfig $playbook.Notifications -Type 'onStart' -Context @{
                playbook = $playbook.Name
                scriptCount = $scripts.Count
            }
        }

        # Interactive confirmation
        if ($Interactive -and -not $PSCmdlet.ShouldProcess("Execute $($scripts.Count) scripts", "Orchestration")) {
            Write-OrchestrationLog "Execution cancelled by user"
            return
        }

        # Execute orchestration
        try {
            $result = if ($Parallel) {
                Invoke-ParallelOrchestration -Scripts $scripts -Configuration $config -Variables $Variables -ContinueOnError:$ContinueOnError
            } else {
                Invoke-SequentialOrchestration -Scripts $scripts -Configuration $config -Variables $Variables -ContinueOnError:$ContinueOnError
            }

            # Post-execution validation for v2.0 playbooks
            if ($LoadPlaybook -and $playbook.Validation -and $playbook.Validation.postConditions) {
                Write-OrchestrationLog "Running post-condition validation..." -Level 'Information'
                
                if (-not (Test-PlaybookConditions -Conditions $playbook.Validation.postConditions -Type 'post-condition' -Variables $Variables)) {
                    Write-OrchestrationLog "Post-condition validation failed" -Level 'Warning'
                    
                    # Send warning notification
                    if ($playbook.Notifications) {
                        Send-PlaybookNotification -NotificationConfig $playbook.Notifications -Type 'onWarning' -Context @{
                            reason = 'Post-condition validation failed'
                            playbook = $playbook.Name
                        }
                    }
                }
            }

            # Send success notification
            if ($LoadPlaybook -and $playbook.Notifications) {
                Send-PlaybookNotification -NotificationConfig $playbook.Notifications -Type 'onSuccess' -Context @{
                    playbook = $playbook.Name
                    duration = if ($result.Duration) { $result.Duration.ToString() } else { 'Unknown' }
                    completed = if ($result.Completed) { $result.Completed } else { $scripts.Count }
                }
            }

            # Return execution result
            $result
        }
        catch {
            # Send failure notification
            if ($LoadPlaybook -and $playbook.Notifications) {
                Send-PlaybookNotification -NotificationConfig $playbook.Notifications -Type 'onFailure' -Context @{
                    playbook = $playbook.Name
                    error = $_.Exception.Message
                }
            }
            
            # Re-throw the error
            throw
        }
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

function Test-PlaybookConditions {
    <#
    .SYNOPSIS
    Test pre-conditions and post-conditions for v2.0 playbooks
    #>
    param(
        [array]$Conditions,
        [string]$Type = 'pre-condition',
        [hashtable]$Variables = @{}
    )

    if (-not $Conditions -or $Conditions.Count -eq 0) {
        return $true
    }

    $allPassed = $true
    
    foreach ($condition in $Conditions) {
        try {
            Write-OrchestrationLog "Testing ${Type}: $($condition.name)" -Level 'Information'
            
            # Validate condition syntax for security
            if ($condition.condition -match '[;&|`]|Invoke-|iex|Get-Content|Set-Content|Remove-Item') {
                Write-OrchestrationLog "Condition contains potentially dangerous commands: $($condition.condition)" -Level 'Error'
                $allPassed = $false
                continue
            }
            
            # Create evaluation context with validated condition
            $scriptBlock = [ScriptBlock]::Create($condition.condition)
            
            # Inject variables into scope
            foreach ($key in $Variables.Keys) {
                Set-Variable -Name $key -Value $Variables[$key] -Scope Local
            }
            
            # Evaluate condition
            $result = & $scriptBlock
            
            if (-not $result) {
                $message = if ($condition.message) { $condition.message } else { "$Type '$($condition.name)' failed" }
                Write-OrchestrationLog $message -Level 'Error'
                $allPassed = $false
            } else {
                Write-OrchestrationLog "$Type '$($condition.name)' passed" -Level 'Information'
            }
        } catch {
            $message = if ($condition.message) { $condition.message } else { "$Type '$($condition.name)' failed with error: $_" }
            Write-OrchestrationLog $message -Level 'Error'
            $allPassed = $false
        }
    }
    
    return $allPassed
}

function Send-PlaybookNotification {
    <#
    .SYNOPSIS
    Send notifications based on playbook configuration
    #>
    param(
        [hashtable]$NotificationConfig,
        [string]$Type,
        [hashtable]$Context = @{}
    )

    if (-not $NotificationConfig -or -not $NotificationConfig.ContainsKey($Type)) {
        return
    }

    $notification = $NotificationConfig[$Type]
    
    # Expand variables in message
    $message = $notification.message
    foreach ($key in $Context.Keys) {
        $message = $message -replace "\{\{$key\}\}", $Context[$key]
    }
    
    # Determine channels (default to console and log)
    $channels = if ($notification.channels) { $notification.channels } else { @('console', 'log') }
    
    # Send to each channel
    foreach ($channel in $channels) {
        switch ($channel) {
            'console' {
                $color = switch ($notification.level) {
                    'Success' { 'Green' }
                    'Warning' { 'Yellow' }
                    'Error' { 'Red' }
                    default { 'White' }
                }
                Write-Host $message -ForegroundColor $color
            }
            'log' {
                Write-OrchestrationLog $message -Level $notification.level
            }
            'github' {
                # Could integrate with GitHub API for PR comments, etc.
                Write-OrchestrationLog "GitHub notification: $message" -Level $notification.level
            }
            default {
                Write-OrchestrationLog "Unsupported notification channel: $channel" -Level 'Warning'
            }
        }
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
                        # Treat null exit code as success (0) - inlined for Start-Job scope
                        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
                        return @{ Success = $true; ExitCode = $exitCode; Output = $result }
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

            # Check if script succeeded (exit code 0 or null means success)
            $exitCode = Get-NormalizedExitCode -ExitCode $result.ExitCode
            $isSuccess = ($result.Success -and $exitCode -eq 0)
            
            if ($isSuccess) {
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
        $maxRetries = 0  # Disabled retries per user request
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
                $scriptInfo = Get-Command $script.Path -ErrorAction SilentlyContinue -ErrorVariable getCommandError
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
                    # If Get-Command fails, don't pass any parameters to avoid parameter binding errors
                    Write-OrchestrationLog "Warning: Could not get script parameter info for $($script.Path). Script will run without parameters to avoid parameter binding errors." -Level 'Warning'
                    
                    # Log diagnostic details
                    if ($getCommandError -and $getCommandError.Count -gt 0) {
                        Write-OrchestrationLog "Get-Command error: $($getCommandError[0].Exception.Message)" -Level 'Debug'
                    }
                    Write-OrchestrationLog "Possible causes: script inaccessible, syntax errors, or execution policy restrictions. Verify script exists and has valid PowerShell syntax." -Level 'Debug'
                    
                    # Don't pass any variables - let the script use defaults or environment detection
                }

                Write-OrchestrationLog "Script: $($script.Number) - Parameters being passed: $($params.Keys -join ', ')" -Level 'Debug'
                & $script.Path @params

                # Treat null or 0 as success
                $exitCode = Get-NormalizedExitCode -ExitCode $LASTEXITCODE
                if ($exitCode -ne 0) {
                    throw "Script exited with code: $exitCode"
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
                if ($retryCount -gt $maxRetries) {
                    Write-OrchestrationLog "Failed: [$($script.Number)] $($script.Name) - $_ (after $maxRetries retries)" -Level 'Error'

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
        [string]$Description
    )

    $playbookDir = Join-Path $script:OrchestrationPath 'playbooks'
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

    Write-OrchestrationLog "Saved playbook: $playbookPath"
}

function ConvertTo-StandardPlaybookFormat {
    <#
    .SYNOPSIS
    Converts playbooks from different versions to a standardized format
    .DESCRIPTION
    Handles both legacy v1 playbooks and new v2.0 schema playbooks,
    converting them to a consistent internal format for execution.
    #>
    param(
        [hashtable]$Playbook
    )

    # Check if this is a v3.0 playbook (has jobs in orchestration)
    if ($Playbook.ContainsKey('metadata') -and $Playbook.ContainsKey('orchestration') -and $Playbook.orchestration.ContainsKey('jobs')) {
        Write-OrchestrationLog "Loading v3.0 playbook (job-based): $($Playbook.metadata.name)" -Level 'Information'
        
        # Return v3.0 playbook as-is (no conversion needed)
        # The playbook will be processed by Invoke-JobBasedOrchestration
        $standardPlaybook = @{
            # Metadata
            Name = $Playbook.metadata.name
            Description = $Playbook.metadata.description
            Version = $Playbook.metadata.version
            Category = $Playbook.metadata.category
            Author = $Playbook.metadata.author
            Tags = $Playbook.metadata.tags
            EstimatedDuration = $Playbook.metadata.estimatedDuration
            
            # Requirements
            Requirements = $Playbook.requirements
            
            # Orchestration with jobs (v3.0)
            IsJobBased = $true
            Orchestration = $Playbook.orchestration
            
            # Validation and notifications
            Validation = $Playbook.validation
            Notifications = $Playbook.notifications
            Reporting = $Playbook.reporting
        }
        
        return $standardPlaybook
    }
    # Check if this is a v2.0 playbook (has metadata and orchestration sections with stages)
    elseif ($Playbook.ContainsKey('metadata') -and $Playbook.ContainsKey('orchestration')) {
        Write-OrchestrationLog "Loading v2.0 playbook: $($Playbook.metadata.name)" -Level 'Information'
        
        # Convert v2.0 format to internal format
        $standardPlaybook = @{
            # Metadata
            Name = $Playbook.metadata.name
            Description = $Playbook.metadata.description
            Version = $Playbook.metadata.version
            Category = $Playbook.metadata.category
            Author = $Playbook.metadata.author
            Tags = $Playbook.metadata.tags
            EstimatedDuration = $Playbook.metadata.estimatedDuration
            
            # Requirements
            Requirements = $Playbook.requirements
            
            # Variables and profiles from orchestration section
            Variables = $Playbook.orchestration.defaultVariables
            Profiles = $Playbook.orchestration.profiles
            
            # Convert stages to internal format
            Stages = @()
            
            # Validation and notifications
            Validation = $Playbook.validation
            Notifications = $Playbook.notifications
            Reporting = $Playbook.reporting
        }
        
        # Convert stages format
        if ($Playbook.orchestration.stages) {
            foreach ($stage in $Playbook.orchestration.stages) {
                $convertedStage = @{
                    Name = $stage.name
                    Description = $stage.description
                    Sequence = $stage.sequences  # Note: v2.0 uses 'sequences' (plural)
                    Variables = $stage.variables
                    Condition = $stage.condition
                    ContinueOnError = $stage.continueOnError
                    Parallel = $stage.parallel
                    Timeout = $stage.timeout
                    Retries = $stage.retries
                }
                $standardPlaybook.Stages += $convertedStage
            }
        }
        
        return $standardPlaybook
    }
    
    # Handle legacy v1 playbook formats
    else {
        Write-OrchestrationLog "Loading legacy v1 playbook" -Level 'Information'
        
        # Return as-is for legacy playbooks, but normalize key cases
        $standardPlaybook = @{}
        
        # Handle different naming conventions in legacy playbooks
        $standardPlaybook.Name = if ($Playbook.Name) { $Playbook.Name } else { $Playbook.name }
        $standardPlaybook.Description = if ($Playbook.Description) { $Playbook.Description } else { $Playbook.description }
        $standardPlaybook.Version = if ($Playbook.Version) { $Playbook.Version } else { $Playbook.version }
        $standardPlaybook.Sequence = if ($Playbook.Sequence) { $Playbook.Sequence } else { $Playbook.sequence }
        $standardPlaybook.Variables = if ($Playbook.Variables) { $Playbook.Variables } else { $Playbook.variables }
        $standardPlaybook.Stages = if ($Playbook.Stages) { $Playbook.Stages } else { $Playbook.stages }
        
        # Copy other properties as-is
        foreach ($key in $Playbook.Keys) {
            if ($key -notin @('Name', 'name', 'Description', 'description', 'Version', 'version', 
                             'Sequence', 'sequence', 'Variables', 'variables', 'Stages', 'stages')) {
                $standardPlaybook[$key] = $Playbook[$key]
            }
        }
        
        return $standardPlaybook
    }
}

function Get-OrchestrationPlaybook {
    param([string]$Name)

    # First try direct path in playbooks root
    $playbookPath = Join-Path $script:OrchestrationPath "playbooks/$Name.json"

    if (Test-Path $playbookPath) {
        $playbook = Get-Content $playbookPath -Raw | ConvertFrom-Json -AsHashtable
        return ConvertTo-StandardPlaybookFormat $playbook
    }

    # Then search in subdirectories
    $playbooksDir = Join-Path $script:OrchestrationPath "playbooks"
    $foundPlaybook = Get-ChildItem -Path $playbooksDir -Filter "$Name.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($foundPlaybook) {
        $playbook = Get-Content $foundPlaybook.FullName -Raw | ConvertFrom-Json -AsHashtable
        return ConvertTo-StandardPlaybookFormat $playbook
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

# ================================
# GitHub Actions-style Job Execution (v3.0)
# ================================

function Invoke-JobBasedOrchestration {
    <#
    .SYNOPSIS
    Execute orchestration using GitHub Actions-style jobs and steps (v3.0 schema)
    
    .DESCRIPTION
    Processes v3.0 playbooks with jobs, steps, outputs, and matrix strategies.
    Provides enhanced dependency management, output propagation, and observability.
    
    .PARAMETER Playbook
    The v3.0 playbook object containing jobs
    
    .PARAMETER Variables
    Variables to pass to jobs and steps
    
    .PARAMETER Configuration
    Configuration hashtable
    
    .PARAMETER DryRun
    Show what would be executed without running
    
    .EXAMPLE
    $playbook = Get-OrchestrationPlaybook -Name 'test-quick-v3'
    Invoke-JobBasedOrchestration -Playbook $playbook
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Playbook,
        
        [Parameter()]
        [hashtable]$Variables = @{},
        
        [Parameter()]
        [hashtable]$Configuration = @{},
        
        [Parameter()]
        [switch]$DryRun
    )
    
    Write-OrchestrationLog "Starting job-based orchestration (v3.0)" -Level 'Information'
    
    # Extract orchestration section
    $orchestration = $Playbook.orchestration
    if (-not $orchestration -or -not $orchestration.jobs) {
        throw "Invalid v3.0 playbook: missing orchestration.jobs"
    }
    
    # Merge global environment variables
    $globalEnv = @{}
    if ($orchestration.env) {
        foreach ($key in $orchestration.env.Keys) {
            $globalEnv[$key] = $orchestration.env[$key]
        }
    }
    
    # Build job dependency graph
    $jobs = $orchestration.jobs
    $jobGraph = Build-JobDependencyGraph -Jobs $jobs
    
    if ($DryRun) {
        Write-OrchestrationLog "DRY RUN MODE - Showing execution plan" -Level 'Information'
        Show-JobExecutionPlan -Jobs $jobs -Graph $jobGraph
        return
    }
    
    # Initialize execution context
    $context = @{
        Jobs = @{}        # Job results
        Outputs = @{}     # Job outputs
        Steps = @{}       # Step outputs within jobs
        StartTime = Get-Date
        Failed = @()      # Failed jobs
        Skipped = @()     # Skipped jobs
    }
    
    # Execute jobs respecting dependencies
    $result = Invoke-JobGraphExecution -Jobs $jobs -Graph $jobGraph -Context $context -GlobalEnv $globalEnv -Variables $Variables -Configuration $Configuration
    
    # Generate summary
    $duration = New-TimeSpan -Start $context.StartTime -End (Get-Date)
    
    Write-OrchestrationLog "Job-based orchestration completed" -Level 'Information' -Data @{
        TotalJobs = $jobs.Count
        Completed = $context.Jobs.Count
        Failed = $context.Failed.Count
        Skipped = $context.Skipped.Count
        Duration = $duration.TotalSeconds
    }
    
    return [PSCustomObject]@{
        Total = $jobs.Count
        Completed = $context.Jobs.Count
        Failed = $context.Failed.Count
        Skipped = $context.Skipped.Count
        Duration = $duration
        Results = $context.Jobs
        Outputs = $context.Outputs
    }
}

function Build-JobDependencyGraph {
    <#
    .SYNOPSIS
    Build dependency graph for jobs (similar to GitHub Actions 'needs')
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Jobs
    )
    
    $graph = @{}
    
    foreach ($jobId in $Jobs.Keys) {
        $job = $Jobs[$jobId]
        
        $graph[$jobId] = @{
            Job = $job
            JobId = $jobId
            Dependencies = @()
            Dependents = @()
        }
        
        # Parse 'needs' field
        if ($job.needs) {
            if ($job.needs -is [string]) {
                $graph[$jobId].Dependencies += $job.needs
            } elseif ($job.needs -is [array]) {
                $graph[$jobId].Dependencies += $job.needs
            }
        }
    }
    
    # Build reverse dependencies (dependents)
    foreach ($jobId in $graph.Keys) {
        foreach ($dep in $graph[$jobId].Dependencies) {
            if ($graph.ContainsKey($dep)) {
                $graph[$dep].Dependents += $jobId
            }
        }
    }
    
    return $graph
}

function Invoke-JobGraphExecution {
    <#
    .SYNOPSIS
    Execute jobs respecting dependency graph (parallel where possible)
    #>
    param(
        [hashtable]$Jobs,
        [hashtable]$Graph,
        [hashtable]$Context,
        [hashtable]$GlobalEnv,
        [hashtable]$Variables,
        [hashtable]$Configuration
    )
    
    $completed = @{}
    $failed = @{}
    $running = @{}
    
    while ($completed.Count + $failed.Count + $Context.Skipped.Count -lt $Jobs.Count) {
        # Find jobs ready to run (all dependencies completed)
        $ready = @()
        foreach ($jobId in $Jobs.Keys) {
            if ($jobId -notin $completed.Keys -and 
                $jobId -notin $failed.Keys -and 
                $jobId -notin $running.Keys -and
                $jobId -notin $Context.Skipped) {
                
                # Check if all dependencies are met
                $node = $Graph[$jobId]
                $depsMet = $true
                
                foreach ($dep in $node.Dependencies) {
                    if ($dep -notin $completed.Keys) {
                        # Check if dependency failed
                        if ($dep -in $failed.Keys) {
                            # Skip this job if dependency failed
                            Write-OrchestrationLog "Skipping job '$jobId' - dependency '$dep' failed" -Level 'Warning'
                            $Context.Skipped += $jobId
                            $depsMet = $false
                            break
                        }
                        $depsMet = $false
                        break
                    }
                }
                
                if ($depsMet) {
                    $ready += $jobId
                }
            }
        }
        
        # Execute ready jobs
        foreach ($jobId in $ready) {
            $job = $Jobs[$jobId]
            
            Write-OrchestrationLog "Starting job: $jobId - $($job.name)" -Level 'Information'
            
            try {
                # Evaluate job condition
                if ($job.if) {
                    $conditionMet = Test-JobCondition -Condition $job.if -Context $Context
                    if (-not $conditionMet) {
                        Write-OrchestrationLog "Skipping job '$jobId' - condition not met: $($job.if)" -Level 'Information'
                        $Context.Skipped += $jobId
                        continue
                    }
                }
                
                # Execute job steps
                $jobResult = Invoke-JobSteps -Job $job -JobId $jobId -Context $Context -GlobalEnv $GlobalEnv -Variables $Variables -Configuration $Configuration
                
                if ($jobResult.Success) {
                    $completed[$jobId] = $jobResult
                    $Context.Jobs[$jobId] = $jobResult
                    
                    # Store job outputs
                    if ($job.outputs) {
                        $Context.Outputs[$jobId] = Resolve-JobOutputs -Job $job -JobResult $jobResult -Context $Context
                    }
                    
                    Write-OrchestrationLog "Completed job: $jobId" -Level 'Information' -Data @{
                        Duration = $jobResult.Duration.TotalSeconds
                        Steps = $jobResult.Steps.Count
                    }
                } else {
                    $failed[$jobId] = $jobResult
                    $Context.Failed += $jobId
                    
                    Write-OrchestrationLog "Failed job: $jobId - $($jobResult.Error)" -Level 'Error'
                    
                    # Check continue-on-error
                    if (-not $job.continueOnError) {
                        Write-OrchestrationLog "Aborting orchestration - job failed without continue-on-error" -Level 'Error'
                        return
                    }
                }
            } catch {
                $failed[$jobId] = @{ Success = $false; Error = $_.ToString() }
                $Context.Failed += $jobId
                Write-OrchestrationLog "Exception in job '$jobId': $_" -Level 'Error'
                
                if (-not $job.continueOnError) {
                    throw
                }
            }
        }
        
        # Prevent infinite loop if no progress
        if ($ready.Count -eq 0 -and $running.Count -eq 0) {
            # Check if we have unprocessed jobs (circular dependency or missing dependency)
            $unprocessed = $Jobs.Keys | Where-Object { $_ -notin $completed.Keys -and $_ -notin $failed.Keys -and $_ -notin $Context.Skipped }
            if ($unprocessed.Count -gt 0) {
                Write-OrchestrationLog "Deadlock detected - unprocessed jobs: $($unprocessed -join ', ')" -Level 'Error'
                break
            } else {
                break
            }
        }
    }
}

function Invoke-JobSteps {
    <#
    .SYNOPSIS
    Execute steps within a job sequentially
    #>
    param(
        [hashtable]$Job,
        [string]$JobId,
        [hashtable]$Context,
        [hashtable]$GlobalEnv,
        [hashtable]$Variables,
        [hashtable]$Configuration
    )
    
    $startTime = Get-Date
    $stepResults = @{}
    $stepOutputs = @{}
    
    # Merge environment variables (global + job-specific)
    $jobEnv = $GlobalEnv.Clone()
    if ($Job.env) {
        foreach ($key in $Job.env.Keys) {
            $jobEnv[$key] = $Job.env[$key]
        }
    }
    
    foreach ($step in $Job.steps) {
        $stepId = if ($step.id) { $step.id } else { "step_$($stepResults.Count + 1)" }
        $stepName = $step.name
        
        Write-OrchestrationLog "  Step: $stepName" -Level 'Information'
        
        try {
            # Evaluate step condition
            if ($step.if) {
                $conditionMet = Test-StepCondition -Condition $step.if -Context $Context -JobId $JobId -StepOutputs $stepOutputs
                if (-not $conditionMet) {
                    Write-OrchestrationLog "    Skipping step '$stepName' - condition not met" -Level 'Debug'
                    $stepResults[$stepId] = @{ Skipped = $true }
                    continue
                }
            }
            
            # Merge step environment
            $stepEnv = $jobEnv.Clone()
            if ($step.env) {
                foreach ($key in $step.env.Keys) {
                    $stepEnv[$key] = $step.env[$key]
                }
            }
            
            # Execute step based on type (run, uses, script)
            $stepResult = if ($step.run) {
                # Execute automation script
                Invoke-AutomationScript -ScriptNumber $step.run -Parameters $step.with -Environment $stepEnv
            } elseif ($step.script) {
                # Execute inline script
                Invoke-InlineScript -Script $step.script -Environment $stepEnv
            } elseif ($step.uses) {
                # Execute reusable action/playbook
                Invoke-ReusableAction -Action $step.uses -Parameters $step.with -Environment $stepEnv
            } else {
                throw "Step '$stepName' has no executable content (run, script, or uses)"
            }
            
            # Store step outputs
            if ($step.outputs) {
                foreach ($output in $step.outputs) {
                    $outputValue = Invoke-Expression $output.value
                    $stepOutputs[$output.name] = $outputValue
                }
            }
            
            $stepResults[$stepId] = @{
                Success = $true
                Result = $stepResult
                Outputs = if ($stepOutputs.Count -gt 0) { $stepOutputs.Clone() } else { @{} }
            }
            
        } catch {
            $stepResults[$stepId] = @{
                Success = $false
                Error = $_.ToString()
            }
            
            Write-OrchestrationLog "    Step failed: $stepName - $_" -Level 'Error'
            
            if (-not $step.continueOnError) {
                # Job fails if step fails without continue-on-error
                return @{
                    Success = $false
                    Error = "Step '$stepName' failed: $_"
                    Steps = $stepResults
                    Duration = New-TimeSpan -Start $startTime -End (Get-Date)
                }
            }
        }
    }
    
    # Store step outputs in context for this job
    $Context.Steps[$JobId] = $stepOutputs
    
    return @{
        Success = $true
        Steps = $stepResults
        StepOutputs = $stepOutputs
        Duration = New-TimeSpan -Start $startTime -End (Get-Date)
    }
}

function Invoke-AutomationScript {
    <#
    .SYNOPSIS
    Execute an automation script by number
    #>
    param(
        [string]$ScriptNumber,
        [hashtable]$Parameters,
        [hashtable]$Environment
    )
    
    $scriptPath = Get-ChildItem -Path $script:ScriptsPath -Filter "${ScriptNumber}_*.ps1" | Select-Object -First 1
    if (-not $scriptPath) {
        throw "Automation script not found: $ScriptNumber"
    }
    
    # Set environment variables
    foreach ($key in $Environment.Keys) {
        Set-Item -Path "env:$key" -Value $Environment[$key]
    }
    
    try {
        & $scriptPath.FullName @Parameters
        return @{ ExitCode = $LASTEXITCODE; Output = "Script executed" }
    } finally {
        # Clean up environment variables
        foreach ($key in $Environment.Keys) {
            Remove-Item -Path "env:$key" -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-InlineScript {
    <#
    .SYNOPSIS
    Execute inline PowerShell script
    #>
    param(
        [string]$Script,
        [hashtable]$Environment
    )
    
    # Set environment variables
    foreach ($key in $Environment.Keys) {
        Set-Item -Path "env:$key" -Value $Environment[$key]
    }
    
    try {
        $scriptBlock = [ScriptBlock]::Create($Script)
        $result = & $scriptBlock
        return @{ Success = $true; Output = $result }
    } finally {
        # Clean up environment variables
        foreach ($key in $Environment.Keys) {
            Remove-Item -Path "env:$key" -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-ReusableAction {
    <#
    .SYNOPSIS
    Execute a reusable action or playbook
    #>
    param(
        [string]$Action,
        [hashtable]$Parameters,
        [hashtable]$Environment
    )
    
    # Check if it's a playbook reference
    if ($Action.StartsWith('playbook:')) {
        $playbookName = $Action.Substring(9)
        $playbook = Get-OrchestrationPlaybook -Name $playbookName
        if (-not $playbook) {
            throw "Playbook not found: $playbookName"
        }
        
        # Execute nested playbook
        Invoke-OrchestrationSequence -LoadPlaybook $playbookName -Variables $Parameters
    } else {
        throw "Unknown action type: $Action"
    }
}

function Test-JobCondition {
    <#
    .SYNOPSIS
    Evaluate job-level condition
    #>
    param(
        [string]$Condition,
        [hashtable]$Context
    )
    
    # Handle special conditions
    if ($Condition -eq 'always()') {
        return $true
    }
    if ($Condition -eq 'success()') {
        return $Context.Failed.Count -eq 0
    }
    if ($Condition -eq 'failure()') {
        return $Context.Failed.Count -gt 0
    }
    
    # Evaluate as PowerShell expression
    try {
        $result = Invoke-Expression $Condition
        return [bool]$result
    } catch {
        Write-OrchestrationLog "Failed to evaluate job condition: $Condition - $_" -Level 'Warning'
        return $false
    }
}

function Test-StepCondition {
    <#
    .SYNOPSIS
    Evaluate step-level condition
    #>
    param(
        [string]$Condition,
        [hashtable]$Context,
        [string]$JobId,
        [hashtable]$StepOutputs
    )
    
    # Handle special conditions
    if ($Condition -eq 'always()') {
        return $true
    }
    if ($Condition -eq 'success()') {
        return $true  # Within job, success means previous steps succeeded
    }
    if ($Condition -eq 'failure()') {
        return $false  # We wouldn't reach here if previous step failed without continue-on-error
    }
    
    # Evaluate as PowerShell expression
    try {
        $result = Invoke-Expression $Condition
        return [bool]$result
    } catch {
        Write-OrchestrationLog "Failed to evaluate step condition: $Condition - $_" -Level 'Warning'
        return $false
    }
}

function Resolve-JobOutputs {
    <#
    .SYNOPSIS
    Resolve job output expressions
    #>
    param(
        [hashtable]$Job,
        [hashtable]$JobResult,
        [hashtable]$Context
    )
    
    $outputs = @{}
    
    foreach ($outputName in $Job.outputs.Keys) {
        $expression = $Job.outputs[$outputName]
        
        # Simple output resolution - would need more sophisticated parsing for full GitHub Actions syntax
        try {
            # For now, look up step outputs directly
            if ($expression -match 'steps\.(\w+)\.outputs\.(\w+)') {
                $stepId = $Matches[1]
                $outputKey = $Matches[2]
                
                if ($JobResult.StepOutputs.ContainsKey($outputKey)) {
                    $outputs[$outputName] = $JobResult.StepOutputs[$outputKey]
                }
            }
        } catch {
            Write-OrchestrationLog "Failed to resolve output '$outputName': $_" -Level 'Warning'
        }
    }
    
    return $outputs
}

function Show-JobExecutionPlan {
    <#
    .SYNOPSIS
    Display job execution plan with dependencies
    #>
    param(
        [hashtable]$Jobs,
        [hashtable]$Graph
    )
    
    Write-Host "`nJob Execution Plan (v3.0):" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    
    # Topological sort for display order
    $visited = @{}
    $sorted = @()
    
    function Visit-Job($jobId) {
        if ($visited.ContainsKey($jobId)) {
            return
        }
        
        $visited[$jobId] = $true
        
        # Visit dependencies first
        foreach ($dep in $Graph[$jobId].Dependencies) {
            Visit-Job $dep
        }
        
        $sorted += $jobId
    }
    
    foreach ($jobId in $Jobs.Keys) {
        Visit-Job $jobId
    }
    
    # Display jobs in execution order
    foreach ($jobId in $sorted) {
        $job = $Jobs[$jobId]
        $node = $Graph[$jobId]
        
        Write-Host "`nJob: $jobId" -ForegroundColor Yellow
        Write-Host "  Name: $($job.name)" -ForegroundColor White
        if ($job.description) {
            Write-Host "  Description: $($job.description)" -ForegroundColor Gray
        }
        if ($node.Dependencies.Count -gt 0) {
            Write-Host "  Depends on: $($node.Dependencies -join ', ')" -ForegroundColor DarkGray
        }
        Write-Host "  Steps: $($job.steps.Count)" -ForegroundColor White
        
        foreach ($step in $job.steps) {
            $stepType = if ($step.run) { "run: $($step.run)" } elseif ($step.script) { "script" } elseif ($step.uses) { "uses: $($step.uses)" } else { "unknown" }
            Write-Host "    - $($step.name) ($stepType)" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`nTotal jobs: $($Jobs.Count)" -ForegroundColor Green
}

# ================================
# End GitHub Actions-style Job Execution
# ================================

# Create alias for seq
Set-Alias -Name 'seq' -Value 'Invoke-OrchestrationSequence' -Scope Global -Force

# Export functions
Export-ModuleMember -Function @(
    'Invoke-OrchestrationSequence'
    'Invoke-Sequence'
    'Get-OrchestrationPlaybook'
    'Save-OrchestrationPlaybook'
    'ConvertTo-StandardPlaybookFormat'
    'Test-PlaybookConditions'
    'Send-PlaybookNotification'
    'Invoke-JobBasedOrchestration'
    'Build-JobDependencyGraph'
    'Invoke-JobGraphExecution'
    'Invoke-JobSteps'
    'Show-JobExecutionPlan'
) -Alias @('seq')