#Requires -Version 7.0

# Import the centralized Logging module using multiple fallback paths
$loggingImported = $false

# Check if Logging module is already available
if (Get-Module -Name 'Logging' -ErrorAction SilentlyContinue) {
    $loggingImported = $true
    Write-Verbose "Logging module already available"
} else {
    # Set up environment variables if not already set
    if (-not $env:PROJECT_ROOT) {
        $env:PROJECT_ROOT = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
    }
    if (-not $env:PWSH_MODULES_PATH) {
        $env:PWSH_MODULES_PATH = (Get-Item $PSScriptRoot).Parent.FullName
    }

    $loggingPaths = @(
        'Logging',  # Try module name first (if in PSModulePath)
        (Join-Path (Split-Path $PSScriptRoot -Parent) "Logging"),  # Relative to modules directory
        (Join-Path $env:PWSH_MODULES_PATH "Logging"),  # Environment path
        (Join-Path $env:PROJECT_ROOT "core-runner/modules/Logging")  # Full project path
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
    Write-Warning "Could not import Logging module from any of the attempted paths. Using fallback Write-Host."
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

# Export only the 4 core functions 
Export-ModuleMember -Function @(
    'Invoke-PatchWorkflow',
    'New-PatchIssue', 
    'New-PatchPR',
    'Invoke-PatchRollback'
)

Write-Verbose "Module loading complete. Exported all public functions."
