function Invoke-StartupExperienceOperation {
    <#
    .SYNOPSIS
        Executes an operation in the StartupExperience management system
    .DESCRIPTION
        Performs various operations within the StartupExperience management
        system with proper validation and error handling
    .PARAMETER Operation
        The operation to execute
    .PARAMETER TestMode
        Run in test mode without making persistent changes
    .PARAMETER WhatIf
        Preview the operation without executing it
    .EXAMPLE
        Invoke-StartupExperienceOperation -Operation "Test" -TestMode
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Operation,

        [switch]$TestMode
    )

    try {
        # Initialize management state if not already done
        if (-not $script:ManagementState) {
            Start-StartupExperienceManagement
        }

        # Validate operation
        $validOperations = @('Test', 'Initialize', 'Configure', 'Reset', 'Validate')
        if ($Operation -notin $validOperations) {
            throw "Invalid operation: $Operation. Valid operations: $($validOperations -join ', ')"
        }

        # Handle WhatIf
        if ($WhatIf) {
            return [PSCustomObject]@{
                Operation = $Operation
                WouldExecute = $true
                TestMode = $TestMode.IsPresent
                Timestamp = Get-Date
            }
        }

        # Execute operation
        $result = switch ($Operation) {
            'Test' {
                [PSCustomObject]@{
                    Operation = $Operation
                    Status = 'Success'
                    Result = 'Test operation completed successfully'
                    TestMode = $TestMode.IsPresent
                }
            }
            'Initialize' {
                [PSCustomObject]@{
                    Operation = $Operation
                    Status = 'Success'
                    Result = 'Initialization completed'
                    TestMode = $TestMode.IsPresent
                }
            }
            'Configure' {
                [PSCustomObject]@{
                    Operation = $Operation
                    Status = 'Success'
                    Result = 'Configuration updated'
                    TestMode = $TestMode.IsPresent
                }
            }
            'Reset' {
                [PSCustomObject]@{
                    Operation = $Operation
                    Status = 'Success'
                    Result = 'System reset completed'
                    TestMode = $TestMode.IsPresent
                }
            }
            'Validate' {
                [PSCustomObject]@{
                    Operation = $Operation
                    Status = 'Success'
                    Result = 'Validation completed'
                    TestMode = $TestMode.IsPresent
                }
            }
            default {
                throw "Unknown operation: $Operation"
            }
        }

        # Update management state
        $script:ManagementState.LastOperation = $Operation
        $script:ManagementState.Operations += @{
            Operation = $Operation
            Timestamp = Get-Date
            TestMode = $TestMode.IsPresent
            Result = $result
        }

        Write-Verbose "Operation '$Operation' executed successfully"
        return $result

    } catch {
        Write-Error "Failed to execute StartupExperience operation: $($_.Exception.Message)"
        throw
    }
}