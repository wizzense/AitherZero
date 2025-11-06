# Initialize ExampleExtension
Write-Verbose "Initializing ExampleExtension..."

# Create data directory if needed
$dataPath = Join-Path $PSScriptRoot "data"
if (-not (Test-Path $dataPath)) {
    New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
}

Write-Verbose "ExampleExtension initialized"
