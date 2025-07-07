function Start-ISOLifecycleWorkflow {
    <#
    .SYNOPSIS
        Orchestrates complete ISO lifecycle workflow from download to deployment-ready customization.

    .DESCRIPTION
        This unified workflow function combines download, customization, and deployment preparation
        into a single streamlined process. It handles the complete ISO lifecycle including:
        - Source ISO download or validation
        - Repository management and metadata tracking
        - ISO customization with autounattend files and scripts
        - Deployment-ready ISO creation with validation
        - Progress tracking and comprehensive logging

    .PARAMETER ISOName
        Name of the ISO to process (for downloads) or display name for custom ISOs

    .PARAMETER ISOSource
        Source for the ISO. Can be:
        - 'Download' - Download from supported sources
        - 'Local' - Use existing local ISO file
        - 'Repository' - Use ISO from configured repository

    .PARAMETER SourcePath
        Path to source ISO file (required when ISOSource is 'Local')

    .PARAMETER DownloadConfig
        Configuration for ISO download (when ISOSource is 'Download')
        Hashtable containing download parameters

    .PARAMETER CustomizationConfig
        Configuration for ISO customization
        Hashtable containing customization parameters

    .PARAMETER OutputPath
        Path for the final deployment-ready ISO

    .PARAMETER WorkflowName
        Name for this workflow instance (for tracking and logging)

    .PARAMETER RepositoryPath
        Path to ISO repository (uses default if not specified)

    .PARAMETER SkipDownload
        Skip download phase (use existing ISO)

    .PARAMETER SkipCustomization
        Skip customization phase (output source ISO)

    .PARAMETER SkipValidation
        Skip final validation of created ISO

    .PARAMETER WhatIf
        Preview the workflow without executing

    .PARAMETER Force
        Force overwrite of existing files

    .EXAMPLE
        # Complete workflow: Download Windows 11 and create custom deployment ISO
        $downloadConfig = @{
            ISOType = 'Windows'
            Version = 'latest'
            Architecture = 'x64'
            Language = 'en-US'
        }
        
        $customConfig = @{
            ComputerName = 'LAB-PC-01'
            AdminPassword = 'P@ssw0rd123!'
            TimeZone = 'Pacific Standard Time'
            EnableRDP = $true
            AutoLogon = $true
            BootstrapScript = '.\Scripts\lab-setup.ps1'
        }
        
        Start-ISOLifecycleWorkflow -ISOName "Windows11" -ISOSource "Download" `
            -DownloadConfig $downloadConfig -CustomizationConfig $customConfig `
            -OutputPath "C:\ISOs\Windows11-Lab-Ready.iso" -WorkflowName "Lab-Setup"

    .EXAMPLE
        # Customize existing ISO with enterprise configuration
        $enterpriseConfig = @{
            OSType = 'Server2025'
            Edition = 'Datacenter'
            ComputerName = 'DC-01'
            Organization = 'Contoso Corp'
            TimeZone = 'Eastern Standard Time'
            DriversPath = @('D:\Drivers\Network', 'D:\Drivers\Storage')
            FirstLogonCommands = @(
                @{
                    CommandLine = 'powershell -ExecutionPolicy Bypass -File C:\Scripts\domain-setup.ps1'
                    Description = 'Configure Domain Controller'
                }
            )
        }
        
        Start-ISOLifecycleWorkflow -ISOName "WindowsServer2025" -ISOSource "Local" `
            -SourcePath "D:\ISOs\WindowsServer2025.iso" -CustomizationConfig $enterpriseConfig `
            -OutputPath "D:\ISOs\DC-01-Ready.iso" -WorkflowName "DC-Deployment"

    .EXAMPLE
        # Preview workflow without execution
        Start-ISOLifecycleWorkflow -ISOName "Ubuntu22.04" -ISOSource "Download" `
            -DownloadConfig @{ISOType='Linux'; Version='22.04'} `
            -OutputPath "C:\ISOs\Ubuntu-Custom.iso" -WhatIf

    .OUTPUTS
        PSCustomObject with workflow results including:
        - WorkflowId: Unique identifier for this workflow
        - Status: Success/Failed/Partial
        - Phases: Details of each workflow phase
        - OutputISO: Path to final deployment-ready ISO
        - Metadata: Comprehensive metadata about the workflow
        - Performance: Timing and resource usage information
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ISOName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Download', 'Local', 'Repository')]
        [string]$ISOSource,

        [Parameter(Mandatory = $false)]
        [string]$SourcePath,

        [Parameter(Mandatory = $false)]
        [hashtable]$DownloadConfig = @{},

        [Parameter(Mandatory = $false)]
        [hashtable]$CustomizationConfig = @{},

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$WorkflowName = "ISO-Workflow-$(Get-Date -Format 'yyyyMMdd-HHmmss')",

        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $false)]
        [switch]$SkipDownload,

        [Parameter(Mandatory = $false)]
        [switch]$SkipCustomization,

        [Parameter(Mandatory = $false)]
        [switch]$SkipValidation,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        # Initialize workflow tracking
        $workflowId = "WF-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([System.Guid]::NewGuid().ToString().Substring(0,8))"
        $workflowStart = Get-Date
        
        Write-CustomLog -Level 'INFO' -Message "Starting ISO lifecycle workflow: $WorkflowName (ID: $workflowId)"
        
        # Validate parameters
        if ($ISOSource -eq 'Local' -and -not $SourcePath) {
            throw "SourcePath is required when ISOSource is 'Local'"
        }
        
        if ($ISOSource -eq 'Download' -and $SkipDownload) {
            throw "Cannot skip download when ISOSource is 'Download'"
        }
        
        # Use default repository if not specified
        if (-not $RepositoryPath) {
            $RepositoryPath = $script:ISOManagementConfig.DefaultRepositoryPath
        }
        
        # Initialize workflow result object
        $workflowResult = [PSCustomObject]@{
            WorkflowId = $workflowId
            WorkflowName = $WorkflowName
            Status = 'InProgress'
            StartTime = $workflowStart
            EndTime = $null
            Duration = $null
            ISOName = $ISOName
            ISOSource = $ISOSource
            SourcePath = $SourcePath
            OutputPath = $OutputPath
            RepositoryPath = $RepositoryPath
            Phases = @{
                Download = @{Status = 'NotStarted'; StartTime = $null; EndTime = $null; Result = $null}
                Customization = @{Status = 'NotStarted'; StartTime = $null; EndTime = $null; Result = $null}
                Validation = @{Status = 'NotStarted'; StartTime = $null; EndTime = $null; Result = $null}
                Repository = @{Status = 'NotStarted'; StartTime = $null; EndTime = $null; Result = $null}
            }
            Configuration = @{
                Download = $DownloadConfig
                Customization = $CustomizationConfig
                Flags = @{
                    SkipDownload = $SkipDownload.IsPresent
                    SkipCustomization = $SkipCustomization.IsPresent
                    SkipValidation = $SkipValidation.IsPresent
                    Force = $Force.IsPresent
                    WhatIf = $WhatIfPreference
                }
            }
            OutputISO = $null
            Metadata = @{}
            Performance = @{}
            Errors = @()
        }
        
        # Preview mode
        if ($WhatIfPreference) {
            Write-Host "=== ISO Lifecycle Workflow Preview ===" -ForegroundColor Yellow
            Write-Host "Workflow: $WorkflowName (ID: $workflowId)" -ForegroundColor White
            Write-Host "ISO Name: $ISOName" -ForegroundColor White
            Write-Host "Source: $ISOSource" -ForegroundColor White
            if ($SourcePath) { Write-Host "Source Path: $SourcePath" -ForegroundColor White }
            Write-Host "Output: $OutputPath" -ForegroundColor White
            Write-Host "Repository: $RepositoryPath" -ForegroundColor White
            Write-Host ""
            Write-Host "Planned Phases:" -ForegroundColor Green
            if (-not $SkipDownload -and $ISOSource -eq 'Download') {
                Write-Host "  1. Download Phase: Download $ISOName from configured source" -ForegroundColor Gray
            }
            if (-not $SkipCustomization) {
                Write-Host "  2. Customization Phase: Apply configuration and create custom ISO" -ForegroundColor Gray
            }
            if (-not $SkipValidation) {
                Write-Host "  3. Validation Phase: Verify ISO integrity and bootability" -ForegroundColor Gray
            }
            Write-Host "  4. Repository Phase: Update repository metadata and inventory" -ForegroundColor Gray
            Write-Host ""
            return $workflowResult
        }
    }

    process {
        try {
            # Phase 1: Download or Source Validation
            if (-not $SkipDownload) {
                $workflowResult.Phases.Download.Status = 'InProgress'
                $workflowResult.Phases.Download.StartTime = Get-Date
                
                Write-CustomLog -Level 'INFO' -Message "Phase 1: ISO Source Processing"
                
                switch ($ISOSource) {
                    'Download' {
                        Write-CustomLog -Level 'INFO' -Message "Downloading ISO: $ISOName"
                        
                        # Prepare download parameters
                        $downloadParams = @{
                            ISOName = $ISOName
                            DownloadPath = Join-Path $RepositoryPath "Downloads"
                            VerifyIntegrity = $true
                            ShowProgress = $true
                        }
                        
                        # Merge user-provided download config
                        foreach ($key in $DownloadConfig.Keys) {
                            $downloadParams[$key] = $DownloadConfig[$key]
                        }
                        
                        # Execute download
                        $downloadResult = Get-ISODownload @downloadParams
                        
                        if ($downloadResult.Status -eq 'Completed') {
                            $SourcePath = $downloadResult.FilePath
                            $workflowResult.Phases.Download.Status = 'Completed'
                            $workflowResult.Phases.Download.Result = $downloadResult
                            Write-CustomLog -Level 'SUCCESS' -Message "Download completed: $SourcePath"
                        } else {
                            throw "Download failed: $($downloadResult.Error)"
                        }
                    }
                    
                    'Local' {
                        Write-CustomLog -Level 'INFO' -Message "Validating local ISO: $SourcePath"
                        
                        if (-not (Test-Path $SourcePath)) {
                            throw "Source ISO not found: $SourcePath"
                        }
                        
                        # Basic validation
                        $validationResult = Test-ISOIntegrity -ISOPath $SourcePath -ValidationLevel 'Basic'
                        if (-not $validationResult.IsValid) {
                            throw "Source ISO validation failed: $($validationResult.Issues -join ', ')"
                        }
                        
                        $workflowResult.Phases.Download.Status = 'Completed'
                        $workflowResult.Phases.Download.Result = @{
                            Status = 'Validated'
                            FilePath = $SourcePath
                            ValidationResult = $validationResult
                        }
                        Write-CustomLog -Level 'SUCCESS' -Message "Local ISO validated: $SourcePath"
                    }
                    
                    'Repository' {
                        Write-CustomLog -Level 'INFO' -Message "Locating ISO in repository: $ISOName"
                        
                        # Search repository for ISO
                        $inventory = Get-ISOInventory -RepositoryPath $RepositoryPath -ISOType 'All'
                        $foundISO = $inventory | Where-Object { $_.Name -like "*$ISOName*" } | Select-Object -First 1
                        
                        if (-not $foundISO) {
                            throw "ISO not found in repository: $ISOName"
                        }
                        
                        $SourcePath = $foundISO.FilePath
                        $workflowResult.Phases.Download.Status = 'Completed'
                        $workflowResult.Phases.Download.Result = @{
                            Status = 'Located'
                            FilePath = $SourcePath
                            InventoryEntry = $foundISO
                        }
                        Write-CustomLog -Level 'SUCCESS' -Message "Repository ISO located: $SourcePath"
                    }
                }
                
                $workflowResult.Phases.Download.EndTime = Get-Date
            } else {
                Write-CustomLog -Level 'INFO' -Message "Skipping download phase"
                $workflowResult.Phases.Download.Status = 'Skipped'
            }
            
            # Phase 2: Customization
            if (-not $SkipCustomization -and $CustomizationConfig.Count -gt 0) {
                $workflowResult.Phases.Customization.Status = 'InProgress'
                $workflowResult.Phases.Customization.StartTime = Get-Date
                
                Write-CustomLog -Level 'INFO' -Message "Phase 2: ISO Customization"
                
                # Prepare customization parameters
                $customParams = @{
                    SourceISOPath = $SourcePath
                    OutputISOPath = $OutputPath
                    Force = $Force.IsPresent
                }
                
                # Apply customization configuration
                if ($CustomizationConfig.ContainsKey('AutounattendConfig')) {
                    $customParams.AutounattendConfig = $CustomizationConfig.AutounattendConfig
                }
                
                if ($CustomizationConfig.ContainsKey('BootstrapScript')) {
                    $customParams.BootstrapScript = $CustomizationConfig.BootstrapScript
                }
                
                if ($CustomizationConfig.ContainsKey('DriversPath')) {
                    $customParams.DriversPath = $CustomizationConfig.DriversPath
                }
                
                if ($CustomizationConfig.ContainsKey('AdditionalFiles')) {
                    $customParams.AdditionalFiles = $CustomizationConfig.AdditionalFiles
                }
                
                if ($CustomizationConfig.ContainsKey('WIMIndex')) {
                    $customParams.WIMIndex = $CustomizationConfig.WIMIndex
                }
                
                # Execute customization
                $customResult = New-CustomISO @customParams
                
                if ($customResult.Success) {
                    $workflowResult.Phases.Customization.Status = 'Completed'
                    $workflowResult.Phases.Customization.Result = $customResult
                    $workflowResult.OutputISO = $customResult.OutputISO
                    Write-CustomLog -Level 'SUCCESS' -Message "Customization completed: $($customResult.OutputISO)"
                } else {
                    throw "Customization failed: $($customResult.Error)"
                }
                
                $workflowResult.Phases.Customization.EndTime = Get-Date
            } else {
                Write-CustomLog -Level 'INFO' -Message "Skipping customization phase"
                $workflowResult.Phases.Customization.Status = 'Skipped'
                
                # If no customization, copy source to output
                if (-not $SkipCustomization) {
                    Copy-Item -Path $SourcePath -Destination $OutputPath -Force:$Force.IsPresent
                    $workflowResult.OutputISO = $OutputPath
                }
            }
            
            # Phase 3: Validation
            if (-not $SkipValidation -and $workflowResult.OutputISO) {
                $workflowResult.Phases.Validation.Status = 'InProgress'
                $workflowResult.Phases.Validation.StartTime = Get-Date
                
                Write-CustomLog -Level 'INFO' -Message "Phase 3: Final Validation"
                
                $validationResult = Test-ISOIntegrity -ISOPath $workflowResult.OutputISO -ValidationLevel 'Standard' -CheckBootability
                
                if ($validationResult.IsValid) {
                    $workflowResult.Phases.Validation.Status = 'Completed'
                    $workflowResult.Phases.Validation.Result = $validationResult
                    Write-CustomLog -Level 'SUCCESS' -Message "Final validation passed"
                } else {
                    $workflowResult.Phases.Validation.Status = 'Failed'
                    $workflowResult.Phases.Validation.Result = $validationResult
                    $workflowResult.Errors += "Validation failed: $($validationResult.Issues -join ', ')"
                    Write-CustomLog -Level 'WARNING' -Message "Final validation failed: $($validationResult.Issues -join ', ')"
                }
                
                $workflowResult.Phases.Validation.EndTime = Get-Date
            } else {
                Write-CustomLog -Level 'INFO' -Message "Skipping validation phase"
                $workflowResult.Phases.Validation.Status = 'Skipped'
            }
            
            # Phase 4: Repository Update
            $workflowResult.Phases.Repository.Status = 'InProgress'
            $workflowResult.Phases.Repository.StartTime = Get-Date
            
            Write-CustomLog -Level 'INFO' -Message "Phase 4: Repository Update"
            
            try {
                # Update repository with new ISO
                if ($workflowResult.OutputISO -and (Test-Path $workflowResult.OutputISO)) {
                    # Get ISO metadata
                    $metadata = Get-ISOMetadata -FilePath $workflowResult.OutputISO
                    
                    # Add workflow metadata
                    $metadata.WorkflowId = $workflowId
                    $metadata.WorkflowName = $WorkflowName
                    $metadata.SourceISO = $SourcePath
                    $metadata.CreatedBy = 'ISOLifecycleWorkflow'
                    $metadata.CreatedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    
                    $workflowResult.Metadata = $metadata
                    
                    # Sync repository
                    $syncResult = Sync-ISORepository -RepositoryPath $RepositoryPath -UpdateMetadata
                    
                    $workflowResult.Phases.Repository.Status = 'Completed'
                    $workflowResult.Phases.Repository.Result = $syncResult
                    Write-CustomLog -Level 'SUCCESS' -Message "Repository updated successfully"
                }
            } catch {
                $workflowResult.Phases.Repository.Status = 'Failed'
                $workflowResult.Phases.Repository.Result = @{Error = $_.Exception.Message}
                $workflowResult.Errors += "Repository update failed: $($_.Exception.Message)"
                Write-CustomLog -Level 'WARNING' -Message "Repository update failed: $($_.Exception.Message)"
            }
            
            $workflowResult.Phases.Repository.EndTime = Get-Date
            
            # Workflow completion
            $workflowResult.EndTime = Get-Date
            $workflowResult.Duration = $workflowResult.EndTime - $workflowResult.StartTime
            
            # Determine overall status
            $completedPhases = ($workflowResult.Phases.Values | Where-Object { $_.Status -eq 'Completed' }).Count
            $failedPhases = ($workflowResult.Phases.Values | Where-Object { $_.Status -eq 'Failed' }).Count
            $skippedPhases = ($workflowResult.Phases.Values | Where-Object { $_.Status -eq 'Skipped' }).Count
            
            if ($failedPhases -gt 0) {
                $workflowResult.Status = 'Failed'
                Write-CustomLog -Level 'ERROR' -Message "Workflow failed with $failedPhases failed phases"
            } elseif ($completedPhases -gt 0) {
                $workflowResult.Status = 'Success'
                Write-CustomLog -Level 'SUCCESS' -Message "Workflow completed successfully"
            } else {
                $workflowResult.Status = 'Partial'
                Write-CustomLog -Level 'WARNING' -Message "Workflow completed with partial success"
            }
            
            # Performance metrics
            $workflowResult.Performance = @{
                TotalDuration = $workflowResult.Duration
                PhaseDurations = @{}
                CompletedPhases = $completedPhases
                FailedPhases = $failedPhases
                SkippedPhases = $skippedPhases
            }
            
            foreach ($phase in $workflowResult.Phases.Keys) {
                $phaseData = $workflowResult.Phases[$phase]
                if ($phaseData.StartTime -and $phaseData.EndTime) {
                    $workflowResult.Performance.PhaseDurations[$phase] = $phaseData.EndTime - $phaseData.StartTime
                }
            }
            
            # Log workflow to history
            try {
                $historyEntry = @{
                    WorkflowId = $workflowId
                    WorkflowName = $WorkflowName
                    Status = $workflowResult.Status
                    StartTime = $workflowResult.StartTime
                    EndTime = $workflowResult.EndTime
                    Duration = $workflowResult.Duration
                    ISOName = $ISOName
                    OutputISO = $workflowResult.OutputISO
                    Phases = $workflowResult.Phases.Keys | ForEach-Object { "$_`: $($workflowResult.Phases[$_].Status)" }
                }
                
                # Add to workflow history
                $historyPath = $script:ISOManagementConfig.WorkflowHistoryPath
                if (Test-Path $historyPath) {
                    $history = Get-Content $historyPath | ConvertFrom-Json
                    $history.Workflows += $historyEntry
                    
                    # Keep only recent entries
                    if ($history.Workflows.Count -gt $script:ISOManagementConfig.MaxHistoryEntries) {
                        $history.Workflows = $history.Workflows | Sort-Object StartTime -Descending | Select-Object -First $script:ISOManagementConfig.MaxHistoryEntries
                    }
                    
                    $history | ConvertTo-Json -Depth 10 | Out-File -FilePath $historyPath -Encoding UTF8
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Failed to log workflow to history: $($_.Exception.Message)"
            }
            
            Write-CustomLog -Level 'INFO' -Message "Workflow completed: $WorkflowName (Duration: $($workflowResult.Duration))"
            
            return $workflowResult
            
        } catch {
            # Error handling
            $workflowResult.Status = 'Failed'
            $workflowResult.EndTime = Get-Date
            $workflowResult.Duration = $workflowResult.EndTime - $workflowResult.StartTime
            $workflowResult.Errors += $_.Exception.Message
            
            Write-CustomLog -Level 'ERROR' -Message "Workflow failed: $($_.Exception.Message)"
            
            return $workflowResult
        }
    }
}