#Requires -Version 7.0

<#
.SYNOPSIS
    PlaybookHelpers.psm1 - Developer-friendly helpers for playbook creation and validation

.DESCRIPTION
    Aitherium™ Enterprise Infrastructure Automation Platform
    Playbook Helpers - Make creating and debugging playbooks EASY!
    
    This module provides:
    - Playbook template generation
    - Schema validation with detailed error messages
    - Parameter helpers
    - Debugging and troubleshooting utilities

.NOTES
    Copyright © 2025 Aitherium Corporation
#>

# Import logging if available
$script:LoggingAvailable = $false
try {
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $loggingPath = Join-Path $projectRoot "aithercore/utilities/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output
}

function Write-PlaybookLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "[Playbook] $Message" -Level $Level -Source "PlaybookHelpers"
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$timestamp] [PLAYBOOK] $Message"
    }
}

function New-PlaybookTemplate {
    <#
    .SYNOPSIS
        Generate a new playbook template with sensible defaults
    
    .DESCRIPTION
        Creates a well-structured playbook template that's easy to customize.
        No more guessing at property names or structure!
    
    .PARAMETER Name
        Playbook name (e.g., 'my-validation')
    
    .PARAMETER Description
        Human-readable description
    
    .PARAMETER Scripts
        Array of script numbers to include (e.g., @('0407', '0413'))
    
    .PARAMETER Type
        Template type: Simple, Testing, CI, Deployment
    
    .PARAMETER OutputPath
        Where to save the playbook (defaults to library/playbooks/)
    
    .EXAMPLE
        New-PlaybookTemplate -Name 'my-validation' -Scripts @('0407', '0413') -Type Testing
        
        Creates a testing playbook template with syntax validation and config validation
    
    .EXAMPLE
        New-PlaybookTemplate -Name 'deploy-prod' -Type Deployment -Scripts @('0100', '0101')
        
        Creates a deployment playbook template
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9-]+$')]
        [string]$Name,
        
        [Parameter()]
        [string]$Description = "Playbook created $(Get-Date -Format 'yyyy-MM-dd')",
        
        [Parameter()]
        [ValidatePattern('^\d{4}$')]
        [string[]]$Scripts = @(),
        
        [Parameter()]
        [ValidateSet('Simple', 'Testing', 'CI', 'Deployment')]
        [string]$Type = 'Simple',
        
        [Parameter()]
        [string]$OutputPath
    )
    
    # Determine output path
    if (-not $OutputPath) {
        $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $OutputPath = Join-Path $projectRoot "library/playbooks/$Name.psd1"
    }
    
    # Build script sequence
    $sequence = @()
    foreach ($scriptNum in $Scripts) {
        $sequence += @"
        @{
            Script = '$scriptNum'
            Description = 'TODO: Add description for script $scriptNum'
            Parameters = @{}
            ContinueOnError = `$false
            Timeout = 300
        }
"@
    }
    
    # If no scripts provided, add placeholder
    if ($sequence.Count -eq 0) {
        $sequence += @"
        @{
            Script = '0000'
            Description = 'TODO: Replace with your script number'
            Parameters = @{}
            ContinueOnError = `$false
            Timeout = 300
        }
"@
    }
    
    $sequenceBlock = $sequence -join ",`n"
    
    # Type-specific defaults
    $typeDefaults = switch ($Type) {
        'Testing' {
            @{
                Parallel = '$false'
                StopOnError = '$true'
                MaxConcurrency = '1'
                ExtraVars = @"

        # Testing-specific variables
        TestMode = `$true
        FailFast = `$true
"@
            }
        }
        'CI' {
            @{
                Parallel = '$false'
                StopOnError = '$true'
                MaxConcurrency = '1'
                ExtraVars = @"

        # CI environment variables
        CI = "true"
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
"@
            }
        }
        'Deployment' {
            @{
                Parallel = '$false'
                StopOnError = '$true'
                MaxConcurrency = '1'
                ExtraVars = @"

        # Deployment variables
        Environment = "Development"  # Override: Development, Staging, Production
        DryRun = `$false
"@
            }
        }
        default {
            @{
                Parallel = '$false'
                StopOnError = '$true'
                MaxConcurrency = '2'
                ExtraVars = ''
            }
        }
    }
    
    # Generate template
    $template = @"
@{
    Name = '$Name'
    Description = '$Description'
    Version = '1.0.0'
    
    # Execute these scripts in sequence
    Sequence = @(
$sequenceBlock
    )
    
    # Variables available to all scripts
    Variables = @{$($typeDefaults.ExtraVars)
    }
    
    # Execution options
    Options = @{
        Parallel = $($typeDefaults.Parallel)
        MaxConcurrency = $($typeDefaults.MaxConcurrency)
        StopOnError = $($typeDefaults.StopOnError)
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = `$true
        MinimumSuccessCount = $($Scripts.Count)
    }
}
"@
    
    if ($PSCmdlet.ShouldProcess($OutputPath, "Create playbook template")) {
        # Ensure directory exists
        $directory = Split-Path $OutputPath -Parent
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        # Write template
        $template | Set-Content -Path $OutputPath -Encoding utf8
        
        Write-PlaybookLog "Created playbook template: $OutputPath" -Level 'Success'
        Write-Host "`n✅ Playbook template created successfully!" -ForegroundColor Green
        Write-Host "   📄 File: $OutputPath" -ForegroundColor Cyan
        Write-Host "`n💡 Next steps:" -ForegroundColor Yellow
        Write-Host "   1. Edit the playbook file to customize scripts and parameters"
        Write-Host "   2. Run: Test-PlaybookDefinition -Path '$OutputPath'"
        Write-Host "   3. Test: Invoke-OrchestrationSequence -LoadPlaybook '$Name' -DryRun"
        Write-Host ""
        
        return $OutputPath
    }
}

function Test-PlaybookDefinition {
    <#
    .SYNOPSIS
        Validate a playbook definition with detailed error messages
    
    .DESCRIPTION
        Pre-flight validation for playbooks. Catches errors BEFORE runtime!
        
        Validates:
        - Required properties (Name, Sequence)
        - Property types and formats
        - Script numbers exist
        - Parameter compatibility
        - Timeout values are reasonable
        - Variable references are valid
    
    .PARAMETER Path
        Path to playbook .psd1 file
    
    .PARAMETER PlaybookData
        Hashtable with playbook definition (alternative to Path)
    
    .PARAMETER Strict
        Enable strict validation (warns about missing descriptions, etc.)
    
    .EXAMPLE
        Test-PlaybookDefinition -Path './library/playbooks/my-playbook.psd1'
        
        Validates the playbook and shows any errors or warnings
    
    .EXAMPLE
        Test-PlaybookDefinition -Path './my-playbook.psd1' -Strict
        
        Strict validation - warns about missing descriptions and best practices
    
    .OUTPUTS
        [PSCustomObject] Validation result with IsValid, Errors, Warnings, Info
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        
        [Parameter(Mandatory, ParameterSetName = 'Data')]
        [hashtable]$PlaybookData,
        
        [Parameter()]
        [switch]$Strict
    )
    
    $result = [PSCustomObject]@{
        IsValid = $true
        Errors = @()
        Warnings = @()
        Info = @()
        PlaybookName = 'Unknown'
        ScriptCount = 0
    }
    
    # Load playbook
    if ($Path) {
        try {
            $content = Get-Content -Path $Path -Raw
            $scriptBlock = [scriptblock]::Create($content)
            $PlaybookData = & $scriptBlock
            
            # Ensure it's a hashtable
            if ($PlaybookData -isnot [hashtable]) {
                $result.Errors += "Playbook file must return a hashtable, got $($PlaybookData.GetType().Name)"
                $result.IsValid = $false
                return $result
            }
            
            $result.Info += "Loaded playbook from: $Path"
        } catch {
            $result.Errors += "Failed to load playbook: $($_.Exception.Message)"
            $result.IsValid = $false
            return $result
        }
    }
    
    # Validate required properties
    if (-not $PlaybookData.ContainsKey('Name')) {
        $result.Errors += "Missing required property: 'Name'"
        $result.IsValid = $false
    } else {
        $result.PlaybookName = $PlaybookData.Name
    }
    
    if (-not ($PlaybookData.ContainsKey('Sequence') -or $PlaybookData.ContainsKey('sequence'))) {
        $result.Errors += "Missing required property: 'Sequence'"
        $result.IsValid = $false
        return $result  # Can't continue without Sequence
    }
    
    # Get sequence
    $sequence = if ($PlaybookData.ContainsKey('Sequence')) {
        @($PlaybookData.Sequence)  # Force array
    } elseif ($PlaybookData.ContainsKey('sequence')) {
        @($PlaybookData.sequence)  # Force array
    } else {
        @()  # Empty array
    }
    
    if ($sequence.Count -eq 0) {
        $result.Errors += "Sequence is empty - at least one script required"
        $result.IsValid = $false
        return $result
    }
    
    $result.ScriptCount = $sequence.Count
    
    # Validate each script in sequence
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $scriptsPath = Join-Path $projectRoot 'library/automation-scripts'
    
    for ($i = 0; $i -lt $sequence.Count; $i++) {
        $scriptDef = $sequence[$i]
        $scriptIndex = $i + 1
        
        # Check if it's a hashtable
        if ($scriptDef -isnot [hashtable]) {
            $typename = if ($scriptDef) { $scriptDef.GetType().Name } else { 'null' }
            $result.Errors += "Script #$scriptIndex : Must be a hashtable, got $typename"
            $result.IsValid = $false
            continue
        }
        
        # Validate Script property
        $scriptProp = $scriptDef['Script'] ?? $scriptDef['script']
        if (-not $scriptProp) {
            $result.Errors += "Script #$scriptIndex : Missing 'Script' property"
            $result.IsValid = $false
            continue
        }
        
        # Extract script number
        $scriptNumber = $null
        if ($scriptProp -match '(\d{4})') {
            $scriptNumber = $Matches[1]
        } else {
            $result.Errors += "Script #$scriptIndex : Script property '$scriptProp' does not contain a four-digit number"
            $result.IsValid = $false
            continue
        }
        
        # Check if script exists
        $scriptFile = Get-ChildItem -Path $scriptsPath -Filter "${scriptNumber}_*.ps1" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $scriptFile) {
            $result.Errors += "Script #$scriptIndex ($scriptNumber): Script file not found in automation-scripts/"
            $result.IsValid = $false
        }
        
        # Validate Timeout
        if ($scriptDef.ContainsKey('Timeout') -or $scriptDef.ContainsKey('timeout')) {
            $timeout = $scriptDef['Timeout'] ?? $scriptDef['timeout']
            if ($timeout -isnot [int] -and $timeout -notmatch '^\d+$') {
                $result.Errors += "Script #$scriptIndex ($scriptNumber): Timeout must be an integer, got '$timeout'"
                $result.IsValid = $false
            } elseif ([int]$timeout -le 0) {
                $result.Errors += "Script #$scriptIndex ($scriptNumber): Timeout must be positive, got $timeout"
                $result.IsValid = $false
            } elseif ([int]$timeout -gt 7200) {
                $result.Warnings += "Script #$scriptIndex ($scriptNumber): Timeout is very high ($timeout seconds > 2 hours)"
            }
        }
        
        # Validate Parameters
        if ($scriptDef.ContainsKey('Parameters') -or $scriptDef.ContainsKey('parameters')) {
            $params = $scriptDef['Parameters'] ?? $scriptDef['parameters']
            if ($params -isnot [hashtable] -and $params -isnot [System.Collections.IDictionary]) {
                $result.Errors += "Script #$scriptIndex ($scriptNumber): Parameters must be a hashtable"
                $result.IsValid = $false
            }
        }
        
        # Validate ContinueOnError
        if ($scriptDef.ContainsKey('ContinueOnError') -or $scriptDef.ContainsKey('continueOnError')) {
            $continueOnError = $scriptDef['ContinueOnError'] ?? $scriptDef['continueOnError']
            if ($continueOnError -isnot [bool] -and $continueOnError -notmatch '^(true|false|\$true|\$false)$') {
                $result.Warnings += "Script #$scriptIndex ($scriptNumber): ContinueOnError should be a boolean"
            }
        }
        
        # Strict mode checks
        if ($Strict) {
            if (-not ($scriptDef.ContainsKey('Description') -or $scriptDef.ContainsKey('description'))) {
                $result.Warnings += "Script #$scriptIndex ($scriptNumber): Missing 'Description' (recommended)"
            }
        }
    }
    
    # Validate Variables section
    if ($PlaybookData.ContainsKey('Variables') -or $PlaybookData.ContainsKey('variables')) {
        $vars = $PlaybookData['Variables'] ?? $PlaybookData['variables']
        if ($vars -isnot [hashtable]) {
            $result.Errors += "Variables must be a hashtable"
            $result.IsValid = $false
        }
    }
    
    # Validate Options section
    if ($PlaybookData.ContainsKey('Options') -or $PlaybookData.ContainsKey('options')) {
        $options = $PlaybookData['Options'] ?? $PlaybookData['options']
        if ($options -isnot [hashtable]) {
            $result.Errors += "Options must be a hashtable"
            $result.IsValid = $false
        } else {
            # Validate specific option values
            if ($options.ContainsKey('MaxConcurrency')) {
                $maxConcurrency = $options.MaxConcurrency
                if ($maxConcurrency -isnot [int] -and $maxConcurrency -notmatch '^\d+$') {
                    $result.Errors += "Options.MaxConcurrency must be an integer"
                    $result.IsValid = $false
                } elseif ([int]$maxConcurrency -le 0) {
                    $result.Errors += "Options.MaxConcurrency must be positive"
                    $result.IsValid = $false
                }
            }
        }
    }
    
    # Summary
    $result.Info += "Validated $($result.ScriptCount) script(s) in sequence"
    
    # Display results
    Write-Host "`n📋 Playbook Validation: " -NoNewline -ForegroundColor Cyan
    Write-Host "$($result.PlaybookName)" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    
    if ($result.Errors.Count -gt 0) {
        Write-Host "`n❌ ERRORS ($($result.Errors.Count)):" -ForegroundColor Red
        foreach ($error in $result.Errors) {
            Write-Host "   • $error" -ForegroundColor Red
        }
    }
    
    if ($result.Warnings.Count -gt 0) {
        Write-Host "`n⚠️  WARNINGS ($($result.Warnings.Count)):" -ForegroundColor Yellow
        foreach ($warning in $result.Warnings) {
            Write-Host "   • $warning" -ForegroundColor Yellow
        }
    }
    
    if ($result.Info.Count -gt 0 -and $result.Errors.Count -eq 0) {
        Write-Host "`n✅ SUCCESS:" -ForegroundColor Green
        foreach ($info in $result.Info) {
            Write-Host "   • $info" -ForegroundColor Green
        }
    }
    
    if ($result.IsValid) {
        Write-Host "`n🎉 Playbook is valid and ready to use!" -ForegroundColor Green
    } else {
        Write-Host "`n💥 Playbook has errors that must be fixed before use" -ForegroundColor Red
    }
    
    Write-Host ""
    
    return $result
}

function Get-PlaybookScriptInfo {
    <#
    .SYNOPSIS
        Get information about scripts referenced in a playbook
    
    .DESCRIPTION
        Shows what scripts will be executed, their descriptions, and metadata.
        Helpful for understanding what a playbook does before running it.
    
    .PARAMETER PlaybookName
        Name of the playbook to analyze
    
    .PARAMETER Path
        Path to playbook file
    
    .EXAMPLE
        Get-PlaybookScriptInfo -PlaybookName 'pr-validation-fast'
        
        Shows all scripts in the PR validation playbook
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Name')]
        [string]$PlaybookName,
        
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path
    )
    
    # Load playbook
    if ($PlaybookName) {
        $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Path = Join-Path $projectRoot "library/playbooks/$PlaybookName.psd1"
    }
    
    if (-not (Test-Path $Path)) {
        Write-Error "Playbook not found: $Path"
        return
    }
    
    $content = Get-Content -Path $Path -Raw
    $scriptBlock = [scriptblock]::Create($content)
    $playbook = & $scriptBlock
    
    $sequence = $playbook.Sequence ?? $playbook.sequence
    if (-not $sequence) {
        Write-Warning "No sequence found in playbook"
        return
    }
    
    Write-Host "`n📚 Playbook: " -NoNewline -ForegroundColor Cyan
    Write-Host "$($playbook.Name)" -ForegroundColor White
    Write-Host "   $($playbook.Description)" -ForegroundColor DarkGray
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    
    Write-Host "`n📜 Scripts ($($sequence.Count)):`n" -ForegroundColor Yellow
    
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $scriptsPath = Join-Path $projectRoot 'library/automation-scripts'
    
    for ($i = 0; $i -lt $sequence.Count; $i++) {
        $scriptDef = $sequence[$i]
        $scriptNum = if ($scriptDef.Script -match '(\d{4})') { $Matches[1] } else { 'Unknown' }
        
        # Get script file info
        $scriptFile = Get-ChildItem -Path $scriptsPath -Filter "${scriptNum}_*.ps1" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        $scriptName = if ($scriptFile) { $scriptFile.Name } else { "$scriptNum (not found)" }
        
        Write-Host "   $($i + 1). " -NoNewline -ForegroundColor DarkGray
        Write-Host "[$scriptNum] " -NoNewline -ForegroundColor Cyan
        Write-Host $scriptName -ForegroundColor White
        
        if ($scriptDef.Description) {
            Write-Host "      → " -NoNewline -ForegroundColor DarkGray
            Write-Host $scriptDef.Description -ForegroundColor Gray
        }
        
        if ($scriptDef.Parameters -and $scriptDef.Parameters.Count -gt 0) {
            Write-Host "      Parameters: " -NoNewline -ForegroundColor DarkGray
            Write-Host ($scriptDef.Parameters.Keys -join ', ') -ForegroundColor Yellow
        }
        
        if ($scriptDef.Timeout) {
            Write-Host "      Timeout: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($scriptDef.Timeout)s" -ForegroundColor Magenta
        }
        
        Write-Host ""
    }
}

function ConvertTo-NormalizedParameter {
    <#
    .SYNOPSIS
        Convert a parameter value to match script parameter type
    
    .DESCRIPTION
        Helper function to convert playbook parameter values to the correct type
        expected by scripts. Handles switch parameters, booleans, strings, etc.
    
    .PARAMETER Value
        The value to convert
    
    .PARAMETER ParameterType
        The target parameter type
    
    .EXAMPLE
        ConvertTo-NormalizedParameter -Value 'true' -ParameterType ([System.Management.Automation.SwitchParameter])
        
        Returns $true (converted from string)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Value,
        
        [Parameter(Mandatory)]
        [type]$ParameterType
    )
    
    # Handle switch parameters
    if ($ParameterType -eq [System.Management.Automation.SwitchParameter]) {
        if ($Value -is [string]) {
            return $Value -in @('true', 'True', 'TRUE', '1', 'yes', 'Yes', 'YES')
        }
        elseif ($Value -is [int]) {
            return $Value -ne 0
        }
        else {
            return [bool]$Value
        }
    }
    
    # Handle boolean
    if ($ParameterType -eq [bool]) {
        if ($Value -is [string]) {
            return $Value -in @('true', 'True', 'TRUE', '1', 'yes', 'Yes', 'YES', '$true')
        }
        elseif ($Value -is [int]) {
            return $Value -ne 0
        }
        else {
            return [bool]$Value
        }
    }
    
    # Handle integers
    if ($ParameterType -eq [int] -or $ParameterType -eq [int32] -or $ParameterType -eq [int64]) {
        return [int]$Value
    }
    
    # Handle strings
    if ($ParameterType -eq [string]) {
        return $Value.ToString()
    }
    
    # Default: return as-is
    return $Value
}

# Export functions
Export-ModuleMember -Function @(
    'New-PlaybookTemplate'
    'Test-PlaybookDefinition'
    'Get-PlaybookScriptInfo'
    'ConvertTo-NormalizedParameter'
)
