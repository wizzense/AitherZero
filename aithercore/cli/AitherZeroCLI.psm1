#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero CLI Module - Powerful CI/CD Automation Interface

.DESCRIPTION
    Professional PowerShell CLI for infrastructure automation, CI/CD pipelines,
    and DevOps workflows. Provides comprehensive cmdlets for script execution,
    orchestration, configuration, reporting, and system management.
    
    Designed for power users who demand scriptability, flexibility, and control.

.NOTES
    Module: AitherZeroCLI
    Version: 2.0.0
    Author: AitherZero Team
#>

#region Module Initialization

# Suppress banner if already shown or in CI
if (-not $env:AITHERZERO_CLI_LOADED) {
    $env:AITHERZERO_CLI_LOADED = "1"
    
    if (-not $env:AITHERZERO_SUPPRESS_BANNER -and -not $env:CI) {
        Write-Host ""
        Write-Host "  AitherZero CLI v2.0 " -ForegroundColor Cyan -NoNewline
        Write-Host "| Powerful CI/CD Automation" -ForegroundColor DarkGray
        Write-Host ""
    }
}

#endregion

#region Helper Functions

function Write-AitherStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Type = 'Info',
        
        [switch]$NoNewline
    )
    
    $colors = @{
        Info = 'Cyan'
        Success = 'Green'
        Warning = 'Yellow'
        Error = 'Red'
        Debug = 'DarkGray'
    }
    
    $prefixes = @{
        Info = '[i]'
        Success = '[✓]'
        Warning = '[!]'
        Error = '[✗]'
        Debug = '[·]'
    }
    
    $params = @{
        Object = "$($prefixes[$Type]) $Message"
        ForegroundColor = $colors[$Type]
    }
    
    if ($NoNewline) {
        $params.NoNewline = $true
    }
    
    Write-Host @params
}

function Get-AitherScriptPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Number
    )
    
    $scriptsPath = Join-Path $env:AITHERZERO_ROOT 'library/automation-scripts'
    
    if (-not (Test-Path $scriptsPath)) {
        return $null
    }
    
    $pattern = "${Number}_*.ps1"
    $scriptFile = Get-ChildItem -Path $scriptsPath -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($scriptFile) {
        return $scriptFile.FullName
    }
    
    return $null
}

function Format-AitherTable {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$InputObject,
        
        [string[]]$Property,
        
        [switch]$AutoSize
    )
    
    begin {
        $items = @()
    }
    
    process {
        $items += $InputObject
    }
    
    end {
        if ($items.Count -eq 0) {
            return
        }
        
        $params = @{}
        if ($Property) { $params.Property = $Property }
        if ($AutoSize) { $params.AutoSize = $true }
        
        $items | Format-Table @params
    }
}

#endregion

#region Script Execution Cmdlets

function Invoke-AitherScript {
    <#
    .SYNOPSIS
        Execute an automation script by number
    
    .DESCRIPTION
        Runs a specific automation script from the 0000-9999 numbered sequence.
        Each script is designed for a specific infrastructure or automation task.
        
        Supports parallel execution, dry-run mode, and detailed logging.
    
    .PARAMETER Number
        The 4-digit script number (0000-9999)
    
    .PARAMETER WhatIf
        Show what would happen without executing
    
    .PARAMETER PassThru
        Return the script execution result object
    
    .PARAMETER Timeout
        Maximum execution time in seconds (default: no timeout)
    
    .PARAMETER Variables
        Hash table of variables to pass to the script
    
    .PARAMETER WorkingDirectory
        Working directory for script execution
    
    .EXAMPLE
        Invoke-AitherScript -Number 0402
        
        Runs the unit test automation script (0402)
    
    .EXAMPLE
        Invoke-AitherScript 0404 -PassThru
        
        Runs PSScriptAnalyzer and returns execution result
    
    .EXAMPLE
        Invoke-AitherScript 0500 -Variables @{Format='JSON'} -Timeout 300
        
        Runs script with custom variables and 5-minute timeout
    
    .EXAMPLE
        0402, 0404, 0407 | Invoke-AitherScript
        
        Pipeline execution of multiple scripts
    
    .OUTPUTS
        None, or [PSCustomObject] if -PassThru is specified
    
    .LINK
        Get-AitherScript
        Invoke-AitherPlaybook
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ScriptNumber', 'Id')]
        [ValidatePattern('^\d{4}$')]
        [string]$Number,
        
        [Parameter()]
        [switch]$PassThru,
        
        [Parameter()]
        [int]$Timeout,
        
        [Parameter()]
        [hashtable]$Variables,
        
        [Parameter()]
        [string]$WorkingDirectory
    )
    
    begin {
        Write-Verbose "Starting script execution..."
        $results = @()
    }
    
    process {
        $scriptPath = Get-AitherScriptPath -Number $Number
        
        if (-not $scriptPath) {
            Write-AitherStatus "Script $Number not found" -Type Error
            
            # Show similar scripts
            $available = Get-AitherScript -Number "$($Number[0..2] -join '')*" | Select-Object -First 5
            if ($available) {
                Write-Host "`nSimilar scripts:" -ForegroundColor Cyan
                $available | Format-Table Number, Name, Category -AutoSize
            }
            
            if ($PassThru) {
                $result = [PSCustomObject]@{
                    Number = $Number
                    Success = $false
                    Error = "Script not found"
                    Duration = [TimeSpan]::Zero
                }
                $results += $result
                return $result
            }
            return
        }
        
        $scriptName = Split-Path $scriptPath -Leaf
        
        if ($PSCmdlet.ShouldProcess($scriptName, "Execute automation script")) {
            Write-AitherStatus "Executing: $scriptName" -Type Info
            Write-Host ""
            
            try {
                $startTime = Get-Date
                
                # Prepare execution parameters
                $execParams = @{
                    FilePath = 'pwsh'
                    ArgumentList = @('-NoProfile', '-File', $scriptPath)
                    NoNewWindow = $true
                }
                
                if ($WorkingDirectory) {
                    $execParams.WorkingDirectory = $WorkingDirectory
                }
                
                if ($Timeout) {
                    $execParams.ArgumentList += '-ExecutionTimeout', $Timeout
                }
                
                # Execute script
                if ($Variables) {
                    # Pass variables as environment variables
                    foreach ($key in $Variables.Keys) {
                        [Environment]::SetEnvironmentVariable("AITHER_$key", $Variables[$key], 'Process')
                    }
                }
                
                & $scriptPath
                $exitCode = $LASTEXITCODE
                
                $duration = (Get-Date) - $startTime
                
                Write-Host ""
                if ($exitCode -eq 0 -or $null -eq $exitCode) {
                    Write-AitherStatus "Completed in $([Math]::Round($duration.TotalSeconds, 2))s" -Type Success
                    $success = $true
                } else {
                    Write-AitherStatus "Failed with exit code $exitCode" -Type Error
                    $success = $false
                }
                
                if ($PassThru) {
                    $result = [PSCustomObject]@{
                        Number = $Number
                        Path = $scriptPath
                        Success = $success
                        ExitCode = $exitCode
                        Duration = $duration
                        StartTime = $startTime
                        EndTime = Get-Date
                    }
                    $results += $result
                    return $result
                }
            }
            catch {
                Write-Host ""
                Write-AitherStatus "Failed: $_" -Type Error
                
                if ($PassThru) {
                    $result = [PSCustomObject]@{
                        Number = $Number
                        Path = $scriptPath
                        Success = $false
                        Error = $_.Exception.Message
                        Duration = (Get-Date) - $startTime
                    }
                    $results += $result
                    return $result
                }
                
                throw
            }
        }
    }
    
    end {
        if ($PassThru -and $results.Count -gt 0) {
            return $results
        }
    }
}

function Get-AitherScript {
    <#
    .SYNOPSIS
        List and search automation scripts
    
    .DESCRIPTION
        Returns information about automation scripts in the 0000-9999 sequence.
        Supports filtering by number, name, range, category, and tags.
    
    .PARAMETER Number
        Filter by specific script number (supports wildcards)
    
    .PARAMETER Name
        Filter by script name (supports wildcards)
    
    .PARAMETER Range
        Filter by number range (e.g., "0400-0499")
    
    .PARAMETER Category
        Filter by category (Environment, Infrastructure, Testing, etc.)
    
    .PARAMETER Tag
        Filter by tag (testing, ci, deployment, etc.)
    
    .PARAMETER Available
        Show only scripts that exist and are executable
    
    .EXAMPLE
        Get-AitherScript
        
        List all automation scripts
    
    .EXAMPLE
        Get-AitherScript -Number 0402
        
        Get information about script 0402
    
    .EXAMPLE
        Get-AitherScript -Range "0400-0499"
        
        List all testing/validation scripts
    
    .EXAMPLE
        Get-AitherScript -Name "*test*" -Available
        
        Find all available scripts with "test" in the name
    
    .EXAMPLE
        Get-AitherScript -Category Testing | Format-Table
        
        List all testing scripts in table format
    
    .OUTPUTS
        [PSCustomObject[]] Array of script information objects
    #>
    
    [CmdletBinding(DefaultParameterSetName='All')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ParameterSetName='ByNumber', Position=0)]
        [string]$Number,
        
        [Parameter(ParameterSetName='ByName')]
        [string]$Name,
        
        [Parameter(ParameterSetName='ByRange')]
        [ValidatePattern('^\d{4}-\d{4}$')]
        [string]$Range,
        
        [Parameter(ParameterSetName='ByCategory')]
        [Parameter(ParameterSetName='All')]
        [ValidateSet('Environment', 'Infrastructure', 'Development', 'Testing', 'Reporting', 'GitAutomation', 'IssueManagement', 'Quality', 'Maintenance', 'All')]
        [string]$Category,
        
        [Parameter()]
        [string[]]$Tag,
        
        [Parameter()]
        [switch]$Available
    )
    
    $scriptsPath = Join-Path $env:AITHERZERO_ROOT 'library/automation-scripts'
    
    if (-not (Test-Path $scriptsPath)) {
        Write-Warning "Automation scripts directory not found: $scriptsPath"
        return @()
    }
    
    $allScripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | 
        Where-Object { $_.Name -match '^(\d{4})_(.+)\.ps1$' } |
        ForEach-Object {
            $num = $Matches[1]
            [PSCustomObject]@{
                Number = $num
                Name = $Matches[2]
                File = $_.Name
                Path = $_.FullName
                Size = $_.Length
                LastModified = $_.LastWriteTime
                Category = switch ([int]$num) {
                    {$_ -ge 0 -and $_ -le 99} { 'Environment' }
                    {$_ -ge 100 -and $_ -le 199} { 'Infrastructure' }
                    {$_ -ge 200 -and $_ -le 299} { 'Development' }
                    {$_ -ge 400 -and $_ -le 499} { 'Testing' }
                    {$_ -ge 500 -and $_ -le 599} { 'Reporting' }
                    {$_ -ge 700 -and $_ -le 799} { 'GitAutomation' }
                    {$_ -ge 800 -and $_ -le 899} { 'IssueManagement' }
                    {$_ -ge 900 -and $_ -le 999} { 'Quality' }
                    {$_ -ge 9000} { 'Maintenance' }
                    default { 'Other' }
                }
                Executable = $_.Mode -match 'x'
            }
        } | Sort-Object Number
    
    # Apply filters
    $filtered = $allScripts
    
    switch ($PSCmdlet.ParameterSetName) {
        'ByNumber' {
            $filtered = $filtered | Where-Object { $_.Number -like $Number }
        }
        'ByName' {
            $filtered = $filtered | Where-Object { $_.Name -like $Name }
        }
        'ByRange' {
            $start, $end = $Range -split '-'
            $filtered = $filtered | Where-Object { [int]$_.Number -ge [int]$start -and [int]$_.Number -le [int]$end }
        }
        'ByCategory' {
            if ($Category -and $Category -ne 'All') {
                $filtered = $filtered | Where-Object { $_.Category -eq $Category }
            }
        }
    }
    
    if ($Category -and $PSCmdlet.ParameterSetName -eq 'All') {
        if ($Category -ne 'All') {
            $filtered = $filtered | Where-Object { $_.Category -eq $Category }
        }
    }
    
    if ($Tag) {
        # Filter by tags (would need to parse script content or metadata)
        # For now, filter by name matching tags
        $filtered = $filtered | Where-Object {
            $script = $_
            $Tag | ForEach-Object { $script.Name -match $_ }
        }
    }
    
    if ($Available) {
        $filtered = $filtered | Where-Object { Test-Path $_.Path }
    }
    
    return $filtered
}

function Invoke-AitherSequence {
    <#
    .SYNOPSIS
        Execute a sequence of automation scripts
    
    .DESCRIPTION
        Runs multiple automation scripts using the AitherZero orchestration engine.
        Supports individual scripts, ranges, wildcards, exclusions, and advanced features.
        
        This is a user-friendly wrapper around Invoke-OrchestrationSequence.
        
        Sequence format examples:
        - Individual: "0500,0501,0700"
        - Ranges: "0510-0520" (executes 0510, 0511, ..., 0520)
        - Mixed: "0500,0501,0510-0520,0700,0701"
        - Wildcards: "04*" (all 0400-0499)
        - Exclusions: "0400-0499,!0450" (all 0400-0499 except 0450)
        - Stages: "stage:Testing" (all scripts tagged with Testing stage)
    
    .PARAMETER Sequence
        Script sequence to execute
        Examples: "0402,0404", "0400-0410", "0500,0510-0520,0700", "04*,!0450"
    
    .PARAMETER ContinueOnError
        Continue executing remaining scripts even if one fails
    
    .PARAMETER Parallel
        Execute scripts in parallel (default: true)
    
    .PARAMETER MaxConcurrency
        Maximum number of parallel executions (default: 4)
    
    .PARAMETER DryRun
        Show what would be executed without running
    
    .PARAMETER Variables
        Hash table of variables to pass to scripts
    
    .PARAMETER SavePlaybook
        Save this sequence as a reusable playbook
    
    .PARAMETER UseCache
        Enable caching of execution results
    
    .PARAMETER GenerateSummary
        Generate markdown execution summary
    
    .EXAMPLE
        Invoke-AitherSequence "0402,0404,0407"
        
        Execute scripts 0402, 0404, and 0407
    
    .EXAMPLE
        Invoke-AitherSequence "0500,0501,0510-0520,0700,0701"
        
        Execute multiple scripts and ranges
    
    .EXAMPLE
        Invoke-AitherSequence "0400-0410" -Parallel -MaxConcurrency 8
        
        Execute range in parallel with max 8 concurrent scripts
    
    .EXAMPLE
        Invoke-AitherSequence "04*,!0450" -DryRun
        
        Show all 0400-0499 scripts except 0450 without executing
    
    .EXAMPLE
        Invoke-AitherSequence "0402,0404" -ContinueOnError -GenerateSummary
        
        Execute sequence, continue on error, generate summary report
    
    .EXAMPLE
        Invoke-AitherSequence "0000-0099,0201,0207" -SavePlaybook "my-setup"
        
        Execute sequence and save as reusable playbook
    
    .LINK
        Invoke-OrchestrationSequence
        Invoke-AitherPlaybook
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position=0, ValueFromPipeline)]
        [string]$Sequence,
        
        [Parameter()]
        [switch]$ContinueOnError,
        
        [Parameter()]
        [switch]$Parallel,
        
        [Parameter()]
        [ValidateRange(1, 32)]
        [int]$MaxConcurrency = 4,
        
        [Parameter()]
        [switch]$DryRun,
        
        [Parameter()]
        [hashtable]$Variables,
        
        [Parameter()]
        [string]$SavePlaybook,
        
        [Parameter()]
        [switch]$UseCache,
        
        [Parameter()]
        [switch]$GenerateSummary
    )
    
    # Build parameters for orchestration engine
    $params = @{
        Sequence = $Sequence
        ContinueOnError = $ContinueOnError
        Parallel = $Parallel
        MaxConcurrency = $MaxConcurrency
    }
    
    if ($DryRun) { $params.DryRun = $true }
    if ($Variables) { $params.Variables = $Variables }
    if ($SavePlaybook) { $params.SavePlaybook = $SavePlaybook }
    if ($UseCache) { $params.UseCache = $true }
    if ($GenerateSummary) { $params.GenerateSummary = $true }
    
    # Call orchestration engine
    if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
        $result = Invoke-OrchestrationSequence @params
        
        # Set exit code based on result
        if ($result) {
            $failedCount = 0
            if ($result.PSObject.Properties.Name -contains 'Failed') {
                $failedCount = $result.Failed
            } elseif ($result -is [array]) {
                $failedCount = ($result | Where-Object { -not $_.Success }).Count
            }
            
            if ($failedCount -gt 0) {
                $global:LASTEXITCODE = 1
                if (-not $ContinueOnError) {
                    Write-Error "Sequence execution failed: $failedCount script(s) failed"
                }
            } else {
                $global:LASTEXITCODE = 0
            }
        }
        
        return $result
    }
    else {
        Write-AitherStatus "OrchestrationEngine not loaded" -Type Error
        $global:LASTEXITCODE = 1
        throw "OrchestrationEngine module not available. Ensure AitherZero module is loaded."
    }
}

#endregion

#region Playbook & Orchestration Cmdlets

function Invoke-AitherPlaybook {
    <#
    .SYNOPSIS
        Execute a playbook sequence
    
    .DESCRIPTION
        Runs a predefined sequence of automation scripts defined in a playbook.
        Playbooks orchestrate multiple scripts for complex CI/CD workflows.
        
        This is a user-friendly wrapper around Invoke-OrchestrationSequence -LoadPlaybook.
        
        Supports parallel execution, dry-run mode, caching, and detailed reporting.
    
    .PARAMETER Name
        Name of the playbook to execute
    
    .PARAMETER Profile
        Playbook profile to use (quick, full, ci, etc.)
    
    .PARAMETER ContinueOnError
        Continue executing remaining scripts even if one fails
    
    .PARAMETER Parallel
        Execute scripts in parallel (default: true)
    
    .PARAMETER MaxParallel
        Maximum number of parallel executions (default: 4)
    
    .PARAMETER Variables
        Hash table of variables to pass to all scripts
    
    .PARAMETER Timeout
        Maximum execution time for entire playbook in seconds
    
    .PARAMETER DryRun
        Show what would be executed without running
    
    .PARAMETER UseCache
        Enable caching of execution results
    
    .PARAMETER GenerateSummary
        Generate markdown execution summary
    
    .EXAMPLE
        Invoke-AitherPlaybook -Name test-quick
        
        Execute the quick test playbook
    
    .EXAMPLE
        Invoke-AitherPlaybook test-full -Parallel
        
        Execute full test suite in parallel
    
    .EXAMPLE
        Invoke-AitherPlaybook pr-validation -Profile ci -Timeout 600
        
        Run PR validation with CI profile and 10-minute timeout
    
    .EXAMPLE
        Invoke-AitherPlaybook test-quick -DryRun
        
        Show what would run without executing
    
    .EXAMPLE
        Invoke-AitherPlaybook test-full -UseCache -GenerateSummary
        
        Run with caching and generate summary report
    
    .LINK
        Invoke-OrchestrationSequence
        Invoke-AitherSequence
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position=0)]
        [ArgumentCompleter({
            param($cmd, $param, $word)
            Get-AitherPlaybook | Where-Object { $_.Name -like "$word*" } | ForEach-Object { $_.Name }
        })]
        [string]$Name,
        
        [Parameter()]
        [string]$Profile,
        
        [Parameter()]
        [switch]$ContinueOnError,
        
        [Parameter()]
        [switch]$Parallel,
        
        [Parameter()]
        [ValidateRange(1, 16)]
        [int]$MaxParallel = 4,
        
        [Parameter()]
        [switch]$PassThru,
        
        [Parameter()]
        [hashtable]$Variables,
        
        [Parameter()]
        [int]$Timeout,
        
        [Parameter()]
        [switch]$DryRun,
        
        [Parameter()]
        [switch]$UseCache,
        
        [Parameter()]
        [switch]$GenerateSummary
    )
    
    # Build parameters for orchestration engine
    $params = @{
        LoadPlaybook = $Name
        ContinueOnError = $ContinueOnError
        Parallel = $Parallel
        MaxConcurrency = $MaxParallel
    }
    
    if ($Variables) { $params.Variables = $Variables }
    if ($Profile) { $params.Profile = $Profile }
    if ($DryRun) { $params.DryRun = $true }
    if ($UseCache) { $params.UseCache = $true }
    if ($GenerateSummary) { $params.GenerateSummary = $true }
    
    # Call orchestration engine
    if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
        $result = Invoke-OrchestrationSequence @params
        
        # Set exit code based on result
        if ($result) {
            $failedCount = 0
            if ($result.PSObject.Properties.Name -contains 'Failed') {
                $failedCount = $result.Failed
            } elseif ($result -is [array]) {
                $failedCount = ($result | Where-Object { -not $_.Success }).Count
            }
            
            if ($failedCount -gt 0) {
                $global:LASTEXITCODE = 1
                if (-not $ContinueOnError) {
                    Write-Error "Playbook execution failed: $failedCount script(s) failed"
                }
            } else {
                $global:LASTEXITCODE = 0
            }
        }
        
        if ($PassThru) {
            return $result
        }
    }
    else {
        Write-AitherStatus "OrchestrationEngine not loaded" -Type Error
        $global:LASTEXITCODE = 1
        throw "OrchestrationEngine module not available. Ensure AitherZero module is loaded."
    }
}

function Get-AitherPlaybook {
    <#
    .SYNOPSIS
        List available playbooks
    
    .DESCRIPTION
        Returns information about all available playbooks in the orchestration directory.
        Playbooks define sequences of automation scripts for complex workflows.
    
    .PARAMETER Name
        Filter by playbook name (supports wildcards)
    
    .PARAMETER Tag
        Filter by tag (test, ci, deployment, etc.)
    
    .EXAMPLE
        Get-AitherPlaybook
        
        List all available playbooks
    
    .EXAMPLE
        Get-AitherPlaybook -Name "*test*"
        
        Find all test-related playbooks
    
    .EXAMPLE
        Get-AitherPlaybook | Where-Object ScriptCount -gt 5
        
        Find playbooks with more than 5 scripts
    
    .OUTPUTS
        [PSCustomObject[]] Array of playbook information objects
    #>
    
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Position=0)]
        [string]$Name = '*',
        
        [Parameter()]
        [string[]]$Tag
    )
    
    $playbooksPath = Join-Path $env:AITHERZERO_ROOT 'library/playbooks'
    
    if (-not (Test-Path $playbooksPath)) {
        Write-Warning "Playbooks directory not found: $playbooksPath"
        return @()
    }
    
    Get-ChildItem -Path $playbooksPath -Filter "$Name.psd1" |
        ForEach-Object {
            try {
                $content = Get-Content -Path $_.FullName -Raw
                $scriptBlock = [scriptblock]::Create($content)
                $data = & $scriptBlock
                
                [PSCustomObject]@{
                    Name = $_.BaseName
                    Description = $data.Description ?? 'No description'
                    ScriptCount = $data.Scripts.Count
                    Profiles = $data.Profiles.Keys -join ', '
                    Tags = $data.Tags -join ', '
                    Path = $_.FullName
                    LastModified = $_.LastWriteTime
                }
            }
            catch {
                [PSCustomObject]@{
                    Name = $_.BaseName
                    Description = 'Failed to parse'
                    ScriptCount = 0
                    Profiles = ''
                    Tags = ''
                    Path = $_.FullName
                    LastModified = $_.LastWriteTime
                }
            }
        } |
        Where-Object {
            if ($Tag) {
                $playbook = $_
                $Tag | ForEach-Object { $playbook.Tags -match $_ }
            }
            else {
                $true
            }
        } |
        Sort-Object Name
}

#endregion

#region Configuration Cmdlets

function Get-AitherConfig {
    <#
    .SYNOPSIS
        Get AitherZero configuration
    
    .DESCRIPTION
        Retrieves configuration values from the AitherZero configuration system.
        Supports getting entire config, specific sections, or individual values.
    
    .PARAMETER Key
        Specific configuration key (dot notation: Section.SubSection.Key)
    
    .PARAMETER Section
        Configuration section to retrieve
    
    .PARAMETER AsJson
        Return configuration as JSON string
    
    .PARAMETER AsHashtable
        Return configuration as hashtable (default)
    
    .EXAMPLE
        Get-AitherConfig
        
        Get entire configuration
    
    .EXAMPLE
        Get-AitherConfig -Key "Core.Profile"
        
        Get specific configuration value
    
    .EXAMPLE
        Get-AitherConfig -Section Testing -AsJson
        
        Get testing configuration as JSON
    
    .OUTPUTS
        [hashtable] or [string] if -AsJson
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Key,
        
        [Parameter()]
        [string]$Section,
        
        [Parameter()]
        [switch]$AsJson,
        
        [Parameter()]
        [switch]$AsHashtable
    )
    
    if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
        $config = Get-Configuration
        
        if ($Key) {
            $parts = $Key -split '\.'
            $value = $config
            foreach ($part in $parts) {
                $value = $value[$part]
            }
            return $value
        }
        
        if ($Section) {
            $config = $config[$Section]
        }
        
        if ($AsJson) {
            return $config | ConvertTo-Json -Depth 10
        }
        
        return $config
    }
    else {
        Write-Warning "Configuration module not loaded"
        return @{}
    }
}

function Set-AitherConfig {
    <#
    .SYNOPSIS
        Set AitherZero configuration value
    
    .DESCRIPTION
        Sets a configuration value in the AitherZero configuration system.
        Changes can be persisted to disk or kept in memory only.
    
    .PARAMETER Key
        Configuration key (dot notation: Section.SubSection.Key)
    
    .PARAMETER Value
        Value to set
    
    .PARAMETER Persist
        Save configuration to disk
    
    .EXAMPLE
        Set-AitherConfig -Key "Core.Profile" -Value "Developer"
        
        Set profile to Developer mode
    
    .EXAMPLE
        Set-AitherConfig -Key "Testing.Profile" -Value "Full" -Persist
        
        Set testing profile and save to disk
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Key,
        
        [Parameter(Mandatory, Position=1)]
        [object]$Value,
        
        [Parameter()]
        [switch]$Persist
    )
    
    if ($PSCmdlet.ShouldProcess($Key, "Set configuration value to $Value")) {
        if (Get-Command Set-Configuration -ErrorAction SilentlyContinue) {
            Set-Configuration -Key $Key -Value $Value
            
            if ($Persist) {
                Export-Configuration
                Write-AitherStatus "Configuration saved" -Type Success
            }
        }
        else {
            Write-Warning "Configuration module not loaded"
        }
    }
}

function Switch-AitherEnvironment {
    <#
    .SYNOPSIS
        Switch configuration environment
    
    .DESCRIPTION
        Switches between different configuration environments (Development, Production, etc.)
    
    .PARAMETER Name
        Environment name
    
    .EXAMPLE
        Switch-AitherEnvironment -Name Production
        
        Switch to production environment
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateSet('Development', 'Production', 'Staging', 'Test')]
        [string]$Name
    )
    
    if (Get-Command Switch-ConfigurationEnvironment -ErrorAction SilentlyContinue) {
        Switch-ConfigurationEnvironment -Name $Name
        Write-AitherStatus "Switched to $Name environment" -Type Success
    }
    else {
        Write-Warning "Configuration module not loaded"
    }
}

#endregion

#region Reporting & Metrics Cmdlets

function Show-AitherDashboard {
    <#
    .SYNOPSIS
        Display system dashboard
    
    .DESCRIPTION
        Shows a real-time dashboard with system status, metrics, and recent executions.
    
    .PARAMETER Refresh
        Auto-refresh interval in seconds
    
    .PARAMETER Detailed
        Show detailed metrics
    
    .EXAMPLE
        Show-AitherDashboard
        
        Display dashboard
    
    .EXAMPLE
        Show-AitherDashboard -Refresh 5 -Detailed
        
        Show detailed dashboard with 5-second auto-refresh
    #>
    
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Refresh,
        
        [Parameter()]
        [switch]$Detailed
    )
    
    if (Get-Command Show-Dashboard -ErrorAction SilentlyContinue) {
        # Create a dashboard object that Show-Dashboard expects
        $dashboardObj = @{
            Title = "AitherZero System Dashboard"
            StartTime = Get-Date
            Components = @{
                Status = @{
                    Data = @{
                        'System' = 'Running'
                        'Platform' = (Get-AitherPlatform)
                        'PowerShell' = "$($PSVersionTable.PSVersion)"
                    }
                }
                Progress = @{
                    Data = @{
                        Completed = 0
                        Total = 0
                    }
                }
            }
        }
        
        Show-Dashboard -Dashboard $dashboardObj
    }
    else {
        # Fallback simple dashboard
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  AitherZero System Dashboard" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        # System info
        Write-Host "System Information:" -ForegroundColor Yellow
        Write-Host "  Platform:     " -NoNewline; Write-Host (Get-AitherPlatform) -ForegroundColor Green
        Write-Host "  PowerShell:   " -NoNewline; Write-Host "$($PSVersionTable.PSVersion)" -ForegroundColor Green
        Write-Host "  Project Root: " -NoNewline; Write-Host $env:AITHERZERO_ROOT -ForegroundColor Green
        Write-Host ""
        
        # Script count
        $scripts = Get-AitherScript
        Write-Host "Automation Scripts:" -ForegroundColor Yellow
        Write-Host "  Total Scripts: " -NoNewline; Write-Host $scripts.Count -ForegroundColor Green
        Write-Host ""
        
        # Playbook count
        $playbooks = Get-AitherPlaybook
        Write-Host "Playbooks:" -ForegroundColor Yellow
        Write-Host "  Total Playbooks: " -NoNewline; Write-Host $playbooks.Count -ForegroundColor Green
        Write-Host ""
        
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    }
}

function Get-AitherMetric {
    <#
    .SYNOPSIS
        Get execution metrics
    
    .DESCRIPTION
        Retrieves execution metrics including script runs, success rates, and performance data.
    
    .PARAMETER Period
        Time period (Today, Week, Month, All)
    
    .PARAMETER Format
        Output format (Object, JSON, CSV)
    
    .EXAMPLE
        Get-AitherMetric
        
        Get metrics for all time
    
    .EXAMPLE
        Get-AitherMetric -Period Week -Format JSON
        
        Get last week's metrics as JSON
    #>
    
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Today', 'Week', 'Month', 'All')]
        [string]$Period = 'All',
        
        [Parameter()]
        [ValidateSet('Object', 'JSON', 'CSV')]
        [string]$Format = 'Object'
    )
    
    if (Get-Command Get-ExecutionMetric -ErrorAction SilentlyContinue) {
        $metrics = Get-ExecutionMetric -Period $Period
        
        switch ($Format) {
            'JSON' { return $metrics | ConvertTo-Json -Depth 5 }
            'CSV' { return $metrics | ConvertTo-Csv -NoTypeInformation }
            default { return $metrics }
        }
    }
    else {
        Write-Warning "Reporting module not loaded"
        return @{}
    }
}

function Export-AitherMetric {
    <#
    .SYNOPSIS
        Export metrics to file
    
    .DESCRIPTION
        Exports execution metrics to a file in various formats.
    
    .PARAMETER Path
        Output file path
    
    .PARAMETER Format
        Export format (JSON, CSV, HTML, Markdown)
    
    .EXAMPLE
        Export-AitherMetric -Path ./metrics.json -Format JSON
        
        Export metrics to JSON file
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [ValidateSet('JSON', 'CSV', 'HTML', 'Markdown')]
        [string]$Format = 'JSON'
    )
    
    if (Get-Command Export-MetricsReport -ErrorAction SilentlyContinue) {
        Export-MetricsReport -Path $Path -Format $Format
        Write-AitherStatus "Metrics exported to $Path" -Type Success
    }
    else {
        Write-Warning "Reporting module not loaded"
    }
}

#endregion

#region Utility Cmdlets

function Get-AitherPlatform {
    <#
    .SYNOPSIS
        Get platform information
    
    .DESCRIPTION
        Returns detailed information about the current platform (OS, architecture, etc.)
    
    .EXAMPLE
        Get-AitherPlatform
        
        Get platform information
    #>
    
    [CmdletBinding()]
    param()
    
    if (Get-Command Get-PlatformName -ErrorAction SilentlyContinue) {
        return Get-PlatformName
    }
    
    if ($IsWindows) { return "Windows" }
    if ($IsLinux) { return "Linux" }
    if ($IsMacOS) { return "macOS" }
    return "Unknown"
}

function Test-AitherAdmin {
    <#
    .SYNOPSIS
        Test if running with administrator privileges
    
    .DESCRIPTION
        Checks if the current PowerShell session has administrator/root privileges.
    
    .EXAMPLE
        Test-AitherAdmin
        
        Returns $true if running as admin, $false otherwise
    #>
    
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    if (Get-Command Test-IsAdministrator -ErrorAction SilentlyContinue) {
        return Test-IsAdministrator
    }
    
    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        return (id -u) -eq 0
    }
}

function Get-AitherVersion {
    <#
    .SYNOPSIS
        Get AitherZero version
    
    .DESCRIPTION
        Returns the current AitherZero version and module information.
    
    .EXAMPLE
        Get-AitherVersion
        
        Get version information
    #>
    
    [CmdletBinding()]
    param()
    
    $versionFile = Join-Path $env:AITHERZERO_ROOT 'VERSION'
    
    if (Test-Path $versionFile) {
        $version = Get-Content $versionFile -Raw
    }
    else {
        $version = "Unknown"
    }
    
    [PSCustomObject]@{
        Version = $version.Trim()
        PowerShellVersion = $PSVersionTable.PSVersion
        Platform = Get-AitherPlatform
        CLIVersion = "2.0.0"
        RootPath = $env:AITHERZERO_ROOT
    }
}

function Test-AitherCommand {
    <#
    .SYNOPSIS
        Test if a command is available
    
    .DESCRIPTION
        Checks if a command or executable is available in the current environment.
    
    .PARAMETER Name
        Command name to test
    
    .EXAMPLE
        Test-AitherCommand -Name git
        
        Returns $true if git is available
    #>
    
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Name
    )
    
    if (Get-Command Test-CommandAvailable -ErrorAction SilentlyContinue) {
        return Test-CommandAvailable -Name $Name
    }
    
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

#endregion

#region Logging Cmdlets

function Write-AitherLog {
    <#
    .SYNOPSIS
        Write to AitherZero log
    
    .DESCRIPTION
        Writes a message to the AitherZero logging system with specified level.
    
    .PARAMETER Message
        Message to log
    
    .PARAMETER Level
        Log level (Information, Warning, Error, Debug, Verbose)
    
    .PARAMETER Category
        Log category (General, Testing, Infrastructure, etc.)
    
    .EXAMPLE
        Write-AitherLog "Starting deployment" -Level Information
        
        Log an informational message
    
    .EXAMPLE
        Write-AitherLog "Deployment failed" -Level Error -Category Infrastructure
        
        Log an error with category
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug', 'Verbose')]
        [string]$Level = 'Information',
        
        [Parameter()]
        [string]$Category = 'General'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source $Category
    }
    else {
        Write-Host "[$Level] $Message"
    }
}

#endregion

#region Environment Configuration Cmdlets

function Get-AitherEnvironment {
    <#
    .SYNOPSIS
        Get current environment configuration status
    
    .DESCRIPTION
        Retrieves the current state of environment configuration including:
        - Windows features (long path support, developer mode)
        - Environment variables
        - PATH configuration
        - Shell integration (Unix)
    
    .PARAMETER Category
        Specific category to retrieve (Windows, Unix, EnvironmentVariables, Path, All)
    
    .EXAMPLE
        Get-AitherEnvironment
        
        Get all environment configuration status
    
    .EXAMPLE
        Get-AitherEnvironment -Category Windows
        
        Get Windows-specific configuration status
    
    .OUTPUTS
        [hashtable] Environment configuration status
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('All', 'Windows', 'Unix', 'EnvironmentVariables', 'Path')]
        [string]$Category = 'All'
    )
    
    if (Get-Command Get-EnvironmentConfiguration -ErrorAction SilentlyContinue) {
        return Get-EnvironmentConfiguration -Category $Category
    }
    else {
        Write-Warning "EnvironmentConfig module not loaded"
        return $null
    }
}

function Set-AitherEnvironment {
    <#
    .SYNOPSIS
        Apply environment configuration from config files
    
    .DESCRIPTION
        Applies environment configuration settings including:
        - Windows long path support
        - Developer mode
        - Environment variables
        - PATH modifications
        - Shell integration (Unix)
    
    .PARAMETER Category
        Specific category to apply (Windows, Unix, EnvironmentVariables, Path, All)
    
    .PARAMETER DryRun
        Preview changes without applying them
    
    .PARAMETER Force
        Skip confirmation prompts
    
    .EXAMPLE
        Set-AitherEnvironment
        
        Apply all environment configuration
    
    .EXAMPLE
        Set-AitherEnvironment -Category Windows -DryRun
        
        Preview Windows configuration changes
    
    .EXAMPLE
        Set-AitherEnvironment -Force
        
        Apply configuration without prompts
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('All', 'Windows', 'Unix', 'EnvironmentVariables', 'Path')]
        [string]$Category = 'All',
        
        [switch]$DryRun,
        
        [switch]$Force
    )
    
    if (Get-Command Set-EnvironmentConfiguration -ErrorAction SilentlyContinue) {
        $params = @{
            Category = $Category
            DryRun = $DryRun
            Force = $Force
        }
        
        return Set-EnvironmentConfiguration @params
    }
    else {
        Write-Warning "EnvironmentConfig module not loaded"
        return $null
    }
}

function Set-AitherEnvVariable {
    <#
    .SYNOPSIS
        Set an environment variable
    
    .DESCRIPTION
        Sets or updates an environment variable at specified scope.
        Provides a simple CLI interface for on-the-fly variable management.
    
    .PARAMETER Name
        Variable name
    
    .PARAMETER Value
        Variable value
    
    .PARAMETER Scope
        Variable scope: Process, User, or Machine (System)
    
    .PARAMETER Force
        Overwrite existing value without confirmation
    
    .EXAMPLE
        Set-AitherEnvVariable -Name 'AITHERZERO_PROFILE' -Value 'Developer' -Scope User
        
        Set user-level environment variable
    
    .EXAMPLE
        Set-AitherEnvVariable -Name 'TEMP_VAR' -Value 'test' -Scope Process -Force
        
        Set process variable for current session
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Name,
        
        [Parameter(Mandatory, Position=1)]
        [AllowEmptyString()]
        [string]$Value,
        
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'Process',
        
        [switch]$Force
    )
    
    if (Get-Command Update-EnvironmentVariable -ErrorAction SilentlyContinue) {
        $params = @{
            Name = $Name
            Value = $Value
            Scope = $Scope
            Force = $Force
        }
        
        return Update-EnvironmentVariable @params
    }
    else {
        # Fallback to basic .NET method
        try {
            [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
            Write-AitherStatus "Set $Scope environment variable: $Name" -Type Success
            return $true
        }
        catch {
            Write-AitherStatus "Error setting environment variable: $($_.Exception.Message)" -Type Error
            return $false
        }
    }
}

#endregion

#region Deployment Artifact Cmdlets

function New-AitherDeploymentArtifact {
    <#
    .SYNOPSIS
        Generate deployment artifacts from configuration
    
    .DESCRIPTION
        Generates deployment artifacts including:
        - Windows: Unattend.xml, registry files
        - Linux: Cloud-init, Kickstart, shell scripts
        - macOS: Brewfiles, shell scripts
        - Docker: Dockerfiles
    
    .PARAMETER Platform
        Target platform(s): Windows, Linux, macOS, Docker, All
    
    .PARAMETER OutputPath
        Base output directory for artifacts (default: ./artifacts)
    
    .PARAMETER ConfigPath
        Base path to configuration files (default: current directory)
    
    .EXAMPLE
        New-AitherDeploymentArtifact -Platform Windows
        
        Generate Windows deployment artifacts
    
    .EXAMPLE
        New-AitherDeploymentArtifact -Platform All -OutputPath ./build
        
        Generate all artifacts in custom location
    
    .OUTPUTS
        [hashtable] Generated artifact paths by platform
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Windows', 'Linux', 'macOS', 'Docker', 'All')]
        [string[]]$Platform = 'All',
        
        [string]$OutputPath = './artifacts',
        
        [string]$ConfigPath = '.'
    )
    
    if (Get-Command New-DeploymentArtifacts -ErrorAction SilentlyContinue) {
        Write-AitherStatus "Generating deployment artifacts for: $($Platform -join ', ')" -Type Info
        
        $params = @{
            Platform = $Platform
            OutputPath = $OutputPath
            ConfigPath = $ConfigPath
        }
        
        $result = New-DeploymentArtifacts @params
        
        # Display summary
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Deployment Artifacts Generated" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($platformKey in $result.Keys) {
            if ($result[$platformKey].Count -gt 0) {
                Write-Host "  $platformKey : $($result[$platformKey].Count) artifact(s)" -ForegroundColor Green
                foreach ($file in $result[$platformKey]) {
                    Write-Host "    - $file" -ForegroundColor DarkGray
                }
            }
        }
        
        Write-Host ""
        
        return $result
    }
    else {
        Write-Warning "DeploymentArtifacts module not loaded"
        return $null
    }
}

function New-AitherUnattendXml {
    <#
    .SYNOPSIS
        Generate Windows Unattend.xml file
    
    .DESCRIPTION
        Creates a Windows Unattend.xml file for automated installation
    
    .PARAMETER ConfigPath
        Path to Windows configuration file (default: ./config.windows.psd1)
    
    .PARAMETER OutputPath
        Output directory (default: ./artifacts/windows)
    
    .EXAMPLE
        New-AitherUnattendXml
        
        Generate Unattend.xml from default config
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = './config.windows.psd1',
        [string]$OutputPath = './artifacts/windows'
    )
    
    if (Get-Command New-WindowsUnattendXml -ErrorAction SilentlyContinue) {
        return New-WindowsUnattendXml -ConfigPath $ConfigPath -OutputPath $OutputPath
    }
    else {
        Write-Warning "DeploymentArtifacts module not loaded"
        return $null
    }
}

function New-AitherBrewfile {
    <#
    .SYNOPSIS
        Generate Homebrew Brewfile
    
    .DESCRIPTION
        Creates a Brewfile for installing macOS packages
    
    .PARAMETER ConfigPath
        Path to macOS configuration file (default: ./config.macos.psd1)
    
    .PARAMETER OutputPath
        Output directory (default: ./artifacts/macos)
    
    .EXAMPLE
        New-AitherBrewfile
        
        Generate Brewfile from default config
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = './config.macos.psd1',
        [string]$OutputPath = './artifacts/macos'
    )
    
    if (Get-Command New-MacOSBrewfile -ErrorAction SilentlyContinue) {
        return New-MacOSBrewfile -ConfigPath $ConfigPath -OutputPath $OutputPath
    }
    else {
        Write-Warning "DeploymentArtifacts module not loaded"
        return $null
    }
}

#endregion

# Export all cmdlets
Export-ModuleMember -Function @(
    # Script Execution
    'Invoke-AitherScript',
    'Get-AitherScript',
    'Invoke-AitherSequence',
    
    # Playbook & Orchestration
    'Invoke-AitherPlaybook',
    'Get-AitherPlaybook',
    
    # Configuration
    'Get-AitherConfig',
    'Set-AitherConfig',
    'Switch-AitherEnvironment',
    
    # Environment Configuration
    'Get-AitherEnvironment',
    'Set-AitherEnvironment',
    'Set-AitherEnvVariable',
    
    # Deployment Artifacts
    'New-AitherDeploymentArtifact',
    'New-AitherUnattendXml',
    'New-AitherBrewfile',
    
    # Reporting & Metrics
    'Show-AitherDashboard',
    'Get-AitherMetric',
    'Export-AitherMetric',
    
    # Utilities
    'Get-AitherPlatform',
    'Test-AitherAdmin',
    'Get-AitherVersion',
    'Test-AitherCommand',
    
    # Logging
    'Write-AitherLog'
) -Alias @(
    'az-script',
    'az-playbook',
    'az-config',
    'az-dashboard',
    'az-metrics'
)
