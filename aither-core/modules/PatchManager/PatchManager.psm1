#Requires -Version 7.0

# Import the centralized Logging module using multiple fallback paths
$loggingImported = $false

# Check if Logging module is already available
if (Get-Module -Name 'Logging' -ErrorAction SilentlyContinue) {
    $loggingImported = $true
    Write-Verbose 'Logging module already available'
} else {
    # Set up environment variables if not already set
    if (-not $env:PROJECT_ROOT) {
        $env:PROJECT_ROOT = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
    }
    if (-not $env:PWSH_MODULES_PATH) {
        $env:PWSH_MODULES_PATH = (Get-Item $PSScriptRoot).Parent.FullName
    }

    $loggingPaths = @(
        'Logging', # Try module name first (if in PSModulePath)
        (Join-Path (Split-Path $PSScriptRoot -Parent) 'Logging'), # Relative to modules directory
        (Join-Path $env:PWSH_MODULES_PATH 'Logging'), # Environment path
        (Join-Path $env:PROJECT_ROOT 'aither-core/modules/Logging')  # Full project path (updated for aither-core)
    )

    foreach ($loggingPath in $loggingPaths) {
        if ($loggingImported) { break }

        try {
            if ($loggingPath -eq 'Logging') {
                Import-Module 'Logging' -Global -ErrorAction Stop
            } elseif ($loggingPath -and (Test-Path $loggingPath)) {
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
    Write-Warning 'Could not import Logging module from any of the attempted paths. Using fallback Write-Host.'
    # Create a fallback Write-CustomLog function
    function Write-CustomLog {
        param([string]$Message, [string]$Level = 'INFO')
        Write-Host "[$Level] $Message"
    }
}

# Import all public functions
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)

# Import all private functions
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

Write-Verbose "Found $($Public.Count) public functions and $($Private.Count) private functions"

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
        Write-Verbose "Successfully imported: $($import.Name)"
    } catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
        throw
    }
}

# Initialize cross-platform environment
try {
    # Initialize cross-platform environment when module is loaded
    $envResult = Initialize-CrossPlatformEnvironment
    if ($envResult.Success) {
        Write-Verbose "Cross-platform environment initialized successfully: $($envResult.Platform)"
        Write-Verbose "PROJECT_ROOT: $env:PROJECT_ROOT"
        Write-Verbose "PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH"
    } else {
        Write-Warning "Failed to initialize cross-platform environment: $($envResult.Error)"
    }
} catch {
    Write-Warning "Error initializing cross-platform environment: $_"
}

# Load Private Functions
$privateFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded private function: $($function.BaseName)"
    } catch {
        Write-Warning "Failed to load private function $($function.Name): $_"
    }
}

# Load Public Functions
$publicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded public function: $($function.BaseName)"
    } catch {
        Write-Warning "Failed to load public function $($function.Name): $_"
    }
}

# Intelligence Functions - Add near the top of the file after imports
function Test-ShouldCreatePR {
    [CmdletBinding()]
    param(
        [string]$PatchDescription,
        [bool]$Force = $false
    )

    if ($Force) {
        return $true
    }

    # Check if this is a minor change that doesn't need PR review
    $minorChangePatterns = @(
        'typo', 'formatting', 'whitespace', 'comment', 'documentation update',
        'log message', 'minor fix', 'cleanup', 'lint fix', 'style fix'
    )

    foreach ($pattern in $minorChangePatterns) {
        if ($PatchDescription -like "*$pattern*") {
            Write-CustomLog -Level 'INFO' -Message "Minor change detected, skipping PR creation: $pattern"
            return $false
        }
    }

    # Check if there are recent similar PRs
    try {
        $recentPRs = gh pr list --state open --limit 10 --json title, headRefName 2>$null | ConvertFrom-Json
        $similarPRs = $recentPRs | Where-Object {
            $_.title -like "*$($PatchDescription.Split(' ')[0..2] -join ' ')*" -or
            $_.headRefName -like "*$($BranchName.Split('-')[-1])*"
        }

        if ($similarPRs) {
            Write-CustomLog -Level 'WARN' -Message "Similar PR already exists, skipping: $($similarPRs[0].title)"
            return $false
        }
    } catch {
        Write-CustomLog -Level 'WARN' -Message "Could not check for similar PRs: $($_.Exception.Message)"
    }

    return $true
}

function Test-ShouldCreateIssue {
    [CmdletBinding()]
    param(
        [string]$PatchDescription,
        [bool]$Force = $false
    )

    if ($Force) {
        return $true
    }

    # Skip issues for very minor changes
    $skipIssuePatterns = @(
        '*typo*', '*formatting*', '*whitespace*', '*indent*',
        '*quick fix*', '*minor*', '*trivial*'
    )

    $lowerDescription = $PatchDescription.ToLower()

    foreach ($pattern in $skipIssuePatterns) {
        if ($lowerDescription -like $pattern) {
            Write-CustomLog -Level 'INFO' -Message "🧠 Skipping issue for pattern: $pattern"
            return $false
        }
    }

    return $true
}

function Invoke-PatchWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PatchDescription,

        [Parameter(Mandatory)]
        [scriptblock]$PatchOperation,

        [string[]]$TestCommands = @(),

        [switch]$CreatePR,

        [bool]$CreateIssue = $true, # Default to true but make smarter

        [ValidateSet('Low', 'Medium', 'High', 'Critical')]
        [string]$Priority = 'Medium',

        [switch]$DryRun,

        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message '🚀 Starting PatchWorkflow v2.1 (Enhanced Intelligence)'

        # Enhanced intelligence: Check if we should create PR/Issue based on content
        if (-not $Force) {
            $shouldCreatePR = Test-ShouldCreatePR -PatchDescription $PatchDescription -Force:$CreatePR
            if ($CreatePR -and -not $shouldCreatePR) {
                Write-CustomLog -Level 'INFO' -Message '🧠 Intelligent PR detection: Skipping PR for minor change'
                $CreatePR = $false
            }

            # Also check if we should create an issue
            $shouldCreateIssue = Test-ShouldCreateIssue -PatchDescription $PatchDescription -Force:$CreateIssue
            if ($CreateIssue -and -not $shouldCreateIssue) {
                Write-CustomLog -Level 'INFO' -Message '🧠 Intelligent issue detection: Skipping issue for trivial change'
                $CreateIssue = $false
            }
        }

        # Log what will be created
        $actions = @()
        if ($CreateIssue) { $actions += 'Issue' }
        if ($CreatePR) { $actions += 'PR' }
        if ($actions.Count -eq 0) { $actions += 'Local commit only' }

        Write-CustomLog -Level 'INFO' -Message "📋 Will create: $($actions -join ', ')"
    }

    process {
        try {
            # Use the core Invoke-GitControlledPatch function with intelligent decisions
            $result = Invoke-GitControlledPatch -PatchDescription $PatchDescription -PatchOperation $PatchOperation -TestCommands $TestCommands -CreatePR:$CreatePR -CreateIssue:$CreateIssue -Priority $Priority -DryRun:$DryRun

            return $result

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Enhanced PatchWorkflow failed: $($_.Exception.Message)"
            throw
        }
    }
}
