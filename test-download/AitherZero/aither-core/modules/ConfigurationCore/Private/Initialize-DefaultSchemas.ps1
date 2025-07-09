function Initialize-DefaultSchemas {
    <#
    .SYNOPSIS
        Initialize default configuration schemas for known modules
    .DESCRIPTION
        Sets up baseline schemas for core AitherZero modules
    #>
    [CmdletBinding()]
    param()

    # Logging module schema
    Register-ConfigurationSchema -ModuleName 'Logging' -Schema @{
        Properties = @{
            LogLevel = @{
                Type = 'string'
                Default = 'INFO'
                ValidValues = @('DEBUG', 'INFO', 'WARNING', 'ERROR', 'SUCCESS')
                Description = 'Default logging level'
            }
            LogToFile = @{
                Type = 'bool'
                Default = $false
                Description = 'Enable file logging'
            }
            LogFilePath = @{
                Type = 'string'
                Default = ''
                Description = 'Path to log file'
            }
            MaxLogSizeMB = @{
                Type = 'int'
                Default = 100
                Min = 1
                Max = 1000
                Description = 'Maximum log file size in MB'
            }
        }
    }

    # LabRunner module schema
    Register-ConfigurationSchema -ModuleName 'LabRunner' -Schema @{
        Properties = @{
            MaxConcurrentJobs = @{
                Type = 'int'
                Default = 5
                Min = 1
                Max = 20
                Description = 'Maximum concurrent lab operations'
            }
            DefaultTimeout = @{
                Type = 'int'
                Default = 3600
                Min = 60
                Max = 86400
                Description = 'Default operation timeout in seconds'
            }
            EnableParallelExecution = @{
                Type = 'bool'
                Default = $true
                Description = 'Enable parallel execution of lab steps'
            }
        }
    }

    # OpenTofuProvider module schema
    Register-ConfigurationSchema -ModuleName 'OpenTofuProvider' -Schema @{
        Properties = @{
            TofuBinaryPath = @{
                Type = 'string'
                Default = 'tofu'
                Description = 'Path to OpenTofu binary'
            }
            WorkspacePath = @{
                Type = 'string'
                Default = ''
                Description = 'Default workspace path for OpenTofu operations'
            }
            AutoInit = @{
                Type = 'bool'
                Default = $true
                Description = 'Automatically run tofu init'
            }
            PlanBeforeApply = @{
                Type = 'bool'
                Default = $true
                Description = 'Always plan before applying changes'
            }
        }
    }

    # ConfigurationCarousel module schema
    Register-ConfigurationSchema -ModuleName 'ConfigurationCarousel' -Schema @{
        Properties = @{
            ConfigurationSets = @{
                Type = 'array'
                Default = @()
                Description = 'Available configuration sets'
            }
            ActiveSet = @{
                Type = 'string'
                Default = 'default'
                Description = 'Currently active configuration set'
            }
            AutoBackup = @{
                Type = 'bool'
                Default = $true
                Description = 'Automatically backup before switching configurations'
            }
        }
    }

    # OrchestrationEngine module schema
    Register-ConfigurationSchema -ModuleName 'OrchestrationEngine' -Schema @{
        Properties = @{
            MaxParallelWorkflows = @{
                Type = 'int'
                Default = 3
                Min = 1
                Max = 10
                Description = 'Maximum parallel workflow executions'
            }
            WorkflowTimeout = @{
                Type = 'int'
                Default = 7200
                Min = 300
                Max = 86400
                Description = 'Default workflow timeout in seconds'
            }
            EnableWorkflowLogging = @{
                Type = 'bool'
                Default = $true
                Description = 'Enable detailed workflow logging'
            }
        }
    }
}
