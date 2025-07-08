function Update-TemplateVersion {
    <#
    .SYNOPSIS
        Updates template version with new changes.

    .DESCRIPTION
        Creates a new version of a template with updated content, manages version
        bumping, and maintains changelog.

    .PARAMETER Name
        Name of the template to update.

    .PARAMETER CurrentVersion
        Current version to update from.

    .PARAMETER NewVersion
        New version number (or use -BumpMajor, -BumpMinor, -BumpPatch).

    .PARAMETER BumpMajor
        Increment major version (breaking changes).

    .PARAMETER BumpMinor
        Increment minor version (new features).

    .PARAMETER BumpPatch
        Increment patch version (bug fixes).

    .PARAMETER Prerelease
        Pre-release label (alpha, beta, rc).

    .PARAMETER Changes
        Hashtable of changes (added, changed, fixed, removed).

    .PARAMETER Path
        Template repository path.

    .EXAMPLE
        Update-TemplateVersion -Name "web-server" -CurrentVersion "1.0.0" -BumpMinor -Changes @{added=@("Load balancer support")}

    .OUTPUTS
        PSCustomObject with new version details
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Explicit')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$CurrentVersion,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [ValidatePattern('^\d+\.\d+\.\d+(-[a-zA-Z0-9-]+)?(\+[a-zA-Z0-9-]+)?$')]
        [string]$NewVersion,

        [Parameter(Mandatory, ParameterSetName = 'BumpMajor')]
        [switch]$BumpMajor,

        [Parameter(Mandatory, ParameterSetName = 'BumpMinor')]
        [switch]$BumpMinor,

        [Parameter(Mandatory, ParameterSetName = 'BumpPatch')]
        [switch]$BumpPatch,

        [Parameter()]
        [ValidateSet('alpha', 'beta', 'rc', 'preview')]
        [string]$Prerelease,

        [Parameter()]
        [hashtable]$Changes,

        [Parameter()]
        [string]$Path = (Get-TemplateConfiguration).TemplatePath
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Updating template version: $Name from v$CurrentVersion"
        $templatePath = Join-Path $Path $Name
        $currentPath = Join-Path $templatePath $CurrentVersion
    }

    process {
        try {
            # Validate current version exists
            if (-not (Test-Path $currentPath)) {
                throw "Current version not found: $Name v$CurrentVersion at $currentPath"
            }

            # Calculate new version
            if ($PSCmdlet.ParameterSetName -ne 'Explicit') {
                $current = [System.Management.Automation.SemanticVersion]::new($CurrentVersion)

                $major = $current.Major
                $minor = $current.Minor
                $patch = $current.Patch

                if ($BumpMajor) {
                    $major++
                    $minor = 0
                    $patch = 0
                } elseif ($BumpMinor) {
                    $minor++
                    $patch = 0
                } elseif ($BumpPatch) {
                    $patch++
                }

                $NewVersion = "$major.$minor.$patch"

                if ($Prerelease) {
                    $NewVersion += "-$Prerelease"
                }
            }

            $newPath = Join-Path $templatePath $NewVersion

            # Check if new version already exists
            if (Test-Path $newPath) {
                throw "Version already exists: $Name v$NewVersion"
            }

            if ($PSCmdlet.ShouldProcess("$Name v$NewVersion", "Create new template version")) {
                Write-CustomLog -Level 'INFO' -Message "Creating new version: v$NewVersion"

                # Create new version from current
                & "$PSScriptRoot/New-VersionedTemplate.ps1" `
                    -Name $Name `
                    -Version $NewVersion `
                    -Path $Path `
                    -FromExisting $currentPath

                # Load and update metadata
                $metadataPath = Join-Path $newPath "template.json"
                $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json -AsHashtable

                # Update version in metadata
                $metadata.version = $NewVersion
                $metadata.updated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
                $metadata.previous_version = $CurrentVersion

                # Save updated metadata
                $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath -Encoding UTF8

                # Update version info with changelog
                $versionInfoPath = Join-Path $newPath "version.json"
                $versionInfo = @{
                    version = $NewVersion
                    released = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
                    previous_version = $CurrentVersion
                    changelog = @{
                        added = @()
                        changed = @()
                        fixed = @()
                        removed = @()
                    }
                }

                # Add changes to changelog
                if ($Changes) {
                    foreach ($changeType in @('added', 'changed', 'fixed', 'removed')) {
                        if ($Changes.ContainsKey($changeType)) {
                            $versionInfo.changelog[$changeType] = @($Changes[$changeType])
                        }
                    }
                }

                # Determine change summary
                $changeSummary = ""
                if ($BumpMajor -or ($NewVersion.Split('.')[0] -ne $CurrentVersion.Split('.')[0])) {
                    $changeSummary = "BREAKING CHANGES"
                } elseif ($BumpMinor -or ($NewVersion.Split('.')[1] -ne $CurrentVersion.Split('.')[1])) {
                    $changeSummary = "New features"
                } else {
                    $changeSummary = "Bug fixes and improvements"
                }

                $versionInfo.summary = $changeSummary

                # Save version info
                $versionInfo | ConvertTo-Json -Depth 10 | Set-Content -Path $versionInfoPath -Encoding UTF8

                # Update README with changelog
                $readmePath = Join-Path $newPath "README.md"
                if (Test-Path $readmePath) {
                    $readmeContent = Get-Content $readmePath -Raw

                    # Find changelog section
                    if ($readmeContent -match '## Changelog') {
                        $changelogSection = @"

## Changelog

### v$NewVersion - $(Get-Date -Format "yyyy-MM-dd")

**$changeSummary**

$(if ($Changes.added) { "#### Added`n" + ($Changes.added | ForEach-Object { "- $_" }) -join "`n" })
$(if ($Changes.changed) { "`n#### Changed`n" + ($Changes.changed | ForEach-Object { "- $_" }) -join "`n" })
$(if ($Changes.fixed) { "`n#### Fixed`n" + ($Changes.fixed | ForEach-Object { "- $_" }) -join "`n" })
$(if ($Changes.removed) { "`n#### Removed`n" + ($Changes.removed | ForEach-Object { "- $_" }) -join "`n" })

### Previous versions
See version history in the repository.
"@

                        $readmeContent = $readmeContent -replace '## Changelog[\s\S]*', $changelogSection
                    } else {
                        # Add changelog section
                        $readmeContent += $changelogSection
                    }

                    Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
                }

                # Update template index
                Update-TemplateIndex -TemplatePath $templatePath -Version $NewVersion -SetAsLatest

                # Create migration guide if major version
                if ($BumpMajor) {
                    $migrationPath = Join-Path $newPath "MIGRATION.md"
                    $migrationContent = @"
# Migration Guide: v$CurrentVersion to v$NewVersion

This guide helps you migrate from v$CurrentVersion to v$NewVersion.

## Breaking Changes

$(if ($Changes.removed) {
    "### Removed Features`n" + ($Changes.removed | ForEach-Object { "- $_" }) -join "`n"
})

## Migration Steps

1. Review breaking changes above
2. Update your configuration files
3. Test in a non-production environment
4. Apply changes to production

## Configuration Changes

Update your deployment configuration:

\`\`\`yaml
# Old (v$CurrentVersion)
template_version: "$CurrentVersion"

# New (v$NewVersion)
template_version: "$NewVersion"
\`\`\`

## Need Help?

If you encounter issues during migration, please:
1. Check the documentation
2. Review the changelog
3. Contact support

---
*Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")*
"@

                    Set-Content -Path $migrationPath -Value $migrationContent -Encoding UTF8
                }

                # Create result object
                $result = [PSCustomObject]@{
                    Template = $Name
                    PreviousVersion = $CurrentVersion
                    NewVersion = $NewVersion
                    Path = $newPath
                    VersionType = if ($BumpMajor) { "Major" } elseif ($BumpMinor) { "Minor" } else { "Patch" }
                    IsPrerelease = $null -ne $Prerelease
                    Changes = $versionInfo.changelog
                    Summary = $changeSummary
                    CreatedAt = (Get-Date).ToUniversalTime()
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Template version updated successfully: $Name v$NewVersion"
                return $result
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to update template version: $_"
            throw
        }
    }

    end {
        if (Test-Path $newPath) {
            Write-CustomLog -Level 'INFO' -Message "New version available at: $newPath"
        }
    }
}
