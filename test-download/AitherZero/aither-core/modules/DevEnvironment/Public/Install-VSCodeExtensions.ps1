function Install-VSCodeExtensions {
    <#
    .SYNOPSIS
    Installs recommended VS Code extensions from a list.

    .DESCRIPTION
    This function reads a list of recommended VS Code extensions and installs
    any that are not already installed. It uses the VS Code CLI for installation.

    .PARAMETER ExtensionListPath
    Path to a file containing the list of extensions (one per line or JSON format).

    .PARAMETER Extensions
    Array of extension IDs to install directly.

    .PARAMETER SkipInstalled
    If specified, skips checking for already installed extensions (faster but may attempt reinstalls).

    .PARAMETER Force
    Forces reinstallation of all extensions even if already installed.

    .EXAMPLE
    Install-VSCodeExtensions -ExtensionListPath "./configs/vscode-extensions.txt"

    .EXAMPLE
    Install-VSCodeExtensions -Extensions @("ms-vscode.powershell", "ms-azuretools.vscode-docker")

    .EXAMPLE
    Install-VSCodeExtensions -ExtensionListPath "./configs/extensions.json" -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ExtensionListPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Direct')]
        [string[]]$Extensions,

        [switch]$SkipInstalled,

        [switch]$Force
    )

    begin {
        # Import required modules
        $projectRoot = & "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force

        Write-CustomLog -Level 'INFO' -Message "Starting VS Code extension installation"

        # Check if VS Code CLI is available
        $codeCommand = Get-Command code -ErrorAction SilentlyContinue
        if (-not $codeCommand) {
            throw "VS Code CLI (code) not found in PATH. Please ensure VS Code is installed and added to PATH."
        }
    }

    process {
        try {
            # Load extension list
            $extensionList = @()

            if ($PSCmdlet.ParameterSetName -eq 'File') {
                Write-CustomLog -Level 'INFO' -Message "Loading extension list from: $ExtensionListPath"

                $content = Get-Content -Path $ExtensionListPath -Raw

                # Try to parse as JSON first
                try {
                    $jsonData = $content | ConvertFrom-Json
                    if ($jsonData.recommendations) {
                        # VS Code extensions.json format
                        $extensionList = $jsonData.recommendations
                    } elseif ($jsonData -is [array]) {
                        # Simple JSON array
                        $extensionList = $jsonData
                    } else {
                        # Unknown JSON format, try to extract strings
                        $extensionList = @($jsonData) | ForEach-Object { $_.ToString() }
                    }
                } catch {
                    # Not JSON, treat as line-separated list
                    $extensionList = $content -split "`r?`n" | Where-Object { $_.Trim() -and -not $_.StartsWith("#") }
                }
            } else {
                $extensionList = $Extensions
            }

            # Remove duplicates and clean up
            $extensionList = $extensionList | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique

            Write-CustomLog -Level 'INFO' -Message "Found $($extensionList.Count) unique extensions to process"

            # Get currently installed extensions if needed
            $installedExtensions = @()
            if (-not $SkipInstalled -and -not $Force) {
                Write-CustomLog -Level 'INFO' -Message "Checking currently installed extensions..."
                $installedOutput = & code --list-extensions 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $installedExtensions = $installedOutput | ForEach-Object { $_.Trim().ToLower() }
                    Write-CustomLog -Level 'INFO' -Message "Found $($installedExtensions.Count) installed extensions"
                }
            }

            # Install extensions
            $installed = 0
            $skipped = 0
            $failed = 0

            foreach ($extension in $extensionList) {
                $extensionId = $extension.Trim()

                # Skip if already installed (unless Force)
                if (-not $Force -and $installedExtensions -contains $extensionId.ToLower()) {
                    Write-CustomLog -Level 'DEBUG' -Message "Extension already installed: $extensionId"
                    $skipped++
                    continue
                }

                # Install extension
                Write-CustomLog -Level 'INFO' -Message "Installing extension: $extensionId"

                $output = & code --install-extension $extensionId --force 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Successfully installed: $extensionId"
                    $installed++
                } else {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to install $extensionId : $output"
                    $failed++
                }
            }

            # Summary
            Write-CustomLog -Level 'SUCCESS' -Message "Extension installation complete: $installed installed, $skipped skipped, $failed failed"

            return @{
                TotalExtensions = $extensionList.Count
                Installed = $installed
                Skipped = $skipped
                Failed = $failed
                Extensions = $extensionList
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to install VS Code extensions: $($_.Exception.Message)"
            throw
        }
    }
}
