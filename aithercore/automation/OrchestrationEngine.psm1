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
$script:ScriptsPath = Join-Path $script:ProjectRoot 'library/automation-scripts'
$script:OrchestrationPath = Join-Path $script:ProjectRoot 'library/playbooks'

# Exit code constants
$script:EXIT_SUCCESS = 0
$script:EXIT_FAILURE = 1
$script:EXIT_TIMEOUT = 124  # Standard timeout exit code (used by GNU timeout command)

# Import logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path $script:ProjectRoot "aithercore/utilities/Logging.psm1"
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

function Test-CIEnvironment {
    <#
    .SYNOPSIS
        Detect if running in a CI/CD environment
    .DESCRIPTION
        Detects various CI/CD platforms and returns environment information
    .OUTPUTS
        [hashtable] CI environment information
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    $ciDetection = @{
        IsCI = $false
        Platform = 'Unknown'
        RunId = $null
        BuildNumber = $null
        Branch = $null
        Commit = $null
    }
    
    # GitHub Actions
    if ($env:GITHUB_ACTIONS -eq 'true') {
        $ciDetection.IsCI = $true
        $ciDetection.Platform = 'GitHub Actions'
        $ciDetection.RunId = $env:GITHUB_RUN_ID
        $ciDetection.BuildNumber = $env:GITHUB_RUN_NUMBER
        $ciDetection.Branch = $env:GITHUB_REF_NAME
        $ciDetection.Commit = $env:GITHUB_SHA
    }
    # Azure Pipelines
    elseif ($env:TF_BUILD -eq 'True') {
        $ciDetection.IsCI = $true
        $ciDetection.Platform = 'Azure Pipelines'
        $ciDetection.RunId = $env:BUILD_BUILDID
        $ciDetection.BuildNumber = $env:BUILD_BUILDNUMBER
        $ciDetection.Branch = $env:BUILD_SOURCEBRANCHNAME
        $ciDetection.Commit = $env:BUILD_SOURCEVERSION
    }
    # GitLab CI
    elseif ($env:GITLAB_CI -eq 'true') {
        $ciDetection.IsCI = $true
        $ciDetection.Platform = 'GitLab CI'
        $ciDetection.RunId = $env:CI_PIPELINE_ID
        $ciDetection.BuildNumber = $env:CI_PIPELINE_IID
        $ciDetection.Branch = $env:CI_COMMIT_REF_NAME
        $ciDetection.Commit = $env:CI_COMMIT_SHA
    }
    # Jenkins
    elseif ($env:JENKINS_URL) {
        $ciDetection.IsCI = $true
        $ciDetection.Platform = 'Jenkins'
        $ciDetection.RunId = $env:BUILD_ID
        $ciDetection.BuildNumber = $env:BUILD_NUMBER
        $ciDetection.Branch = $env:BRANCH_NAME ?? $env:GIT_BRANCH
        $ciDetection.Commit = $env:GIT_COMMIT
    }
    # Generic CI
    elseif ($env:CI -eq 'true') {
        $ciDetection.IsCI = $true
        $ciDetection.Platform = 'Generic CI'
    }
    
    return $ciDetection
}

function Export-OrchestrationResult {
    <#
    .SYNOPSIS
        Export orchestration results in multiple formats for CI/CD integration
    .DESCRIPTION
        Exports execution results in various formats suitable for CI/CD pipelines
    .PARAMETER Result
        Orchestration result object to export
    .PARAMETER Format
        Output format (JSON, XML, JUnit, GitHubActions)
    .PARAMETER Path
        Output file path
    .EXAMPLE
        Export-OrchestrationResult -Result $result -Format JUnit -Path "./test-results.xml"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result,
        
        [Parameter(Mandatory)]
        [ValidateSet('JSON', 'XML', 'JUnit', 'GitHubActions')]
        [string]$Format,
        
        [Parameter()]
        [string]$Path
    )
    
    $output = switch ($Format) {
        'JSON' {
            $Result | ConvertTo-Json -Depth 10
        }
        
        'XML' {
            # Create XML document
            $xml = New-Object System.Xml.XmlDocument
            $root = $xml.CreateElement('OrchestrationResult')
            $xml.AppendChild($root) | Out-Null
            
            # Add properties
            $props = @('Success', 'Completed', 'Failed', 'Skipped', 'Duration')
            foreach ($prop in $props) {
                if ($Result.PSObject.Properties[$prop]) {
                    $elem = $xml.CreateElement($prop)
                    $elem.InnerText = $Result.$prop
                    $root.AppendChild($elem) | Out-Null
                }
            }
            
            # Add script results
            if ($Result.Results) {
                $resultsElem = $xml.CreateElement('Scripts')
                foreach ($scriptResult in $Result.Results) {
                    $scriptElem = $xml.CreateElement('Script')
                    $scriptElem.SetAttribute('Number', $scriptResult.Number)
                    $scriptElem.SetAttribute('Success', $scriptResult.Success)
                    $scriptElem.SetAttribute('Duration', $scriptResult.Duration)
                    if ($scriptResult.Error) {
                        $scriptElem.SetAttribute('Error', $scriptResult.Error)
                    }
                    $resultsElem.AppendChild($scriptElem) | Out-Null
                }
                $root.AppendChild($resultsElem) | Out-Null
            }
            
            $xml.OuterXml
        }
        
        'JUnit' {
            # Create JUnit XML format
            $xml = New-Object System.Xml.XmlDocument
            $testsuites = $xml.CreateElement('testsuites')
            $xml.AppendChild($testsuites) | Out-Null
            
            $testsuite = $xml.CreateElement('testsuite')
            $testsuite.SetAttribute('name', 'AitherZero Orchestration')
            $testsuite.SetAttribute('tests', $Result.Completed + $Result.Failed)
            $testsuite.SetAttribute('failures', $Result.Failed)
            $testsuite.SetAttribute('skipped', $Result.Skipped ?? 0)
            $testsuite.SetAttribute('time', $Result.Duration.TotalSeconds)
            $testsuite.SetAttribute('timestamp', (Get-Date).ToString('o'))
            $testsuites.AppendChild($testsuite) | Out-Null
            
            if ($Result.Results) {
                foreach ($scriptResult in $Result.Results) {
                    $testcase = $xml.CreateElement('testcase')
                    $testcase.SetAttribute('name', "Script-$($scriptResult.Number)")
                    $testcase.SetAttribute('classname', 'AitherZero.Orchestration')
                    $testcase.SetAttribute('time', $scriptResult.Duration.TotalSeconds)
                    
                    if (-not $scriptResult.Success) {
                        $failure = $xml.CreateElement('failure')
                        $failure.SetAttribute('message', $scriptResult.Error ?? 'Script execution failed')
                        $failure.SetAttribute('type', 'ScriptFailure')
                        $testcase.AppendChild($failure) | Out-Null
                    }
                    
                    $testsuite.AppendChild($testcase) | Out-Null
                }
            }
            
            $xml.OuterXml
        }
        
        'GitHubActions' {
            # GitHub Actions output format with annotations
            $output = @()
            
            # Set outputs
            $output += "::set-output name=success::$($Result.Success ?? $true)"
            $output += "::set-output name=completed::$($Result.Completed ?? 0)"
            $output += "::set-output name=failed::$($Result.Failed ?? 0)"
            $output += "::set-output name=skipped::$($Result.Skipped ?? 0)"
            $output += "::set-output name=duration::$($Result.Duration.TotalSeconds)"
            
            # Add annotations for failures
            if ($Result.Results) {
                foreach ($scriptResult in $Result.Results | Where-Object { -not $_.Success }) {
                    $message = "Script $($scriptResult.Number) failed"
                    if ($scriptResult.Error) {
                        $message += ": $($scriptResult.Error)"
                    }
                    $output += "::error::$message"
                }
            }
            
            # Summary
            $totalScripts = $Result.Completed + $Result.Failed
            if ($Result.Failed -eq 0) {
                $output += "::notice::Orchestration succeeded: $($Result.Completed)/$totalScripts scripts completed"
            }
            else {
                $output += "::error::Orchestration failed: $($Result.Failed)/$totalScripts scripts failed"
            }
            
            $output -join "`n"
        }
    }
    
    if ($Path) {
        $output | Out-File -FilePath $Path -Encoding utf8 -NoNewline
        Write-OrchestrationLog "Report exported to: $Path" -Level 'Information'
    }
    else {
        Write-Output $output
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
    Enhanced with GitHub Actions-like features: matrix builds, caching, and job outputs.

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
    
    .PARAMETER ConfigFile
    Path to a custom configuration file that will be merged with config.psd1 and config.local.psd1.
    Config precedence (highest to lowest): ConfigFile > config.local.psd1 > config.psd1
    This enables environment-specific configurations (e.g., config.ci.psd1, config.production.psd1)

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

    .PARAMETER Matrix
    Matrix build parameters for parallel execution with different configurations
    
    .PARAMETER UseCache
    Enable caching of execution results and artifacts

    .PARAMETER GenerateSummary
    Generate markdown execution summary report
    
    .PARAMETER OutputFormat
    Export results in specified format for CI/CD integration:
    - JSON: Structured JSON output for parsing and processing
    - XML: Standard XML format for data exchange
    - JUnit: JUnit XML format for test result integration (compatible with Jenkins, GitLab CI, Azure Pipelines)
    - GitHubActions: GitHub Actions-specific output with annotations and workflow commands
    - None: No output file (default)
    
    .PARAMETER OutputPath
    Path where the output report file will be saved. Required when OutputFormat is not 'None'
    
    .PARAMETER ThrowOnError
    Throw a terminating exception if any script fails. Essential for CI/CD pipelines to detect failures.
    When enabled, sets exit code to 1 and throws an exception that will halt the pipeline.
    
    .PARAMETER Quiet
    Suppress non-essential console output. Useful for CI/CD environments where you only want errors and warnings.
    Sets the AITHERZERO_QUIET environment variable during execution.
    
    .PARAMETER PassThru
    Return the detailed execution result object even when not using OutputFormat.
    The result includes: Success, Completed, Failed, Skipped counts, Duration, and individual script results.

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
    # CI/CD: Run tests with custom config and JUnit output
    Invoke-OrchestrationSequence -Sequence "0402,0404,0407" -ConfigFile "./config.ci.psd1" -OutputFormat JUnit -OutputPath "./test-results.xml" -ThrowOnError
    
    # This is ideal for CI/CD pipelines:
    # - Custom config file for CI environment settings
    # - JUnit output for test result integration
    # - ThrowOnError ensures pipeline fails on errors
    
    .EXAMPLE
    # GitHub Actions integration
    Invoke-OrchestrationSequence -Sequence "stage:testing" -ConfigFile "./config.ci.psd1" -OutputFormat GitHubActions -Quiet
    
    # Outputs GitHub Actions workflow commands:
    # - ::set-output commands for workflow variables
    # - ::error annotations for failed scripts
    # - ::notice annotations for success summaries
    
    .EXAMPLE
    # Production deployment with custom config
    Invoke-OrchestrationSequence -LoadPlaybook "deploy-prod" -ConfigFile "./config.production.psd1" -ThrowOnError -PassThru
    
    # Uses production-specific configuration
    # Returns result object for programmatic access
    # Throws on error to halt deployment on failures

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
    
    .EXAMPLE
    # Matrix build - run tests with different configurations
    Invoke-OrchestrationSequence -Sequence "0402" -Matrix @{
        profile = @('quick', 'comprehensive')
        platform = @('Windows', 'Linux')
    }
    
    .EXAMPLE
    # With caching enabled
    Invoke-OrchestrationSequence -LoadPlaybook "test-full" -UseCache -GenerateSummary
    
    .OUTPUTS
    [PSCustomObject] Execution result object when PassThru or OutputFormat is specified.
    Contains: Success, Completed, Failed, Skipped, Duration, Results, ExitCode
    
    .NOTES
    Exit Codes:
    - 0: All scripts succeeded
    - 1: One or more scripts failed (only when not using -ContinueOnError)
    - 10: Partial success (some scripts failed but ContinueOnError was enabled)
    
    Configuration Hierarchy (when using -ConfigFile):
    1. Custom config file specified in -ConfigFile (highest priority)
    2. config.local.psd1 (local developer overrides, gitignored)
    3. config.psd1 (base configuration)
    
    CI/CD Integration:
    - Automatically detects CI environments (GitHub Actions, Azure Pipelines, GitLab CI, Jenkins)
    - Sets appropriate exit codes for pipeline failure detection
    - Supports standard output formats (JUnit, JSON) for result integration
    
    .LINK
    Get-MergedConfiguration
    
    .LINK
    Invoke-AitherWorkflow
    
    .LINK
    Test-CIEnvironment
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
        [string]$ConfigFile,

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
        [hashtable]$Matrix,

        [Parameter()]
        [switch]$UseCache,

        [Parameter()]
        [switch]$GenerateSummary,
        
        [Parameter()]
        [ValidateSet('JSON', 'XML', 'JUnit', 'GitHubActions', 'None')]
        [string]$OutputFormat = 'None',
        
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$ThrowOnError,
        
        [Parameter()]
        [switch]$Quiet,
        
        [Parameter()]
        [switch]$PassThru
    )

    begin {
        # Set quiet mode for CI/CD
        if ($Quiet) {
            $env:AITHERZERO_QUIET = '1'
        }
        
        # Detect CI environment
        $ciInfo = Test-CIEnvironment
        if ($ciInfo.IsCI -and -not $Quiet) {
            Write-OrchestrationLog "CI environment detected: $($ciInfo.Platform)" -Level 'Information'
        }
        
        Write-OrchestrationLog "Starting orchestration engine"

        # Load configuration with custom config file support
        if ($ConfigFile) {
            Write-OrchestrationLog "Loading configuration from custom file: $ConfigFile" -Level 'Information'
            # Get merged configuration (config.psd1 < config.local.psd1 < custom file)
            if (Get-Command Get-MergedConfiguration -ErrorAction SilentlyContinue) {
                $customConfig = Get-MergedConfiguration -ConfigFile $ConfigFile
                # If Configuration is also provided as hashtable, merge it on top
                if ($Configuration -is [hashtable]) {
                    $customConfig = Merge-Configuration -Current $customConfig -New $Configuration
                }
                $config = Get-OrchestrationConfiguration -Configuration $customConfig
            }
            else {
                # Fallback to standard loading
                $config = Get-OrchestrationConfiguration -Configuration $Configuration
            }
        }
        else {
            $config = Get-OrchestrationConfiguration -Configuration $Configuration
        }

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
            # Validate playbook is enabled in configuration
            if ($config.Automation.Playbooks -and $config.Automation.Playbooks.ContainsKey($LoadPlaybook)) {
                $playbookConfig = $config.Automation.Playbooks[$LoadPlaybook]
                
                # Check if playbook is enabled
                if ($playbookConfig.Enabled -eq $false) {
                    throw "Playbook '$LoadPlaybook' is disabled in configuration. Enable it in config.psd1 Automation.Playbooks section."
                }
                
                # Check environment restrictions
                $currentEnv = if ($env:AITHERZERO_ENVIRONMENT) { 
                    $env:AITHERZERO_ENVIRONMENT 
                } elseif ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true') {
                    'CI'
                } else {
                    'Dev'
                }
                
                if ($playbookConfig.AllowedEnvironments -and $playbookConfig.AllowedEnvironments.Count -gt 0) {
                    if ($currentEnv -notin $playbookConfig.AllowedEnvironments) {
                        throw "Playbook '$LoadPlaybook' is not allowed in '$currentEnv' environment. Allowed: $($playbookConfig.AllowedEnvironments -join ', ')"
                    }
                }
                
                # Check if approval required
                if ($playbookConfig.RequiresApproval -and -not $Interactive) {
                    Write-OrchestrationLog "Playbook '$LoadPlaybook' requires approval" -Level 'Warning'
                    if (-not $config.Automation.SkipConfirmation) {
                        $response = Read-Host "Execute playbook '$LoadPlaybook'? (yes/no)"
                        if ($response -ne 'yes') {
                            throw "Playbook execution cancelled by user"
                        }
                    }
                }
                
                Write-OrchestrationLog "Playbook '$LoadPlaybook' validated: $($playbookConfig.Description)" -Level 'Information'
            } else {
                Write-OrchestrationLog "Playbook '$LoadPlaybook' not found in configuration registry - proceeding without validation" -Level 'Warning'
            }
            
            $playbook = Get-OrchestrationPlaybook -Name $LoadPlaybook
            if (-not $playbook) {
                throw "Playbook not found: $LoadPlaybook"
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
                # Check if Sequence contains hashtable objects (v1 playbook with script definitions)
                # or simple strings/numbers (traditional format)
                if ($playbook.Sequence[0] -is [hashtable]) {
                    Write-OrchestrationLog "Playbook contains script definitions, normalizing and extracting script numbers/paths"
                    $extractedSequence = @()
                    
                    # Store normalized script definitions for later use
                    $script:PlaybookScriptDefinitions = @{}
                    $validationIssues = @()
                    
                    foreach ($scriptDef in $playbook.Sequence) {
                        # Normalize the script definition (pass Configuration for defaults)
                        $normalized = ConvertTo-NormalizedScriptDefinition -Definition $scriptDef -ScriptNumber 'Unknown' -Configuration $Configuration
                        
                        if (-not $normalized.Valid) {
                            $validationIssues += "Skipping invalid script definition: $($normalized.ValidationIssues -join '; ')"
                            Write-OrchestrationLog "Skipping invalid script definition: $($normalized.ValidationIssues -join '; ')" -Level 'Warning'
                            continue
                        }
                        
                        if ($normalized.ValidationIssues.Count -gt 0) {
                            Write-OrchestrationLog "Script definition issues: $($normalized.ValidationIssues -join '; ')" -Level 'Warning'
                        }
                        
                        if ($normalized.Script) {
                            # Extract just the script name/number
                            $scriptName = $normalized.Script
                            $scriptNumber = $null
                            
                            # Strip off anything besides the four-digit number
                            # Handles formats like:
                            # - "0407_Validate-Syntax.ps1" -> "0407"
                            # - "0407" -> "0407"
                            # - "automation-scripts/0407_Validate-Syntax.ps1" -> "0407"
                            # - "library/automation-scripts/0407.ps1" -> "0407"
                            if ($scriptName -match '(\d{4})') {
                                $scriptNumber = $Matches[1]
                            }
                            # If no four-digit number found, throw an exception
                            else {
                                $errorMsg = "Script name '$scriptName' does not contain a four-digit number. All scripts must be referenced by their four-digit number (e.g., '0407', '0413', or '0512')."
                                Write-OrchestrationLog $errorMsg -Level 'Error'
                                throw $errorMsg
                            }
                            
                            if ($scriptNumber) {
                                $extractedSequence += $scriptNumber
                                
                                # Store the normalized script definition keyed by script number
                                $script:PlaybookScriptDefinitions[$scriptNumber] = @{
                                    Script = $normalized.Script
                                    Parameters = $normalized.Parameters
                                    Timeout = $normalized.Timeout
                                    ContinueOnError = $normalized.ContinueOnError
                                    Description = $normalized.Description
                                }
                            }
                        }
                    }
                    
                    if ($validationIssues.Count -gt 0) {
                        Write-OrchestrationLog "Playbook validation found $($validationIssues.Count) issue(s)" -Level 'Warning'
                    }
                    
                    $Sequence = $extractedSequence
                    Write-OrchestrationLog "Extracted sequence: $($Sequence -join ', ')"
                } else {
                    # Traditional format - already strings/numbers
                    $Sequence = $playbook.Sequence
                    $script:PlaybookScriptDefinitions = $null
                }
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

        # Initialize caching system if enabled
        if ($UseCache) {
            $script:CacheManager = Initialize-OrchestrationCache -Configuration $config
            Write-OrchestrationLog "Caching enabled - cache directory: $($script:CacheManager.CacheDir)" -Level 'Information'
        }

        # Initialize execution summary tracking if requested
        if ($GenerateSummary) {
            $script:ExecutionSummary = @{
                StartTime = Get-Date
                Playbook = $LoadPlaybook
                Variables = $Variables
                Stages = @()
                Outputs = @{}
            }
            Write-OrchestrationLog "Execution summary generation enabled" -Level 'Information'
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
        $scripts = Get-OrchestrationScripts -Numbers $scriptNumbers -Variables $Variables -Conditions $Conditions -Configuration $Configuration -PlaybookName $LoadPlaybook

        # Matrix build handling - expand scripts for each matrix combination
        if ($Matrix) {
            Write-OrchestrationLog "Matrix build enabled with $($Matrix.Keys.Count) dimensions" -Level 'Information'
            $scripts = Expand-MatrixBuilds -Scripts $scripts -Matrix $Matrix -Variables $Variables
            Write-OrchestrationLog "Expanded to $($scripts.Count) matrix job(s)" -Level 'Information'
        }

        # Save playbook if requested
        if ($SavePlaybook) {
            Save-OrchestrationPlaybook -Name $SavePlaybook -Sequence $Sequence -Variables $Variables -Profile $ExecutionProfile
            Write-OrchestrationLog "Saved playbook: $SavePlaybook"
        }

        # Dry run mode
        if ($DryRun) {
            Write-OrchestrationLog "DRY RUN MODE - No scripts will be executed"
            if ($Matrix) {
                Show-MatrixOrchestrationPlan -Scripts $scripts -Matrix $Matrix
            } else {
                Show-OrchestrationPlan -Scripts $scripts
            }
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

            # Generate execution summary if requested
            if ($GenerateSummary) {
                $script:ExecutionSummary.EndTime = Get-Date
                $script:ExecutionSummary.Duration = $result.Duration
                $script:ExecutionSummary.Result = $result
                $summaryPath = Export-OrchestrationSummary -Summary $script:ExecutionSummary -Configuration $config
                Write-OrchestrationLog "Execution summary saved to: $summaryPath" -Level 'Information'
                
                # Add summary path to result
                $result | Add-Member -NotePropertyName 'SummaryPath' -NotePropertyValue $summaryPath -Force
            }

            # Save to cache if enabled
            if ($UseCache) {
                Save-OrchestrationCache -CacheManager $script:CacheManager -Result $result -Scripts $scripts -Variables $Variables
                Write-OrchestrationLog "Execution result cached" -Level 'Information'
            }
            
            # Export in specified format if requested
            if ($OutputFormat -ne 'None') {
                if ($OutputPath) {
                    Export-OrchestrationResult -Result $result -Format $OutputFormat -Path $OutputPath
                } else {
                    Export-OrchestrationResult -Result $result -Format $OutputFormat
                }
            }
            
            # Set exit code based on results
            # Exit code 10 for partial success when ContinueOnError is used
            # Exit code 1 for failures when ContinueOnError is not used
            # Exit code 0 for complete success
            if ($result.Failed -eq 0) {
                $exitCode = 0
            }
            elseif ($ContinueOnError) {
                $exitCode = 10  # Partial success
            }
            else {
                $exitCode = 1  # Failure
            }
            $global:LASTEXITCODE = $exitCode
            
            # Throw on error if requested (for CI/CD)
            if ($ThrowOnError -and $result.Failed -gt 0) {
                throw "Orchestration failed: $($result.Failed) script(s) failed"
            }

            # Return execution result if PassThru or for CI/CD tracking
            if ($PassThru -or $OutputFormat -ne 'None') {
                return $result
            }
        }
        catch {
            # Send failure notification
            if ($LoadPlaybook -and $playbook.Notifications) {
                Send-PlaybookNotification -NotificationConfig $playbook.Notifications -Type 'onFailure' -Context @{
                    playbook = $playbook.Name
                    error = $_.Exception.Message
                }
            }
            
            # Set error exit code
            $global:LASTEXITCODE = 1
            
            # Re-throw if requested
            if ($ThrowOnError) {
                throw
            }
            
            Write-OrchestrationLog "Orchestration failed: $($_.Exception.Message)" -Level 'Error'
        }
        finally {
            # Clean up environment
            if ($Quiet) {
                Remove-Item Env:\AITHERZERO_QUIET -ErrorAction SilentlyContinue
            }
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
            $currentProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $currentScriptsPath = Join-Path $currentProjectRoot 'library/automation-scripts'
            $existingScripts = Get-ChildItem -Path $currentScriptsPath -Filter "*.ps1" -File |
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

            $currentProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $currentScriptsPath = Join-Path $currentProjectRoot 'library/automation-scripts'
            $matchingScripts = Get-ChildItem -Path $currentScriptsPath -Filter "${pattern}_*.ps1" -File |
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

function ConvertTo-NormalizedScriptDefinition {
    <#
    .SYNOPSIS
    Normalizes a script definition to a standard format with validation
    
    .DESCRIPTION
    Handles different playbook formats and property name variations.
    Validates types and provides safe defaults for missing properties.
    Uses configuration file for fallback defaults.
    
    .PARAMETER Definition
    The script definition (can be string, number, or hashtable)
    
    .PARAMETER ScriptNumber
    The extracted script number (for context in error messages)
    
    .PARAMETER Configuration
    Configuration hashtable with system defaults
    #>
    param(
        [Parameter(Mandatory)]
        $Definition,
        
        [string]$ScriptNumber,
        
        [hashtable]$Configuration
    )
    
    # Get system defaults from configuration
    $defaultTimeout = if ($Configuration -and $Configuration.Automation.DefaultTimeout) {
        $Configuration.Automation.DefaultTimeout
    } else {
        3600  # 1 hour fallback
    }
    
    $defaultContinueOnError = if ($Configuration -and $null -ne $Configuration.Automation.ContinueOnError) {
        $Configuration.Automation.ContinueOnError
    } else {
        $false
    }
    
    # Maximum allowed timeout (from config or hardcoded)
    $maxTimeout = if ($Configuration -and $Configuration.Automation.MaxTimeout) {
        $Configuration.Automation.MaxTimeout
    } else {
        7200  # 2 hours
    }
    
    $normalized = @{
        Script = $null
        ScriptNumber = $ScriptNumber
        Parameters = @{}
        Timeout = $null  # null means use default or no timeout
        ContinueOnError = $defaultContinueOnError
        Description = ''
        Valid = $true
        ValidationIssues = @()
    }
    
    # Handle different definition formats
    if ($Definition -is [hashtable]) {
        # Extract Script property (case-insensitive)
        $scriptProp = $Definition['Script'] ?? $Definition['script'] ?? $Definition['ScriptPath'] ?? $Definition['scriptPath']
        if (-not $scriptProp) {
            $normalized.Valid = $false
            $normalized.ValidationIssues += "Script definition missing 'Script' property"
            return $normalized
        }
        $normalized.Script = $scriptProp
        
        # Extract Parameters (case-insensitive, type-safe)
        $paramsProp = $Definition['Parameters'] ?? $Definition['parameters'] ?? $Definition['Params'] ?? $Definition['params']
        if ($paramsProp) {
            if ($paramsProp -is [hashtable]) {
                $normalized.Parameters = $paramsProp
            } elseif ($paramsProp -is [System.Collections.IDictionary]) {
                # Convert IDictionary to hashtable
                $normalized.Parameters = @{}
                foreach ($key in $paramsProp.Keys) {
                    $normalized.Parameters[$key] = $paramsProp[$key]
                }
            } else {
                $normalized.ValidationIssues += "Parameters must be a hashtable, got $($paramsProp.GetType().Name)"
                $normalized.Parameters = @{}
            }
        }
        
        # Extract Timeout (case-insensitive, type-safe)
        $timeoutProp = $Definition['Timeout'] ?? $Definition['timeout'] ?? $Definition['TimeoutSeconds'] ?? $Definition['timeoutSeconds']
        if ($null -ne $timeoutProp) {
            try {
                $timeoutValue = [int]$timeoutProp
                if ($timeoutValue -le 0) {
                    $normalized.ValidationIssues += "Timeout must be positive, got $timeoutValue (using default: ${defaultTimeout}s)"
                    $normalized.Timeout = $defaultTimeout
                } elseif ($timeoutValue -gt $maxTimeout) {
                    $normalized.ValidationIssues += "Timeout exceeds maximum (${maxTimeout}s), got $timeoutValue (capping at ${maxTimeout}s)"
                    $normalized.Timeout = $maxTimeout
                } else {
                    $normalized.Timeout = $timeoutValue
                }
            } catch {
                $normalized.ValidationIssues += "Timeout must be an integer, got '$timeoutProp' (using default: ${defaultTimeout}s)"
                $normalized.Timeout = $defaultTimeout
            }
        }
        
        # Extract ContinueOnError (case-insensitive, type-safe)
        $continueProp = $Definition['ContinueOnError'] ?? $Definition['continueOnError'] ?? $Definition['continue_on_error']
        if ($null -ne $continueProp) {
            if ($continueProp -is [bool]) {
                $normalized.ContinueOnError = $continueProp
            } elseif ($continueProp -is [string]) {
                $normalized.ContinueOnError = $continueProp -in @('true', 'True', 'TRUE', '1', 'yes', 'Yes', 'YES')
            } elseif ($continueProp -is [int]) {
                $normalized.ContinueOnError = $continueProp -ne 0
            } else {
                $normalized.ValidationIssues += "ContinueOnError must be boolean, got $($continueProp.GetType().Name) (using default: $defaultContinueOnError)"
                $normalized.ContinueOnError = $defaultContinueOnError
            }
        }
        
        # Extract Description (case-insensitive)
        $descProp = $Definition['Description'] ?? $Definition['description']
        if ($descProp) {
            $normalized.Description = $descProp.ToString()
        }
        
    } elseif ($Definition -is [string] -or $Definition -is [int]) {
        # Simple format - just script number/name
        $normalized.Script = $Definition.ToString()
    } else {
        $normalized.Valid = $false
        $normalized.ValidationIssues += "Invalid definition type: $($Definition.GetType().Name)"
    }
    
    return $normalized
}

function Get-ScriptRangeDefaults {
    <#
    .SYNOPSIS
    Gets default settings for a script based on its number range
    
    .DESCRIPTION
    Looks up defaults from configuration based on script number.
    Falls back to global defaults if range not found.
    
    .PARAMETER ScriptNumber
    The script number (e.g., '0407')
    
    .PARAMETER Configuration
    Configuration hashtable with script range defaults
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptNumber,
        
        [hashtable]$Configuration
    )
    
    $defaults = @{
        Timeout = $null
        ContinueOnError = $false
        RequiresElevation = $false
        Stage = 'Default'
        AllowParallel = $true
    }
    
    if (-not $Configuration -or -not $Configuration.Automation) {
        return $defaults
    }
    
    # Get global automation defaults
    if ($Configuration.Automation.DefaultTimeout) {
        $defaults.Timeout = $Configuration.Automation.DefaultTimeout
    }
    if ($null -ne $Configuration.Automation.ContinueOnError) {
        $defaults.ContinueOnError = $Configuration.Automation.ContinueOnError
    }
    
    # Find matching range
    if ($Configuration.Automation.ScriptRangeDefaults) {
        $number = [int]$ScriptNumber
        
        foreach ($range in $Configuration.Automation.ScriptRangeDefaults.Keys) {
            if ($range -match '^(\d{4})-(\d{4})$') {
                $start = [int]$Matches[1]
                $end = [int]$Matches[2]
                
                if ($number -ge $start -and $number -le $end) {
                    $rangeDefaults = $Configuration.Automation.ScriptRangeDefaults[$range]
                    
                    # Override with range-specific defaults
                    if ($rangeDefaults.DefaultTimeout) {
                        $defaults.Timeout = $rangeDefaults.DefaultTimeout
                    }
                    if ($null -ne $rangeDefaults.ContinueOnError) {
                        $defaults.ContinueOnError = $rangeDefaults.ContinueOnError
                    }
                    if ($null -ne $rangeDefaults.RequiresElevation) {
                        $defaults.RequiresElevation = $rangeDefaults.RequiresElevation
                    }
                    if ($rangeDefaults.Stage) {
                        $defaults.Stage = $rangeDefaults.Stage
                    }
                    if ($null -ne $rangeDefaults.AllowParallel) {
                        $defaults.AllowParallel = $rangeDefaults.AllowParallel
                    }
                    
                    break
                }
            }
        }
    }
    
    return $defaults
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
        [hashtable]$Conditions,
        [hashtable]$Configuration,
        [string]$PlaybookName  # Add playbook name for config lookup
    )

    $scripts = @()
    
    # Get playbook-specific defaults from config if available
    $playbookDefaults = $null
    if ($PlaybookName -and $Configuration.Automation.Playbooks -and $Configuration.Automation.Playbooks.ContainsKey($PlaybookName)) {
        $playbookDefaults = $Configuration.Automation.Playbooks[$PlaybookName].ScriptDefaults
    }

    foreach ($number in $Numbers) {
        # Dynamically resolve scripts path (same as playbooks path fix)
        $currentProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $currentScriptsPath = Join-Path $currentProjectRoot 'library/automation-scripts'
        
        $scriptFile = Get-ChildItem -Path $currentScriptsPath -Filter "${number}_*.ps1" -File | Select-Object -First 1

        if (-not $scriptFile) {
            Write-OrchestrationLog "Script not found for number: $number" -Level 'Warning'
            continue
        }

        # Get configuration defaults for this script range
        $configDefaults = Get-ScriptRangeDefaults -ScriptNumber $number -Configuration $Configuration
        
        # Apply playbook-specific defaults if available (overrides range defaults)
        if ($playbookDefaults) {
            # Check for script-specific override
            if ($playbookDefaults.ContainsKey($number)) {
                $scriptOverride = $playbookDefaults[$number]
                if ($scriptOverride.Timeout) {
                    $configDefaults.Timeout = $scriptOverride.Timeout
                }
                if ($null -ne $scriptOverride.ContinueOnError) {
                    $configDefaults.ContinueOnError = $scriptOverride.ContinueOnError
                }
            }
            # Check for playbook-wide defaults
            if ($playbookDefaults.DefaultTimeout) {
                $configDefaults.Timeout = $playbookDefaults.DefaultTimeout
            }
            if ($null -ne $playbookDefaults.ContinueOnError) {
                $configDefaults.ContinueOnError = $playbookDefaults.ContinueOnError
            }
        }

        # Parse script metadata
        $metadata = Get-ScriptMetadata -Path $scriptFile.FullName
        
        # Merge metadata with config defaults (metadata takes precedence)
        if (-not $metadata.Stage -or $metadata.Stage -eq 'Default') {
            $metadata.Stage = $configDefaults.Stage
        }

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

        # Check if this script has playbook-defined properties (Parameters, Timeout, ContinueOnError)
        # Priority: Playbook > Script metadata > Config defaults > Hardcoded defaults
        $playbookDefinition = $null
        if ($script:PlaybookScriptDefinitions -and $script:PlaybookScriptDefinitions.ContainsKey($number)) {
            $playbookDefinition = $script:PlaybookScriptDefinitions[$number]
            Write-OrchestrationLog "Applying playbook definition for script $number" -Level 'Debug'
            
            # Validate parameters against script signature
            if ($playbookDefinition.Parameters -and $playbookDefinition.Parameters.Count -gt 0) {
                $scriptInfo = Get-Command $scriptFile.FullName -ErrorAction SilentlyContinue
                if ($scriptInfo) {
                    $invalidParams = @()
                    foreach ($paramName in $playbookDefinition.Parameters.Keys) {
                        if (-not $scriptInfo.Parameters.ContainsKey($paramName)) {
                            $invalidParams += $paramName
                        }
                    }
                    
                    if ($invalidParams.Count -gt 0) {
                        Write-OrchestrationLog "Warning: Script $number has invalid playbook parameters: $($invalidParams -join ', ')" -Level 'Warning'
                        # Remove invalid parameters
                        foreach ($invalidParam in $invalidParams) {
                            $playbookDefinition.Parameters.Remove($invalidParam)
                        }
                    }
                }
            }
        }

        # Build script object with metadata and playbook-defined properties
        # Priority order: Playbook > Config Defaults > Hardcoded Defaults
        $scriptObj = [PSCustomObject]@{
            Number = $number
            Name = $scriptFile.Name
            Path = $scriptFile.FullName
            Stage = $metadata.Stage
            Dependencies = $metadata.Dependencies
            Description = if ($playbookDefinition -and $playbookDefinition.Description) { 
                $playbookDefinition.Description 
            } else { 
                $metadata.Description 
            }
            Condition = $metadata.Condition
            Tags = $metadata.Tags
            Priority = [int]$number
            Variables = $stageVariables  # Include stage-specific variables
            
            # Playbook-defined properties (validated and normalized)
            # Priority: Playbook > Config Range Defaults > Hardcoded
            Parameters = if ($playbookDefinition -and $playbookDefinition.Parameters) { 
                $playbookDefinition.Parameters 
            } else { 
                @{} 
            }
            Timeout = if ($playbookDefinition -and $playbookDefinition.Timeout) { 
                $playbookDefinition.Timeout  # Playbook wins
            } elseif ($configDefaults.Timeout) {
                $configDefaults.Timeout  # Config default second
            } else { 
                $null  # No timeout
            }
            ContinueOnError = if ($playbookDefinition -and $null -ne $playbookDefinition.ContinueOnError) { 
                [bool]$playbookDefinition.ContinueOnError  # Playbook wins
            } else { 
                [bool]$configDefaults.ContinueOnError  # Config default second
            }
            RequiresElevation = $configDefaults.RequiresElevation
            AllowParallel = $configDefaults.AllowParallel
        }
        
        $scripts += $scriptObj
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

function ConvertTo-ParameterValue {
    <#
    .SYNOPSIS
        Convert a variable value to match the expected parameter type
    .DESCRIPTION
        Handles type conversion for common PowerShell parameter types,
        especially switch parameters that can't accept string values.
    .PARAMETER Value
        The value to convert
    .PARAMETER ParameterType
        The target parameter type
    .EXAMPLE
        ConvertTo-ParameterValue -Value "true" -ParameterType ([System.Management.Automation.SwitchParameter])
    #>
    param(
        [Parameter(Mandatory)]
        $Value,
        
        [Parameter(Mandatory)]
        [System.Type]$ParameterType
    )
    
    # Handle null/empty values
    if ($null -eq $Value -or $Value -eq '') {
        return $null
    }
    
    # Already correct type
    if ($Value.GetType() -eq $ParameterType) {
        return $Value
    }
    
    # Handle switch parameters
    if ($ParameterType -eq [System.Management.Automation.SwitchParameter]) {
        if ($Value -is [bool]) {
            return [System.Management.Automation.SwitchParameter]::new($Value)
        }
        elseif ($Value -is [string]) {
            $boolValue = $Value -in @('true', 'True', 'TRUE', '1', 'yes', 'Yes', 'YES')
            return [System.Management.Automation.SwitchParameter]::new($boolValue)
        }
        elseif ($Value -is [int]) {
            return [System.Management.Automation.SwitchParameter]::new($Value -ne 0)
        }
        else {
            # Try to convert to bool first
            try {
                $boolValue = [bool]$Value
                return [System.Management.Automation.SwitchParameter]::new($boolValue)
            }
            catch {
                return [System.Management.Automation.SwitchParameter]::new($false)
            }
        }
    }
    
    # Handle boolean parameters
    if ($ParameterType -eq [bool]) {
        if ($Value -is [string]) {
            return $Value -in @('true', 'True', 'TRUE', '1', 'yes', 'Yes', 'YES')
        }
        elseif ($Value -is [int]) {
            return $Value -ne 0
        }
        else {
            try {
                return [bool]$Value
            }
            catch {
                return $false
            }
        }
    }
    
    # For other types, try standard PowerShell type conversion
    try {
        return [System.Management.Automation.LanguagePrimitives]::ConvertTo($Value, $ParameterType)
    }
    catch {
        # If conversion fails, return original value and let PowerShell handle it
        return $Value
    }
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

            # Use script-specific variables if available, otherwise use global variables
            $scriptVars = if ($script.Variables) { $script.Variables } else { $Variables }
            
            # Merge playbook-defined parameters (takes precedence over variables)
            $mergedParams = $scriptVars.Clone()
            if ($script.Parameters -and $script.Parameters.Count -gt 0) {
                foreach ($key in $script.Parameters.Keys) {
                    $mergedParams[$key] = $script.Parameters[$key]
                }
            }

            Write-OrchestrationLog "Starting: [$($script.Number)] $($script.Name)" -Level 'Information' -Data @{
                ScriptPath = $script.Path
                Stage = $script.Stage
                Dependencies = ($script.Dependencies -join ', ')
                HasVariables = ($mergedParams.Count -gt 0)
                HasPlaybookParams = ($script.Parameters -and $script.Parameters.Count -gt 0)
            }

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
                                $paramInfo = $scriptInfo.Parameters[$key]
                                $paramType = $paramInfo.ParameterType
                                
                                # Convert value to match parameter type
                                $convertedValue = $Vars[$key]
                                if ($paramType -eq [System.Management.Automation.SwitchParameter]) {
                                    # Handle switch parameters
                                    if ($convertedValue -is [string]) {
                                        $convertedValue = $convertedValue -in @('true', 'True', 'TRUE', '1', 'yes', 'Yes', 'YES')
                                    }
                                    elseif ($convertedValue -is [int]) {
                                        $convertedValue = $convertedValue -ne 0
                                    }
                                    # PowerShell will auto-convert bool to switch
                                }
                                
                                $params[$key] = $convertedValue
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
            } -ArgumentList $script.Path, $Configuration, $mergedParams

            $jobs[$script.Number] = @{
                Job = $job
                Script = $script
                StartTime = Get-Date
            }
        }

        # Check for completed jobs
        $completedJobs = $jobs.GetEnumerator() | Where-Object { $_.Value.Job.State -eq 'Completed' }
        
        # Check for timed-out jobs
        $currentTime = Get-Date
        $timedOutJobs = $jobs.GetEnumerator() | Where-Object { 
            $_.Value.Job.State -eq 'Running' -and 
            $_.Value.Script.Timeout -and
            ((New-TimeSpan -Start $_.Value.StartTime -End $currentTime).TotalSeconds -gt $_.Value.Script.Timeout)
        }
        
        # Handle timed-out jobs
        foreach ($entry in $timedOutJobs) {
            $number = $entry.Key
            $jobInfo = $entry.Value
            $duration = New-TimeSpan -Start $jobInfo.StartTime -End $currentTime
            
            Write-OrchestrationLog "Timeout: [$number] $($jobInfo.Script.Name) exceeded timeout of $($jobInfo.Script.Timeout)s (Duration: $($duration.TotalSeconds)s)" -Level 'Error'
            
            # Stop the job
            Stop-Job -Job $jobInfo.Job -PassThru | Remove-Job -Force
            
            $failed[$number] = @{
                Success = $false
                Error = "Script exceeded timeout of $($jobInfo.Script.Timeout) seconds"
                ExitCode = $script:EXIT_TIMEOUT
            }
            
            $jobs.Remove($number)
            
            if (-not $ContinueOnError) {
                # Cancel remaining jobs
                foreach ($activeJob in $jobs.Values) {
                    Stop-Job -Job $activeJob.Job -PassThru | Remove-Job -Force
                }
                break
            }
        }

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
        while ($retryCount -le $maxRetries -and -not $succeeded) {
            try {
                # Increment attempt counter at the start of each iteration
                $retryCount++
                
                # Log retry attempts (after incrementing, so retryCount now represents current attempt number)
                if ($retryCount -gt 1) {
                    Write-OrchestrationLog "Retry attempt $($retryCount - 1)/$maxRetries for [$($script.Number)] $($script.Name) (Attempt $retryCount of $($maxRetries + 1))"
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
                        RetryAttempt = $retryCount - 1  # Adjust for pre-increment
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
                
                # Add playbook-defined parameters first (if available) - with type conversion
                if ($script.Parameters -and $script.Parameters.Count -gt 0 -and $scriptInfo) {
                    Write-OrchestrationLog "Script: $($script.Number) - Applying playbook parameters: $($script.Parameters.Keys -join ', ')" -Level 'Debug'
                    foreach ($key in $script.Parameters.Keys) {
                        # Only add if script accepts this parameter
                        if ($scriptInfo.Parameters.ContainsKey($key)) {
                            $paramInfo = $scriptInfo.Parameters[$key]
                            $paramType = $paramInfo.ParameterType
                            
                            # Convert value to match parameter type
                            $convertedValue = $script.Parameters[$key]
                            if ($paramType -eq [System.Management.Automation.SwitchParameter]) {
                                # Handle switch parameters
                                if ($convertedValue -is [string]) {
                                    $convertedValue = $convertedValue -in @('true', 'True', 'TRUE', '1', 'yes', 'Yes', 'YES')
                                }
                                elseif ($convertedValue -is [int]) {
                                    $convertedValue = $convertedValue -ne 0
                                }
                                # PowerShell will auto-convert bool to switch
                            }
                            
                            $params[$key] = $convertedValue
                        } else {
                            # Log warning if parameter doesn't exist on script
                            Write-OrchestrationLog "Warning: Script $($script.Number) has invalid playbook parameters: $key" -Level 'Warning'
                        }
                    }
                }
                elseif ($script.Parameters -and $script.Parameters.Count -gt 0) {
                    # No scriptInfo available, add parameters as-is (fallback)
                    foreach ($key in $script.Parameters.Keys) {
                        $params[$key] = $script.Parameters[$key]
                    }
                }

                if ($scriptInfo) {
                    # Only add Configuration if the script accepts it
                    if ($scriptInfo.Parameters.ContainsKey('Configuration')) {
                        if ($Configuration) { $params['Configuration'] = $Configuration }
                    }

                    # Only add variables that match script parameters (don't override playbook parameters)
                    foreach ($key in $scriptVars.Keys) {
                        if ($scriptInfo.Parameters.ContainsKey($key) -and -not $params.ContainsKey($key)) {
                            # Skip null or empty values
                            if ($null -ne $scriptVars[$key] -and $scriptVars[$key] -ne '') {
                                $paramInfo = $scriptInfo.Parameters[$key]
                                $paramType = $paramInfo.ParameterType
                                
                                # Convert value to match parameter type
                                $convertedValue = $scriptVars[$key]
                                if ($paramType -eq [System.Management.Automation.SwitchParameter]) {
                                    # Handle switch parameters
                                    if ($convertedValue -is [string]) {
                                        $convertedValue = $convertedValue -in @('true', 'True', 'TRUE', '1', 'yes', 'Yes', 'YES')
                                    }
                                    elseif ($convertedValue -is [int]) {
                                        $convertedValue = $convertedValue -ne 0
                                    }
                                    # PowerShell will auto-convert bool to switch
                                }
                                
                                $params[$key] = $convertedValue
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
                        RetryAttempt = $retryCount - 1  # Adjust for pre-increment
                    }
                }

                $completed[$script.Number] = @{
                    Success = $true
                    ExitCode = 0
                    Duration = $duration
                    RetryCount = $retryCount - 1  # Adjust for pre-increment
                }

            } catch {
                # With pre-increment, $retryCount represents attempts made so far
                # maxRetries = 0 means 1 attempt total (no retries)
                # maxRetries = 1 means 2 attempts total (1 original + 1 retry)
                # So: $retryCount > $maxRetries means we've exhausted all allowed attempts
                if ($retryCount -gt $maxRetries) {
                    Write-OrchestrationLog "Failed: [$($script.Number)] $($script.Name) - $_ (after $($maxRetries) retries)" -Level 'Error'

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
            # Use scriptblock evaluation to handle PowerShell expressions in config
            $configContent = Get-Content -Path $configPath -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $Configuration = & $scriptBlock
        } else {
            $Configuration = @{}
        }
    } elseif ($Configuration -is [string]) {
        # Load from file path
        if (Test-Path $Configuration) {
            # Use scriptblock evaluation to handle PowerShell expressions in config
            $configContent = Get-Content -Path $Configuration -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $Configuration = & $scriptBlock
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
    Handles v1 (legacy), v2.0 (stages-based), and v3.0 (jobs-based) playbooks,
    converting them to a consistent internal format for execution.
    
    Ensures full backward compatibility with existing JSON playbooks.
    #>
    param(
        [hashtable]$Playbook
    )

    # Check if this is a v3.0 playbook (has jobs instead of stages)
    if ($Playbook.ContainsKey('metadata') -and 
        $Playbook.ContainsKey('orchestration') -and 
        $Playbook.orchestration.ContainsKey('jobs')) {
        
        Write-OrchestrationLog "Loading v3.0 jobs-based playbook: $($Playbook.metadata.name)" -Level 'Information'
        
        # Convert v3.0 jobs to v2.0 stages format for backward compatibility
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
            
            # Variables and profiles
            Variables = if ($Playbook.orchestration.defaultVariables) { 
                $Playbook.orchestration.defaultVariables 
            } else { @{} }
            Profiles = if ($Playbook.orchestration.profiles) { 
                $Playbook.orchestration.profiles 
            } else { @{} }
            
            # Convert jobs to stages
            Stages = @()
            
            # Store original jobs for advanced execution
            Jobs = $Playbook.orchestration.jobs
            
            # Validation and notifications
            Validation = $Playbook.validation
            Notifications = $Playbook.notifications
            Reporting = $Playbook.reporting
        }
        
        # Convert jobs to stages format for compatibility
        foreach ($jobKey in $Playbook.orchestration.jobs.Keys) {
            $job = $Playbook.orchestration.jobs[$jobKey]
            
            # Extract script numbers from steps
            $sequences = @()
            foreach ($step in $job.steps) {
                if ($step.run) {
                    $sequences += $step.run
                }
            }
            
            $convertedStage = @{
                Name = $job.name
                Description = if ($job.description) { $job.description } else { "" }
                Sequence = $sequences
                Variables = if ($job.env) { $job.env } else { @{} }
                Condition = if ($job.if) { $job.if } else { $null }
                ContinueOnError = if ($job.continueOnError) { $job.continueOnError } else { $false }
                Parallel = $false  # Jobs run sequentially by default
                Timeout = if ($job.timeout) { $job.timeout } else { 3600 }
                Retries = 0
            }
            
            # Handle matrix strategy
            if ($job.strategy -and $job.strategy.matrix) {
                $convertedStage.Matrix = $job.strategy.matrix
            }
            
            $standardPlaybook.Stages += $convertedStage
        }
        
        return $standardPlaybook
    }
    
    # Check if this is a v2.0 playbook (has metadata and orchestration with stages)
    elseif ($Playbook.ContainsKey('metadata') -and $Playbook.ContainsKey('orchestration')) {
        Write-OrchestrationLog "Loading v2.0 stages-based playbook: $($Playbook.metadata.name)" -Level 'Information'
        
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

    # Try both .psd1 and .json formats
    # Dynamically resolve playbooks directory based on current module location
    # This ensures the correct path is used even when module is re-imported in different locations
    $currentProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $playbooksDir = Join-Path $currentProjectRoot 'library/playbooks'
    
    # First try .psd1 format (PowerShell Data File)
    $psd1Path = Join-Path $playbooksDir "$Name.psd1"
    if (Test-Path $psd1Path) {
        # Use Import-ConfigDataFile if available, otherwise scriptblock evaluation
        if (Get-Command Import-ConfigDataFile -ErrorAction SilentlyContinue) {
            $playbook = Import-ConfigDataFile -Path $psd1Path
        } else {
            $content = Get-Content -Path $psd1Path -Raw
            $scriptBlock = [scriptblock]::Create($content)
            $playbook = & $scriptBlock
        }
        return ConvertTo-StandardPlaybookFormat $playbook
    }
    
    # Then try .json format (legacy)
    $jsonPath = Join-Path $playbooksDir "$Name.json"
    if (Test-Path $jsonPath) {
        $playbook = Get-Content $jsonPath -Raw | ConvertFrom-Json -AsHashtable
        return ConvertTo-StandardPlaybookFormat $playbook
    }

    # Finally search in subdirectories for both formats
    $foundPlaybook = Get-ChildItem -Path $playbooksDir -Filter "$Name.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($foundPlaybook) {
        if (Get-Command Import-ConfigDataFile -ErrorAction SilentlyContinue) {
            $playbook = Import-ConfigDataFile -Path $foundPlaybook.FullName
        } else {
            $content = Get-Content -Path $foundPlaybook.FullName -Raw
            $scriptBlock = [scriptblock]::Create($content)
            $playbook = & $scriptBlock
        }
        return ConvertTo-StandardPlaybookFormat $playbook
    }
    
    $foundPlaybook = Get-ChildItem -Path $playbooksDir -Filter "$Name.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($foundPlaybook) {
        $playbook = Get-Content $foundPlaybook.FullName -Raw | ConvertFrom-Json -AsHashtable
        return ConvertTo-StandardPlaybookFormat $playbook
    }

    return $null
}

#
# GitHub Actions-like Features: Matrix Builds, Caching, Job Outputs
#

function Expand-MatrixBuilds {
    <#
    .SYNOPSIS
    Expand scripts into matrix builds with different parameter combinations
    
    .DESCRIPTION
    Takes a set of scripts and matrix parameters, generating all combinations
    for parallel execution. Similar to GitHub Actions matrix strategy.
    
    .EXAMPLE
    $matrix = @{
        profile = @('quick', 'comprehensive')
        platform = @('Windows', 'Linux')
    }
    Expand-MatrixBuilds -Scripts $scripts -Matrix $matrix
    #>
    param(
        [array]$Scripts,
        [hashtable]$Matrix,
        [hashtable]$Variables
    )

    $expandedScripts = @()
    
    # Generate all matrix combinations
    $combinations = Get-MatrixCombinations -Matrix $Matrix
    
    Write-OrchestrationLog "Generated $($combinations.Count) matrix combinations" -Level 'Information'
    
    foreach ($combination in $combinations) {
        foreach ($script in $Scripts) {
            # Clone the script object
            $matrixScript = $script.PSObject.Copy()
            
            # Create matrix-specific variables
            $matrixVars = $Variables.Clone()
            foreach ($key in $combination.Keys) {
                $matrixVars[$key] = $combination[$key]
            }
            
            # Update script with matrix variables
            $matrixScript.Variables = $matrixVars
            $matrixScript.MatrixConfig = $combination
            
            # Generate unique identifier for this matrix job
            $matrixId = ($combination.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','
            $matrixScript.MatrixId = $matrixId
            $matrixScript.Number = "$($script.Number)-matrix-$($expandedScripts.Count)"
            
            $expandedScripts += $matrixScript
        }
    }
    
    return $expandedScripts
}

function Get-MatrixCombinations {
    <#
    .SYNOPSIS
    Generate all combinations from matrix dimensions
    
    .DESCRIPTION
    Recursively generates all possible combinations of matrix parameters
    #>
    param([hashtable]$Matrix)
    
    $dimensions = @($Matrix.Keys)
    if ($dimensions.Count -eq 0) {
        return @(@{})
    }
    
    $combinations = @(@{})
    
    foreach ($dimension in $dimensions) {
        $newCombinations = @()
        $values = $Matrix[$dimension]
        
        foreach ($combination in $combinations) {
            foreach ($value in $values) {
                $newCombination = $combination.Clone()
                $newCombination[$dimension] = $value
                $newCombinations += $newCombination
            }
        }
        
        $combinations = $newCombinations
    }
    
    return $combinations
}

function Show-MatrixOrchestrationPlan {
    <#
    .SYNOPSIS
    Display orchestration plan for matrix builds
    #>
    param(
        [array]$Scripts,
        [hashtable]$Matrix
    )
    
    Write-Host "`nMatrix Orchestration Plan:" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host "`nMatrix Dimensions:" -ForegroundColor Yellow
    foreach ($dimension in $Matrix.Keys) {
        Write-Host "  $dimension : $($Matrix[$dimension] -join ', ')" -ForegroundColor White
    }
    
    $combinations = ($Scripts | Select-Object -First 1 -ExpandProperty MatrixConfig -ErrorAction SilentlyContinue).Count
    if (-not $combinations) {
        $combinations = (Get-MatrixCombinations -Matrix $Matrix).Count
    }
    
    Write-Host "`nTotal Combinations: $combinations" -ForegroundColor Green
    Write-Host "Total Jobs: $($Scripts.Count)" -ForegroundColor Green
    
    Write-Host "`nJobs:" -ForegroundColor Yellow
    foreach ($script in $Scripts) {
        $matrixInfo = if ($script.MatrixId) { " [$($script.MatrixId)]" } else { "" }
        Write-Host "  [$($script.Number)]$matrixInfo $($script.Name)" -ForegroundColor White
    }
}

function Initialize-OrchestrationCache {
    <#
    .SYNOPSIS
    Initialize the orchestration caching system
    
    .DESCRIPTION
    Sets up the cache directory structure and returns a cache manager object
    #>
    param([hashtable]$Configuration)
    
    $cacheDir = Join-Path $script:ProjectRoot '.orchestration-cache'
    
    # Create cache directories
    @('results', 'artifacts', 'metadata') | ForEach-Object {
        $dir = Join-Path $cacheDir $_
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    return @{
        CacheDir = $cacheDir
        ResultsDir = Join-Path $cacheDir 'results'
        ArtifactsDir = Join-Path $cacheDir 'artifacts'
        MetadataDir = Join-Path $cacheDir 'metadata'
        Enabled = $true
    }
}

function Save-OrchestrationCache {
    <#
    .SYNOPSIS
    Save orchestration execution results to cache
    #>
    param(
        [hashtable]$CacheManager,
        [object]$Result,
        [array]$Scripts,
        [hashtable]$Variables
    )
    
    try {
        # Generate cache key from scripts and variables
        $cacheKey = Get-OrchestrationCacheKey -Scripts $Scripts -Variables $Variables
        
        # Save result
        $resultPath = Join-Path $CacheManager.ResultsDir "$cacheKey.json"
        $Result | ConvertTo-Json -Depth 10 | Set-Content -Path $resultPath
        
        # Save metadata
        $metadata = @{
            CacheKey = $cacheKey
            Timestamp = Get-Date -Format 'o'
            Scripts = ($Scripts | Select-Object Number, Name, Path)
            Variables = $Variables
            Success = ($Result.Failed -eq 0)
        }
        $metadataPath = Join-Path $CacheManager.MetadataDir "$cacheKey.meta.json"
        $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath
        
        Write-OrchestrationLog "Cached execution result: $cacheKey" -Level 'Debug'
    } catch {
        Write-OrchestrationLog "Failed to save cache: $_" -Level 'Warning'
    }
}

function Get-OrchestrationCacheKey {
    <#
    .SYNOPSIS
    Generate a unique cache key from scripts and variables
    #>
    param(
        [array]$Scripts,
        [hashtable]$Variables
    )
    
    $scriptIds = ($Scripts | ForEach-Object { $_.Number }) -join ','
    $varJson = $Variables | ConvertTo-Json -Compress
    $combined = "$scriptIds|$varJson"
    
    # Generate SHA256 hash
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($combined))
    $hashString = [BitConverter]::ToString($hash) -replace '-', ''
    
    return $hashString.Substring(0, 16)  # Use first 16 chars
}

function Export-OrchestrationSummary {
    <#
    .SYNOPSIS
    Export execution summary as markdown report
    
    .DESCRIPTION
    Generates a GitHub Actions-style job summary in markdown format
    #>
    param(
        [hashtable]$Summary,
        [hashtable]$Configuration
    )
    
    $reportsDir = Join-Path $script:ProjectRoot 'reports/orchestration'
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
    $summaryPath = Join-Path $reportsDir "summary-$timestamp.md"
    
    $markdown = @"
# Orchestration Execution Summary

**Playbook**: $($Summary.Playbook)  
**Started**: $($Summary.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))  
**Completed**: $($Summary.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))  
**Duration**: $($Summary.Duration.ToString())  
**Status**: $(if ($Summary.Result.Failed -eq 0) { '✅ Success' } else { '❌ Failed' })

## Results

| Metric | Count |
|--------|-------|
| Total Scripts | $($Summary.Result.Total) |
| Completed | $($Summary.Result.Completed) ✅ |
| Failed | $($Summary.Result.Failed) ❌ |
| Success Rate | $([math]::Round(($Summary.Result.Completed / $Summary.Result.Total) * 100, 2))% |

## Variables

``````json
$($Summary.Variables | ConvertTo-Json)
``````

## Execution Details

"@
    
    # Add failed scripts if any
    if ($Summary.Result.Results.Failed.Count -gt 0) {
        $markdown += "`n### ❌ Failed Scripts`n`n"
        foreach ($failedScript in $Summary.Result.Results.Failed.GetEnumerator()) {
            $markdown += "- **$($failedScript.Key)**: $($failedScript.Value.Error)`n"
        }
    }
    
    $markdown | Set-Content -Path $summaryPath
    
    return $summaryPath
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

#region Powerful One-Liner Helpers

function Invoke-AitherWorkflow {
    <#
    .SYNOPSIS
        Execute a complete workflow in a single command
    
    .DESCRIPTION
        Powerful one-liner function for CI/CD and automation scenarios.
        Combines script execution, playbook orchestration, and config management.
        
        Supports:
        - Custom config files (config.production.psd1, config.ci.psd1, etc.)
        - Config hierarchy: custom > config.local.psd1 > config.psd1
        - Variable injection
        - Multiple output formats
        - CI/CD-friendly error handling
    
    .PARAMETER Script
        Single script number to execute (e.g., "0402")
    
    .PARAMETER Sequence
        Script sequence (e.g., "0402,0404,0407" or "stage:testing")
    
    .PARAMETER Playbook
        Playbook name to execute
    
    .PARAMETER ConfigFile
        Custom configuration file (e.g., "config.production.psd1")
    
    .PARAMETER Variables
        Variables to inject into the workflow
    
    .PARAMETER OutputFormat
        Output format (JSON, XML, JUnit, GitHubActions)
    
    .PARAMETER OutputPath
        Path to save output report
    
    .PARAMETER Quiet
        Suppress non-essential output
    
    .PARAMETER ThrowOnError
        Throw exception on error (for CI/CD)
    
    .EXAMPLE
        Invoke-AitherWorkflow -Script 0402
        # Run tests
    
    .EXAMPLE
        Invoke-AitherWorkflow -Sequence "0402,0404" -ConfigFile "./config.ci.psd1" -OutputFormat JUnit -OutputPath "./results.xml"
        # CI/CD: Run tests with custom config, output JUnit
    
    .EXAMPLE
        Invoke-AitherWorkflow -Playbook "test-full" -Variables @{MaxConcurrency=8} -Quiet -ThrowOnError
        # Non-interactive test execution with custom concurrency
    
    .EXAMPLE
        azw -Playbook "deploy-prod" -ConfigFile "./config.production.psd1" -ThrowOnError
        # Production deployment with prod config (using alias)
    
    .OUTPUTS
        [PSCustomObject] Execution result if PassThru or OutputFormat is specified
    
    .NOTES
        Alias: azw (AitherZero Workflow)
        
        Config precedence: ConfigFile > config.local.psd1 > config.psd1
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Script')]
    [Alias('azw')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Script', Position = 0)]
        [ValidatePattern('^\d{4}$')]
        [string]$Script,
        
        [Parameter(Mandatory, ParameterSetName = 'Sequence', Position = 0)]
        [string[]]$Sequence,
        
        [Parameter(Mandatory, ParameterSetName = 'Playbook', Position = 0)]
        [string]$Playbook,
        
        [Parameter()]
        [string]$ConfigFile,
        
        [Parameter()]
        [hashtable]$Variables,
        
        [Parameter()]
        [ValidateSet('JSON', 'XML', 'JUnit', 'GitHubActions', 'None')]
        [string]$OutputFormat = 'None',
        
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$Quiet,
        
        [Parameter()]
        [switch]$ThrowOnError,
        
        [Parameter()]
        [switch]$PassThru
    )
    
    $params = @{
        PassThru = $PassThru
        Quiet = $Quiet
        ThrowOnError = $ThrowOnError
    }
    
    if ($ConfigFile) {
        $params.ConfigFile = $ConfigFile
    }
    
    if ($Variables) {
        $params.Variables = $Variables
    }
    
    if ($OutputFormat -ne 'None') {
        $params.OutputFormat = $OutputFormat
        if ($OutputPath) {
            $params.OutputPath = $OutputPath
        }
    }
    
    switch ($PSCmdlet.ParameterSetName) {
        'Script' {
            if (Get-Command Invoke-AitherScript -ErrorAction SilentlyContinue) {
                # Invoke-AitherScript doesn't support Quiet/ThrowOnError
                # Only pass supported parameters, but include common parameters (WhatIf, Confirm, Verbose, etc.)
                $scriptParams = @{
                    Number = $Script
                    PassThru = $PassThru
                }
                if ($Variables) {
                    $scriptParams.Variables = $Variables
                }
                
                # Pass common parameters automatically
                if ($PSBoundParameters.ContainsKey('WhatIf')) {
                    $scriptParams.WhatIf = $PSBoundParameters['WhatIf']
                }
                if ($PSBoundParameters.ContainsKey('Confirm')) {
                    $scriptParams.Confirm = $PSBoundParameters['Confirm']
                }
                if ($PSBoundParameters.ContainsKey('Verbose')) {
                    $scriptParams.Verbose = $PSBoundParameters['Verbose']
                }
                
                Invoke-AitherScript @scriptParams
            }
            else {
                throw "Invoke-AitherScript not available. Ensure AitherZero module is loaded."
            }
        }
        'Sequence' {
            $params.Sequence = $Sequence
            Invoke-OrchestrationSequence @params
        }
        'Playbook' {
            $params.LoadPlaybook = $Playbook
            Invoke-OrchestrationSequence @params
        }
    }
}

function Test-AitherAll {
    <#
    .SYNOPSIS
        Run all tests in one command
    
    .DESCRIPTION
        One-liner to execute complete test suite:
        - Unit tests (0402)
        - PSScriptAnalyzer (0404)
        - Syntax validation (0407)
    
    .PARAMETER ConfigFile
        Custom configuration file
    
    .PARAMETER OutputFormat
        Output format (JUnit for CI/CD)
    
    .PARAMETER OutputPath
        Path to save test results
    
    .EXAMPLE
        Test-AitherAll
        # Run all tests
    
    .EXAMPLE
        Test-AitherAll -OutputFormat JUnit -OutputPath "./test-results.xml"
        # CI/CD: Run all tests, output JUnit XML
    
    .EXAMPLE
        aztest -ConfigFile "./config.ci.psd1" -ThrowOnError
        # CI/CD with custom config (using alias)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('aztest')]
    param(
        [Parameter()]
        [string]$ConfigFile,
        
        [Parameter()]
        [ValidateSet('JSON', 'XML', 'JUnit', 'GitHubActions', 'None')]
        [string]$OutputFormat = 'None',
        
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$ThrowOnError
    )
    
    $params = @{
        Sequence = "0402,0404,0407"
        ThrowOnError = $ThrowOnError
        PassThru = $true
    }
    
    if ($ConfigFile) {
        $params.ConfigFile = $ConfigFile
    }
    
    if ($OutputFormat -ne 'None') {
        $params.OutputFormat = $OutputFormat
        if ($OutputPath) {
            $params.OutputPath = $OutputPath
        }
    }
    
    Invoke-OrchestrationSequence @params
}

function Invoke-AitherDeploy {
    <#
    .SYNOPSIS
        Execute deployment workflow in one command
    
    .DESCRIPTION
        One-liner for deployment automation with config file support
    
    .PARAMETER Environment
        Environment to deploy to (Development, Staging, Production)
    
    .PARAMETER ConfigFile
        Configuration file for the target environment
    
    .PARAMETER Variables
        Additional variables to pass
    
    .EXAMPLE
        Invoke-AitherDeploy -Environment Production -ConfigFile "./config.production.psd1"
        # Deploy to production
    
    .EXAMPLE
        azdeploy -Environment Staging -Variables @{SkipTests=$false}
        # Deploy to staging with testing enabled (using alias)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('azdeploy')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Development', 'Staging', 'Production')]
        [string]$Environment,
        
        [Parameter()]
        [string]$ConfigFile,
        
        [Parameter()]
        [hashtable]$Variables = @{},
        
        [Parameter()]
        [switch]$ThrowOnError
    )
    
    # Add environment to variables
    $Variables.Environment = $Environment
    
    $params = @{
        LoadPlaybook = "deploy-$($Environment.ToLower())"
        Variables = $Variables
        ThrowOnError = $ThrowOnError
        PassThru = $true
    }
    
    if ($ConfigFile) {
        $params.ConfigFile = $ConfigFile
    }
    
    Invoke-OrchestrationSequence @params
}

function Get-AitherConfig {
    <#
    .SYNOPSIS
        Get configuration with hierarchy support in one line
    
    .DESCRIPTION
        Quick config access with automatic merging:
        - config.psd1 (base)
        - config.local.psd1 (local overrides)
        - Custom file (if specified)
    
    .PARAMETER ConfigFile
        Custom configuration file
    
    .PARAMETER Section
        Configuration section to return
    
    .PARAMETER Key
        Specific key to return
    
    .EXAMPLE
        $config = Get-AitherConfig
        # Get full merged configuration
    
    .EXAMPLE
        $maxConcurrency = Get-AitherConfig -Section "Automation" -Key "MaxConcurrency"
        # Get specific value
    
    .EXAMPLE
        $prodConfig = Get-AitherConfig -ConfigFile "./config.production.psd1"
        # Get production configuration
    
    .EXAMPLE
        azconfig -Section Testing
        # Get testing configuration (using alias)
    #>
    [CmdletBinding()]
    [Alias('azconfig')]
    param(
        [Parameter()]
        [string]$ConfigFile,
        
        [Parameter()]
        [string]$Section,
        
        [Parameter()]
        [string]$Key
    )
    
    if (Get-Command Get-MergedConfiguration -ErrorAction SilentlyContinue) {
        $params = @{}
        if ($ConfigFile) { $params.ConfigFile = $ConfigFile }
        if ($Section) { $params.Section = $Section }
        if ($Key) { $params.Key = $Key }
        
        Get-MergedConfiguration @params
    }
    else {
        Write-Warning "Get-MergedConfiguration not available. Using Get-Configuration."
        Get-Configuration
    }
}

#endregion

# Create alias for seq
Set-Alias -Name 'seq' -Value 'Invoke-OrchestrationSequence' -Scope Global -Force

# Export functions
Export-ModuleMember -Function @(
    'Invoke-OrchestrationSequence'
    'Invoke-Sequence'
    'Invoke-ParallelOrchestration'
    'Invoke-SequentialOrchestration'
    'Get-OrchestrationPlaybook'
    'Save-OrchestrationPlaybook'
    'ConvertTo-StandardPlaybookFormat'
    'Test-PlaybookConditions'
    'Send-PlaybookNotification'
    'Expand-MatrixBuilds'
    'Get-MatrixCombinations'
    'Show-MatrixOrchestrationPlan'
    'Initialize-OrchestrationCache'
    'Save-OrchestrationCache'
    'Get-OrchestrationCacheKey'
    'Export-OrchestrationSummary'
    'Test-CIEnvironment'
    'Export-OrchestrationResult'
    'Invoke-AitherWorkflow'
    'Test-AitherAll'
    'Invoke-AitherDeploy'
    'Get-AitherConfig'
) -Alias @('seq', 'azw', 'aztest', 'azdeploy', 'azconfig')