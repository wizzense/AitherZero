function Start-IntelligentSetup {
    <#
    .SYNOPSIS
        Intelligent setup wizard for AitherZero with enhanced user experience
    .DESCRIPTION
        Provides a guided setup experience with:
        - Platform detection and optimization
        - Installation profiles (minimal, developer, full)
        - AI tools integration
        - Dependency checking and resolution
        - Configuration templates
        - Progress tracking and user feedback
        - Error recovery and troubleshooting
    .PARAMETER InstallationProfile
        Installation profile to use: minimal, developer, full, or interactive
    .PARAMETER SkipOptional
        Skip optional components and use minimal setup
    .PARAMETER ConfigPath
        Path to custom configuration file
    .PARAMETER Unattended
        Run in unattended mode with no user interaction
    .PARAMETER Force
        Force setup even if already completed
    .EXAMPLE
        Start-IntelligentSetup
        # Interactive setup with profile selection
    .EXAMPLE
        Start-IntelligentSetup -InstallationProfile developer
        # Developer profile setup
    .EXAMPLE
        Start-IntelligentSetup -Unattended -InstallationProfile minimal
        # Minimal setup without user interaction
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('minimal', 'developer', 'full', 'interactive')]
        [string]$InstallationProfile = 'interactive',
        
        [Parameter()]
        [switch]$SkipOptional,
        
        [Parameter()]
        [string]$ConfigPath,
        
        [Parameter()]
        [switch]$Unattended,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Intelligent Setup (Profile: $InstallationProfile)" -Source 'UserExperience'
        
        # Check if setup was already completed
        $setupCompleteMarker = Join-Path $script:UserConfigPaths.UserProfile 'setup-complete'
        if ((Test-Path $setupCompleteMarker) -and -not $Force) {
            Write-Host "✅ AitherZero setup was already completed." -ForegroundColor Green
            Write-Host "Use -Force to run setup again, or use Start-UserExperience for normal operation." -ForegroundColor Yellow
            return @{
                AlreadyCompleted = $true
                CompletedDate = (Get-Item $setupCompleteMarker).CreationTime
                TotalSteps = 0
                Steps = @()
            }
        }
        
        # Initialize setup state with enhanced tracking
        $setupState = Initialize-SetupState -Profile $InstallationProfile -Unattended:$Unattended
    }
    
    process {
        try {
            # Show welcome and setup information
            if (-not $Unattended) {
                Show-SetupWelcome -SetupState $setupState
            }
            
            # Initialize progress tracking
            $progressId = Initialize-SetupProgress -SetupState $setupState -Unattended:$Unattended
            
            # Get setup steps based on profile and system analysis
            $setupStepsInfo = Get-EnhancedSetupSteps -Profile $InstallationProfile -SystemAnalysis $setupState.SystemAnalysis
            $setupSteps = $setupStepsInfo.Steps
            $profileInfo = $setupStepsInfo.Profile
            
            # Update setup state with step information
            $setupState.TotalSteps = $setupSteps.Count
            $setupState.ProfileInfo = $profileInfo
            $setupState.Steps = @()
            
            # Show profile information unless unattended
            if (-not $Unattended) {
                Show-SetupProfileInfo -Profile $InstallationProfile -ProfileInfo $profileInfo
            }
            
            # Execute setup steps with enhanced error handling
            foreach ($step in $setupSteps) {
                $setupState.CurrentStep++
                
                $stepResult = Invoke-SetupStep -Step $step -SetupState $setupState -ProgressId $progressId -Unattended:$Unattended
                $setupState.Steps += $stepResult
                
                # Handle step failures with recovery options
                if ($stepResult.Status -eq 'Failed' -and -not $SkipOptional) {
                    $recovery = Handle-SetupStepFailure -Step $step -Result $stepResult -SetupState $setupState -Unattended:$Unattended
                    if (-not $recovery.Continue) {
                        Write-CustomLog -Level 'ERROR' -Message "Setup cancelled due to critical failure in step: $($step.Name)" -Source 'UserExperience'
                        return $setupState
                    }
                }
            }
            
            # Post-setup configuration
            Complete-SetupProcess -SetupState $setupState -ConfigPath $ConfigPath
            
            # Create setup completion marker
            $setupCompleteInfo = @{
                CompletedDate = Get-Date
                Profile = $InstallationProfile
                Version = '1.0.0'
                SessionId = $setupState.SessionId
                Duration = (Get-Date) - $setupState.StartTime
                Success = $true
            }
            
            $setupCompleteInfo | ConvertTo-Json -Depth 3 | Set-Content -Path $setupCompleteMarker
            
            # Show completion summary
            if (-not $Unattended) {
                Show-SetupCompletion -SetupState $setupState
            }
            
            Write-CustomLog -Level 'INFO' -Message "Intelligent Setup completed successfully" -Source 'UserExperience'
            
            return $setupState
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Setup failed with error: $_" -Source 'UserExperience'
            $setupState.Success = $false
            $setupState.Error = $_.Exception.Message
            
            if (-not $Unattended) {
                Show-SetupError -Error $_ -SetupState $setupState
            }
            
            throw
        } finally {
            # Cleanup progress tracking
            if ($progressId) {
                try {
                    Complete-ProgressOperation -OperationId $progressId -ShowSummary:(-not $Unattended)
                } catch {
                    Write-Verbose "Could not complete progress operation: $_"
                }
            }
        }
    }
}

function Initialize-SetupState {
    <#
    .SYNOPSIS
        Initializes the setup state with comprehensive system analysis
    #>
    param(
        [string]$Profile,
        [switch]$Unattended
    )
    
    $systemAnalysis = Get-ComprehensiveSystemAnalysis
    
    return @{
        StartTime = Get-Date
        SessionId = [System.Guid]::NewGuid().ToString()
        InstallationProfile = $Profile
        SystemAnalysis = $systemAnalysis
        Steps = @()
        CurrentStep = 0
        TotalSteps = 0
        Errors = @()
        Warnings = @()
        Recommendations = @()
        Success = $false
        Unattended = $Unattended
        UserInteractions = @()
        Performance = @{
            StepTimes = @{}
            TotalTime = 0
        }
    }
}

function Get-ComprehensiveSystemAnalysis {
    <#
    .SYNOPSIS
        Performs comprehensive system analysis for optimal setup
    #>
    
    $analysis = @{
        Platform = Get-PlatformInfo
        Capabilities = Get-TerminalCapabilities
        Dependencies = Get-SystemDependencies
        Performance = Get-SystemPerformance
        Security = Get-SecurityContext
        Network = Get-NetworkStatus
        Storage = Get-StorageInfo
        Recommendations = @()
    }
    
    # Generate recommendations based on analysis
    $analysis.Recommendations = Get-SetupRecommendations -Analysis $analysis
    
    return $analysis
}

function Get-SystemDependencies {
    <#
    .SYNOPSIS
        Analyzes system dependencies and tools
    #>
    
    $dependencies = @{
        PowerShell = @{
            Version = $PSVersionTable.PSVersion.ToString()
            Edition = $PSVersionTable.PSEdition
            Compatible = $PSVersionTable.PSVersion.Major -ge 7
        }
        Git = @{
            Available = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
            Version = $null
            Configured = $false
        }
        NodeJS = @{
            Available = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
            Version = $null
        }
        Infrastructure = @{
            OpenTofu = $null -ne (Get-Command tofu -ErrorAction SilentlyContinue)
            Terraform = $null -ne (Get-Command terraform -ErrorAction SilentlyContinue)
        }
        Cloud = @{
            Azure = $null -ne (Get-Command az -ErrorAction SilentlyContinue)
            AWS = $null -ne (Get-Command aws -ErrorAction SilentlyContinue)
            GCloud = $null -ne (Get-Command gcloud -ErrorAction SilentlyContinue)
        }
        Development = @{
            VSCode = Test-VSCodeAvailable
            Docker = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
        }
    }
    
    # Get detailed version information
    if ($dependencies.Git.Available) {
        try {
            $dependencies.Git.Version = (git --version 2>$null) -replace '^git version ', ''
            $dependencies.Git.Configured = (git config --global user.name 2>$null) -and (git config --global user.email 2>$null)
        } catch { }
    }
    
    if ($dependencies.NodeJS.Available) {
        try {
            $dependencies.NodeJS.Version = (node --version 2>$null) -replace '^v', ''
        } catch { }
    }
    
    return $dependencies
}

function Get-SystemPerformance {
    <#
    .SYNOPSIS
        Analyzes system performance characteristics
    #>
    
    return @{
        ProcessorCount = [System.Environment]::ProcessorCount
        TotalMemory = if ($IsWindows) {
            try {
                [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            } catch { $null }
        } else { $null }
        PowerShellPerformance = Measure-PowerShellPerformance
        DiskSpace = Get-DiskSpaceInfo
    }
}

function Get-SecurityContext {
    <#
    .SYNOPSIS
        Analyzes security context and requirements
    #>
    
    return @{
        ExecutionPolicy = Get-ExecutionPolicy
        IsAdmin = Test-IsAdministrator
        SecurityFeatures = Get-SecurityFeatures
        Compliance = Test-SecurityCompliance
    }
}

function Get-NetworkStatus {
    <#
    .SYNOPSIS
        Analyzes network connectivity and requirements
    #>
    
    $networkTests = @(
        @{ Name = 'GitHub'; Url = 'https://api.github.com'; Critical = $true },
        @{ Name = 'PowerShell Gallery'; Url = 'https://www.powershellgallery.com'; Critical = $false },
        @{ Name = 'OpenTofu Registry'; Url = 'https://registry.opentofu.org'; Critical = $false }
    )
    
    $results = @{
        InternetConnected = $false
        ProxyDetected = $false
        TestedEndpoints = @()
        CriticalEndpointsAvailable = $false
    }
    
    foreach ($test in $networkTests) {
        $testResult = Test-NetworkEndpoint -Name $test.Name -Url $test.Url -Critical $test.Critical
        $results.TestedEndpoints += $testResult
        
        if ($testResult.Success) {
            $results.InternetConnected = $true
        }
    }
    
    $results.CriticalEndpointsAvailable = ($results.TestedEndpoints | Where-Object { $_.Critical -and $_.Success }).Count -gt 0
    $results.ProxyDetected = Test-ProxyConfiguration
    
    return $results
}

function Get-StorageInfo {
    <#
    .SYNOPSIS
        Analyzes storage requirements and availability
    #>
    
    $projectPath = $script:UserExperienceState.ProjectRoot
    $userConfigPath = $script:UserConfigPaths.UserProfile
    
    return @{
        ProjectPath = @{
            Path = $projectPath
            Available = Test-Path $projectPath
            FreeSpace = Get-PathFreeSpace -Path $projectPath
        }
        UserConfig = @{
            Path = $userConfigPath
            Available = Test-Path $userConfigPath
            FreeSpace = Get-PathFreeSpace -Path $userConfigPath
        }
        TempSpace = @{
            Path = $env:TEMP ?? '/tmp'
            FreeSpace = Get-PathFreeSpace -Path ($env:TEMP ?? '/tmp')
        }
    }
}

function Get-EnhancedSetupSteps {
    <#
    .SYNOPSIS
        Gets enhanced setup steps based on profile and system analysis
    #>
    param(
        [string]$Profile,
        [hashtable]$SystemAnalysis
    )
    
    # Base steps required for all profiles
    $baseSteps = @(
        @{
            Name = 'System Analysis'
            Function = 'Test-SystemRequirements'
            Required = $true
            EstimatedTime = 10
            Description = 'Analyze system capabilities and requirements'
        },
        @{
            Name = 'Configuration Setup'
            Function = 'Initialize-UserConfiguration'
            Required = $true
            EstimatedTime = 15
            Description = 'Initialize user configuration and preferences'
        },
        @{
            Name = 'Module Discovery'
            Function = 'Initialize-ModuleSystem'
            Required = $true
            EstimatedTime = 20
            Description = 'Discover and initialize AitherZero modules'
        }
    )
    
    # Profile-specific steps
    $profileSteps = switch ($Profile) {
        'minimal' {
            @(
                @{
                    Name = 'Essential Dependencies'
                    Function = 'Install-EssentialDependencies'
                    Required = $true
                    EstimatedTime = 30
                    Description = 'Install only essential dependencies'
                }
            )
        }
        'developer' {
            @(
                @{
                    Name = 'Development Dependencies'
                    Function = 'Install-DevelopmentDependencies'
                    Required = $false
                    EstimatedTime = 60
                    Description = 'Install development tools and dependencies'
                },
                @{
                    Name = 'AI Tools Integration'
                    Function = 'Setup-AITools'
                    Required = $false
                    EstimatedTime = 90
                    Description = 'Install and configure AI development tools'
                },
                @{
                    Name = 'Development Environment'
                    Function = 'Configure-DevelopmentEnvironment'
                    Required = $false
                    EstimatedTime = 45
                    Description = 'Configure development environment and VS Code integration'
                }
            )
        }
        'full' {
            @(
                @{
                    Name = 'Complete Dependencies'
                    Function = 'Install-CompleteDependencies'
                    Required = $false
                    EstimatedTime = 120
                    Description = 'Install complete set of dependencies and tools'
                },
                @{
                    Name = 'Infrastructure Tools'
                    Function = 'Setup-InfrastructureTools'
                    Required = $false
                    EstimatedTime = 90
                    Description = 'Install and configure infrastructure automation tools'
                },
                @{
                    Name = 'Cloud Integration'
                    Function = 'Setup-CloudIntegration'
                    Required = $false
                    EstimatedTime = 60
                    Description = 'Configure cloud provider integrations'
                },
                @{
                    Name = 'Enterprise Features'
                    Function = 'Setup-EnterpriseFeatures'
                    Required = $false
                    EstimatedTime = 45
                    Description = 'Configure enterprise features and security'
                }
            )
        }
        default {
            # Interactive profile - let user choose
            @()
        }
    }
    
    # Combine steps
    $allSteps = $baseSteps + $profileSteps
    
    # Add conditional steps based on system analysis
    $conditionalSteps = Get-ConditionalSetupSteps -SystemAnalysis $SystemAnalysis
    $allSteps += $conditionalSteps
    
    # Add final validation step
    $allSteps += @{
        Name = 'Final Validation'
        Function = 'Test-SetupCompletion'
        Required = $true
        EstimatedTime = 15
        Description = 'Validate setup completion and generate recommendations'
    }
    
    # Profile metadata
    $profileInfo = Get-ProfileMetadata -Profile $Profile -Steps $allSteps
    
    return @{
        Steps = $allSteps
        Profile = $profileInfo
        EstimatedTotalTime = ($allSteps | Measure-Object EstimatedTime -Sum).Sum
    }
}

function Invoke-SetupStep {
    <#
    .SYNOPSIS
        Executes a setup step with comprehensive error handling and progress tracking
    #>
    param(
        [hashtable]$Step,
        [hashtable]$SetupState,
        [string]$ProgressId,
        [switch]$Unattended
    )
    
    $stepStartTime = Get-Date
    Write-CustomLog -Level 'INFO' -Message "Executing setup step: $($Step.Name)" -Source 'UserExperience'
    
    # Update progress
    if (-not $Unattended) {
        Update-SetupProgress -ProgressId $ProgressId -StepName $Step.Name -Status 'Running' -SetupState $SetupState
    }
    
    $result = @{
        Name = $Step.Name
        Status = 'Unknown'
        Details = @()
        StartTime = $stepStartTime
        Duration = 0
        RetryCount = 0
        Warnings = @()
        Error = $null
    }
    
    $maxRetries = if ($Step.Required) { 2 } else { 1 }
    
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            $result.RetryCount = $attempt - 1
            
            # Execute the step function
            if (Get-Command $Step.Function -ErrorAction SilentlyContinue) {
                $stepResult = & $Step.Function -SetupState $SetupState
                
                # Merge step result
                if ($stepResult.Status) { $result.Status = $stepResult.Status }
                if ($stepResult.Details) { $result.Details = $stepResult.Details }
                if ($stepResult.Warnings) { $result.Warnings = $stepResult.Warnings }
                
                # Success - break retry loop
                if ($result.Status -in @('Passed', 'Success', 'Completed')) {
                    break
                }
            } else {
                throw "Step function '$($Step.Function)' not found"
            }
            
        } catch {
            $result.Error = $_.Exception.Message
            $result.Status = 'Failed'
            
            Write-CustomLog -Level 'ERROR' -Message "Step '$($Step.Name)' failed (attempt $attempt): $_" -Source 'UserExperience'
            
            # Don't retry on last attempt
            if ($attempt -eq $maxRetries) {
                $result.Details += "Failed after $maxRetries attempts: $_"
                break
            } else {
                $result.Details += "Attempt $attempt failed, retrying: $_"
                Start-Sleep -Seconds 2
            }
        }
    }
    
    # Calculate duration
    $result.Duration = (Get-Date) - $stepStartTime
    $SetupState.Performance.StepTimes[$Step.Name] = $result.Duration.TotalSeconds
    
    # Update progress
    if (-not $Unattended) {
        $progressStatus = switch ($result.Status) {
            'Passed' { 'Success' }
            'Success' { 'Success' }
            'Completed' { 'Success' }
            'Failed' { 'Failed' }
            'Warning' { 'Warning' }
            default { 'Completed' }
        }
        
        Update-SetupProgress -ProgressId $ProgressId -StepName $Step.Name -Status $progressStatus -SetupState $SetupState
    }
    
    Write-CustomLog -Level 'INFO' -Message "Setup step '$($Step.Name)' completed with status: $($result.Status)" -Source 'UserExperience'
    
    return $result
}

# Helper functions for the setup steps would continue here...
# This includes the actual step implementation functions like Test-SystemRequirements, etc.

function Show-SetupWelcome {
    <#
    .SYNOPSIS
        Shows the setup welcome screen
    #>
    param([hashtable]$SetupState)
    
    Clear-Host
    
    Write-Host ""
    Write-Host "    ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "    ║              AitherZero Intelligent Setup Wizard              ║" -ForegroundColor Cyan
    Write-Host "    ║                         Version 2.0                           ║" -ForegroundColor Cyan
    Write-Host "    ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Welcome! This wizard will configure AitherZero for optimal" -ForegroundColor White
    Write-Host "    performance on your system." -ForegroundColor White
    Write-Host ""
    Write-Host "    🔍 System Analysis Results:" -ForegroundColor Yellow
    Write-Host "       Platform: $($SetupState.SystemAnalysis.Platform.OS) $($SetupState.SystemAnalysis.Platform.Version)" -ForegroundColor White
    Write-Host "       PowerShell: $($SetupState.SystemAnalysis.Dependencies.PowerShell.Version)" -ForegroundColor White
    Write-Host "       Profile: $($SetupState.InstallationProfile)" -ForegroundColor White
    
    if ($SetupState.SystemAnalysis.Recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "    💡 Key Recommendations:" -ForegroundColor Green
        $SetupState.SystemAnalysis.Recommendations | Select-Object -First 3 | ForEach-Object {
            Write-Host "       • $_" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    if (-not $SetupState.Unattended) {
        Write-Host "    Press Enter to begin setup..." -ForegroundColor Green -NoNewline
        Read-Host
    }
}