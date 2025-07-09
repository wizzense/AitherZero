# OpenTofuProvider Module
# Infrastructure Abstraction Layer for OpenTofu/Terraform deployments

# Import required modules
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Write-CustomLog is guaranteed to be available from AitherCore orchestration
# No explicit Logging import needed - trust the orchestration system

# Dot source all function files
Write-Verbose "Loading OpenTofuProvider functions..."

try {
    # Load Private functions first
    $privatePath = Join-Path $PSScriptRoot "Private"
    if (Test-Path $privatePath) {
        $privateFiles = Get-ChildItem -Path $privatePath -Filter "*.ps1" -Recurse
        foreach ($file in $privateFiles) {
            Write-Verbose "Loading private function: $($file.Name)"
            . $file.FullName
        }
    }

    # Load Public functions
    $publicPath = Join-Path $PSScriptRoot "Public"
    if (Test-Path $publicPath) {
        $publicFiles = Get-ChildItem -Path $publicPath -Filter "*.ps1" -Recurse
        foreach ($file in $publicFiles) {
            Write-Verbose "Loading public function: $($file.Name)"
            . $file.FullName
        }
    }

    Write-Verbose "OpenTofuProvider functions loaded successfully"

} catch {
    Write-Error "Failed to load OpenTofuProvider functions: $($_.Exception.Message)"
    Write-Error "Error in file: $($_.InvocationInfo.ScriptName) at line $($_.InvocationInfo.ScriptLineNumber)"
    throw
}

# Export all public functions and helper functions that should be available
$publicFunctions = @()

# Add all functions loaded from public files
Get-ChildItem -Path (Join-Path $PSScriptRoot "Public") -Filter "*.ps1" -Recurse | ForEach-Object {
    $functionName = $_.BaseName
    if (Get-Command $functionName -ErrorAction SilentlyContinue) {
        Write-Verbose "Exporting public function: $functionName"
        $publicFunctions += $functionName
    }
}

# Add helper functions that should be publicly available
$helperFunctions = @('ConvertFrom-Yaml', 'ConvertTo-Yaml', 'Test-OpenTofuInstallation')
foreach ($helperFunction in $helperFunctions) {
    if (Get-Command $helperFunction -ErrorAction SilentlyContinue) {
        Write-Verbose "Exporting helper function: $helperFunction"
        $publicFunctions += $helperFunction
    }
}

if ($publicFunctions) {
    # Remove duplicates and export
    $uniqueFunctions = $publicFunctions | Sort-Object | Get-Unique
    Export-ModuleMember -Function $uniqueFunctions
    Write-CustomLog -Level 'INFO' -Message "OpenTofuProvider module v1.2.0 loaded - Exported $($uniqueFunctions.Count) unique functions"
    Write-Verbose "Exported functions: $($uniqueFunctions -join ', ')"
} else {
    Write-CustomLog -Level 'WARN' -Message "OpenTofuProvider module loaded but no functions were exported"
}

# Module initialization
Write-CustomLog -Level 'INFO' -Message "Infrastructure Abstraction Layer enabled"
