# Script to update Start-AitherZero.ps1 with new interactive mode integration

# Read the current launcher
$launcherPath = Join-Path $PSScriptRoot ".." ".." "Start-AitherZero.ps1"
$content = Get-Content $launcherPath -Raw

# Find the section where we handle default mode selection
$insertPoint = $content.IndexOf("# Handle default mode selection")

# Create the new code to insert
$newCode = @'

# Check for license and load StartupExperience module if available
$startupExperienceAvailable = $false
$licenseManagerAvailable = $false

try {
    if (Get-Module -Name "StartupExperience" -ListAvailable) {
        Import-Module StartupExperience -Force
        $startupExperienceAvailable = $true
    }
    if (Get-Module -Name "LicenseManager" -ListAvailable) {
        Import-Module LicenseManager -Force
        $licenseManagerAvailable = $true
    }
} catch {
    Write-Verbose "Could not load enhanced startup modules: $_"
}

# Handle license application if provided
if ($PSBoundParameters.ContainsKey('ApplyLicense')) {
    if ($licenseManagerAvailable) {
        Set-License -LicenseKey $ApplyLicense
        Write-Host ""
    } else {
        Write-Warning "License management not available. Please ensure all modules are loaded."
    }
}

# Determine startup mode
$useEnhancedStartup = $false
if ($Interactive -or (-not $Auto -and -not $Scripts)) {
    # Check if enhanced startup is available
    if ($startupExperienceAvailable) {
        $useEnhancedStartup = $true
    }
}

# If Quickstart flag is set, force interactive mode
if ($PSBoundParameters.ContainsKey('Quickstart')) {
    $Interactive = $true
    $useEnhancedStartup = $startupExperienceAvailable
}

'@

# Also need to add the ApplyLicense parameter
$paramInsertPoint = $content.IndexOf("[Parameter(HelpMessage = 'Installation profile for setup')]")
$licenseParam = @'

    [Parameter(HelpMessage = 'Apply a license key to unlock features')]
    [string]$ApplyLicense,

    [Parameter(HelpMessage = 'Quick start with interactive setup')]
    [switch]$Quickstart,

'@

# Create the modified content
$modifiedContent = $content.Substring(0, $paramInsertPoint) + $licenseParam + $content.Substring($paramInsertPoint)

# Insert the new startup code
$insertPoint2 = $modifiedContent.IndexOf("# Handle default mode selection")
$modifiedContent = $modifiedContent.Substring(0, $insertPoint2) + $newCode + $modifiedContent.Substring($insertPoint2)

# Modify the section that starts the core application
$coreStartPoint = $modifiedContent.IndexOf("# Start the core application")
$enhancedStartCode = @'

# Start the application based on mode
if ($useEnhancedStartup) {
    # Use enhanced interactive startup experience
    Write-Host 'Starting enhanced interactive mode...' -ForegroundColor Green
    Write-Host ''
    
    $startupParams = @{}
    if ($PSBoundParameters.ContainsKey('ConfigFile')) {
        # Extract profile name from config file
        $profileName = [System.IO.Path]::GetFileNameWithoutExtension($ConfigFile)
        $startupParams['Profile'] = $profileName
    }
    
    Start-InteractiveMode @startupParams
} else {
    # Use traditional core runner
    
'@

$modifiedContent = $modifiedContent.Replace("# Start the core application", $enhancedStartCode)

# Close the else block properly
$endPoint = $modifiedContent.IndexOf("exit $LASTEXITCODE")
$modifiedContent = $modifiedContent.Substring(0, $endPoint + 18) + "`n}" + $modifiedContent.Substring($endPoint + 18)

# Save to a new file for review
$outputPath = Join-Path $PSScriptRoot "Start-AitherZero-Enhanced.ps1"
$modifiedContent | Set-Content $outputPath -Encoding UTF8

Write-Host "Updated launcher saved to: $outputPath"
Write-Host "Review the changes and replace the original when ready."