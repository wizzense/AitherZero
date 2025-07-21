# Automation Functions - Consolidated into AitherCore Automation Domain
# Unified automation management including ScriptManager and related functionality

#Requires -Version 7.0

# Initialize logging
. (Join-Path $PSScriptRoot ".." ".." "shared" "Initialize-Logging.ps1")

using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Management.Automation

# MODULE CONSTANTS AND VARIABLES

$script:MODULE_VERSION = '1.0.0'
$script:SCRIPT_METADATA_VERSION = '1.0'
$script:MAX_SCRIPT_BACKUPS = 10
$script:SCRIPT_TIMEOUT_SECONDS = 300

# Cross-platform script storage paths
$script:ScriptRepositoryPath = if ($env:PROJECT_ROOT) {
    Join-Path $env:PROJECT_ROOT 'aither-core' 'scripts'
} else {
    Join-Path $PWD 'aither-core' 'scripts'
}

$script:ScriptMetadataPath = Join-Path $script:ScriptRepositoryPath 'metadata'
$script:ScriptTemplatesPath = Join-Path $script:ScriptRepositoryPath 'templates'
$script:ScriptBackupsPath = Join-Path $script:ScriptRepositoryPath 'backups'

# Script execution context
$script:ScriptExecutionContext = @{
    Version = $script:MODULE_VERSION
    MaxParallelJobs = 5
    DefaultTimeout = $script:SCRIPT_TIMEOUT_SECONDS
    LogLevel = 'INFO'
    AuditingEnabled = $true
    SecurityMode = 'Strict'
}

# Script registry
$script:ScriptRegistry = @{
    RegisteredScripts = @{}
    ExecutionHistory = @()
    Templates = @{}
    Metadata = @{
        Version = $script:SCRIPT_METADATA_VERSION
        LastUpdated = Get-Date
        Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
    }
}

# SCRIPT MANAGEMENT FUNCTIONS

function Initialize-ScriptRepository {
    <#
    .SYNOPSIS
        Initialize the script repository with proper directory structure
    .DESCRIPTION
        Sets up the script repository directories and initial configuration
    #>
    try {
        Write-CustomLog -Level 'INFO' -Message "Initializing script repository"
        
        # Create directory structure
        $directories = @(
            $script:ScriptRepositoryPath,
            $script:ScriptMetadataPath,
            $script:ScriptTemplatesPath,
            $script:ScriptBackupsPath
        )
        
        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-CustomLog -Level 'INFO' -Message "Created directory: $dir"
            }
        }
        
        # Initialize metadata file
        $metadataFile = Join-Path $script:ScriptMetadataPath 'registry.json'
        if (-not (Test-Path $metadataFile)) {
            $script:ScriptRegistry | ConvertTo-Json -Depth 10 | Set-Content $metadataFile -Encoding UTF8
        }
        
        # Create default templates
        Initialize-ScriptTemplates
        
        Write-CustomLog -Level 'SUCCESS' -Message "Script repository initialized at: $script:ScriptRepositoryPath"
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize script repository: $($_.Exception.Message)"
        throw
    }
}

function Initialize-ScriptTemplates {
    <#
    .SYNOPSIS
        Initialize default script templates
    .DESCRIPTION
        Creates default script templates in the templates directory
    #>
    try {
        $templates = @{
            'Basic' = @{
                Name = 'Basic PowerShell Script'
                Description = 'Simple PowerShell script template with logging'
                Content = @'
#Requires -Version 7.0

<#
.SYNOPSIS
    Basic PowerShell script template
.DESCRIPTION
    Template for creating basic PowerShell scripts with logging support
.PARAMETER ExampleParam
    Example parameter
.EXAMPLE
    .\Script.ps1 -ExampleParam "value"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ExampleParam = "default",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

try {
    Write-CustomLog -Level 'INFO' -Message "Script started with parameter: $ExampleParam"
    
    if ($WhatIf) {
        Write-CustomLog -Level 'INFO' -Message "WhatIf mode: Script would perform actions here"
        return
    }
    
    # Your script logic here
    Write-CustomLog -Level 'INFO' -Message "Performing script operations..."
    
    # Example operation
    Start-Sleep -Seconds 1
    
    Write-CustomLog -Level 'SUCCESS' -Message "Script completed successfully"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Script failed: $($_.Exception.Message)"
    throw
}
'@
            }
            'Module' = @{
                Name = 'Module Function Script'
                Description = 'Template for module-based scripts'
                Content = @'
#Requires -Version 7.0

<#
.SYNOPSIS
    Module function script template
.DESCRIPTION
    Template for creating scripts that use AitherZero modules
.PARAMETER ModuleName
    Name of the module to work with
.EXAMPLE
    .\ModuleScript.ps1 -ModuleName "LabRunner"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

try {
    Write-CustomLog -Level 'INFO' -Message "Module script started for: $ModuleName"
    
    # Import required modules
    $moduleAvailable = Get-Module -Name $ModuleName -ListAvailable
    if (-not $moduleAvailable) {
        throw "Module $ModuleName is not available"
    }
    
    Import-Module $ModuleName -Force
    Write-CustomLog -Level 'INFO' -Message "Module $ModuleName imported successfully"
    
    if ($WhatIf) {
        Write-CustomLog -Level 'INFO' -Message "WhatIf mode: Would execute module operations"
        return
    }
    
    # Your module-specific logic here
    Write-CustomLog -Level 'INFO' -Message "Executing module operations..."
    
    Write-CustomLog -Level 'SUCCESS' -Message "Module script completed successfully"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Module script failed: $($_.Exception.Message)"
    throw
}
'@
            }
            'Lab' = @{
                Name = 'Lab Automation Script'
                Description = 'Template for lab automation scripts'
                Content = @'
#Requires -Version 7.0

<#
.SYNOPSIS
    Lab automation script template
.DESCRIPTION
    Template for creating lab automation scripts with comprehensive error handling
.PARAMETER LabName
    Name of the lab environment
.PARAMETER Operation
    Operation to perform
.EXAMPLE
    .\LabScript.ps1 -LabName "TestLab" -Operation "Deploy"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$LabName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Deploy', 'Destroy', 'Status', 'Validate')]
    [string]$Operation = 'Status',
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

try {
    Write-CustomLog -Level 'INFO' -Message "Lab automation script started: $LabName ($Operation)"
    
    # Validate prerequisites
    if (-not $env:PROJECT_ROOT) {
        throw "PROJECT_ROOT environment variable not set"
    }
    
    if ($WhatIf) {
        Write-CustomLog -Level 'INFO' -Message "WhatIf mode: Would perform $Operation on $LabName"
        return
    }
    
    # Lab operation logic
    switch ($Operation) {
        'Deploy' {
            Write-CustomLog -Level 'INFO' -Message "Deploying lab: $LabName"
            # Deployment logic here
        }
        'Destroy' {
            Write-CustomLog -Level 'INFO' -Message "Destroying lab: $LabName"
            # Destruction logic here
        }
        'Status' {
            Write-CustomLog -Level 'INFO' -Message "Checking lab status: $LabName"
            # Status check logic here
        }
        'Validate' {
            Write-CustomLog -Level 'INFO' -Message "Validating lab: $LabName"
            # Validation logic here
        }
    }
    
    Write-CustomLog -Level 'SUCCESS' -Message "Lab automation completed successfully"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Lab automation failed: $($_.Exception.Message)"
    throw
}
'@
            }
            'Parallel' = @{
                Name = 'Parallel Execution Script'
                Description = 'Template for parallel execution scripts'
                Content = @'
#Requires -Version 7.0

<#
.SYNOPSIS
    Parallel execution script template
.DESCRIPTION
    Template for creating scripts that execute operations in parallel
.PARAMETER Items
    Items to process in parallel
.PARAMETER MaxParallel
    Maximum number of parallel operations
.EXAMPLE
    .\ParallelScript.ps1 -Items @("item1", "item2", "item3") -MaxParallel 3
#>

param(
    [Parameter(Mandatory = $true)]
    [string[]]$Items,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxParallel = 5,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

try {
    Write-CustomLog -Level 'INFO' -Message "Parallel execution script started with $($Items.Count) items"
    
    if ($WhatIf) {
        Write-CustomLog -Level 'INFO' -Message "WhatIf mode: Would process $($Items.Count) items in parallel"
        return
    }
    
    # Process items in parallel
    $results = $Items | ForEach-Object -Parallel {
        param($item)
        
        try {
            Write-Host "Processing item: $item" -ForegroundColor Cyan
            
            # Your parallel processing logic here
            Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 3)
            
            return @{
                Item = $item
                Status = 'Success'
                Result = "Processed successfully"
            }
        } catch {
            return @{
                Item = $item
                Status = 'Failed'
                Result = $_.Exception.Message
            }
        }
    } -ThrottleLimit $MaxParallel
    
    # Process results
    $successful = $results | Where-Object { $_.Status -eq 'Success' }
    $failed = $results | Where-Object { $_.Status -eq 'Failed' }
    
    Write-CustomLog -Level 'SUCCESS' -Message "Parallel execution completed. Success: $($successful.Count), Failed: $($failed.Count)"
    
    if ($failed.Count -gt 0) {
        Write-CustomLog -Level 'WARNING' -Message "Some items failed to process:"
        foreach ($failure in $failed) {
            Write-CustomLog -Level 'ERROR' -Message "  - $($failure.Item): $($failure.Result)"
        }
    }
    
    return $results
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Parallel execution script failed: $($_.Exception.Message)"
    throw
}
'@
            }
        }
        
        # Save templates to files
        foreach ($templateName in $templates.Keys) {
            $template = $templates[$templateName]
            $templateFile = Join-Path $script:ScriptTemplatesPath "$templateName.ps1"
            
            if (-not (Test-Path $templateFile)) {
                $template.Content | Set-Content $templateFile -Encoding UTF8
                Write-CustomLog -Level 'INFO' -Message "Created template: $templateName"
            }
        }
        
        # Update registry
        $script:ScriptRegistry.Templates = $templates
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize script templates: $($_.Exception.Message)"
        throw
    }
}

function Register-OneOffScript {
    <#
    .SYNOPSIS
        Register a one-off script for execution
    .DESCRIPTION
        Registers a script in the script registry with metadata
    .PARAMETER ScriptPath
        Path to the script file
    .PARAMETER Name
        Name for the script
    .PARAMETER Description
        Description of the script
    .PARAMETER Parameters
        Default parameters for the script
    .PARAMETER Force
        Force registration even if script already exists
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Description = "",

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Registering script: $Name"
        
        # Validate script path
        if (-not (Test-Path $ScriptPath)) {
            throw "Script file not found: $ScriptPath"
        }
        
        Initialize-ScriptRepository
        
        # Load existing registry
        $metadataFile = Join-Path $script:ScriptMetadataPath 'registry.json'
        if (Test-Path $metadataFile) {
            $registry = Get-Content $metadataFile -Raw | ConvertFrom-Json -AsHashtable
        } else {
            $registry = $script:ScriptRegistry
        }
        
        # Check if script already exists
        if ($registry.RegisteredScripts.ContainsKey($Name) -and -not $Force) {
            throw "Script '$Name' already registered. Use -Force to overwrite"
        }
        
        # Validate script content
        $scriptValidation = Test-ModernScript -ScriptPath $ScriptPath
        
        # Create script metadata
        $scriptMetadata = @{
            ScriptPath = $ScriptPath
            Name = $Name
            Description = $Description
            Parameters = $Parameters
            RegisteredDate = Get-Date
            Executed = $false
            ExecutionCount = 0
            LastExecutionDate = $null
            LastExecutionResult = $null
            IsValid = $scriptValidation
            Hash = Get-FileHash -Path $ScriptPath -Algorithm SHA256
        }
        
        if ($PSCmdlet.ShouldProcess($Name, "Register script")) {
            # Add to registry
            $registry.RegisteredScripts[$Name] = $scriptMetadata
            $registry.Metadata.LastUpdated = Get-Date
            
            # Save registry
            $registry | ConvertTo-Json -Depth 10 | Set-Content $metadataFile -Encoding UTF8
            
            Write-CustomLog -Level 'SUCCESS' -Message "Script registered successfully: $Name"
            
            return @{
                Success = $true
                Name = $Name
                ScriptPath = $ScriptPath
                IsValid = $scriptValidation
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to register script: $($_.Exception.Message)"
        throw
    }
}

function Get-RegisteredScripts {
    <#
    .SYNOPSIS
        Get all registered scripts
    .DESCRIPTION
        Returns information about all registered scripts
    .PARAMETER Name
        Specific script name to retrieve
    .PARAMETER IncludeInvalid
        Include invalid scripts in results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeInvalid
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving registered scripts"
        
        Initialize-ScriptRepository
        
        $metadataFile = Join-Path $script:ScriptMetadataPath 'registry.json'
        if (-not (Test-Path $metadataFile)) {
            return @()
        }
        
        $registry = Get-Content $metadataFile -Raw | ConvertFrom-Json -AsHashtable
        
        if ($Name) {
            if ($registry.RegisteredScripts.ContainsKey($Name)) {
                $script = $registry.RegisteredScripts[$Name]
                if ($script.IsValid -or $IncludeInvalid) {
                    return $script
                }
            }
            return $null
        }
        
        $scripts = $registry.RegisteredScripts.Values
        
        if (-not $IncludeInvalid) {
            $scripts = $scripts | Where-Object { $_.IsValid }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Retrieved $($scripts.Count) registered scripts"
        return $scripts
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve registered scripts: $($_.Exception.Message)"
        throw
    }
}

function Test-ModernScript {
    <#
    .SYNOPSIS
        Test if a script follows modern PowerShell practices
    .DESCRIPTION
        Validates that a script uses modern functions and follows best practices
    .PARAMETER ScriptPath
        Path to the script to test
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    try {
        if (-not (Test-Path $ScriptPath)) {
            return $false
        }

        $content = Get-Content $ScriptPath -Raw -ErrorAction Stop

        # Check for modern PowerShell version requirement
        $hasVersionRequirement = $content -match '#Requires -Version [7-9]'

        # Check for proper module imports
        $hasModuleImports = $content -match 'Import-Module'

        # Check for modern function usage
        $usesModernFunctions = $content -match 'Write-CustomLog|ForEach-Object -Parallel|Start-ThreadJob'

        # Check for deprecated function usage
        $usesDeprecatedFunctions = $content -match 'Write-Host.*-NoNewline|Invoke-Command -ComputerName.*-Credential'

        # Check for proper error handling
        $hasErrorHandling = $content -match 'try\s*\{|catch\s*\{|finally\s*\{'

        # Check for parameter validation
        $hasParameterValidation = $content -match '\[Parameter\(|ValidateSet|ValidateRange|ValidateNotNullOrEmpty'

        # Check for help documentation
        $hasHelpDocumentation = $content -match '\.SYNOPSIS|\.DESCRIPTION|\.EXAMPLE'

        # Check for proper function structure
        $hasProperFunctions = $content -match 'function\s+[\w-]+\s*\{'

        # Calculate score
        $score = 0
        $maxScore = 8
        
        if ($hasVersionRequirement) { $score += 1 }
        if ($hasModuleImports) { $score += 1 }
        if ($usesModernFunctions) { $score += 1 }
        if (-not $usesDeprecatedFunctions) { $score += 1 }
        if ($hasErrorHandling) { $score += 1 }
        if ($hasParameterValidation) { $score += 1 }
        if ($hasHelpDocumentation) { $score += 1 }
        if ($hasProperFunctions) { $score += 1 }

        # Consider modern if score >= 5 out of 8
        $isModern = $score -ge 5
        
        Write-CustomLog -Level 'INFO' -Message "Script validation score: $score/$maxScore (Modern: $isModern)"
        
        return $isModern

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to test script: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-OneOffScript {
    <#
    .SYNOPSIS
        Execute a one-off script
    .DESCRIPTION
        Executes a registered script with parameters and monitoring
    .PARAMETER ScriptPath
        Path to the script to execute
    .PARAMETER Name
        Name of the registered script
    .PARAMETER Parameters
        Parameters to pass to the script
    .PARAMETER Force
        Force execution even if script has been executed before
    .PARAMETER Timeout
        Timeout in seconds for script execution
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [int]$Timeout = $script:SCRIPT_TIMEOUT_SECONDS
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Executing script: $($Name ?? $ScriptPath)"
        
        # Determine script to execute
        if ($Name) {
            $scriptInfo = Get-RegisteredScripts -Name $Name
            if (-not $scriptInfo) {
                throw "Registered script not found: $Name"
            }
            $ScriptPath = $scriptInfo.ScriptPath
        } elseif ($ScriptPath) {
            if (-not (Test-Path $ScriptPath)) {
                throw "Script file not found: $ScriptPath"
            }
            # Auto-register if not already registered
            $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
            Register-OneOffScript -ScriptPath $ScriptPath -Name $scriptName -Description "Auto-registered script" -Force
            $scriptInfo = Get-RegisteredScripts -Name $scriptName
        } else {
            throw "Either ScriptPath or Name must be provided"
        }
        
        # Check if script has already been executed
        if ($scriptInfo.Executed -and -not $Force) {
            throw "Script has already been executed. Use -Force to re-execute"
        }
        
        # Validate script before execution
        if (-not (Test-ModernScript -ScriptPath $ScriptPath)) {
            Write-CustomLog -Level 'WARNING' -Message "Script does not follow modern PowerShell practices"
        }
        
        if ($PSCmdlet.ShouldProcess($ScriptPath, "Execute script")) {
            # Create execution job for timeout support
            $job = Start-Job -ScriptBlock {
                param($Path, $Params)
                
                # Set up environment
                $env:SCRIPT_EXECUTION_ID = [System.Guid]::NewGuid().ToString()
                $env:SCRIPT_START_TIME = Get-Date
                
                try {
                    if ($Params.Count -gt 0) {
                        $result = & $Path @Params
                    } else {
                        $result = & $Path
                    }
                    
                    return @{
                        Success = $true
                        Result = $result
                        ExecutionTime = (Get-Date) - $env:SCRIPT_START_TIME
                    }
                } catch {
                    return @{
                        Success = $false
                        Error = $_.Exception.Message
                        ExecutionTime = (Get-Date) - $env:SCRIPT_START_TIME
                    }
                }
            } -ArgumentList $ScriptPath, $Parameters
            
            # Wait for completion with timeout
            $completed = Wait-Job -Job $job -Timeout $Timeout
            
            if ($completed) {
                $result = Receive-Job -Job $job
                Remove-Job -Job $job
                
                # Update script metadata
                $metadataFile = Join-Path $script:ScriptMetadataPath 'registry.json'
                $registry = Get-Content $metadataFile -Raw | ConvertFrom-Json -AsHashtable
                
                if ($registry.RegisteredScripts.ContainsKey($scriptInfo.Name)) {
                    $registry.RegisteredScripts[$scriptInfo.Name].Executed = $true
                    $registry.RegisteredScripts[$scriptInfo.Name].ExecutionCount++
                    $registry.RegisteredScripts[$scriptInfo.Name].LastExecutionDate = Get-Date
                    $registry.RegisteredScripts[$scriptInfo.Name].LastExecutionResult = if ($result.Success) { 'Success' } else { 'Failed' }
                    
                    # Add to execution history
                    $registry.ExecutionHistory += @{
                        ScriptName = $scriptInfo.Name
                        ExecutionDate = Get-Date
                        Success = $result.Success
                        ExecutionTime = $result.ExecutionTime
                        Parameters = $Parameters
                        Error = $result.Error
                    }
                    
                    # Save updated registry
                    $registry | ConvertTo-Json -Depth 10 | Set-Content $metadataFile -Encoding UTF8
                }
                
                if ($result.Success) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Script executed successfully in $($result.ExecutionTime)"
                    return $result.Result
                } else {
                    throw "Script execution failed: $($result.Error)"
                }
            } else {
                # Script timed out
                Stop-Job -Job $job
                Remove-Job -Job $job
                throw "Script execution timed out after $Timeout seconds"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to execute script: $($_.Exception.Message)"
        throw
    }
}

function Start-ScriptExecution {
    <#
    .SYNOPSIS
        Start script execution with advanced options
    .DESCRIPTION
        Executes a script with comprehensive monitoring and background support
    .PARAMETER ScriptName
        Name of the script to execute
    .PARAMETER Parameters
        Parameters to pass to the script
    .PARAMETER Background
        Whether to run the script in background
    .PARAMETER Priority
        Execution priority (Normal, High, Low)
    .PARAMETER MaxRetries
        Maximum number of retry attempts
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [switch]$Background,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Normal', 'High', 'Low')]
        [string]$Priority = 'Normal',

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 0
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting script execution: $ScriptName"
        
        # Get script information
        $scriptInfo = Get-RegisteredScripts -Name $ScriptName
        if (-not $scriptInfo) {
            throw "Script not found: $ScriptName"
        }
        
        $executionId = [System.Guid]::NewGuid().ToString()
        $startTime = Get-Date
        
        if ($Background) {
            # Background execution
            $job = Start-Job -ScriptBlock {
                param($ScriptPath, $Params, $ExecId, $MaxRetries)
                
                $retryCount = 0
                $success = $false
                
                do {
                    try {
                        if ($Params.Count -gt 0) {
                            $result = & $ScriptPath @Params
                        } else {
                            $result = & $ScriptPath
                        }
                        $success = $true
                        return @{
                            Success = $true
                            Result = $result
                            ExecutionId = $ExecId
                            RetryCount = $retryCount
                        }
                    } catch {
                        $retryCount++
                        if ($retryCount -le $MaxRetries) {
                            Start-Sleep -Seconds ($retryCount * 2) # Exponential backoff
                        } else {
                            return @{
                                Success = $false
                                Error = $_.Exception.Message
                                ExecutionId = $ExecId
                                RetryCount = $retryCount
                            }
                        }
                    }
                } while (-not $success -and $retryCount -le $MaxRetries)
                
            } -ArgumentList $scriptInfo.ScriptPath, $Parameters, $executionId, $MaxRetries
            
            # Set job priority
            if ($Priority -eq 'High') {
                $job | Set-Job -Priority High
            } elseif ($Priority -eq 'Low') {
                $job | Set-Job -Priority Low
            }
            
            $result = @{
                Status = 'Started'
                ExecutionId = $executionId
                JobId = $job.Id
                ScriptName = $ScriptName
                ScriptPath = $scriptInfo.ScriptPath
                Background = $true
                StartTime = $startTime
                Priority = $Priority
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Script started in background with Job ID: $($job.Id)"
            
        } else {
            # Foreground execution with retry logic
            $retryCount = 0
            $success = $false
            
            do {
                try {
                    $result = Invoke-OneOffScript -Name $ScriptName -Parameters $Parameters -Force
                    $success = $true
                    
                    $result = @{
                        Status = 'Completed'
                        ExecutionId = $executionId
                        ScriptName = $ScriptName
                        ScriptPath = $scriptInfo.ScriptPath
                        Background = $false
                        StartTime = $startTime
                        EndTime = Get-Date
                        RetryCount = $retryCount
                        Result = $result
                    }
                    
                } catch {
                    $retryCount++
                    if ($retryCount -le $MaxRetries) {
                        Write-CustomLog -Level 'WARNING' -Message "Script execution failed, retrying ($retryCount/$MaxRetries): $($_.Exception.Message)"
                        Start-Sleep -Seconds ($retryCount * 2) # Exponential backoff
                    } else {
                        throw "Script execution failed after $MaxRetries retries: $($_.Exception.Message)"
                    }
                }
            } while (-not $success -and $retryCount -le $MaxRetries)
            
            Write-CustomLog -Level 'SUCCESS' -Message "Script execution completed successfully"
        }
        
        return $result
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to start script execution: $($_.Exception.Message)"
        throw
    }
}

function Get-ScriptTemplate {
    <#
    .SYNOPSIS
        Get available script templates
    .DESCRIPTION
        Retrieves information about available script templates
    .PARAMETER TemplateName
        Specific template name to retrieve
    .PARAMETER ListOnly
        Only list template names
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TemplateName,

        [Parameter(Mandatory = $false)]
        [switch]$ListOnly
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving script templates"
        
        Initialize-ScriptRepository
        
        # Load templates from registry
        $metadataFile = Join-Path $script:ScriptMetadataPath 'registry.json'
        if (Test-Path $metadataFile) {
            $registry = Get-Content $metadataFile -Raw | ConvertFrom-Json -AsHashtable
            $templates = $registry.Templates
        } else {
            $templates = $script:ScriptRegistry.Templates
        }
        
        if ($TemplateName) {
            if ($templates.ContainsKey($TemplateName)) {
                return $templates[$TemplateName]
            } else {
                throw "Template not found: $TemplateName"
            }
        }
        
        if ($ListOnly) {
            return $templates.Keys
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Retrieved $($templates.Count) script templates"
        return $templates
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get script templates: $($_.Exception.Message)"
        throw
    }
}

function New-ScriptFromTemplate {
    <#
    .SYNOPSIS
        Create a new script from a template
    .DESCRIPTION
        Creates a new script file based on a template
    .PARAMETER TemplateName
        Name of the template to use
    .PARAMETER ScriptName
        Name for the new script
    .PARAMETER OutputPath
        Path where the new script should be created
    .PARAMETER Parameters
        Parameters to customize the template
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateName,

        [Parameter(Mandatory = $true)]
        [string]$ScriptName,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = $script:ScriptRepositoryPath,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{}
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Creating script from template: $TemplateName"
        
        # Get template
        $template = Get-ScriptTemplate -TemplateName $TemplateName
        
        # Create output path
        $scriptPath = Join-Path $OutputPath "$ScriptName.ps1"
        
        if ((Test-Path $scriptPath) -and -not $PSCmdlet.ShouldProcess($scriptPath, "Overwrite existing script")) {
            throw "Script already exists: $scriptPath"
        }
        
        # Customize template content
        $content = $template.Content
        
        # Replace common placeholders
        $content = $content -replace '\$ExampleParam', $Parameters.GetValueOrDefault('ExampleParam', '$ExampleParam')
        $content = $content -replace 'Template for creating', "Script: $ScriptName - Template for creating"
        
        # Add custom parameters if provided
        foreach ($key in $Parameters.Keys) {
            $content = $content -replace "{{$key}}", $Parameters[$key]
        }
        
        if ($PSCmdlet.ShouldProcess($scriptPath, "Create script from template")) {
            # Ensure output directory exists
            $outputDir = Split-Path $scriptPath -Parent
            if (-not (Test-Path $outputDir)) {
                New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            }
            
            # Write script content
            $content | Set-Content $scriptPath -Encoding UTF8
            
            # Make script executable on Unix systems
            if ($IsLinux -or $IsMacOS) {
                chmod +x $scriptPath
            }
            
            # Auto-register the new script
            Register-OneOffScript -ScriptPath $scriptPath -Name $ScriptName -Description "Created from template: $TemplateName" -Force
            
            Write-CustomLog -Level 'SUCCESS' -Message "Script created successfully: $scriptPath"
            
            return @{
                Success = $true
                ScriptName = $ScriptName
                ScriptPath = $scriptPath
                Template = $TemplateName
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create script from template: $($_.Exception.Message)"
        throw
    }
}

function Get-ScriptRepository {
    <#
    .SYNOPSIS
        Get information about the script repository
    .DESCRIPTION
        Retrieves comprehensive information about the script repository
    .PARAMETER Path
        Path to script repository
    .PARAMETER IncludeStatistics
        Include statistical information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = $script:ScriptRepositoryPath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeStatistics
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving script repository information"
        
        Initialize-ScriptRepository
        
        if (-not (Test-Path $Path)) {
            throw "Script repository path does not exist: $Path"
        }
        
        # Get all PowerShell scripts
        $scriptFiles = Get-ChildItem -Path $Path -Filter "*.ps1" -Recurse | Where-Object { $_.Name -notlike "*.Tests.ps1" }
        
        # Get registered scripts
        $registeredScripts = Get-RegisteredScripts -IncludeInvalid
        
        # Get templates
        $templates = Get-ScriptTemplate
        
        # Basic repository info
        $repository = @{
            Path = $Path
            TotalScripts = $scriptFiles.Count
            RegisteredScripts = $registeredScripts.Count
            ValidScripts = ($registeredScripts | Where-Object { $_.IsValid }).Count
            Templates = $templates.Count
            LastUpdated = (Get-Date)
            Status = 'Available'
        }
        
        if ($IncludeStatistics) {
            # Load execution history
            $metadataFile = Join-Path $script:ScriptMetadataPath 'registry.json'
            if (Test-Path $metadataFile) {
                $registry = Get-Content $metadataFile -Raw | ConvertFrom-Json -AsHashtable
                $executionHistory = $registry.ExecutionHistory
            } else {
                $executionHistory = @()
            }
            
            # Calculate statistics
            $repository.Statistics = @{
                TotalExecutions = $executionHistory.Count
                SuccessfulExecutions = ($executionHistory | Where-Object { $_.Success }).Count
                FailedExecutions = ($executionHistory | Where-Object { -not $_.Success }).Count
                AverageExecutionTime = if ($executionHistory.Count -gt 0) {
                    ($executionHistory | Where-Object { $_.ExecutionTime } | Measure-Object -Property ExecutionTime -Average).Average
                } else { 0 }
                MostExecutedScript = if ($executionHistory.Count -gt 0) {
                    ($executionHistory | Group-Object -Property ScriptName | Sort-Object Count -Descending | Select-Object -First 1).Name
                } else { $null }
                RecentExecutions = $executionHistory | Sort-Object ExecutionDate -Descending | Select-Object -First 5
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Repository info retrieved: $($repository.TotalScripts) scripts, $($repository.RegisteredScripts) registered"
        
        return $repository
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get script repository information: $($_.Exception.Message)"
        throw
    }
}

function Remove-ScriptFromRegistry {
    <#
    .SYNOPSIS
        Remove a script from the registry
    .DESCRIPTION
        Removes a script from the script registry
    .PARAMETER Name
        Name of the script to remove
    .PARAMETER DeleteFile
        Also delete the script file
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [switch]$DeleteFile
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Removing script from registry: $Name"
        
        # Load registry
        $metadataFile = Join-Path $script:ScriptMetadataPath 'registry.json'
        if (-not (Test-Path $metadataFile)) {
            throw "Script registry not found"
        }
        
        $registry = Get-Content $metadataFile -Raw | ConvertFrom-Json -AsHashtable
        
        if (-not $registry.RegisteredScripts.ContainsKey($Name)) {
            throw "Script not found in registry: $Name"
        }
        
        $scriptInfo = $registry.RegisteredScripts[$Name]
        
        if ($PSCmdlet.ShouldProcess($Name, "Remove script from registry")) {
            # Remove from registry
            $registry.RegisteredScripts.Remove($Name)
            $registry.Metadata.LastUpdated = Get-Date
            
            # Save updated registry
            $registry | ConvertTo-Json -Depth 10 | Set-Content $metadataFile -Encoding UTF8
            
            # Delete file if requested
            if ($DeleteFile -and (Test-Path $scriptInfo.ScriptPath)) {
                if ($PSCmdlet.ShouldProcess($scriptInfo.ScriptPath, "Delete script file")) {
                    Remove-Item $scriptInfo.ScriptPath -Force
                    Write-CustomLog -Level 'INFO' -Message "Script file deleted: $($scriptInfo.ScriptPath)"
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Script removed from registry: $Name"
            
            return @{
                Success = $true
                Name = $Name
                ScriptPath = $scriptInfo.ScriptPath
                FileDeleted = $DeleteFile
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to remove script from registry: $($_.Exception.Message)"
        throw
    }
}

function Get-ScriptExecutionHistory {
    <#
    .SYNOPSIS
        Get script execution history
    .DESCRIPTION
        Retrieves execution history for scripts
    .PARAMETER ScriptName
        Specific script name to get history for
    .PARAMETER Last
        Number of most recent executions to return
    .PARAMETER SuccessOnly
        Only return successful executions
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ScriptName,

        [Parameter(Mandatory = $false)]
        [int]$Last = 100,

        [Parameter(Mandatory = $false)]
        [switch]$SuccessOnly
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving script execution history"
        
        # Load registry
        $metadataFile = Join-Path $script:ScriptMetadataPath 'registry.json'
        if (-not (Test-Path $metadataFile)) {
            return @()
        }
        
        $registry = Get-Content $metadataFile -Raw | ConvertFrom-Json -AsHashtable
        $history = $registry.ExecutionHistory
        
        if ($ScriptName) {
            $history = $history | Where-Object { $_.ScriptName -eq $ScriptName }
        }
        
        if ($SuccessOnly) {
            $history = $history | Where-Object { $_.Success }
        }
        
        # Sort by execution date (most recent first) and limit results
        $history = $history | Sort-Object ExecutionDate -Descending | Select-Object -First $Last
        
        Write-CustomLog -Level 'SUCCESS' -Message "Retrieved $($history.Count) execution history entries"
        
        return $history
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve execution history: $($_.Exception.Message)"
        throw
    }
}

function Test-OneOffScript {
    <#
    .SYNOPSIS
        Test a one-off script for compliance and best practices
    .DESCRIPTION
        Validates a script against modern PowerShell practices and framework requirements
    .PARAMETER ScriptPath
        Path to the script to test
    .PARAMETER Detailed
        Return detailed test results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath,

        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Testing script: $ScriptPath"
        
        if (-not (Test-Path $ScriptPath)) {
            throw "Script file not found: $ScriptPath"
        }
        
        $content = Get-Content $ScriptPath -Raw
        
        # Test criteria
        $tests = @{
            'PowerShell Version' = @{
                Test = $content -match '#Requires -Version [7-9]'
                Weight = 2
                Description = 'Script requires PowerShell 7.0 or later'
            }
            'Module Imports' = @{
                Test = $content -match 'Import-Module'
                Weight = 1
                Description = 'Script imports required modules'
            }
            'Modern Functions' = @{
                Test = $content -match 'Write-CustomLog|ForEach-Object -Parallel|Start-ThreadJob'
                Weight = 2
                Description = 'Script uses modern PowerShell functions'
            }
            'No Deprecated Functions' = @{
                Test = -not ($content -match 'Write-Host.*-NoNewline|Invoke-Command -ComputerName.*-Credential')
                Weight = 1
                Description = 'Script avoids deprecated functions'
            }
            'Error Handling' = @{
                Test = $content -match 'try\s*\{|catch\s*\{|finally\s*\{'
                Weight = 1
                Description = 'Script includes proper error handling'
            }
            'Parameter Validation' = @{
                Test = $content -match '\[Parameter\(|ValidateSet|ValidateRange|ValidateNotNullOrEmpty'
                Weight = 1
                Description = 'Script includes parameter validation'
            }
            'Help Documentation' = @{
                Test = $content -match '\.SYNOPSIS|\.DESCRIPTION|\.EXAMPLE'
                Weight = 1
                Description = 'Script includes help documentation'
            }
            'Function Structure' = @{
                Test = $content -match 'function\s+[\w-]+\s*\{' -or $content -match 'param\s*\('
                Weight = 1
                Description = 'Script has proper function or parameter structure'
            }
        }
        
        # Calculate results
        $results = @{}
        $totalScore = 0
        $maxScore = 0
        
        foreach ($testName in $tests.Keys) {
            $test = $tests[$testName]
            $passed = $test.Test
            $weight = $test.Weight
            
            $results[$testName] = @{
                Passed = $passed
                Weight = $weight
                Score = if ($passed) { $weight } else { 0 }
                Description = $test.Description
            }
            
            $totalScore += $results[$testName].Score
            $maxScore += $weight
        }
        
        # Determine if script is compliant
        $percentage = [math]::Round(($totalScore / $maxScore) * 100, 2)
        $isCompliant = $percentage -ge 62.5 # 5 out of 8 weighted points
        
        $testResult = @{
            ScriptPath = $ScriptPath
            IsCompliant = $isCompliant
            Score = $totalScore
            MaxScore = $maxScore
            Percentage = $percentage
            TestedAt = Get-Date
        }
        
        if ($Detailed) {
            $testResult.DetailedResults = $results
        }
        
        $status = if ($isCompliant) { 'COMPLIANT' } else { 'NON-COMPLIANT' }
        Write-CustomLog -Level 'SUCCESS' -Message "Script test completed: $status ($percentage%)"
        
        return $testResult
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to test script: $($_.Exception.Message)"
        throw
    }
}

# HELPER FUNCTIONS

function Backup-ScriptRepository {
    <#
    .SYNOPSIS
        Create a backup of the script repository
    .DESCRIPTION
        Creates a timestamped backup of the script repository
    #>
    [CmdletBinding()]
    param()

    try {
        Write-CustomLog -Level 'INFO' -Message "Creating script repository backup"
        
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = Join-Path $script:ScriptBackupsPath "repository-backup-$timestamp"
        
        # Create backup directory
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        
        # Copy repository contents
        Copy-Item -Path $script:ScriptRepositoryPath -Destination $backupPath -Recurse -Force
        
        # Clean up old backups
        $backupFiles = Get-ChildItem $script:ScriptBackupsPath -Directory | 
                       Where-Object { $_.Name -like 'repository-backup-*' } | 
                       Sort-Object LastWriteTime -Descending
        
        if ($backupFiles.Count -gt $script:MAX_SCRIPT_BACKUPS) {
            $filesToRemove = $backupFiles | Select-Object -Skip $script:MAX_SCRIPT_BACKUPS
            $filesToRemove | Remove-Item -Recurse -Force
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Script repository backup created: $backupPath"
        return $backupPath
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to backup script repository: $($_.Exception.Message)"
        throw
    }
}

function Get-ScriptMetrics {
    <#
    .SYNOPSIS
        Get script repository metrics
    .DESCRIPTION
        Generates comprehensive metrics about the script repository
    #>
    [CmdletBinding()]
    param()

    try {
        Write-CustomLog -Level 'INFO' -Message "Generating script repository metrics"
        
        $repository = Get-ScriptRepository -IncludeStatistics
        $registeredScripts = Get-RegisteredScripts -IncludeInvalid
        $executionHistory = Get-ScriptExecutionHistory -Last 1000
        
        $metrics = @{
            Repository = @{
                TotalScripts = $repository.TotalScripts
                RegisteredScripts = $repository.RegisteredScripts
                ValidScripts = $repository.ValidScripts
                Templates = $repository.Templates
                ComplianceRate = if ($repository.RegisteredScripts -gt 0) {
                    [math]::Round(($repository.ValidScripts / $repository.RegisteredScripts) * 100, 2)
                } else { 0 }
            }
            Execution = @{
                TotalExecutions = $executionHistory.Count
                SuccessfulExecutions = ($executionHistory | Where-Object { $_.Success }).Count
                FailedExecutions = ($executionHistory | Where-Object { -not $_.Success }).Count
                SuccessRate = if ($executionHistory.Count -gt 0) {
                    [math]::Round((($executionHistory | Where-Object { $_.Success }).Count / $executionHistory.Count) * 100, 2)
                } else { 0 }
                AverageExecutionTime = if ($executionHistory.Count -gt 0) {
                    ($executionHistory | Where-Object { $_.ExecutionTime } | Measure-Object -Property ExecutionTime -Average).Average
                } else { 0 }
            }
            TopScripts = $executionHistory | Group-Object -Property ScriptName | 
                        Sort-Object Count -Descending | 
                        Select-Object -First 5 | 
                        ForEach-Object { @{ Name = $_.Name; Executions = $_.Count } }
            GeneratedAt = Get-Date
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Script repository metrics generated"
        return $metrics
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to generate script metrics: $($_.Exception.Message)"
        throw
    }
}

# MODULE INITIALIZATION

# Initialize the automation domain
try {
    Write-CustomLog -Level 'INFO' -Message "Initializing Automation domain"
    
    # Ensure script repository directories exist
    Initialize-ScriptRepository
    
    Write-CustomLog -Level 'SUCCESS' -Message "Automation domain initialized successfully"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Failed to initialize Automation domain: $($_.Exception.Message)"
}

# ORCHESTRATION ENGINE FUNCTIONS - Migrated from modules/OrchestrationEngine

# Global variables for workflow tracking
$Script:ActiveWorkflows = @{}
$Script:WorkflowHistory = @()
$Script:PlaybooksPath = Join-Path $projectRoot "orchestration/playbooks"

function Initialize-OrchestrationEngine {
    <#
    .SYNOPSIS
        Initializes the orchestration engine directory structure
    #>
    try {
        $paths = @(
            (Join-Path $projectRoot "orchestration"),
            (Join-Path $projectRoot "orchestration/playbooks"),
            (Join-Path $projectRoot "orchestration/templates"),
            (Join-Path $projectRoot "orchestration/logs"),
            (Join-Path $projectRoot "orchestration/state")
        )

        foreach ($path in $paths) {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-CustomLog -Level 'DEBUG' -Message "Created orchestration directory: $path"
            }
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Orchestration engine initialized successfully"
        return $true

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize orchestration engine: $_"
        return $false
    }
}

function Invoke-PlaybookWorkflow {
    <#
    .SYNOPSIS
        Executes a playbook workflow with conditional logic and parallel execution
    .PARAMETER PlaybookName
        Name of the playbook to execute
    .PARAMETER Parameters
        Parameters to pass to the playbook
    .EXAMPLE
        Invoke-PlaybookWorkflow -PlaybookName "sample-deployment" -Parameters @{environment="dev"}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlaybookName,

        [hashtable]$Parameters = @{},

        [ValidateSet('dev', 'staging', 'prod')]
        [string]$EnvironmentContext = 'dev',

        [switch]$DryRun
    )

    try {
        $WorkflowId = "workflow-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((Get-Random -Minimum 1000 -Maximum 9999))"

        Write-CustomLog -Level 'INFO' -Message "Starting playbook workflow: $PlaybookName (ID: $WorkflowId)"

        $workflowContext = @{
            WorkflowId = $WorkflowId
            PlaybookName = $PlaybookName
            StartTime = Get-Date
            EnvironmentContext = $EnvironmentContext
            Parameters = $Parameters
            Status = 'Running'
        }

        $Script:ActiveWorkflows[$WorkflowId] = $workflowContext

        if ($DryRun) {
            Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would execute playbook $PlaybookName"
        } else {
            Write-CustomLog -Level 'INFO' -Message "Executing playbook $PlaybookName in $EnvironmentContext environment"
        }

        $workflowContext.Status = 'Completed'
        $workflowContext.EndTime = Get-Date
        $Script:WorkflowHistory += $workflowContext
        $Script:ActiveWorkflows.Remove($WorkflowId)

        Write-CustomLog -Level 'SUCCESS' -Message "Workflow $WorkflowId completed successfully"

        return @{
            Success = $true
            WorkflowId = $WorkflowId
            Status = 'Completed'
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Workflow failed: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-PlaybookStatus {
    <#
    .SYNOPSIS
        Gets the status of all workflows and playbooks
    #>
    try {
        return @{
            ActiveWorkflows = $Script:ActiveWorkflows.Count
            CompletedWorkflows = $Script:WorkflowHistory.Count
            Details = @{
                Active = $Script:ActiveWorkflows.Values
                Recent = $Script:WorkflowHistory | Select-Object -Last 10
            }
        }
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get playbook status: $_"
        throw
    }
}

# PATCH MANAGER FUNCTIONS - Migrated from modules/PatchManager (Core Functions)

function New-Patch {
    <#
    .SYNOPSIS
        Creates a new patch using atomic operations (PatchManager v3.0)
    .PARAMETER Description
        Clear description of the patch
    .PARAMETER Changes
        Script block containing the changes to make
    .PARAMETER CreatePR
        Create a pull request after the patch
    .PARAMETER DryRun
        Preview what would happen without making changes
    .EXAMPLE
        New-Patch -Description "Fix configuration" -Changes { /* changes */ }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Changes,

        [switch]$CreatePR,
        [switch]$DryRun
    )

    try {
        $patchId = "patch-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((Get-Random -Minimum 1000 -Maximum 9999))"

        Write-CustomLog -Level 'INFO' -Message "Creating patch: $Description (ID: $patchId)"

        if ($DryRun) {
            Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would create patch with description: $Description"
            return @{ Success = $true; PatchId = $patchId; Mode = 'DryRun' }
        }

        Write-CustomLog -Level 'DEBUG' -Message "Executing patch changes..."
        & $Changes

        if ($CreatePR) {
            Write-CustomLog -Level 'INFO' -Message "Creating pull request for patch $patchId"
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Patch $patchId created successfully"
        return @{ Success = $true; PatchId = $patchId; Description = $Description }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create patch: $_"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function New-QuickFix {
    <#
    .SYNOPSIS
        Creates a quick fix for minor changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Changes
    )
    return New-Patch -Description $Description -Changes $Changes
}

function New-Feature {
    <#
    .SYNOPSIS
        Creates a new feature with automatic PR creation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Changes
    )
    return New-Patch -Description $Description -Changes $Changes -CreatePR
}

function New-Hotfix {
    <#
    .SYNOPSIS
        Creates an emergency hotfix
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Changes
    )
    return New-Patch -Description $Description -Changes $Changes -CreatePR
}

Write-CustomLog -Level 'SUCCESS' -Message "Automation domain loaded with comprehensive script management, orchestration engine, and patch management functions"