function New-LabAPI {
    <#
    .SYNOPSIS
        Create the Lab automation API wrapper
    .DESCRIPTION
        Provides a fluent interface for lab automation operations
    #>
    [CmdletBinding()]
    param()

    $labAPI = [PSCustomObject]@{
        # Lab execution methods
        Execute = $null
        Start = $null
        Stop = $null

        # Lab status and monitoring
        GetStatus = $null
        GetJobs = $null
        GetHistory = $null

        # Lab configuration
        Configure = $null
        GetConfig = $null

        # Lab validation
        Validate = $null
        Test = $null

        # Lab scripting
        RunScript = $null
        ListScripts = $null
    }

    # Execute lab operations
    $labAPI.Execute = {
        param(
            [Parameter(Mandatory)]
            [string]$Operation,

            [Parameter()]
            [hashtable]$Parameters = @{},

            [Parameter()]
            [switch]$Async,

            [Parameter()]
            [int]$Timeout = 3600
        )

        try {
            Write-CustomLog -Level 'INFO' -Message "Executing lab operation: $Operation"

            # Use ModuleCommunication API if available
            if (Get-Command 'Invoke-ModuleAPI' -ErrorAction SilentlyContinue) {
                return Invoke-ModuleAPI -Module "LabRunner" -Operation $Operation -Parameters $Parameters -Async:$Async -Timeout $Timeout
            }

            # Fallback to direct LabRunner calls
            switch ($Operation) {
                'DeployInfrastructure' {
                    if (Get-Command 'Start-LabAutomation' -ErrorAction SilentlyContinue) {
                        return Start-LabAutomation @Parameters
                    }
                }
                'RunStep' {
                    if (Get-Command 'Invoke-LabStep' -ErrorAction SilentlyContinue) {
                        return Invoke-LabStep @Parameters
                    }
                }
                default {
                    throw "Unknown lab operation: $Operation"
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Lab operation failed: $_"
            throw
        }
    }.GetNewClosure()

    # Start lab automation
    $labAPI.Start = {
        param(
            [Parameter()]
            [string]$ConfigPath,

            [Parameter()]
            [switch]$Auto,

            [Parameter()]
            [string[]]$Scripts
        )

        try {
            $params = @{}
            if ($ConfigPath) { $params.ConfigPath = $ConfigPath }
            if ($Auto) { $params.Auto = $true }
            if ($Scripts) { $params.Scripts = $Scripts }

            return $this.Execute('Start', $params)

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to start lab automation: $_"
            throw
        }
    }.GetNewClosure()

    # Get lab status
    $labAPI.GetStatus = {
        param(
            [Parameter()]
            [string]$LabName
        )

        try {
            if (Get-Command 'Get-LabStatus' -ErrorAction SilentlyContinue) {
                $params = @{}
                if ($LabName) { $params.LabName = $LabName }
                return Get-LabStatus @params
            }

            return @{
                Status = 'Unknown'
                Message = 'LabRunner module not available'
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get lab status: $_"
            throw
        }
    }.GetNewClosure()

    # Get lab configuration
    $labAPI.GetConfig = {
        try {
            if (Get-Command 'Get-ModuleConfiguration' -ErrorAction SilentlyContinue) {
                return Get-ModuleConfiguration -ModuleName "LabRunner"
            }

            # Fallback to direct config access
            if (Get-Command 'Get-LabConfig' -ErrorAction SilentlyContinue) {
                return Get-LabConfig
            }

            return @{ Message = 'Configuration not available' }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get lab configuration: $_"
            throw
        }
    }.GetNewClosure()

    # Configure lab settings
    $labAPI.Configure = {
        param(
            [Parameter(Mandatory)]
            [hashtable]$Configuration,

            [Parameter()]
            [switch]$Merge
        )

        try {
            if (Get-Command 'Set-ModuleConfiguration' -ErrorAction SilentlyContinue) {
                return Set-ModuleConfiguration -ModuleName "LabRunner" -Configuration $Configuration -Merge:$Merge
            }

            throw "Configuration system not available"

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to configure lab: $_"
            throw
        }
    }.GetNewClosure()

    # Validate lab environment
    $labAPI.Validate = {
        param(
            [Parameter()]
            [string]$ValidationLevel = 'Quick'
        )

        try {
            # Use testing framework if available
            if (Get-Command 'Invoke-BulletproofTests' -ErrorAction SilentlyContinue) {
                return Invoke-BulletproofTests -ValidationLevel $ValidationLevel
            }

            # Basic validation
            $result = @{
                IsValid = $true
                Tests = @()
                Summary = "Basic validation completed"
            }

            # Check if LabRunner module is loaded
            if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
                $result.Tests += @{
                    Name = "LabRunner Module"
                    Status = "Passed"
                    Message = "Module loaded successfully"
                }
            } else {
                $result.IsValid = $false
                $result.Tests += @{
                    Name = "LabRunner Module"
                    Status = "Failed"
                    Message = "Module not loaded"
                }
            }

            return $result

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Lab validation failed: $_"
            throw
        }
    }.GetNewClosure()

    # Run lab script
    $labAPI.RunScript = {
        param(
            [Parameter(Mandatory)]
            [string]$ScriptName,

            [Parameter()]
            [hashtable]$Parameters = @{}
        )

        try {
            return $this.Execute('RunScript', @{
                ScriptName = $ScriptName
                Parameters = $Parameters
            })

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to run lab script: $_"
            throw
        }
    }.GetNewClosure()

    # Add type information
    $labAPI.PSObject.TypeNames.Insert(0, 'AitherZero.Platform.LabAPI')

    return $labAPI
}
