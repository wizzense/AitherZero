# AitherZero Intelligent Setup Wizard Module
# Provides enhanced first-time setup experience with progress tracking

#Requires -Version 7.0

# Load shared utilities
$moduleRoot = $PSScriptRoot
if (-not $moduleRoot) {
    $moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Load shared utilities
. (Join-Path $PSScriptRoot ".." ".." "shared" "Find-ProjectRoot.ps1")

# Load all private functions first
$privateFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded private function: $($function.BaseName)"
    } catch {
        Write-Warning "Failed to load private function $($function.BaseName): $_"
    }
}

# Load all public functions
$publicFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded public function: $($function.BaseName)"
    } catch {
        Write-Warning "Failed to load public function $($function.BaseName): $_"
    }
}

# Module initialization message
Write-Verbose "SetupWizard module loaded successfully from $moduleRoot"

# Export public functions (already handled in individual function files)
if ($publicFunctions.Count -gt 0) {
    Export-ModuleMember -Function $publicFunctions.BaseName
}