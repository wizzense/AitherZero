# WinGet Manifest Templates

This directory contains template files for WinGet (Windows Package Manager) manifests.

## Overview

WinGet requires three manifest files for each package version:

1. **Version Manifest** (`Wizzense.AitherZero.yaml`)
   - Contains version identifier and metadata
   - Links to the other manifest files

2. **Installer Manifest** (`Wizzense.AitherZero.installer.yaml`)
   - Contains installer details (URL, hash, architecture)
   - Defines installation behavior

3. **Locale Manifest** (`Wizzense.AitherZero.locale.en-US.yaml`)
   - Contains package descriptions and metadata
   - Localized information (English-US)

## Usage

### Automated (Recommended)

The `automation-scripts/0797_generate-winget-manifests.ps1` script automatically:
1. Downloads the release ZIP file
2. Calculates SHA256 hash
3. Generates manifests from templates
4. Validates manifest format
5. Prepares for submission to microsoft/winget-pkgs

```powershell
# Generate manifests for a specific release
./automation-scripts/0797_generate-winget-manifests.ps1 -Version "1.2.0"

# With dry run to preview
./automation-scripts/0797_generate-winget-manifests.ps1 -Version "1.2.0" -DryRun
```

### Manual

1. Copy template files and remove `.template` extension
2. Replace placeholder values:
   - `{VERSION}` - Release version (e.g., 1.2.0)
   - `{RELEASE_DATE}` - Release date in YYYY-MM-DD format
   - `{SHA256_HASH}` - SHA256 hash of the installer ZIP
3. Validate using `winget validate --manifest <path>`
4. Submit via PR to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs)

## Placeholders

| Placeholder | Example | Description |
|-------------|---------|-------------|
| `{VERSION}` | 1.2.0 | Semantic version without 'v' prefix |
| `{RELEASE_DATE}` | 2025-01-15 | ISO 8601 date format (YYYY-MM-DD) |
| `{SHA256_HASH}` | abc123... | SHA256 hash of the installer file |

## Submission Process

1. **Fork winget-pkgs**: Fork [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs)

2. **Create manifests**:
   ```bash
   mkdir -p manifests/w/Wizzense/AitherZero/1.2.0
   # Copy generated manifests to this directory
   ```

3. **Validate locally**:
   ```bash
   winget validate --manifest manifests/w/Wizzense/AitherZero/1.2.0/
   ```

4. **Create PR**:
   ```bash
   git checkout -b aitherzero-1.2.0
   git add manifests/w/Wizzense/AitherZero/
   git commit -m "New version: Wizzense.AitherZero version 1.2.0"
   git push origin aitherzero-1.2.0
   gh pr create --repo microsoft/winget-pkgs \
     --title "New version: Wizzense.AitherZero version 1.2.0" \
     --body "Automated submission for AitherZero v1.2.0"
   ```

5. **Wait for validation**: Microsoft's automated bots validate the submission

6. **Manual review**: Microsoft team reviews (typically 1-7 days)

7. **Approval**: Once approved, package is available via `winget install Wizzense.AitherZero`

## Current Status

⚠️ **Note**: AitherZero currently distributes as a PowerShell module in a ZIP archive without a traditional Windows installer (MSI/EXE).

WinGet manifests use the "portable" installer type which:
- Downloads the ZIP file
- Extracts to a user-specified location
- Requires user to run `bootstrap.ps1` for setup

### Future Improvements

For a better WinGet experience, consider:
1. Creating a proper Windows installer (MSI recommended)
2. Automatic installation to PowerShell modules path
3. Start Menu integration
4. Automatic PATH configuration
5. Silent installation support

See [docs/PUBLISHING-GUIDE.md](../docs/PUBLISHING-GUIDE.md) for detailed guidance on creating installers.

## Schema Reference

- [Version Manifest Schema](https://aka.ms/winget-manifest.version.1.6.0.schema.json)
- [Installer Manifest Schema](https://aka.ms/winget-manifest.installer.1.6.0.schema.json)
- [Locale Manifest Schema](https://aka.ms/winget-manifest.defaultLocale.1.6.0.schema.json)

## Additional Resources

- [WinGet Documentation](https://docs.microsoft.com/en-us/windows/package-manager/)
- [Manifest Schema Docs](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest/schema)
- [WinGet Create Tool](https://github.com/microsoft/winget-create)
- [Submission Guidelines](https://github.com/microsoft/winget-pkgs/blob/master/AUTHORING_MANIFESTS.md)

---

**Last Updated**: 2025-10-29
**Schema Version**: 1.6.0
