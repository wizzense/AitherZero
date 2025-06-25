#Requires -Version 7.0

# BackupManager Module - Core module file
# Comprehensive backup management for OpenTofu Lab Automation

# Import the centralized Logging module
$loggingImported = $false

# Check if Logging module is already available
if (Get-Module -Name 'Logging' -ErrorAction SilentlyContinue) {
    $loggingImported = $true
    Write-Verbose 'Logging module already available'
} else {
    $loggingPaths = @(
        'Logging' # Try module name first (if in PSModulePath)
        (Join-Path (Split-Path $PSScriptRoot -Parent) 'Logging') # Relative to modules directory
    )
    
    # Add environment paths only if they exist
    if ($env:PWSH_MODULES_PATH) {
        $loggingPaths += (Join-Path $env:PWSH_MODULES_PATH 'Logging')
    }
    if ($env:PROJECT_ROOT) {
        $loggingPaths += (Join-Path $env:PROJECT_ROOT 'aither-core/modules/Logging')
    }

    foreach ($loggingPath in $loggingPaths) {
        if ($loggingImported) { break }

        try {
            if ($loggingPath -eq 'Logging') {
                Import-Module 'Logging' -Global -ErrorAction Stop
            } elseif (Test-Path $loggingPath) {
                Import-Module $loggingPath -Global -ErrorAction Stop
            } else {
                Write-Verbose "Path does not exist: $loggingPath"
                continue
            }
            Write-Verbose "Successfully imported Logging module from: $loggingPath"
            $loggingImported = $true
        } catch {
            Write-Verbose "Failed to import Logging from $loggingPath : $($_.Exception.Message)"
        }
    }
}

if (-not $loggingImported) {
    Write-Warning 'Could not import Logging module from any of the attempted paths'
}

# Import LabRunner for additional utilities
$LabRunnerPath = Join-Path $PSScriptRoot '..' 'LabRunner'
if (Test-Path $LabRunnerPath) {
    Import-Module $LabRunnerPath -Force -ErrorAction SilentlyContinue
}

# Module-level variables
$script:BackupRootPath = 'backups/consolidated-backups'
$script:ArchivePath = 'archive'
$script:MaxBackupAge = 30 # days
$script:BackupExclusions = @(
    '*.tmp', '*.log', '*.cache', '*.lock',
    '.git/*', 'node_modules/*', '.vscode/*',
    'backups/consolidated-backups/*',
    'coverage/*', 'TestResults*'
)

# Import all public functions
$PublicPath = Join-Path $PSScriptRoot 'Public'
$PrivatePath = Join-Path $PSScriptRoot 'Private'

$PublicFunctions = @()
$PrivateFunctions = @()

if (Test-Path $PublicPath) {
    $PublicFunctions = @(Get-ChildItem -Path "$PublicPath\*.ps1" -ErrorAction SilentlyContinue)
}

if (Test-Path $PrivatePath) {
    $PrivateFunctions = @(Get-ChildItem -Path "$PrivatePath\*.ps1" -ErrorAction SilentlyContinue)
}

Write-Verbose "Found $($PublicFunctions.Count) public functions to import"

# Dot source the files
foreach ($Function in @($PublicFunctions + $PrivateFunctions)) {
    try {
        Write-Verbose "Importing function from $($Function.FullName)"
        . $Function.FullName
    } catch {
        Write-Error "Failed to import function $($Function.FullName): $_"
    }
}

# Export public functions
if ($PublicFunctions.Count -gt 0) {
    $FunctionNames = $PublicFunctions.BaseName
    Write-Verbose "Exporting functions: $($FunctionNames -join ', ')"
    Export-ModuleMember -Function $FunctionNames
} else {
    Write-Warning 'No public functions found to export'
}

# Module cleanup
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    # Cleanup code here if needed
}
