function Invoke-ISOPipeline {
    <#
    .SYNOPSIS
        Executes a batch ISO processing pipeline for multiple ISOs or configurations.

    .DESCRIPTION
        This function enables batch processing of multiple ISOs through a standardized pipeline,
        supporting bulk operations for enterprise deployments. It can process multiple source ISOs,
        apply different configurations, and create deployment-ready ISOs in parallel or sequential mode.

    .PARAMETER PipelineConfiguration
        Hashtable or path to JSON file containing the pipeline configuration with ISO processing instructions

    .PARAMETER InputISOs
        Array of input ISO specifications. Can be file paths, ISO names for download, or configuration objects

    .PARAMETER OutputDirectory
        Base directory for output ISOs (individual paths can be specified in configuration)

    .PARAMETER ProcessingMode
        Processing mode for the pipeline:
        - 'Sequential' - Process ISOs one at a time (default)
        - 'Parallel' - Process multiple ISOs simultaneously
        - 'Batch' - Process in configurable batch sizes

    .PARAMETER MaxConcurrency
        Maximum number of concurrent operations when using Parallel mode (default: 3)

    .PARAMETER ContinueOnError
        Continue processing remaining ISOs if one fails

    .PARAMETER GenerateReport
        Generate comprehensive processing report

    .PARAMETER TemplateLibrary
        Path to custom template library or 'Default' for built-in templates

    .PARAMETER ValidateOnly
        Validate pipeline configuration without executing

    .EXAMPLE
        # Simple batch processing with template
        $isos = @(
            @{Name = 'DC-01'; Template = 'WindowsServer2025-DC'; SourceISO = 'WindowsServer2025.iso'},
            @{Name = 'FILE-01'; Template = 'WindowsServer2025-Member'; SourceISO = 'WindowsServer2025.iso'},
            @{Name = 'WEB-01'; Template = 'Ubuntu22.04-Server'; SourceISO = 'ubuntu-22.04-server.iso'}
        )
        
        Invoke-ISOPipeline -InputISOs $isos -OutputDirectory 'C:\DeploymentISOs' -ProcessingMode 'Parallel'

    .EXAMPLE
        # Advanced pipeline with configuration file
        $config = @{
            Pipeline = @{
                Name = 'Lab Infrastructure Deployment'
                Version = '1.0'
                ProcessingMode = 'Sequential'
                ContinueOnError = $true
            }
            DefaultSettings = @{
                Organization = 'Contoso Corp'
                TimeZone = 'Eastern Standard Time'
                AdminPassword = 'P@ssw0rd123!'
            }
            ISOs = @(
                @{
                    Name = 'DC-01'
                    Template = 'WindowsServer2025-DC'
                    SourceISO = 'download:WindowsServer2025'
                    ComputerName = 'CONTOSO-DC-01'
                    Configuration = @{
                        DomainName = 'contoso.local'
                        SafeModePassword = 'SafeMode123!'
                    }
                    OutputPath = 'DC-01-Deployment.iso'
                },
                @{
                    Name = 'SQL-01'
                    Template = 'WindowsServer2025-Member'
                    SourceISO = 'WindowsServer2025.iso'
                    ComputerName = 'CONTOSO-SQL-01'
                    Configuration = @{
                        ServerRoles = @('SQL Server 2022')
                        JoinDomain = 'contoso.local'
                    }
                    OutputPath = 'SQL-01-Deployment.iso'
                }
            )
        }
        
        Invoke-ISOPipeline -PipelineConfiguration $config -OutputDirectory 'C:\LabDeployment'

    .EXAMPLE
        # Load configuration from JSON file
        Invoke-ISOPipeline -PipelineConfiguration 'C:\Configs\lab-deployment-pipeline.json' `
            -OutputDirectory 'D:\ISOs\Deployments' -GenerateReport

    .OUTPUTS
        PSCustomObject with pipeline execution results including:
        - PipelineId: Unique identifier for this pipeline execution
        - Status: Overall pipeline status
        - ProcessedISOs: Results for each processed ISO
        - Performance: Timing and resource usage metrics
        - Report: Detailed execution report (if GenerateReport specified)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        $PipelineConfiguration,

        [Parameter(Mandatory = $false)]
        [array]$InputISOs = @(),

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDirectory,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Sequential', 'Parallel', 'Batch')]
        [string]$ProcessingMode = 'Sequential',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10)]
        [int]$MaxConcurrency = 3,

        [Parameter(Mandatory = $false)]
        [switch]$ContinueOnError,

        [Parameter(Mandatory = $false)]
        [switch]$GenerateReport,

        [Parameter(Mandatory = $false)]
        [string]$TemplateLibrary = 'Default',

        [Parameter(Mandatory = $false)]
        [switch]$ValidateOnly
    )

    begin {
        $pipelineId = "PIPE-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([System.Guid]::NewGuid().ToString().Substring(0,8))"
        $pipelineStart = Get-Date
        
        Write-CustomLog -Level 'INFO' -Message "Starting ISO pipeline execution: $pipelineId"
        
        # Initialize pipeline result
        $pipelineResult = [PSCustomObject]@{
            PipelineId = $pipelineId
            Status = 'InProgress'
            StartTime = $pipelineStart
            EndTime = $null
            Duration = $null
            ProcessingMode = $ProcessingMode
            MaxConcurrency = $MaxConcurrency
            ProcessedISOs = @()
            SuccessCount = 0
            FailureCount = 0
            SkippedCount = 0
            Performance = @{}
            Errors = @()
            Report = $null
        }
        
        # Ensure output directory exists
        if (-not (Test-Path $OutputDirectory)) {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
            Write-CustomLog -Level 'INFO' -Message "Created output directory: $OutputDirectory"
        }
    }

    process {
        try {
            # Load and validate pipeline configuration
            $config = Get-PipelineConfiguration -PipelineConfiguration $PipelineConfiguration -InputISOs $InputISOs
            
            if (-not $config -or $config.ISOs.Count -eq 0) {
                throw "No valid ISO configurations found in pipeline"
            }
            
            Write-CustomLog -Level 'INFO' -Message "Pipeline configuration loaded: $($config.ISOs.Count) ISOs to process"
            
            # Validation mode
            if ($ValidateOnly) {
                Write-Host "=== Pipeline Validation ===" -ForegroundColor Yellow
                Write-Host "Pipeline ID: $pipelineId" -ForegroundColor White
                Write-Host "Processing Mode: $ProcessingMode" -ForegroundColor White
                Write-Host "Output Directory: $OutputDirectory" -ForegroundColor White
                Write-Host "ISOs to Process: $($config.ISOs.Count)" -ForegroundColor White
                Write-Host ""
                
                $validationResults = @()
                foreach ($iso in $config.ISOs) {
                    $validation = Test-ISOPipelineConfiguration -ISOConfig $iso -OutputDirectory $OutputDirectory
                    $validationResults += $validation
                    
                    $statusIcon = if ($validation.IsValid) { "$([char]0x2713)" } else { "$([char]0x2717)" }
                    Write-Host "$statusIcon $($iso.Name): $($validation.Status)" -ForegroundColor $(if ($validation.IsValid) { 'Green' } else { 'Red' })
                    
                    if (-not $validation.IsValid) {
                        foreach ($issue in $validation.Issues) {
                            Write-Host "    • $issue" -ForegroundColor Yellow
                        }
                    }
                }
                
                $overallValid = ($validationResults | Where-Object { -not $_.IsValid }).Count -eq 0
                Write-Host ""
                Write-Host "Overall Validation: $(if ($overallValid) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($overallValid) { 'Green' } else { 'Red' })
                
                $pipelineResult.Status = if ($overallValid) { 'Validated' } else { 'ValidationFailed' }
                return $pipelineResult
            }
            
            # Execute pipeline based on processing mode
            switch ($ProcessingMode) {
                'Sequential' {
                    $pipelineResult.ProcessedISOs = Invoke-SequentialProcessing -ISOs $config.ISOs -OutputDirectory $OutputDirectory -ContinueOnError:$ContinueOnError.IsPresent
                }
                
                'Parallel' {
                    $pipelineResult.ProcessedISOs = Invoke-ParallelProcessing -ISOs $config.ISOs -OutputDirectory $OutputDirectory -MaxConcurrency $MaxConcurrency -ContinueOnError:$ContinueOnError.IsPresent
                }
                
                'Batch' {
                    $pipelineResult.ProcessedISOs = Invoke-BatchProcessing -ISOs $config.ISOs -OutputDirectory $OutputDirectory -MaxConcurrency $MaxConcurrency -ContinueOnError:$ContinueOnError.IsPresent
                }
            }
            
            # Calculate statistics
            $pipelineResult.SuccessCount = ($pipelineResult.ProcessedISOs | Where-Object { $_.Status -eq 'Success' }).Count
            $pipelineResult.FailureCount = ($pipelineResult.ProcessedISOs | Where-Object { $_.Status -eq 'Failed' }).Count
            $pipelineResult.SkippedCount = ($pipelineResult.ProcessedISOs | Where-Object { $_.Status -eq 'Skipped' }).Count
            
            # Determine overall status
            if ($pipelineResult.FailureCount -eq 0) {
                $pipelineResult.Status = 'Success'
            } elseif ($pipelineResult.SuccessCount -gt 0) {
                $pipelineResult.Status = 'Partial'
            } else {
                $pipelineResult.Status = 'Failed'
            }
            
            Write-CustomLog -Level 'INFO' -Message "Pipeline completed: $($pipelineResult.SuccessCount) successful, $($pipelineResult.FailureCount) failed, $($pipelineResult.SkippedCount) skipped"
            
        } catch {
            $pipelineResult.Status = 'Failed'
            $pipelineResult.Errors += $_.Exception.Message
            Write-CustomLog -Level 'ERROR' -Message "Pipeline execution failed: $($_.Exception.Message)"
        } finally {
            $pipelineResult.EndTime = Get-Date
            $pipelineResult.Duration = $pipelineResult.EndTime - $pipelineResult.StartTime
            
            # Generate performance metrics
            $pipelineResult.Performance = @{
                TotalDuration = $pipelineResult.Duration
                AverageISOProcessingTime = if ($pipelineResult.ProcessedISOs.Count -gt 0) {
                    [TimeSpan]::FromMilliseconds(($pipelineResult.ProcessedISOs | Measure-Object -Property DurationMs -Average).Average)
                } else { [TimeSpan]::Zero }
                ProcessingRate = if ($pipelineResult.Duration.TotalMinutes -gt 0) {
                    [Math]::Round($pipelineResult.ProcessedISOs.Count / $pipelineResult.Duration.TotalMinutes, 2)
                } else { 0 }
                ConcurrencyEfficiency = if ($ProcessingMode -eq 'Parallel') {
                    Calculate-ConcurrencyEfficiency -ProcessedISOs $pipelineResult.ProcessedISOs -MaxConcurrency $MaxConcurrency
                } else { 'N/A' }
            }
            
            # Generate report if requested
            if ($GenerateReport) {
                $pipelineResult.Report = New-PipelineReport -PipelineResult $pipelineResult -OutputDirectory $OutputDirectory
                Write-CustomLog -Level 'INFO' -Message "Pipeline report generated: $($pipelineResult.Report.ReportPath)"
            }
        }

        return $pipelineResult
    }
}

# Helper function to get pipeline configuration
function Get-PipelineConfiguration {
    param($PipelineConfiguration, $InputISOs)
    
    $config = @{
        Pipeline = @{
            Name = 'ISO Processing Pipeline'
            Version = '1.0'
        }
        DefaultSettings = @{}
        ISOs = @()
    }
    
    # Handle different configuration input types
    if ($PipelineConfiguration -is [string] -and (Test-Path $PipelineConfiguration)) {
        # Load from JSON file
        try {
            $loadedConfig = Get-Content $PipelineConfiguration | ConvertFrom-Json
            $config = Convert-HashtableFromJson $loadedConfig
            Write-CustomLog -Level 'INFO' -Message "Loaded pipeline configuration from file: $PipelineConfiguration"
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to load configuration file: $($_.Exception.Message)"
            throw
        }
    } elseif ($PipelineConfiguration -is [hashtable]) {
        # Use provided hashtable
        $config = $PipelineConfiguration
    } elseif ($InputISOs.Count -gt 0) {
        # Build configuration from InputISOs array
        $config.ISOs = $InputISOs
    } else {
        throw "No valid pipeline configuration or input ISOs provided"
    }
    
    # Validate configuration structure
    if (-not $config.ISOs -or $config.ISOs.Count -eq 0) {
        throw "No ISOs defined in pipeline configuration"
    }
    
    return $config
}

# Helper function for sequential processing
function Invoke-SequentialProcessing {
    param($ISOs, $OutputDirectory, $ContinueOnError)
    
    $results = @()
    $currentIndex = 1
    $totalISOs = $ISOs.Count
    
    foreach ($iso in $ISOs) {
        Write-CustomLog -Level 'INFO' -Message "Processing ISO $currentIndex of $totalISOs`: $($iso.Name)"
        
        $isoStart = Get-Date
        try {
            $result = Process-SingleISO -ISOConfig $iso -OutputDirectory $OutputDirectory
            $result.ProcessingOrder = $currentIndex
            $result.Status = 'Success'
        } catch {
            $result = [PSCustomObject]@{
                Name = $iso.Name
                Status = 'Failed'
                Error = $_.Exception.Message
                ProcessingOrder = $currentIndex
                StartTime = $isoStart
                EndTime = Get-Date
                DurationMs = ((Get-Date) - $isoStart).TotalMilliseconds
            }
            
            Write-CustomLog -Level 'ERROR' -Message "Failed to process ISO $($iso.Name): $($_.Exception.Message)"
            
            if (-not $ContinueOnError) {
                Write-CustomLog -Level 'ERROR' -Message "Stopping pipeline due to error (ContinueOnError not specified)"
                break
            }
        }
        
        $results += $result
        $currentIndex++
        
        # Progress indicator
        $percentComplete = [Math]::Round(($currentIndex - 1) / $totalISOs * 100, 1)
        Write-Progress -Activity "Processing ISO Pipeline" -Status "Processing $($iso.Name)" -PercentComplete $percentComplete
    }
    
    Write-Progress -Activity "Processing ISO Pipeline" -Completed
    return $results
}

# Helper function for parallel processing
function Invoke-ParallelProcessing {
    param($ISOs, $OutputDirectory, $MaxConcurrency, $ContinueOnError)
    
    Write-CustomLog -Level 'INFO' -Message "Starting parallel processing with max concurrency: $MaxConcurrency"
    
    $results = @()
    $runspaces = @()
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxConcurrency)
    $runspacePool.Open()
    
    try {
        # Start runspaces for each ISO
        for ($i = 0; $i -lt $ISOs.Count; $i++) {
            $iso = $ISOs[$i]
            
            $powershell = [powershell]::Create()
            $powershell.RunspacePool = $runspacePool
            
            $scriptBlock = {
                param($ISOConfig, $OutputDir, $ProcessingOrder)
                
                try {
                    $result = Process-SingleISO -ISOConfig $ISOConfig -OutputDirectory $OutputDir
                    $result.ProcessingOrder = $ProcessingOrder
                    $result.Status = 'Success'
                    return $result
                } catch {
                    return [PSCustomObject]@{
                        Name = $ISOConfig.Name
                        Status = 'Failed'
                        Error = $_.Exception.Message
                        ProcessingOrder = $ProcessingOrder
                        StartTime = Get-Date
                        EndTime = Get-Date
                        DurationMs = 0
                    }
                }
            }
            
            $powershell.AddScript($scriptBlock)
            $powershell.AddParameter('ISOConfig', $iso)
            $powershell.AddParameter('OutputDir', $OutputDirectory)
            $powershell.AddParameter('ProcessingOrder', $i + 1)
            
            $runspaces += [PSCustomObject]@{
                PowerShell = $powershell
                AsyncResult = $powershell.BeginInvoke()
                ISO = $iso
                Index = $i
            }
        }
        
        # Wait for completion and collect results
        $completedCount = 0
        while ($runspaces.Count -gt 0) {
            $completed = $runspaces | Where-Object { $_.AsyncResult.IsCompleted }
            
            foreach ($runspace in $completed) {
                try {
                    $result = $runspace.PowerShell.EndInvoke($runspace.AsyncResult)
                    $results += $result
                    $completedCount++
                    
                    Write-CustomLog -Level 'INFO' -Message "Completed ISO processing: $($runspace.ISO.Name) ($completedCount of $($ISOs.Count))"
                } catch {
                    $errorResult = [PSCustomObject]@{
                        Name = $runspace.ISO.Name
                        Status = 'Failed'
                        Error = $_.Exception.Message
                        ProcessingOrder = $runspace.Index + 1
                        StartTime = Get-Date
                        EndTime = Get-Date
                        DurationMs = 0
                    }
                    $results += $errorResult
                    $completedCount++
                    
                    Write-CustomLog -Level 'ERROR' -Message "Runspace error for ISO $($runspace.ISO.Name): $($_.Exception.Message)"
                } finally {
                    $runspace.PowerShell.Dispose()
                }
            }
            
            # Remove completed runspaces
            $runspaces = $runspaces | Where-Object { -not $_.AsyncResult.IsCompleted }
            
            # Progress update
            $percentComplete = [Math]::Round($completedCount / $ISOs.Count * 100, 1)
            Write-Progress -Activity "Processing ISO Pipeline (Parallel)" -Status "Completed: $completedCount of $($ISOs.Count)" -PercentComplete $percentComplete
            
            if ($runspaces.Count -gt 0) {
                Start-Sleep -Milliseconds 500
            }
        }
        
    } finally {
        # Cleanup
        foreach ($runspace in $runspaces) {
            try {
                $runspace.PowerShell.Dispose()
            } catch {
                # Ignore cleanup errors
            }
        }
        
        $runspacePool.Close()
        $runspacePool.Dispose()
        Write-Progress -Activity "Processing ISO Pipeline (Parallel)" -Completed
    }
    
    return $results | Sort-Object ProcessingOrder
}

# Helper function for batch processing
function Invoke-BatchProcessing {
    param($ISOs, $OutputDirectory, $MaxConcurrency, $ContinueOnError)
    
    $batchSize = $MaxConcurrency
    $results = @()
    $totalBatches = [Math]::Ceiling($ISOs.Count / $batchSize)
    
    Write-CustomLog -Level 'INFO' -Message "Starting batch processing: $totalBatches batches of $batchSize ISOs each"
    
    for ($batchIndex = 0; $batchIndex -lt $totalBatches; $batchIndex++) {
        $startIndex = $batchIndex * $batchSize
        $endIndex = [Math]::Min($startIndex + $batchSize - 1, $ISOs.Count - 1)
        $batchISOs = $ISOs[$startIndex..$endIndex]
        
        Write-CustomLog -Level 'INFO' -Message "Processing batch $($batchIndex + 1) of $totalBatches (ISOs $($startIndex + 1)-$($endIndex + 1))"
        
        # Process batch in parallel
        $batchResults = Invoke-ParallelProcessing -ISOs $batchISOs -OutputDirectory $OutputDirectory -MaxConcurrency $batchSize -ContinueOnError $ContinueOnError
        
        # Update processing order to reflect global order
        foreach ($result in $batchResults) {
            $result.ProcessingOrder = $startIndex + $result.ProcessingOrder
        }
        
        $results += $batchResults
        
        # Brief pause between batches
        if ($batchIndex -lt $totalBatches - 1) {
            Start-Sleep -Seconds 2
        }
    }
    
    return $results | Sort-Object ProcessingOrder
}

# Helper function to process a single ISO
function Process-SingleISO {
    param($ISOConfig, $OutputDirectory)
    
    $isoStart = Get-Date
    
    # Determine output path
    $outputPath = if ($ISOConfig.OutputPath) {
        if ([System.IO.Path]::IsPathRooted($ISOConfig.OutputPath)) {
            $ISOConfig.OutputPath
        } else {
            Join-Path $OutputDirectory $ISOConfig.OutputPath
        }
    } else {
        Join-Path $OutputDirectory "$($ISOConfig.Name).iso"
    }
    
    # Execute ISO creation based on configuration
    if ($ISOConfig.Template) {
        # Use template-based creation
        $params = @{
            ISOTemplate = $ISOConfig.Template
            ComputerName = $ISOConfig.ComputerName
            AdminPassword = $ISOConfig.AdminPassword
            SourceISO = $ISOConfig.SourceISO
            OutputPath = $outputPath
        }
        
        # Add optional parameters
        if ($ISOConfig.Organization) { $params.Organization = $ISOConfig.Organization }
        if ($ISOConfig.TimeZone) { $params.TimeZone = $ISOConfig.TimeZone }
        if ($ISOConfig.Configuration) { 
            # Map configuration to appropriate parameters
            if ($ISOConfig.Configuration.DomainName -or $ISOConfig.Configuration.JoinDomain) {
                $params.DomainConfiguration = $ISOConfig.Configuration
            }
            if ($ISOConfig.Configuration.IPAddress) {
                $params.IPConfiguration = $ISOConfig.Configuration
            }
            if ($ISOConfig.Configuration.ContainsKey('AdvancedOptions')) {
                $params.AdvancedOptions = $ISOConfig.Configuration.AdvancedOptions
            }
        }
        
        $result = New-DeploymentReadyISO @params
        
    } else {
        # Use direct customization
        $params = @{
            SourceISOPath = $ISOConfig.SourceISO
            OutputISOPath = $outputPath
        }
        
        if ($ISOConfig.AutounattendConfig) { $params.AutounattendConfig = $ISOConfig.AutounattendConfig }
        if ($ISOConfig.BootstrapScript) { $params.BootstrapScript = $ISOConfig.BootstrapScript }
        if ($ISOConfig.DriversPath) { $params.DriversPath = $ISOConfig.DriversPath }
        
        $result = New-CustomISO @params
    }
    
    # Build result object
    $isoResult = [PSCustomObject]@{
        Name = $ISOConfig.Name
        Status = if ($result.Success) { 'Success' } else { 'Failed' }
        SourceISO = $ISOConfig.SourceISO
        OutputISO = $outputPath
        Template = $ISOConfig.Template
        ComputerName = $ISOConfig.ComputerName
        StartTime = $isoStart
        EndTime = Get-Date
        DurationMs = ((Get-Date) - $isoStart).TotalMilliseconds
        Result = $result
        Error = if (-not $result.Success) { $result.Errors -join '; ' } else { $null }
    }
    
    return $isoResult
}

# Helper function to test ISO pipeline configuration
function Test-ISOPipelineConfiguration {
    param($ISOConfig, $OutputDirectory)
    
    $issues = @()
    $isValid = $true
    
    # Validate required fields
    if (-not $ISOConfig.Name) {
        $issues += "ISO configuration missing Name field"
        $isValid = $false
    }
    
    if (-not $ISOConfig.SourceISO) {
        $issues += "ISO configuration missing SourceISO field"
        $isValid = $false
    }
    
    # Validate source ISO exists or can be downloaded
    if ($ISOConfig.SourceISO -and -not $ISOConfig.SourceISO.StartsWith('download:')) {
        if (-not (Test-Path $ISOConfig.SourceISO)) {
            $issues += "Source ISO file not found: $($ISOConfig.SourceISO)"
            $isValid = $false
        }
    }
    
    # Validate template if specified
    if ($ISOConfig.Template) {
        $templateLibrary = Get-ISOTemplateLibrary
        $template = $templateLibrary | Where-Object { $_.Name -eq $ISOConfig.Template }
        if (-not $template) {
            $issues += "Template not found: $($ISOConfig.Template)"
            $isValid = $false
        }
    }
    
    # Validate computer name if specified
    if ($ISOConfig.ComputerName -and $ISOConfig.ComputerName -notmatch '^[a-zA-Z0-9-]{1,15}$') {
        $issues += "Invalid computer name format: $($ISOConfig.ComputerName)"
        $isValid = $false
    }
    
    # Validate output directory
    $outputDir = Split-Path $OutputDirectory -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        $issues += "Output directory parent path does not exist: $outputDir"
        $isValid = $false
    }
    
    return @{
        IsValid = $isValid
        Status = if ($isValid) { 'Valid' } else { 'Invalid' }
        Issues = $issues
    }
}

# Helper function to calculate concurrency efficiency
function Calculate-ConcurrencyEfficiency {
    param($ProcessedISOs, $MaxConcurrency)
    
    if ($ProcessedISOs.Count -eq 0) { return 0 }
    
    # Calculate theoretical minimum time if perfectly parallel
    $longestDuration = ($ProcessedISOs | Measure-Object -Property DurationMs -Maximum).Maximum
    $totalDuration = ($ProcessedISOs | Measure-Object -Property DurationMs -Sum).Sum
    
    $theoreticalMinTime = [Math]::Max($longestDuration, $totalDuration / $MaxConcurrency)
    $actualTotalTime = ($ProcessedISOs | Measure-Object -Property DurationMs -Maximum).Maximum
    
    if ($actualTotalTime -gt 0) {
        return [Math]::Round(($theoreticalMinTime / $actualTotalTime) * 100, 1)
    } else {
        return 0
    }
}

# Helper function to generate pipeline report
function New-PipelineReport {
    param($PipelineResult, $OutputDirectory)
    
    $reportPath = Join-Path $OutputDirectory "pipeline-report-$($PipelineResult.PipelineId).html"
    
    # Generate HTML report content
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>ISO Pipeline Report - $($PipelineResult.PipelineId)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .summary { background-color: #e8f5e8; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .error { background-color: #ffeaea; padding: 10px; margin: 10px 0; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .success { color: green; font-weight: bold; }
        .failed { color: red; font-weight: bold; }
        .partial { color: orange; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>ISO Pipeline Execution Report</h1>
        <p><strong>Pipeline ID:</strong> $($PipelineResult.PipelineId)</p>
        <p><strong>Status:</strong> <span class="$(($PipelineResult.Status).ToLower())">$($PipelineResult.Status)</span></p>
        <p><strong>Processing Mode:</strong> $($PipelineResult.ProcessingMode)</p>
        <p><strong>Duration:</strong> $($PipelineResult.Duration)</p>
        <p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    </div>

    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total ISOs:</strong> $($PipelineResult.ProcessedISOs.Count)</p>
        <p><strong>Successful:</strong> $($PipelineResult.SuccessCount)</p>
        <p><strong>Failed:</strong> $($PipelineResult.FailureCount)</p>
        <p><strong>Skipped:</strong> $($PipelineResult.SkippedCount)</p>
        <p><strong>Success Rate:</strong> $([Math]::Round(($PipelineResult.SuccessCount / $PipelineResult.ProcessedISOs.Count) * 100, 1))%</p>
    </div>

    <h2>Processed ISOs</h2>
    <table>
        <tr>
            <th>Order</th>
            <th>Name</th>
            <th>Status</th>
            <th>Template</th>
            <th>Computer Name</th>
            <th>Duration</th>
            <th>Output ISO</th>
        </tr>
"@

    foreach ($iso in $PipelineResult.ProcessedISOs) {
        $statusClass = ($iso.Status).ToLower()
        $duration = if ($iso.DurationMs) { [TimeSpan]::FromMilliseconds($iso.DurationMs).ToString() } else { 'N/A' }
        
        $htmlContent += @"
        <tr>
            <td>$($iso.ProcessingOrder)</td>
            <td>$($iso.Name)</td>
            <td><span class="$statusClass">$($iso.Status)</span></td>
            <td>$($iso.Template)</td>
            <td>$($iso.ComputerName)</td>
            <td>$duration</td>
            <td>$($iso.OutputISO)</td>
        </tr>
"@
    }

    $htmlContent += @"
    </table>

    <h2>Performance Metrics</h2>
    <ul>
        <li><strong>Total Duration:</strong> $($PipelineResult.Performance.TotalDuration)</li>
        <li><strong>Average ISO Processing Time:</strong> $($PipelineResult.Performance.AverageISOProcessingTime)</li>
        <li><strong>Processing Rate:</strong> $($PipelineResult.Performance.ProcessingRate) ISOs/minute</li>
        <li><strong>Concurrency Efficiency:</strong> $($PipelineResult.Performance.ConcurrencyEfficiency)%</li>
    </ul>
</body>
</html>
"@

    # Write report to file
    Set-Content -Path $reportPath -Value $htmlContent -Encoding UTF8
    
    return @{
        ReportPath = $reportPath
        Format = 'HTML'
        Generated = Get-Date
    }
}

# Helper function to convert JSON to hashtable
function Convert-HashtableFromJson {
    param($JsonObject)
    
    if ($JsonObject -is [PSCustomObject]) {
        $hashtable = @{}
        foreach ($property in $JsonObject.PSObject.Properties) {
            $hashtable[$property.Name] = Convert-HashtableFromJson $property.Value
        }
        return $hashtable
    } elseif ($JsonObject -is [array]) {
        return $JsonObject | ForEach-Object { Convert-HashtableFromJson $_ }
    } else {
        return $JsonObject
    }
}