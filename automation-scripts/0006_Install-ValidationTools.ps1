#Requires -Version 7.0
# Stage: Prepare
# Dependencies: PowerShell7
# Description: Install validation tools (PSScriptAnalyzer, Pester)

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Import script utilities
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $ProjectRoot "domains/automation/ScriptUtilities.psm1") -Force

Write-ScriptLog "Starting validation tools installation"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }
    $validationConfig = if ($config.Validation) { $config.Validation } else { @{} }

    # Default tools
    $tools = @(
        @{ Name = 'PSScriptAnalyzer'; Required = $true },
        @{ Name = 'Pester'; Required = $true }
    )

    # Add any additional tools from configuration
    if ($validationConfig.AdditionalTools) {
        foreach ($tool in $validationConfig.AdditionalTools) {
            $tools += @{ Name = $tool; Required = $false }
        }
    }

    $failedInstalls = @()

    foreach ($toolInfo in $tools) {
        $toolName = $toolInfo.Name
        $isRequired = $toolInfo.Required

        try {
            # Check if already installed
            $installed = Get-Module -ListAvailable -Name $toolName -ErrorAction SilentlyContinue

            if ($installed) {
                Write-ScriptLog "$toolName is already installed (version: $($installed.Version))"

                # Check for updates if configured
                if ($validationConfig.CheckForUpdates -eq $true) {
                    Write-ScriptLog "Checking for updates to $toolName"
                    $onlineModule = Find-Module -Name $toolName -ErrorAction SilentlyContinue
                    if ($onlineModule -and $onlineModule.Version -gt $installed.Version) {
                        Write-ScriptLog "Updating $toolName from $($installed.Version) to $($onlineModule.Version)"
                        Update-Module -Name $toolName -Force -ErrorAction Stop
                        Write-ScriptLog "Successfully updated $toolName"
                    }
                }
            } else {
                Write-ScriptLog "Installing $toolName..."

                # Install parameters
                $installParams = @{
                    Name = $toolName
                    Force = $true
                    AllowClobber = $true
                    Scope = 'CurrentUser'
                    ErrorAction = 'Stop'
                }

                # Add specific version if configured
                if ($validationConfig.ToolVersions -and $validationConfig.ToolVersions.$toolName) {
                    $installParams['RequiredVersion'] = $validationConfig.ToolVersions.$toolName
                    Write-ScriptLog "Installing specific version: $($validationConfig.ToolVersions.$toolName)"
                }

                Install-Module @installParams
                Write-ScriptLog "Successfully installed $toolName"

                # Verify installation
                $verifyInstall = Get-Module -ListAvailable -Name $toolName -ErrorAction SilentlyContinue
                if ($verifyInstall) {
                    Write-ScriptLog "Verified: $toolName version $($verifyInstall.Version) is installed"
                } else {
                    throw "Installation verification failed"
                }
            }
        } catch {
            $errorMsg = "Failed to install $toolName : $($_.Exception.Message)"
            if ($isRequired) {
                Write-ScriptLog -Level 'Error' -Message $errorMsg
                $failedInstalls += $toolName
            } else {
                Write-ScriptLog -Level 'Warning' -Message $errorMsg
            }
        }
    }

    # Summary
    Write-ScriptLog "Validation tools installation summary:"
    Write-ScriptLog "  - Total tools: $($tools.Count)"
    Write-ScriptLog "  - Failed installs: $($failedInstalls.Count)"

    if ($failedInstalls.Count -gt 0) {
        Write-ScriptLog -Level 'Error' -Message "Failed to install required tools: $($failedInstalls -join ', ')"
        exit 1
    }

    Write-ScriptLog "Validation tools installation completed successfully"
    exit 0

} catch {
    Write-ScriptLog -Level 'Error' -Message "Critical error during validation tools installation: $($_.Exception.Message)"
    Write-ScriptLog -Level 'Error' -Message $_.ScriptStackTrace
    exit 1
}