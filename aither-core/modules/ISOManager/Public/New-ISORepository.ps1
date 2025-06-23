function New-ISORepository {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $false)]
        [string]$Name = "AitherZero-ISORepository",

        [Parameter(Mandatory = $false)]
        [string]$Description = "AitherZero Infrastructure Automation ISO Repository",

        [Parameter(Mandatory = $false)]
        [hashtable]$Configuration = @{},

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating ISO repository: $Name at $RepositoryPath"
    }

    process {
        try {
            # Check if repository already exists
            if ((Test-Path $RepositoryPath) -and -not $Force) {
                $existingConfig = Join-Path $RepositoryPath "repository.config.json"
                if (Test-Path $existingConfig) {
                    Write-CustomLog -Level 'WARN' -Message "Repository already exists at $RepositoryPath. Use -Force to recreate."
                    $existingRepo = Get-Content $existingConfig | ConvertFrom-Json
                    return $existingRepo
                }
            }

            if ($PSCmdlet.ShouldProcess($RepositoryPath, "Create ISO Repository")) {
                # Create repository directory structure
                $directories = @(
                    $RepositoryPath,
                    (Join-Path $RepositoryPath "Windows"),
                    (Join-Path $RepositoryPath "Linux"),
                    (Join-Path $RepositoryPath "Custom"),
                    (Join-Path $RepositoryPath "Metadata"),
                    (Join-Path $RepositoryPath "Logs"),
                    (Join-Path $RepositoryPath "Temp")
                )

                foreach ($dir in $directories) {
                    if (-not (Test-Path $dir)) {
                        New-Item -ItemType Directory -Path $dir -Force | Out-Null
                        Write-CustomLog -Level 'INFO' -Message "Created directory: $dir"
                    }
                }

                # Create repository configuration
                $repoConfig = @{
                    Name = $Name
                    Description = $Description
                    Path = $RepositoryPath
                    Created = Get-Date
                    Version = "1.0.0"
                    Structure = @{
                        Windows = (Join-Path $RepositoryPath "Windows")
                        Linux = (Join-Path $RepositoryPath "Linux")
                        Custom = (Join-Path $RepositoryPath "Custom")
                        Metadata = (Join-Path $RepositoryPath "Metadata")
                        Logs = (Join-Path $RepositoryPath "Logs")
                        Temp = (Join-Path $RepositoryPath "Temp")
                    }
                    Configuration = $Configuration
                    Statistics = @{
                        TotalISOs = 0
                        WindowsISOs = 0
                        LinuxISOs = 0
                        CustomISOs = 0
                        TotalSizeGB = 0
                    }
                }

                # Save repository configuration
                $configPath = Join-Path $RepositoryPath "repository.config.json"
                $repoConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath

                # Create README file
                $readmePath = Join-Path $RepositoryPath "README.md"
                $readmeContent = @"
# $Name

$Description

## Repository Structure

- **Windows/**: Windows ISO files (Windows 10, 11, Server editions)
- **Linux/**: Linux distribution ISO files (Ubuntu, CentOS, RHEL, etc.)
- **Custom/**: Custom or third-party ISO files
- **Metadata/**: ISO metadata and catalog files
- **Logs/**: Download and operation logs
- **Temp/**: Temporary files during downloads

## Configuration

Repository configuration is stored in `repository.config.json`

## Management

Use the AitherZero ISOManager module to manage this repository:

```powershell
# Get repository inventory
Get-ISOInventory -RepositoryPath "$RepositoryPath"

# Download an ISO
Get-ISODownload -ISOName "Windows11" -DownloadPath "$RepositoryPath/Windows"

# Verify ISO integrity
Test-ISOIntegrity -FilePath "path/to/iso/file.iso"
```

Created: $(Get-Date)
"@
                $readmeContent | Set-Content $readmePath

                # Create .gitignore for version control
                $gitignorePath = Join-Path $RepositoryPath ".gitignore"
                $gitignoreContent = @"
# ISO files (large binaries)
*.iso
*.img

# Temporary files
Temp/
*.tmp
*.temp

# Logs
Logs/*.log

# OS generated files
.DS_Store
Thumbs.db
"@
                $gitignoreContent | Set-Content $gitignorePath

                Write-CustomLog -Level 'SUCCESS' -Message "ISO repository created successfully: $RepositoryPath"
                return $repoConfig
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create ISO repository: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed ISO repository creation"
    }
}
