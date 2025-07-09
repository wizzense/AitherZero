function New-VersionedTemplate {
    <#
    .SYNOPSIS
        Creates a new versioned infrastructure template.

    .DESCRIPTION
        Creates a new infrastructure template with semantic versioning support,
        dependency tracking, and metadata management.

    .PARAMETER Name
        Name of the template.

    .PARAMETER Version
        Semantic version (default: 1.0.0).

    .PARAMETER Path
        Path where template should be created.

    .PARAMETER Description
        Template description.

    .PARAMETER Provider
        Target infrastructure provider.

    .PARAMETER Dependencies
        Array of template dependencies with version constraints.

    .PARAMETER Parameters
        Template parameters definition.

    .PARAMETER Resources
        Resource definitions for the template.

    .PARAMETER FromExisting
        Create new version from existing template.

    .EXAMPLE
        New-VersionedTemplate -Name "web-server" -Path "./templates" -Provider "Hyper-V" -Description "Web server template"

    .OUTPUTS
        PSCustomObject with template details
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z0-9-_]+$')]
        [string]$Name,

        [Parameter()]
        [ValidatePattern('^\d+\.\d+\.\d+(-[a-zA-Z0-9-]+)?(\+[a-zA-Z0-9-]+)?$')]
        [string]$Version = "1.0.0",

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$Description = "Infrastructure template",

        [Parameter()]
        [ValidateSet('Hyper-V', 'Azure', 'AWS', 'VMware', 'Generic')]
        [string]$Provider = 'Generic',

        [Parameter()]
        [hashtable[]]$Dependencies,

        [Parameter()]
        [hashtable]$Parameters,

        [Parameter()]
        [hashtable[]]$Resources,

        [Parameter()]
        [string]$FromExisting
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating versioned template: $Name v$Version"
        $templatePath = Join-Path $Path $Name
        $versionPath = Join-Path $templatePath $Version
    }

    process {
        try {
            # Validate version doesn't already exist
            if ((Test-Path $versionPath) -and -not $FromExisting) {
                throw "Template version already exists: $Name v$Version"
            }

            if ($PSCmdlet.ShouldProcess("$Name v$Version", "Create versioned template")) {
                # Create directory structure
                $directories = @(
                    $templatePath
                    $versionPath
                    (Join-Path $versionPath "modules")
                    (Join-Path $versionPath "tests")
                    (Join-Path $versionPath "docs")
                )

                foreach ($dir in $directories) {
                    if (-not (Test-Path $dir)) {
                        New-Item -ItemType Directory -Path $dir -Force | Out-Null
                    }
                }

                # Handle creation from existing template
                if ($FromExisting) {
                    Write-CustomLog -Level 'INFO' -Message "Creating from existing template: $FromExisting"

                    $existingPath = if (Test-Path $FromExisting) {
                        $FromExisting
                    } else {
                        # Try to find in template path
                        $possiblePaths = @(
                            (Join-Path $Path $FromExisting)
                            (Join-Path $templatePath $FromExisting)
                        )
                        $found = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
                        if (-not $found) {
                            throw "Existing template not found: $FromExisting"
                        }
                        $found
                    }

                    # Copy existing template files
                    $filesToCopy = Get-ChildItem -Path $existingPath -File -Recurse |
                        Where-Object { $_.Name -notmatch '\.git|\.terraform|\.tfstate' }

                    foreach ($file in $filesToCopy) {
                        $relativePath = $file.FullName.Substring($existingPath.Length + 1)
                        $targetPath = Join-Path $versionPath $relativePath
                        $targetDir = Split-Path $targetPath -Parent

                        if (-not (Test-Path $targetDir)) {
                            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                        }

                        Copy-Item -Path $file.FullName -Destination $targetPath -Force
                    }

                    # Load existing metadata if available
                    $metadataPath = Join-Path $existingPath "template.json"
                    if (Test-Path $metadataPath) {
                        $existingMetadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
                        if (-not $Description -and $existingMetadata.description) {
                            $Description = $existingMetadata.description
                        }
                        if (-not $Parameters -and $existingMetadata.parameters) {
                            $Parameters = $existingMetadata.parameters
                        }
                        if (-not $Resources -and $existingMetadata.resources) {
                            $Resources = $existingMetadata.resources
                        }
                    }
                }

                # Create template metadata
                $metadata = @{
                    name = $Name
                    version = $Version
                    description = $Description
                    provider = $Provider
                    created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
                    author = $env:USERNAME
                    schema_version = "2.0"
                }

                # Add dependencies if specified
                if ($Dependencies) {
                    $metadata.dependencies = @()
                    foreach ($dep in $Dependencies) {
                        $metadata.dependencies += @{
                            name = $dep.name
                            version = $dep.version ?? ">=1.0.0"
                            provider = $dep.provider ?? $Provider
                            optional = $dep.optional ?? $false
                        }
                    }
                }

                # Add parameters if specified
                if ($Parameters) {
                    $metadata.parameters = $Parameters
                } else {
                    # Default parameters structure
                    $metadata.parameters = @{
                        template_name = @{
                            type = "string"
                            description = "Name for this deployment"
                            default = $Name
                        }
                    }
                }

                # Add resources if specified
                if ($Resources) {
                    $metadata.resources = $Resources
                } else {
                    # Default empty resources
                    $metadata.resources = @()
                }

                # Save metadata
                $metadataPath = Join-Path $versionPath "template.json"
                $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath -Encoding UTF8

                # Create version info
                $versionInfo = @{
                    version = $Version
                    released = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
                    changelog = @{
                        added = @()
                        changed = @()
                        fixed = @()
                        removed = @()
                    }
                }

                $versionInfoPath = Join-Path $versionPath "version.json"
                $versionInfo | ConvertTo-Json -Depth 10 | Set-Content -Path $versionInfoPath -Encoding UTF8

                # Create README for this version
                $readmeContent = @"
# $Name v$Version

$Description

## Provider

This template targets: **$Provider**

## Parameters

$(if ($Parameters) {
    $Parameters.GetEnumerator() | ForEach-Object {
        "- **$($_.Key)**: $($_.Value.description) (Type: $($_.Value.type), Default: $($_.Value.default))"
    } | Out-String
} else {
    "No parameters defined yet."
})

## Dependencies

$(if ($Dependencies) {
    $Dependencies | ForEach-Object {
        "- $($_.name) $($_.version)"
    } | Out-String
} else {
    "No dependencies."
})

## Usage

\`\`\`powershell
# Deploy this template
Start-InfrastructureDeployment -Template "$Name" -Version "$Version"
\`\`\`

## Changelog

Initial version.

---
*Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")*
"@

                Set-Content -Path (Join-Path $versionPath "README.md") -Value $readmeContent -Encoding UTF8

                # Create main.tf placeholder if not from existing
                if (-not $FromExisting) {
                    $mainTfContent = @"
# $Name Template v$Version
# $Description

# Provider configuration
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Add provider requirements here
  }
}

# Variables
$(if ($Parameters) {
    $Parameters.GetEnumerator() | ForEach-Object {
        @"

variable "$($_.Key)" {
  description = "$($_.Value.description)"
  type        = $($_.Value.type)
$(if ($_.Value.default) { "  default     = `"$($_.Value.default)`"`n" })}"
"@
    } | Out-String
})

# Resources
# Add your infrastructure resources here
"@

                    Set-Content -Path (Join-Path $versionPath "main.tf") -Value $mainTfContent -Encoding UTF8
                }

                # Update template index
                Update-TemplateIndex -TemplatePath $templatePath -Version $Version

                # Create result object
                $result = [PSCustomObject]@{
                    Name = $Name
                    Version = $Version
                    Path = $versionPath
                    Provider = $Provider
                    Description = $Description
                    CreatedAt = (Get-Date).ToUniversalTime()
                    Metadata = $metadata
                    FromExisting = $FromExisting
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Versioned template created successfully"
                return $result
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create versioned template: $_"
            throw
        }
    }

    end {
        if (Test-Path $versionPath) {
            Write-CustomLog -Level 'INFO' -Message "Template available at: $versionPath"
        }
    }
}
