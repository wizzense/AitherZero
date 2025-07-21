Import-Module platyPS -ErrorAction SilentlyContinue

# Function to find the project root
function Get-ProjectRoot {
    $currentDir = Get-Location
    while ($currentDir -and $currentDir.Path -ne $currentDir.Drive.Name) {
        if (Test-Path (Join-Path $currentDir.Path "aither-core")) {
            return $currentDir.Path
        }
        $currentDir = Split-Path -Parent -Path $currentDir.Path
    }
    throw "Could not find project root"
}

$ProjectRoot = Get-ProjectRoot

# Define the parent directory where the domain modules are located
$ModuleParentDir = Join-Path $ProjectRoot "aither-core/domains"

# Set the output path for the documentation
$OutputPath = Join-Path $ProjectRoot "docs/api/infrastructure"

# Add the module parent directory to the PSModulePath
$env:PSModulePath = "$ModuleParentDir;$($env:PSModulePath)"

# Ensure the output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

# Import the module by name
Import-Module Infrastructure -Force

# Generate the documentation
New-MarkdownHelp -Module Infrastructure -OutputFolder $OutputPath -Force

Write-Host "Documentation for Infrastructure module generated successfully at $OutputPath"
