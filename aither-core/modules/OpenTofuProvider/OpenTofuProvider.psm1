#Requires -Version 7.0

# Import logging module
Import-Module "$PSScriptRoot/../Logging" -Force

# Import classes
$classFiles = Get-ChildItem "$PSScriptRoot/Classes" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $classFiles) {
    . $file.FullName
}

# Import private functions
$privateFiles = Get-ChildItem "$PSScriptRoot/Private" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $privateFiles) {
    . $file.FullName
}

# Import public functions
$publicFiles = Get-ChildItem "$PSScriptRoot/Public" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $publicFiles) {
    . $file.FullName
}

# Module initialization
Write-CustomLog -Level 'INFO' -Message 'OpenTofuProvider module loaded successfully'

# Export public functions
Export-ModuleMember -Function @(
    'Install-OpenTofuSecure',
    'Initialize-OpenTofuProvider',
    'Test-OpenTofuSecurity',
    'New-LabInfrastructure',
    'Get-TaliesinsProviderConfig',
    'Set-SecureCredentials',
    'Test-InfrastructureCompliance',
    'Export-LabTemplate',
    'Import-LabConfiguration'
)
