# OpenTofuProvider Module
# Infrastructure Abstraction Layer for OpenTofu/Terraform deployments

# Import required modules
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import Logging module
Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force

# Dot source all function files
$functionFolders = @('Public', 'Private')
foreach ($folder in $functionFolders) {
    $folderPath = Join-Path $PSScriptRoot $folder
    if (Test-Path $folderPath) {
        $files = Get-ChildItem -Path $folderPath -Include *.ps1 -Recurse
        foreach ($file in $files) {
            . $file.FullName
        }
    }
}

# Dot source new subdirectory functions
$subdirectories = @('Repository', 'Templates', 'Configuration', 'Deployment', 'ISO', 'RepositoryManagement', 'TemplateManagement', 'ConfigurationManagement', 'AdvancedFeatures')
foreach ($subdir in $subdirectories) {
    $subdirPath = Join-Path $PSScriptRoot "Public" $subdir
    if (Test-Path $subdirPath) {
        $files = Get-ChildItem -Path $subdirPath -Include *.ps1 -Recurse
        foreach ($file in $files) {
            . $file.FullName
        }
    }
}

# Module initialization
Write-CustomLog -Level 'INFO' -Message "OpenTofuProvider module v1.1.0 loaded - Infrastructure Abstraction Layer enabled"

# Export module members (handled by manifest)