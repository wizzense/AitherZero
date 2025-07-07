#Requires -Version 7.0

<#
.SYNOPSIS
    Creates the unified AitherZero platform API gateway object.

.DESCRIPTION
    Builds a comprehensive API gateway object that provides organized access
    to all AitherZero modules through a consistent interface pattern.

.PARAMETER Profile
    The platform profile (Minimal, Standard, Full).

.PARAMETER Environment
    The environment configuration.

.NOTES
    This function creates the core API object used by Initialize-AitherPlatform.
    It implements the API gateway pattern for module interaction.
#>

function New-AitherPlatformAPI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Minimal', 'Standard', 'Full')]
        [string]$Profile,
        
        [Parameter()]
        [string]$Environment = 'default'
    )
    
    process {
        try {
            # Create the main platform API object
            $platform = [PSCustomObject]@{
                # Platform metadata
                Profile = $Profile
                Environment = $Environment
                InitializedAt = Get-Date
                Version = "2.0.0"
                
                # Lab automation and orchestration
                Lab = [PSCustomObject]@{
                    Execute = { 
                        param($Operation, $Parameters = @{})
                        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
                            Invoke-LabOperation -Operation $Operation -Parameters $Parameters
                        } else {
                            throw "LabRunner module not available. Initialize with Standard or Full profile."
                        }
                    }
                    Status = { 
                        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
                            Get-LabStatus
                        } else {
                            @{ Status = "LabRunner not loaded"; Available = $false }
                        }
                    }
                    Scripts = { 
                        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
                            Get-LabScripts
                        } else {
                            @()
                        }
                    }
                    Deploy = { 
                        param($ConfigPath)
                        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
                            Start-LabAutomation -ConfigPath $ConfigPath
                        } else {
                            throw "LabRunner module not available"
                        }
                    }
                    Automation = {
                        param([switch]$Auto)
                        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
                            Start-LabAutomation -Auto:$Auto
                        } else {
                            throw "LabRunner module not available"
                        }
                    }
                }
                
                # Configuration management (unified)
                Configuration = [PSCustomObject]@{
                    Get = { 
                        param($ModuleName, $Key = $null)
                        if (Get-Module ConfigurationCore -ErrorAction SilentlyContinue) {
                            if ($Key) {
                                Get-ModuleConfiguration -ModuleName $ModuleName -Key $Key
                            } else {
                                Get-ModuleConfiguration -ModuleName $ModuleName
                            }
                        } else {
                            throw "ConfigurationCore module not available"
                        }
                    }
                    Set = { 
                        param($ModuleName, $Key, $Value)
                        if (Get-Module ConfigurationCore -ErrorAction SilentlyContinue) {
                            Set-ModuleConfiguration -ModuleName $ModuleName -Key $Key -Value $Value
                        } else {
                            throw "ConfigurationCore module not available"
                        }
                    }
                    Switch = { 
                        param($Environment)
                        if (Get-Module ConfigurationCarousel -ErrorAction SilentlyContinue) {
                            Switch-ConfigurationSet -Environment $Environment
                        } else {
                            throw "ConfigurationCarousel module not available"
                        }
                    }
                    Validate = {
                        param($ModuleName)
                        if (Get-Module ConfigurationCore -ErrorAction SilentlyContinue) {
                            Test-ModuleConfiguration -ModuleName $ModuleName
                        } else {
                            throw "ConfigurationCore module not available"
                        }
                    }
                    Repository = {
                        param($Action, $Parameters = @{})
                        if (Get-Module ConfigurationRepository -ErrorAction SilentlyContinue) {
                            switch ($Action) {
                                'Clone' { Clone-ConfigurationRepository @Parameters }
                                'Sync' { Sync-ConfigurationRepository @Parameters }
                                'Create' { New-ConfigurationRepository @Parameters }
                                default { throw "Unknown action: $Action" }
                            }
                        } else {
                            throw "ConfigurationRepository module not available"
                        }
                    }
                }
                
                # Orchestration and workflows
                Orchestration = [PSCustomObject]@{
                    RunPlaybook = { 
                        param($PlaybookName, $Parameters = @{})
                        if (Get-Module OrchestrationEngine -ErrorAction SilentlyContinue) {
                            Invoke-PlaybookWorkflow -PlaybookName $PlaybookName -Parameters $Parameters
                        } else {
                            throw "OrchestrationEngine module not available"
                        }
                    }
                    GetStatus = { 
                        if (Get-Module OrchestrationEngine -ErrorAction SilentlyContinue) {
                            Get-PlaybookStatus
                        } else {
                            @{ Status = "OrchestrationEngine not loaded" }
                        }
                    }
                    StopWorkflow = { 
                        param($WorkflowId)
                        if (Get-Module OrchestrationEngine -ErrorAction SilentlyContinue) {
                            Stop-PlaybookWorkflow -WorkflowId $WorkflowId
                        } else {
                            throw "OrchestrationEngine module not available"
                        }
                    }
                    ListPlaybooks = { 
                        if (Get-Module OrchestrationEngine -ErrorAction SilentlyContinue) {
                            Get-AvailablePlaybooks
                        } else {
                            @()
                        }
                    }
                }
                
                # Development and patch management
                Patch = [PSCustomObject]@{
                    Create = { 
                        param($Description, $Operation, [switch]$CreatePR)
                        if (Get-Module PatchManager -ErrorAction SilentlyContinue) {
                            Invoke-PatchWorkflow -PatchDescription $Description -PatchOperation $Operation -CreatePR:$CreatePR
                        } else {
                            throw "PatchManager module not available. Use Full profile for development tools."
                        }
                    }
                    Rollback = { 
                        param($Type = "LastCommit")
                        if (Get-Module PatchManager -ErrorAction SilentlyContinue) {
                            Invoke-PatchRollback -RollbackType $Type
                        } else {
                            throw "PatchManager module not available"
                        }
                    }
                    Validate = {
                        param($ModuleName)
                        if (Get-Module PatchManager -ErrorAction SilentlyContinue) {
                            Invoke-PatchValidation -ModuleName $ModuleName
                        } else {
                            throw "PatchManager module not available"
                        }
                    }
                    Status = { 
                        if (Get-Module PatchManager -ErrorAction SilentlyContinue) {
                            Get-PatchStatus
                        } else {
                            @{ Status = "PatchManager not loaded" }
                        }
                    }
                }
                
                # Testing framework
                Testing = [PSCustomObject]@{
                    Run = { 
                        param($ValidationLevel = "Standard")
                        if (Get-Module TestingFramework -ErrorAction SilentlyContinue) {
                            ./tests/Run-BulletproofValidation.ps1 -ValidationLevel $ValidationLevel
                        } else {
                            throw "TestingFramework module not available"
                        }
                    }
                    Module = { 
                        param($ModuleName)
                        if (Get-Module TestingFramework -ErrorAction SilentlyContinue) {
                            ./tests/Invoke-DynamicTests.ps1 -ModuleName $ModuleName
                        } else {
                            throw "TestingFramework module not available"
                        }
                    }
                    Coverage = { 
                        if (Get-Module TestingFramework -ErrorAction SilentlyContinue) {
                            ./tests/Run-CodeCoverage.ps1
                        } else {
                            throw "TestingFramework module not available"
                        }
                    }
                    Performance = { 
                        ./Test-PerformanceMonitoring.ps1
                    }
                    Quick = {
                        if (Get-Module TestingFramework -ErrorAction SilentlyContinue) {
                            ./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick
                        } else {
                            throw "TestingFramework module not available"
                        }
                    }
                }
                
                # Infrastructure deployment
                Infrastructure = [PSCustomObject]@{
                    Deploy = { 
                        param($TemplatePath, $Parameters = @{})
                        if (Get-Module OpenTofuProvider -ErrorAction SilentlyContinue) {
                            Invoke-OpenTofuDeployment -TemplatePath $TemplatePath -Parameters $Parameters
                        } else {
                            throw "OpenTofuProvider module not available"
                        }
                    }
                    Plan = { 
                        param($TemplatePath)
                        if (Get-Module OpenTofuProvider -ErrorAction SilentlyContinue) {
                            Get-OpenTofuPlan -TemplatePath $TemplatePath
                        } else {
                            throw "OpenTofuProvider module not available"
                        }
                    }
                    Destroy = { 
                        param($TemplatePath)
                        if (Get-Module OpenTofuProvider -ErrorAction SilentlyContinue) {
                            Remove-OpenTofuDeployment -TemplatePath $TemplatePath
                        } else {
                            throw "OpenTofuProvider module not available"
                        }
                    }
                    Status = { 
                        if (Get-Module OpenTofuProvider -ErrorAction SilentlyContinue) {
                            Get-InfrastructureStatus
                        } else {
                            @{ Status = "OpenTofuProvider not loaded" }
                        }
                    }
                }
                
                # ISO management
                ISO = [PSCustomObject]@{
                    Download = { 
                        param($ISOName, $Destination = $null)
                        if (Get-Module ISOManager -ErrorAction SilentlyContinue) {
                            Get-ISODownload -ISOName $ISOName -Destination $Destination
                        } else {
                            throw "ISOManager module not available"
                        }
                    }
                    Customize = { 
                        param($SourceISO, $CustomizationProfile)
                        if (Get-Module ISOCustomizer -ErrorAction SilentlyContinue) {
                            New-CustomISO -SourceISO $SourceISO -Profile $CustomizationProfile
                        } else {
                            throw "ISOCustomizer module not available"
                        }
                    }
                    Inventory = { 
                        if (Get-Module ISOManager -ErrorAction SilentlyContinue) {
                            Get-ISOInventory
                        } else {
                            @()
                        }
                    }
                    Repository = { 
                        param($Path)
                        if (Get-Module ISOManager -ErrorAction SilentlyContinue) {
                            New-ISORepository -RepositoryPath $Path
                        } else {
                            throw "ISOManager module not available"
                        }
                    }
                }
                
                # Backup and maintenance
                Maintenance = [PSCustomObject]@{
                    Backup = { 
                        param($Mode = "Standard")
                        if (Get-Module BackupManager -ErrorAction SilentlyContinue) {
                            Start-BackupOperation -Mode $Mode
                        } else {
                            throw "BackupManager module not available"
                        }
                    }
                    Clean = { 
                        if (Get-Module BackupManager -ErrorAction SilentlyContinue) {
                            Remove-OldBackups
                        } else {
                            throw "BackupManager module not available"
                        }
                    }
                    Health = { Test-CoreApplicationHealth }
                    Unified = { 
                        param($Mode = "Quick")
                        Invoke-UnifiedMaintenance -Mode $Mode
                    }
                }
                
                # Progress tracking
                Progress = [PSCustomObject]@{
                    Start = { 
                        param($OperationName, $TotalSteps)
                        if (Get-Module ProgressTracking -ErrorAction SilentlyContinue) {
                            Start-ProgressOperation -OperationName $OperationName -TotalSteps $TotalSteps
                        } else {
                            throw "ProgressTracking module not available"
                        }
                    }
                    Update = { 
                        param($OperationId, $StepName)
                        if (Get-Module ProgressTracking -ErrorAction SilentlyContinue) {
                            Update-ProgressOperation -OperationId $OperationId -StepName $StepName
                        } else {
                            throw "ProgressTracking module not available"
                        }
                    }
                    Complete = { 
                        param($OperationId)
                        if (Get-Module ProgressTracking -ErrorAction SilentlyContinue) {
                            Complete-ProgressOperation -OperationId $OperationId
                        } else {
                            throw "ProgressTracking module not available"
                        }
                    }
                    Multi = {
                        param($Title, $Operations)
                        if (Get-Module ProgressTracking -ErrorAction SilentlyContinue) {
                            Start-MultiProgress -Title $Title -Operations $Operations
                        } else {
                            throw "ProgressTracking module not available"
                        }
                    }
                }
                
                # Platform management and status
                Platform = [PSCustomObject]@{
                    Status = { Get-PlatformStatus }
                    Modules = { Get-CoreModuleStatus }
                    Health = { Get-PlatformHealth }
                    Toolset = { Get-IntegratedToolset }
                    Lifecycle = { Get-PlatformLifecycle }
                    Reload = {
                        param([switch]$Force)
                        Initialize-CoreApplication -Force:$Force
                    }
                }
                
                # Communication and events
                Communication = [PSCustomObject]@{
                    Publish = { 
                        param($Channel, $Event, $Data)
                        if (Get-Module ModuleCommunication -ErrorAction SilentlyContinue) {
                            Publish-ModuleEvent -Channel $Channel -Event $Event -Data $Data
                        } else {
                            # Fallback to basic event system
                            Publish-TestEvent -EventName $Event -EventData $Data
                        }
                    }
                    Subscribe = { 
                        param($Channel, $EventPattern, $Handler)
                        if (Get-Module ModuleCommunication -ErrorAction SilentlyContinue) {
                            Subscribe-ModuleEvent -Channel $Channel -EventPattern $EventPattern -Handler $Handler
                        } else {
                            # Fallback to basic event system
                            Subscribe-TestEvent -EventName $EventPattern -Action $Handler
                        }
                    }
                    API = { 
                        param($Module, $Operation, $Parameters)
                        if (Get-Module ModuleCommunication -ErrorAction SilentlyContinue) {
                            Invoke-ModuleAPI -Module $Module -Operation $Operation -Parameters $Parameters
                        } else {
                            throw "ModuleCommunication module not available"
                        }
                    }
                }
                
                # Quick actions for common tasks
                Quick = [PSCustomObject]@{
                    CreateISO = { 
                        param($ISOName = "Windows11")
                        Start-QuickAction -Action "CreateISO" -Parameters @{ ISOName = $ISOName }
                    }
                    RunTests = { 
                        param($Level = "Standard")
                        Start-QuickAction -Action "RunTests" -Parameters @{ ValidationLevel = $Level }
                    }
                    LabSetup = { 
                        param($Parameters = @{})
                        Start-QuickAction -Action "LabSetup" -Parameters $Parameters
                    }
                    SystemHealth = { Start-QuickAction -Action "SystemHealth" }
                    ModuleStatus = { Start-QuickAction -Action "ModuleStatus" }
                }
                
                # Integrated workflows
                Workflows = [PSCustomObject]@{
                    ISO = { 
                        param($Parameters = @{})
                        Invoke-IntegratedWorkflow -WorkflowType "ISOWorkflow" -Parameters $Parameters
                    }
                    Development = { 
                        param($Parameters = @{})
                        Invoke-IntegratedWorkflow -WorkflowType "DevelopmentWorkflow" -Parameters $Parameters
                    }
                    Lab = { 
                        param($Parameters = @{})
                        Invoke-IntegratedWorkflow -WorkflowType "LabDeployment" -Parameters $Parameters
                    }
                    Maintenance = { 
                        param($Parameters = @{})
                        Invoke-IntegratedWorkflow -WorkflowType "MaintenanceOperations" -Parameters $Parameters
                    }
                }
                
                # Security and credentials
                Security = [PSCustomObject]@{
                    GetCredential = {
                        param($Name)
                        if (Get-Module SecureCredentials -ErrorAction SilentlyContinue) {
                            Get-SecureCredential -Name $Name
                        } else {
                            throw "SecureCredentials module not available"
                        }
                    }
                    SetCredential = {
                        param($Name, $Credential)
                        if (Get-Module SecureCredentials -ErrorAction SilentlyContinue) {
                            Set-SecureCredential -Name $Name -Credential $Credential
                        } else {
                            throw "SecureCredentials module not available"
                        }
                    }
                    Automation = {
                        param($Action, $Parameters = @{})
                        if (Get-Module SecurityAutomation -ErrorAction SilentlyContinue) {
                            & "Invoke-Security$Action" @Parameters
                        } else {
                            throw "SecurityAutomation module not available"
                        }
                    }
                }
                
                # Remote connections
                Remote = [PSCustomObject]@{
                    Connect = {
                        param($Target, $Protocol = "WinRM")
                        if (Get-Module RemoteConnection -ErrorAction SilentlyContinue) {
                            Connect-RemoteSystem -Target $Target -Protocol $Protocol
                        } else {
                            throw "RemoteConnection module not available"
                        }
                    }
                    Test = {
                        param($Target)
                        if (Get-Module RemoteConnection -ErrorAction SilentlyContinue) {
                            Test-RemoteConnection -Target $Target
                        } else {
                            throw "RemoteConnection module not available"
                        }
                    }
                    Disconnect = {
                        param($SessionId)
                        if (Get-Module RemoteConnection -ErrorAction SilentlyContinue) {
                            Disconnect-RemoteSession -SessionId $SessionId
                        } else {
                            throw "RemoteConnection module not available"
                        }
                    }
                }
            }
            
            # Add TypeName for better object identification
            $platform.PSObject.TypeNames.Insert(0, 'AitherZero.PlatformAPI')
            
            Write-CustomLog -Message "✅ Platform API gateway created with $($platform.PSObject.Properties.Count) service categories" -Level "SUCCESS"
            
            return $platform
            
        } catch {
            Write-CustomLog -Message "❌ Failed to create platform API: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}