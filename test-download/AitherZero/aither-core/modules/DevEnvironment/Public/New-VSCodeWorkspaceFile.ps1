function New-VSCodeWorkspaceFile {
    <#
    .SYNOPSIS
    Generates a VS Code workspace file with configured folders and settings.

    .DESCRIPTION
    This function creates a .code-workspace file that configures VS Code with
    specified folder paths and workspace-specific settings. Useful for creating
    consistent development environments across teams.

    .PARAMETER WorkspaceName
    Name for the workspace file (without extension).

    .PARAMETER WorkspacePath
    Path where the workspace file should be created. Defaults to current directory.

    .PARAMETER Folders
    Array of folder paths to include in the workspace. Can be relative or absolute paths.

    .PARAMETER Settings
    Hashtable of workspace-specific settings to apply.

    .PARAMETER Extensions
    Array of recommended extension IDs for this workspace.

    .PARAMETER Launch
    Launch configuration for debugging (as hashtable).

    .PARAMETER Tasks
    Task configuration for the workspace (as hashtable).

    .EXAMPLE
    New-VSCodeWorkspaceFile -WorkspaceName "AitherZero" -Folders @(".", "./opentofu", "./tests")

    .EXAMPLE
    New-VSCodeWorkspaceFile -WorkspaceName "MyProject" -Folders @("src", "tests") -Settings @{ "editor.formatOnSave" = $true }

    .EXAMPLE
    $settings = @{
        "powershell.codeFormatting.preset" = "OTBS"
        "editor.formatOnSave" = $true
    }
    New-VSCodeWorkspaceFile -WorkspaceName "PowerShellProject" -Settings $settings -Extensions @("ms-vscode.powershell")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceName,

        [Parameter(Mandatory = $false)]
        [string]$WorkspacePath = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [string[]]$Folders = @("."),

        [Parameter(Mandatory = $false)]
        [hashtable]$Settings = @{},

        [Parameter(Mandatory = $false)]
        [string[]]$Extensions = @(),

        [Parameter(Mandatory = $false)]
        [hashtable]$Launch,

        [Parameter(Mandatory = $false)]
        [hashtable]$Tasks
    )

    begin {
        # Import required modules
        $projectRoot = & "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force

        Write-CustomLog -Level 'INFO' -Message "Creating VS Code workspace file: $WorkspaceName"
    }

    process {
        try {
            # Ensure workspace path exists
            if (-not (Test-Path $WorkspacePath)) {
                New-Item -ItemType Directory -Path $WorkspacePath -Force | Out-Null
            }

            # Build workspace file path
            $workspaceFileName = "$WorkspaceName.code-workspace"
            $workspaceFilePath = Join-Path $WorkspacePath $workspaceFileName

            # Convert folders to proper format
            $folderObjects = @()
            foreach ($folder in $Folders) {
                # Convert to relative path if it's under the workspace path
                $folderPath = $folder
                if ([System.IO.Path]::IsPathRooted($folder)) {
                    try {
                        $relativePath = [System.IO.Path]::GetRelativePath($WorkspacePath, $folder)
                        if (-not $relativePath.StartsWith("..")) {
                            $folderPath = $relativePath
                        }
                    } catch {
                        # Keep absolute path if relative conversion fails
                    }
                }

                # Normalize path separators for cross-platform compatibility
                $folderPath = $folderPath.Replace('\', '/')

                # Get folder name for display
                $folderName = Split-Path -Path $folder -Leaf
                if ($folderName -eq "." -or [string]::IsNullOrEmpty($folderName)) {
                    $folderName = Split-Path -Path $WorkspacePath -Leaf
                }

                $folderObjects += @{
                    path = $folderPath
                    name = $folderName
                }
            }

            # Build workspace structure
            $workspace = [ordered]@{
                folders = $folderObjects
            }

            # Add settings if provided
            if ($Settings.Count -gt 0) {
                $workspace.settings = $Settings
            }

            # Add extensions recommendations if provided
            if ($Extensions.Count -gt 0) {
                $workspace.extensions = @{
                    recommendations = $Extensions
                }
            }

            # Add launch configuration if provided
            if ($Launch) {
                $workspace.launch = $Launch
            }

            # Add tasks configuration if provided
            if ($Tasks) {
                $workspace.tasks = $Tasks
            }

            # Convert to JSON with proper formatting
            $jsonContent = $workspace | ConvertTo-Json -Depth 10

            # VS Code expects specific formatting for workspace files
            # Ensure proper indentation and no BOM
            $formattedJson = $jsonContent -replace '(?m)^(\s*)"(\w+)":', '$1"$2":'

            # Save workspace file
            [System.IO.File]::WriteAllText($workspaceFilePath, $formattedJson, [System.Text.Encoding]::UTF8)

            Write-CustomLog -Level 'SUCCESS' -Message "Workspace file created: $workspaceFilePath"

            # Return workspace information
            return @{
                WorkspaceFile = $workspaceFilePath
                WorkspaceName = $WorkspaceName
                FolderCount = $folderObjects.Count
                SettingsCount = $Settings.Count
                ExtensionsCount = $Extensions.Count
                HasLaunchConfig = [bool]$Launch
                HasTasksConfig = [bool]$Tasks
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create workspace file: $($_.Exception.Message)"
            throw
        }
    }
}
