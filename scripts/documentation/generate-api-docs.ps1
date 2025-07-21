# Generate API Documentation for AitherZero Domains
# This script generates markdown documentation from PowerShell function comments

param(
    [ValidateSet('Infrastructure', 'Security', 'Configuration', 'Utilities', 'Experience', 'Automation', 'All')]
    [string]$Domain = 'All',
    [string]$OutputPath = $null
)

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

# Initialize logging
. (Join-Path $ProjectRoot "aither-core/shared/Initialize-Logging.ps1")

# Define the domains directory
$DomainsDir = Join-Path $ProjectRoot "aither-core/domains"

# Set default output path if not provided
if (-not $OutputPath) {
    $OutputPath = Join-Path $ProjectRoot "docs/api"
}

# Function to generate docs for a single domain
function Generate-DomainDocs {
    param(
        [string]$DomainName,
        [string]$DomainScriptPath,
        [string]$OutputDir
    )
    
    Write-CustomLog -Level 'INFO' -Message "Generating documentation for $DomainName domain..."
    
    # Ensure output directory exists
    $domainOutputPath = Join-Path $OutputDir $DomainName.ToLower()
    if (-not (Test-Path $domainOutputPath)) {
        New-Item -Path $domainOutputPath -ItemType Directory -Force | Out-Null
    }
    
    # Load the domain script
    . $DomainScriptPath
    
    # Get all functions from the domain by parsing the script
    $scriptContent = Get-Content $DomainScriptPath -Raw
    $functionPattern = 'function\s+([A-Za-z0-9-_]+)\s*\{'
    $functionNames = [regex]::Matches($scriptContent, $functionPattern) | ForEach-Object { $_.Groups[1].Value }
    
    $functions = @()
    foreach ($funcName in $functionNames) {
        if (Get-Command -Name $funcName -ErrorAction SilentlyContinue) {
            $functions += Get-Command -Name $funcName
        }
    }
    
    # Generate documentation for each function
    $docContent = @"
# $DomainName Domain API Documentation

This document provides API documentation for the $DomainName domain functions.

## Functions

"@
    
    foreach ($func in $functions) {
        $help = Get-Help $func.Name -Full -ErrorAction SilentlyContinue
        
        if ($help) {
            $docContent += @"

### $($func.Name)

**Synopsis:** $($help.Synopsis)

**Description:** $($help.Description.Text -join ' ')

**Parameters:**
"@
            
            foreach ($param in $help.Parameters.Parameter) {
                $docContent += @"

- **$($param.Name)** ($($param.Type.Name)): $($param.Description.Text -join ' ')
"@
            }
            
            if ($help.Examples.Example) {
                $docContent += @"

**Examples:**
"@
                foreach ($example in $help.Examples.Example) {
                    $docContent += @"

``````powershell
$($example.Code)
``````
$($example.Remarks.Text -join ' ')
"@
                }
            }
            
            $docContent += "`n---`n"
        }
    }
    
    # Write documentation file
    $docFilePath = Join-Path $domainOutputPath "README.md"
    Set-Content -Path $docFilePath -Value $docContent -Encoding UTF8
    
    Write-CustomLog -Level 'SUCCESS' -Message "Documentation generated for $DomainName at: $docFilePath"
}

# Main execution
try {
    if ($Domain -eq 'All') {
        # Generate docs for all domains
        $domainFiles = @{
            'Infrastructure' = Join-Path $DomainsDir "infrastructure/Infrastructure.ps1"
            'Security' = Join-Path $DomainsDir "security/Security.ps1"
            'Configuration' = Join-Path $DomainsDir "configuration/Configuration.ps1"
            'Utilities' = Join-Path $DomainsDir "utilities/Utilities.ps1"
            'Experience' = Join-Path $DomainsDir "experience/Experience.ps1"
            'Automation' = Join-Path $DomainsDir "automation/Automation.ps1"
        }
        
        foreach ($domainEntry in $domainFiles.GetEnumerator()) {
            if (Test-Path $domainEntry.Value) {
                Generate-DomainDocs -DomainName $domainEntry.Key -DomainScriptPath $domainEntry.Value -OutputDir $OutputPath
            } else {
                Write-CustomLog -Level 'WARNING' -Message "Domain file not found: $($domainEntry.Value)"
            }
        }
    } else {
        # Generate docs for specific domain
        $domainScriptPath = Join-Path $DomainsDir "$($Domain.ToLower())/$Domain.ps1"
        if (Test-Path $domainScriptPath) {
            Generate-DomainDocs -DomainName $Domain -DomainScriptPath $domainScriptPath -OutputDir $OutputPath
        } else {
            throw "Domain script not found: $domainScriptPath"
        }
    }
    
    Write-CustomLog -Level 'SUCCESS' -Message "API documentation generation completed successfully!"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Error generating documentation: $_"
    throw
}
