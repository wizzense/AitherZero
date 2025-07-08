#Requires -Version 7.0

# Robust project root detection using shared utility
$findProjectRootPath = Join-Path $PSScriptRoot "../../shared/Find-ProjectRoot.ps1"
if (Test-Path $findProjectRootPath) {
    . $findProjectRootPath
    $script:ProjectRoot = Find-ProjectRoot
} else {
    # Fallback: basic upward traversal
    $script:ProjectRoot = $PSScriptRoot
    while ($script:ProjectRoot -and -not (Test-Path (Join-Path $script:ProjectRoot "aither-core"))) {
        $parent = Split-Path $script:ProjectRoot -Parent
        if ($parent -eq $script:ProjectRoot) { break }
        $script:ProjectRoot = $parent
    }
}

# Import the centralized Logging module
$loggingImported = $false

# Import ProgressTracking module for enhanced lab deployment tracking
$progressTrackingImported = $false

# Check if Logging module is already available
if (Get-Module -Name 'Logging' -ErrorAction SilentlyContinue) {
    $loggingImported = $true
    Write-Verbose "Logging module already available"
} else {
    # Robust path resolution using project root
    $loggingPaths = @(
        'Logging',  # Try module name first (if in PSModulePath)
        (Join-Path (Split-Path $PSScriptRoot -Parent) "Logging"),  # Relative to modules directory
        (Join-Path $script:ProjectRoot "aither-core/modules/Logging")  # Project root based path
    )

    # Add environment-based paths if available
    if ($env:PWSH_MODULES_PATH) {
        $loggingPaths += (Join-Path $env:PWSH_MODULES_PATH "Logging")
    }
    if ($env:PROJECT_ROOT) {
        $loggingPaths += (Join-Path $env:PROJECT_ROOT "aither-core/modules/Logging")
    }

    foreach ($loggingPath in $loggingPaths) {
        if ($loggingImported) { break }

        try {
            if ($loggingPath -eq 'Logging') {
                Import-Module 'Logging' -Global -ErrorAction Stop
            } elseif (Test-Path $loggingPath) {
                Import-Module $loggingPath -Global -ErrorAction Stop
            } else {
                continue
            }
            Write-Verbose "Successfully imported Logging module from: $loggingPath"
            $loggingImported = $true
        } catch {
            Write-Verbose "Failed to import Logging from $loggingPath : $_"
        }
    }
}

if (-not $loggingImported) {
    Write-Warning "Could not import Logging module from any of the attempted paths"
    # Fallback: dot-source local logger if centralized not available
    $localLogger = Join-Path $PSScriptRoot "Logger.ps1"
    if (Test-Path $localLogger) {
        . $localLogger
    }
}

# Progress logging function for enhanced deployment tracking
function Write-ProgressLog {
    <#
    .SYNOPSIS
        Write progress log messages with formatting
    
    .DESCRIPTION
        Provides consistent progress logging for long-running operations
    
    .PARAMETER Message
        The message to log
    
    .PARAMETER Level
        Log level (Info, Success, Error, Warning)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Error', 'Warning')]
        [string]$Level = 'Info'
    )
    
    try {
        # Use Write-CustomLog if available, otherwise fallback
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            $logLevel = switch ($Level) {
                'Info' { 'INFO' }
                'Success' { 'SUCCESS' }
                'Error' { 'ERROR' }
                'Warning' { 'WARNING' }
                default { 'INFO' }
            }
            Write-CustomLog -Message $Message -Level $logLevel
        } else {
            $color = switch ($Level) {
                'Info' { 'Cyan' }
                'Success' { 'Green' }
                'Error' { 'Red' }
                'Warning' { 'Yellow' }
                default { 'White' }
            }
            Write-Host "[$Level] $Message" -ForegroundColor $color
        }
    } catch {
        Write-Host "[$Level] $Message"
    }
}

# Try to import ProgressTracking module (conditional - non-breaking)
if (Get-Module -Name 'ProgressTracking' -ErrorAction SilentlyContinue) {
    $progressTrackingImported = $true
    Write-Verbose "ProgressTracking module already available"
} else {
    # Robust path resolution for ProgressTracking module
    $progressTrackingPaths = @(
        'ProgressTracking',  # Try module name first (if in PSModulePath)
        (Join-Path (Split-Path $PSScriptRoot -Parent) "ProgressTracking"),  # Relative to modules directory
        (Join-Path $script:ProjectRoot "aither-core/modules/ProgressTracking")  # Project root based path
    )

    # Add environment-based paths if available
    if ($env:PWSH_MODULES_PATH) {
        $progressTrackingPaths += (Join-Path $env:PWSH_MODULES_PATH "ProgressTracking")
    }
    if ($env:PROJECT_ROOT) {
        $progressTrackingPaths += (Join-Path $env:PROJECT_ROOT "aither-core/modules/ProgressTracking")
    }

    foreach ($progressPath in $progressTrackingPaths) {
        if ($progressTrackingImported) { break }

        try {
            if ($progressPath -eq 'ProgressTracking') {
                Import-Module 'ProgressTracking' -Global -ErrorAction Stop
            } elseif (Test-Path $progressPath) {
                Import-Module $progressPath -Global -ErrorAction Stop
            } else {
                continue
            }
            Write-Verbose "Successfully imported ProgressTracking module from: $progressPath"
            $progressTrackingImported = $true
        } catch {
            Write-Verbose "Failed to import ProgressTracking from $progressPath : $_"
        }
    }
}

if (-not $progressTrackingImported) {
    Write-Verbose "ProgressTracking module not available - progress tracking features disabled"
}

# Dot-source utility modules
. $PSScriptRoot/Get-Platform.ps1
. $PSScriptRoot/Network.ps1
. $PSScriptRoot/InvokeOpenTofuInstaller.ps1
. $PSScriptRoot/Format-Config.ps1
. $PSScriptRoot/Expand-All.ps1
. $PSScriptRoot/Menu.ps1
. $PSScriptRoot/Download-Archive.ps1

# Temporary Get-Platform function
function Get-Platform {
    if ($IsWindows) { return 'Windows' }
    elseif ($IsLinux) { return 'Linux' }
    elseif ($IsMacOS) { return 'MacOS' }
    else { return 'Unknown' }
}

function Get-CrossPlatformTempPath {
    <#
    .SYNOPSIS
    Returns the appropriate temporary directory path for the current platform.

    .DESCRIPTION
    Provides a cross-platform way to get the temporary directory, handling cases where
    $env:TEMP might not be set (e.g., on Linux/macOS).
    #>
    if ($env:TEMP) {
        return $env:TEMP
    } else {
        return [System.IO.Path]::GetTempPath()
    }
}

function Invoke-CrossPlatformCommand {
    <#
    .SYNOPSIS
    Safely invokes platform-specific cmdlets with fallback behavior

    .DESCRIPTION
    Checks if a cmdlet is available before invoking it, allowing scripts to be more
    cross-platform compatible. Provides mock-friendly execution for testing.

    .PARAMETER CommandName
    The name of the cmdlet to invoke

    .PARAMETER Parameters
    Hashtable of parameters to pass to the cmdlet

    .PARAMETER MockResult
    Result to return when the cmdlet is not available (for testing/cross-platform compatibility)

    .PARAMETER SkipOnUnavailable
    If true, silently skip execution when cmdlet is unavailable instead of throwing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [hashtable]$Parameters = @{},

        [object]$MockResult = $null,

        [switch]$SkipOnUnavailable
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        return & $CommandName @Parameters
    } elseif ($MockResult -ne $null) {
        Write-CustomLog "Command '$CommandName' not available, returning mock result" 'WARN'
        return $MockResult
    } elseif ($SkipOnUnavailable) {
        Write-CustomLog "Command '$CommandName' not available, skipping" 'WARN'
        return $null
    } else {
        throw "Command '$CommandName' is not available on this platform"
    }
}

function Invoke-LabStep {
    [CmdletBinding()]
    param(
        [scriptblock]$Body,
        [object]$Config
    )

    # Handle config parameter - can be string path, JSON string, or object
    if ($Config -is [string]) {
        if (Test-Path $Config) {
            $Config = Get-Content -Raw -Path $Config | ConvertFrom-Json
        } else {
            try { $Config = $Config | ConvertFrom-Json } catch {}
        }
    }

    $suppress = $false
    if ($env:LAB_CONSOLE_LEVEL -eq '0') {
        $suppress = $true
    } elseif ($PSCommandPath -and (Split-Path $PSCommandPath -Leaf) -eq 'dummy.ps1') {
        $suppress = $true
    }

    $prevConsole = $null
    if ($suppress) {
        if (Get-Variable -Name ConsoleLevel -Scope Script -ErrorAction SilentlyContinue) {
            $prevConsole = $script:ConsoleLevel
        }
        $script:ConsoleLevel = -1
    }

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    try {
        & $Body $Config
    } catch {
        if (-not $suppress) {
            Write-CustomLog "ERROR: $_" 'ERROR'
        }
        throw
    } finally {
        $ErrorActionPreference = $prevEAP
        if ($suppress -and $null -ne $prevConsole) {
            $script:ConsoleLevel = $prevConsole
        }
    }
}

function Invoke-LabDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [scriptblock]$Action,
        [string]$Prefix = 'download',
        [string]$Extension
    )

    $ext = if ($Extension) {
        if ($Extension.StartsWith('.')) { $Extension } else { ".$Extension" }
    } else {
        try { [System.IO.Path]::GetExtension($Uri).Split('?')[0] } catch { '' }
    }

    $tempDir = Get-CrossPlatformTempPath
    $path = Join-Path $tempDir ("{0}_{1}{2}" -f $Prefix, [guid]::NewGuid(), $ext)
    Write-CustomLog "Downloading $Uri to $path"

    try {
        Invoke-LabWebRequest -Uri $Uri -OutFile $path -UseBasicParsing
        & $Action $path
    } finally {
        Remove-Item $path -Force -ErrorAction SilentlyContinue
    }
}

function Read-LoggedInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        [switch]$AsSecureString,
        [string]$DefaultValue = ""
    )

    # Check if we're in non-interactive mode (test environment, etc.)
    $IsNonInteractive = ($Host.Name -eq 'Default Host') -or
                      ([Environment]::UserInteractive -eq $false) -or
                      ($env:PESTER_RUN -eq 'true')

    if ($IsNonInteractive) {
        Write-CustomLog "Non-interactive mode detected. Using default value for: $Prompt" 'INFO'
        if ($AsSecureString -and -not [string]::IsNullOrEmpty($DefaultValue)) {
            # This is a legitimate use case for test environments - PSScriptAnalyzer suppressed: PSAvoidUsingConvertToSecureStringWithPlainText
            return ConvertTo-SecureString -String $DefaultValue -AsPlainText -Force
        }
        return $DefaultValue
    }

    if ($AsSecureString) {
        Write-CustomLog "$Prompt (secure input)"
        return Read-Host -Prompt $Prompt -AsSecureString
    }

    $answer = Read-Host -Prompt $Prompt
    Write-CustomLog "$($Prompt): $answer"
    return $answer
}

function Invoke-LabWebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [string]$OutFile,
        [switch]$UseBasicParsing
    )

    try {
        Invoke-WebRequest @PSBoundParameters
    } catch {
        Write-CustomLog "Web request failed for $Uri : $_" 'ERROR'
        throw
    }
}

function Invoke-LabNpm {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Args
    )

    Write-CustomLog "Running npm $($Args -join ' ')" 'INFO'
    npm @Args
}

function Resolve-ProjectPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $projectRoot = $env:PROJECT_ROOT
    if (-not $projectRoot) {
        $projectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    }

    return Join-Path $projectRoot $RelativePath
}

function Get-LabConfig {
    [CmdletBinding()]
    param(
        [string]$Path = 'configs/lab_config.yaml'
    )

    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        $Path
    } else {
        Resolve-ProjectPath $Path
    }

    if (-not (Test-Path $fullPath)) {
        Write-CustomLog "Config file not found: $fullPath" 'WARN'
        return $null
    }

    try {
        # Simple YAML-like parsing for basic config files
        $content = Get-Content $fullPath -Raw
        $config = @{}

        $content -split "`n" | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith('#')) {
                if ($line -match '^(\w+):\s*(.+)$') {
                    $config[$matches[1]] = $matches[2].Trim('"''')
                }
            }
        }

        return $config
    } catch {
        Write-CustomLog "Failed to parse config file $fullPath : $_" 'ERROR'
        throw
    }
}

# ============================================================================
# LAB AUTOMATION COMPATIBILITY FUNCTIONS
# ============================================================================

function Start-LabAutomation {
    <#
    .SYNOPSIS
        Starts lab automation workflow with enhanced progress tracking

    .DESCRIPTION
        Compatibility function for starting lab automation processes with visual progress indicators,
        time estimates, and comprehensive status reporting during deployment operations.

    .PARAMETER Configuration
        Lab configuration parameters

    .PARAMETER Steps
        Specific lab steps to execute

    .PARAMETER ShowProgress
        Enable enhanced progress tracking (requires ProgressTracking module)

    .PARAMETER ProgressStyle
        Style of progress display: Bar, Spinner, Percentage, or Detailed
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{},
        [string[]]$Steps = @(),
        [switch]$ShowProgress,
        [ValidateSet('Bar', 'Spinner', 'Percentage', 'Detailed')]
        [string]$ProgressStyle = 'Bar'
    )

    Write-CustomLog -Message "🚀 Starting lab automation workflow" -Level "INFO"

    # Initialize progress tracking if available and requested
    $progressOperationId = $null
    $useProgressTracking = $ShowProgress -and $script:progressTrackingImported

    if ($useProgressTracking) {
        try {
            $totalSteps = if ($Steps.Count -gt 0) { $Steps.Count } else { 5 }  # Default lab automation steps
            $progressOperationId = Start-ProgressOperation -OperationName "Lab Automation Workflow" -TotalSteps $totalSteps -ShowTime -ShowETA -Style $ProgressStyle
            Write-ProgressLog -Message "Initialized progress tracking for lab automation" -Level 'Info'
        } catch {
            Write-CustomLog -Message "Warning: Could not initialize progress tracking: $($_.Exception.Message)" -Level "WARN"
            $useProgressTracking = $false
        }
    }

    try {
        if ($Steps.Count -gt 0) {
            # Execute specific steps with progress tracking
            for ($i = 0; $i -lt $Steps.Count; $i++) {
                $step = $Steps[$i]

                if ($useProgressTracking) {
                    Update-ProgressOperation -OperationId $progressOperationId -CurrentStep ($i + 1) -StepName "Executing: $step"
                }

                Write-CustomLog -Message "📋 Executing lab step: $step" -Level "INFO"

                try {
                    Invoke-LabStep -StepName $step -Config $Configuration

                    if ($useProgressTracking) {
                        Write-ProgressLog -Message "Completed step: $step" -Level 'Success'
                    }
                } catch {
                    if ($useProgressTracking) {
                        Add-ProgressError -OperationId $progressOperationId -Error "Failed to execute step '$step': $($_.Exception.Message)"
                        Write-ProgressLog -Message "Failed step: $step - $($_.Exception.Message)" -Level 'Error'
                    }
                    throw
                }
            }
        } else {
            # Execute default lab configuration with progress tracking
            Write-CustomLog -Message "📋 Executing default lab configuration" -Level "INFO"

            if ($useProgressTracking) {
                # Update progress for different phases of default execution
                Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 1 -StepName "Loading lab configuration"
            }

            $config = Get-LabConfig

            if ($useProgressTracking) {
                Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 2 -StepName "Validating configuration"
            }

            # Validate configuration
            if (-not $config) {
                $errorMsg = "Lab configuration could not be loaded"
                if ($useProgressTracking) {
                    Add-ProgressError -OperationId $progressOperationId -Error $errorMsg
                }
                throw $errorMsg
            }

            if ($useProgressTracking) {
                Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 3 -StepName "Preparing lab environment"
            }

            # Execute parallel lab runner with enhanced progress tracking
            if ($useProgressTracking) {
                Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 4 -StepName "Starting parallel lab deployment"
            }

            Invoke-ParallelLabRunner -Config $config -ShowProgress:$ShowProgress -ProgressStyle $ProgressStyle

            if ($useProgressTracking) {
                Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 5 -StepName "Finalizing deployment"
            }
        }

        # Complete progress tracking
        if ($useProgressTracking) {
            Complete-ProgressOperation -OperationId $progressOperationId -ShowSummary
        }

        $result = @{
            Status = "Success"
            Message = "Lab automation completed successfully"
            ExecutedSteps = $Steps
            ProgressTrackingEnabled = $useProgressTracking
        }

        Write-CustomLog -Message "✅ Lab automation completed successfully" -Level "SUCCESS"

        return $result

    } catch {
        # Handle errors and complete progress tracking
        if ($useProgressTracking -and $progressOperationId) {
            Add-ProgressError -OperationId $progressOperationId -Error $_.Exception.Message
            Complete-ProgressOperation -OperationId $progressOperationId -ShowSummary
        }

        Write-CustomLog -Message "❌ Lab automation failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-ParallelRunnerSupport {
    <#
    .SYNOPSIS
        Tests whether the current environment supports parallel execution

    .DESCRIPTION
        Validates if the current PowerShell environment has the necessary components
        for parallel execution, including ThreadJob module and runspace support

    .PARAMETER Detailed
        Return detailed information about parallel execution capabilities

    .EXAMPLE
        Test-ParallelRunnerSupport

    .EXAMPLE
        Test-ParallelRunnerSupport -Detailed
    #>
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )

    $result = @{
        Supported = $false
        PowerShellVersion = $PSVersionTable.PSVersion
        ThreadJobAvailable = $false
        RunspaceSupport = $false
        MaxConcurrency = 1
        Platform = Get-Platform
        Details = @()
    }

    try {
        # Check PowerShell version (7.0+ recommended for best performance)
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $result.Details += "PowerShell 7+ detected - optimal parallel support"
        } elseif ($PSVersionTable.PSVersion.Major -ge 5) {
            $result.Details += "PowerShell 5+ detected - basic parallel support"
        } else {
            $result.Details += "PowerShell version too old for reliable parallel execution"
            if ($Detailed) { return $result }
        }

        # Check ThreadJob module availability
        try {
            Import-Module ThreadJob -Force -ErrorAction Stop
            $result.ThreadJobAvailable = $true
            $result.Details += "ThreadJob module available"
        } catch {
            try {
                # Try to install ThreadJob if not available
                Install-Module ThreadJob -Force -Scope CurrentUser -ErrorAction Stop
                Import-Module ThreadJob -Force -ErrorAction Stop
                $result.ThreadJobAvailable = $true
                $result.Details += "ThreadJob module installed and loaded"
            } catch {
                $result.Details += "ThreadJob module not available and could not be installed"
                if ($Detailed) { return $result }
            }
        }

        # Test runspace creation
        try {
            $testRunspace = [powershell]::Create()
            $testRunspace.AddScript({ 1 + 1 }) | Out-Null
            $testResult = $testRunspace.Invoke()
            $testRunspace.Dispose()

            if ($testResult -eq 2) {
                $result.RunspaceSupport = $true
                $result.Details += "Runspace creation and execution successful"
            }
        } catch {
            $result.Details += "Runspace creation failed: $($_.Exception.Message)"
            if ($Detailed) { return $result }
        }

        # Determine maximum concurrency
        $processorCount = [Environment]::ProcessorCount
        $availableMemory = if ($IsWindows) {
            try {
                (Get-CimInstance -ClassName Win32_OperatingSystem).TotalVisibleMemorySize / 1MB
            } catch { 4 }  # Default fallback
        } else {
            try {
                # Linux/macOS memory detection
                if (Test-Path '/proc/meminfo') {
                    $memInfo = Get-Content '/proc/meminfo' | Where-Object { $_ -match '^MemTotal:' }
                    if ($memInfo -match '(\d+)') {
                        [int]($matches[1]) / 1024 / 1024  # Convert KB to GB
                    } else { 4 }
                } else { 4 }
            } catch { 4 }
        }

        # Calculate optimal concurrency (conservative approach)
        $memoryBasedLimit = [Math]::Max(1, [Math]::Floor($availableMemory / 0.5))  # 512MB per thread
        $result.MaxConcurrency = [Math]::Min($processorCount * 2, $memoryBasedLimit)
        $result.Details += "Optimal concurrency: $($result.MaxConcurrency) (CPU: $processorCount, Memory: ${availableMemory}GB)"

        # Final determination
        $result.Supported = $result.ThreadJobAvailable -and $result.RunspaceSupport

        if ($result.Supported) {
            $result.Details += "Parallel execution fully supported"
            Write-CustomLog -Message "✅ Parallel execution support validated successfully" -Level "INFO"
        } else {
            $result.Details += "Parallel execution not supported - falling back to sequential"
            Write-CustomLog -Message "⚠️ Parallel execution not available - using sequential execution" -Level "WARN"
        }

    } catch {
        $result.Details += "Error during parallel support test: $($_.Exception.Message)"
        Write-CustomLog -Message "❌ Failed to test parallel support: $($_.Exception.Message)" -Level "ERROR"
    }

    if ($Detailed) {
        return $result
    } else {
        return $result.Supported
    }
}

function Get-LabStatus {
    <#
    .SYNOPSIS
        Gets the current status of lab automation

    .DESCRIPTION
        Compatibility function for retrieving lab automation status

    .PARAMETER Detailed
        Whether to return detailed status information
    #>
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )

    Write-CustomLog -Message "📊 Retrieving lab automation status" -Level "INFO"

    try {
        $status = @{
            Timestamp = Get-Date
            Platform = Get-Platform
            ConfigurationLoaded = $null -ne (Get-LabConfig -ErrorAction SilentlyContinue)
            ParallelSupport = Test-ParallelRunnerSupport
        }

        if ($Detailed) {
            $config = Get-LabConfig -ErrorAction SilentlyContinue
            $status.Configuration = $config
            $status.AvailableSteps = if ($config) { $config.Keys } else { @() }
            $status.ParallelSupportDetails = Test-ParallelRunnerSupport -Detailed
        }

        return $status
    } catch {
        Write-CustomLog -Message "❌ Failed to get lab status: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Start-EnhancedLabDeployment {
    <#
    .SYNOPSIS
        Start enhanced lab deployment with comprehensive progress tracking and OpenTofu integration

    .DESCRIPTION
        Provides a comprehensive lab deployment experience with visual progress tracking,
        time estimates, resource monitoring, and integration with OpenTofu infrastructure
        deployment stages.

    .PARAMETER ConfigurationPath
        Path to the lab deployment configuration file

    .PARAMETER ShowProgress
        Enable enhanced progress tracking with visual indicators

    .PARAMETER ProgressStyle
        Style of progress display: Bar, Spinner, Percentage, or Detailed

    .PARAMETER DryRun
        Perform planning and validation without applying changes

    .PARAMETER MaxRetries
        Maximum retry attempts for failed operations

    .PARAMETER Force
        Continue deployment even with warnings

    .PARAMETER Stage
        Run specific deployment stage only

    .EXAMPLE
        Start-EnhancedLabDeployment -ConfigurationPath "./lab-config.yaml" -ShowProgress -ProgressStyle Detailed

    .EXAMPLE
        Start-EnhancedLabDeployment -ConfigurationPath "./lab-config.yaml" -DryRun -ShowProgress
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$ConfigurationPath,

        [switch]$ShowProgress,

        [ValidateSet('Bar', 'Spinner', 'Percentage', 'Detailed')]
        [string]$ProgressStyle = 'Detailed',

        [switch]$DryRun,

        [ValidateRange(0, 5)]
        [int]$MaxRetries = 2,

        [switch]$Force,

        [ValidateSet('Prepare', 'Validate', 'Plan', 'Apply', 'Verify')]
        [string]$Stage
    )

    Write-CustomLog -Level 'INFO' -Message "Starting enhanced lab deployment from: $ConfigurationPath"

    # Initialize progress tracking if available and requested
    $progressOperationId = $null
    $useProgressTracking = $ShowProgress -and $script:progressTrackingImported

    if ($useProgressTracking) {
        try {
            $totalSteps = if ($Stage) { 1 } else { 7 }  # Prepare, Validate, Plan, Apply, Verify, Cleanup, Summary
            $progressOperationId = Start-ProgressOperation -OperationName "Enhanced Lab Deployment" -TotalSteps $totalSteps -ShowTime -ShowETA -Style $ProgressStyle
            Write-ProgressLog -Message "Initialized progress tracking for enhanced lab deployment" -Level 'Info'
        } catch {
            Write-CustomLog -Message "Warning: Could not initialize progress tracking: $($_.Exception.Message)" -Level "WARN"
            $useProgressTracking = $false
        }
    }

    try {
        $deploymentResult = @{
            Success = $false
            ConfigurationPath = $ConfigurationPath
            StartTime = Get-Date
            EndTime = $null
            Duration = $null
            Stage = $Stage
            DryRun = $DryRun.IsPresent
            ProgressTracking = $useProgressTracking
            Stages = @{}
            Resources = @{}
            Warnings = @()
            Errors = @()
        }

        # Step 1: Load and validate configuration
        if ($useProgressTracking) {
            Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 1 -StepName "Loading lab configuration"
        }

        Write-CustomLog -Level 'INFO' -Message "Loading lab configuration from: $ConfigurationPath"
        $config = Get-LabConfig -Path $ConfigurationPath

        if (-not $config) {
            $errorMsg = "Failed to load lab configuration from: $ConfigurationPath"
            if ($useProgressTracking) {
                Add-ProgressError -OperationId $progressOperationId -Error $errorMsg
            }
            throw $errorMsg
        }

        # Step 2: Check for OpenTofu integration
        if ($useProgressTracking) {
            Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 2 -StepName "Checking infrastructure deployment capabilities"
        }

        $hasOpenTofuProvider = Get-Module -Name 'OpenTofuProvider' -ListAvailable -ErrorAction SilentlyContinue
        $hasInfrastructureConfig = $config.infrastructure -or $config.opentofu -or $config.terraform

        if ($hasOpenTofuProvider -and $hasInfrastructureConfig) {
            Write-CustomLog -Level 'INFO' -Message "OpenTofu infrastructure deployment detected"

            # Step 3: Use OpenTofu deployment with progress tracking
            if ($useProgressTracking) {
                Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 3 -StepName "Starting OpenTofu infrastructure deployment"
            }

            # Import OpenTofu provider
            Import-Module (Join-Path $script:ProjectRoot "aither-core/modules/OpenTofuProvider") -Force

            # Call OpenTofu deployment function
            $infraResult = Start-InfrastructureDeployment -ConfigurationPath $ConfigurationPath -DryRun:$DryRun -Stage $Stage -MaxRetries $MaxRetries -Force:$Force

            if ($infraResult.Success) {
                $deploymentResult.Success = $true
                $deploymentResult.Stages = $infraResult.Stages
                $deploymentResult.Resources = $infraResult.Resources
                $deploymentResult.Warnings = $infraResult.Warnings
                $deploymentResult.Errors = $infraResult.Errors

                if ($useProgressTracking) {
                    Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 6 -StepName "Infrastructure deployment completed successfully"
                    Write-ProgressLog -Message "OpenTofu deployment completed successfully" -Level 'Success'
                }
            } else {
                $deploymentResult.Errors = $infraResult.Errors
                $deploymentResult.Warnings = $infraResult.Warnings

                if ($useProgressTracking) {
                    Add-ProgressError -OperationId $progressOperationId -Error "Infrastructure deployment failed"
                    Write-ProgressLog -Message "OpenTofu deployment failed" -Level 'Error'
                }

                if (-not $Force) {
                    throw "Infrastructure deployment failed: $($infraResult.Errors -join '; ')"
                }
            }
        } else {
            Write-CustomLog -Level 'INFO' -Message "Using standard lab automation workflow"

            # Step 3-5: Use standard lab automation with progress tracking
            if ($useProgressTracking) {
                Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 3 -StepName "Starting standard lab automation"
            }

            $labResult = Start-LabAutomation -Configuration $config -ShowProgress:$ShowProgress -ProgressStyle $ProgressStyle

            if ($labResult.Status -eq 'Success') {
                $deploymentResult.Success = $true

                if ($useProgressTracking) {
                    Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 5 -StepName "Lab automation completed successfully"
                    Write-ProgressLog -Message "Standard lab automation completed successfully" -Level 'Success'
                }
            } else {
                if ($useProgressTracking) {
                    Add-ProgressError -OperationId $progressOperationId -Error "Lab automation failed"
                    Write-ProgressLog -Message "Standard lab automation failed" -Level 'Error'
                }

                if (-not $Force) {
                    throw "Lab automation failed"
                }
            }
        }

        # Step 6: Final validation and cleanup
        if ($useProgressTracking) {
            Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 6 -StepName "Performing final validation"
        }

        # Perform final health checks
        $healthCheck = Test-LabDeploymentHealth -Config $config
        if (-not $healthCheck.Success) {
            $deploymentResult.Warnings += "Health check warnings: $($healthCheck.Warnings -join '; ')"

            if ($useProgressTracking) {
                Add-ProgressWarning -OperationId $progressOperationId -Warning "Deployment health check warnings detected"
            }
        }

        # Step 7: Generate summary
        if ($useProgressTracking) {
            Update-ProgressOperation -OperationId $progressOperationId -CurrentStep 7 -StepName "Generating deployment summary"
        }

        $deploymentResult.EndTime = Get-Date
        $deploymentResult.Duration = $deploymentResult.EndTime - $deploymentResult.StartTime

        # Complete progress tracking
        if ($useProgressTracking) {
            Complete-ProgressOperation -OperationId $progressOperationId -ShowSummary
        }

        # Generate comprehensive summary
        Write-EnhancedDeploymentSummary -Result $deploymentResult

        Write-CustomLog -Level 'SUCCESS' -Message "Enhanced lab deployment completed successfully"

        return [PSCustomObject]$deploymentResult

    } catch {
        # Handle errors and complete progress tracking
        if ($useProgressTracking -and $progressOperationId) {
            Add-ProgressError -OperationId $progressOperationId -Error $_.Exception.Message
            Complete-ProgressOperation -OperationId $progressOperationId -ShowSummary
        }

        $deploymentResult.Success = $false
        $deploymentResult.EndTime = Get-Date
        $deploymentResult.Duration = $deploymentResult.EndTime - $deploymentResult.StartTime
        $deploymentResult.Errors += $_.Exception.Message

        Write-CustomLog -Level 'ERROR' -Message "Enhanced lab deployment failed: $($_.Exception.Message)"

        # Still return result for analysis
        return [PSCustomObject]$deploymentResult
    }
}

function Test-LabDeploymentHealth {
    <#
    .SYNOPSIS
        Perform health checks on lab deployment
    #>
    param([object]$Config)

    $result = @{
        Success = $true
        Warnings = @()
        Checks = @{}
    }

    try {
        # Basic connectivity check
        if ($Config.network -and $Config.network.gateway) {
            $pingResult = Test-Connection -ComputerName $Config.network.gateway -Count 1 -Quiet -ErrorAction SilentlyContinue
            $result.Checks['NetworkConnectivity'] = $pingResult

            if (-not $pingResult) {
                $result.Warnings += "Network gateway not reachable: $($Config.network.gateway)"
            }
        }

        # Check for required services
        if ($Config.services) {
            foreach ($service in $Config.services) {
                $serviceStatus = Get-Service -Name $service -ErrorAction SilentlyContinue
                $result.Checks["Service_$service"] = $serviceStatus -and $serviceStatus.Status -eq 'Running'

                if (-not $result.Checks["Service_$service"]) {
                    $result.Warnings += "Service not running: $service"
                }
            }
        }

        # Check disk space
        $diskSpace = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -lt 1GB }
        if ($diskSpace) {
            $result.Warnings += "Low disk space detected on: $($diskSpace.Name -join ', ')"
        }

        return $result

    } catch {
        $result.Success = $false
        $result.Warnings += "Health check failed: $($_.Exception.Message)"
        return $result
    }
}

function Write-EnhancedDeploymentSummary {
    <#
    .SYNOPSIS
        Write comprehensive deployment summary
    #>
    param([PSCustomObject]$Result)

    Write-Host "`n$('='*70)" -ForegroundColor Cyan
    Write-Host "ENHANCED LAB DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "$('='*70)" -ForegroundColor Cyan

    Write-Host "Configuration: $($Result.ConfigurationPath)"
    Write-Host "Duration: $([Math]::Round($Result.Duration.TotalMinutes, 2)) minutes"
    Write-Host "Status: $(if ($Result.Success) { 'SUCCESS' } else { 'FAILED' })" -ForegroundColor $(if ($Result.Success) { 'Green' } else { 'Red' })
    Write-Host "Progress Tracking: $(if ($Result.ProgressTracking) { 'ENABLED' } else { 'DISABLED' })"

    if ($Result.DryRun) {
        Write-Host "Mode: DRY RUN" -ForegroundColor Yellow
    }

    if ($Result.Stage) {
        Write-Host "Stage: $($Result.Stage)" -ForegroundColor Yellow
    }

    if ($Result.Stages.Count -gt 0) {
        Write-Host "`nDeployment Stages:" -ForegroundColor Yellow
        foreach ($stage in $Result.Stages.Keys) {
            $stageResult = $Result.Stages[$stage]
            $status = if ($stageResult.Success) { "✓" } else { "✗" }
            $color = if ($stageResult.Success) { "Green" } else { "Red" }
            $duration = if ($stageResult.Duration) { " ($([Math]::Round($stageResult.Duration.TotalSeconds, 1))s)" } else { "" }
            Write-Host "  $status $stage$duration" -ForegroundColor $color
        }
    }

    if ($Result.Resources.Count -gt 0) {
        Write-Host "`nDeployed Resources:" -ForegroundColor Green
        foreach ($resourceType in $Result.Resources.Keys) {
            $resource = $Result.Resources[$resourceType]
            Write-Host "  ${resourceType}: $($resource.Count)" -ForegroundColor White
        }
    }

    if ($Result.Warnings.Count -gt 0) {
        Write-Host "`nWarnings:" -ForegroundColor Yellow
        foreach ($warning in $Result.Warnings) {
            Write-Host "  ⚠️ $warning" -ForegroundColor Yellow
        }
    }

    if ($Result.Errors.Count -gt 0) {
        Write-Host "`nErrors:" -ForegroundColor Red
        foreach ($error in $Result.Errors) {
            Write-Host "  ❌ $error" -ForegroundColor Red
        }
    }

    Write-Host "`n$('='*70)`n" -ForegroundColor Cyan
}

# Import nested module for additional functions if available
try {
    Import-Module (Join-Path $PSScriptRoot 'Resolve-ProjectPath.psm1') -Force -ErrorAction Stop
} catch {
    Write-Verbose "Failed to import Resolve-ProjectPath.psm1: $_"
}

# Import all public functions if they exist (temporarily disabled for debugging)
# Import public functions
$publicFunctionsPath = Join-Path $PSScriptRoot "Public"
if (Test-Path $publicFunctionsPath) {
    Get-ChildItem -Path "$publicFunctionsPath/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            . $_.FullName
        } catch {
            Write-Warning "Failed to import $($_.Name): $_"
        }
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-CrossPlatformTempPath',
    'Invoke-CrossPlatformCommand',
    'Invoke-LabStep',
    'Invoke-LabDownload',
    'Read-LoggedInput',
    'Invoke-LabWebRequest',
    'Invoke-LabNpm',
    'Resolve-ProjectPath',
    'Get-LabConfig',
    'Format-Config',
    'Expand-All',
    'Get-MenuSelection',
    'Get-GhDownloadArgs',
    'Invoke-ArchiveDownload',
    'Get-Platform',
    'Invoke-OpenTofuInstaller',
    'Invoke-ParallelLabRunner',
    'Test-ParallelRunnerSupport',
    'Start-LabAutomation',
    'Get-LabStatus',
    'Start-EnhancedLabDeployment',
    'Start-AdvancedLabOrchestration'
)
