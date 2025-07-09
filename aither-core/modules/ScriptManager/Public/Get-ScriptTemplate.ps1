function Get-ScriptTemplate {
    <#
    .SYNOPSIS
    Gets available script templates

    .DESCRIPTION
    Returns information about available script templates that can be used for creating new scripts

    .PARAMETER TemplateName
    Optional name of a specific template to retrieve

    .PARAMETER Category
    Optional category to filter templates

    .EXAMPLE
    Get-ScriptTemplate

    .EXAMPLE
    Get-ScriptTemplate -TemplateName "PowerShell-Module"

    .EXAMPLE
    Get-ScriptTemplate -Category "Automation"
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TemplateName,

        [Parameter()]
        [string]$Category
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Getting script templates"
    }

    process {
        try {
            # Define built-in templates
            $templates = @(
                @{
                    Name = "PowerShell-Basic"
                    Category = "PowerShell"
                    Description = "Basic PowerShell script template with error handling"
                    Content = @"
#Requires -Version 7.0

<#
.SYNOPSIS
    [Brief description of what the script does]

.DESCRIPTION
    [Detailed description of the script's functionality]

.PARAMETER ParameterName
    [Description of parameter]

.EXAMPLE
    .\script-name.ps1

.NOTES
    Author: [Your Name]
    Date: $(Get-Date -Format 'yyyy-MM-dd')
    Version: 1.0.0
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = `$false)]
    [string]`$ParameterName
)

begin {
    # Write-CustomLog is guaranteed to be available from AitherCore orchestration
    # No explicit Logging import needed - trust the orchestration system
    
    Write-CustomLog -Level 'INFO' -Message "Script started"
}

process {
    try {
        # Main script logic here
        Write-CustomLog -Level 'INFO' -Message "Processing..."

        if (`$PSCmdlet.ShouldProcess("Target", "Action")) {
            # Perform operations here
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Script completed successfully"
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Script failed: `$(`$_.Exception.Message)"
        throw
    }
}

end {
    Write-CustomLog -Level 'INFO' -Message "Script execution finished"
}
"@
                },
                @{
                    Name = "PowerShell-Module"
                    Category = "PowerShell"
                    Description = "PowerShell module template with manifest"
                    Content = "# PowerShell module template content..."
                },
                @{
                    Name = "Automation-Script"
                    Category = "Automation"
                    Description = "Automation script template for infrastructure tasks"
                    Content = "# Automation script template content..."
                },
                @{
                    Name = "Test-Script"
                    Category = "Testing"
                    Description = "Pester test script template"
                    Content = "# Pester test template content..."
                }
            )

            # Filter by template name if specified
            if ($TemplateName) {
                $templates = $templates | Where-Object { $_.Name -eq $TemplateName }
            }

            # Filter by category if specified
            if ($Category) {
                $templates = $templates | Where-Object { $_.Category -eq $Category }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Found $($templates.Count) script templates"

            return $templates
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get script templates: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Script template query completed"
    }
}
