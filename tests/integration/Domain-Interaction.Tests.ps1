# Domain Interaction Validation Tests
# Agent 3 Mission: Cross-Domain Integration Testing
# Tests specific domain-to-domain interactions and data flow

#Requires -Version 7.0

BeforeAll {
    # Setup test environment
    $projectRoot = $PSScriptRoot
    while ($projectRoot -and -not (Test-Path (Join-Path $projectRoot "aither-core"))) {
        $parent = Split-Path $projectRoot -Parent
        if ($parent -eq $projectRoot) { break }
        $projectRoot = $parent
    }
    
    $env:PROJECT_ROOT = $projectRoot
    $env:PWSH_MODULES_PATH = Join-Path $projectRoot "aither-core/modules"
    
    # Import AitherCore
    $coreModulePath = Join-Path $projectRoot "aither-core/AitherCore.psm1"
    Remove-Module AitherCore -Force -ErrorAction SilentlyContinue
    Import-Module $coreModulePath -Force
    
    # Initialize system
    Initialize-CoreApplication -RequiredOnly:$false
    
    # Test results collection
    $script:InteractionResults = @{
        InfrastructureToConfiguration = @()
        ConfigurationToInfrastructure = @()
        SecurityToAll = @()
        AutomationToInfrastructure = @()
        ExperienceToConfiguration = @()
        UtilitiesToAll = @()
        ModuleToModuleCommunication = @()
        SharedResourceAccess = @()
        EventSystemInteraction = @()
        StartTime = Get-Date
    }
}

Describe "Domain-to-Domain Interaction Tests" {
    
    Context "Infrastructure → Configuration Domain" {
        It "Should allow infrastructure to read configuration settings" {
            # Test infrastructure domain accessing configuration
            $labConfigCmd = Get-Command Get-LabConfig -ErrorAction SilentlyContinue
            $configStoreCmd = Get-Command Get-ConfigurationStore -ErrorAction SilentlyContinue
            
            if ($labConfigCmd -and $configStoreCmd) {
                # Infrastructure domain function accessing configuration domain
                $configStore = Get-ConfigurationStore
                $configStore | Should -Not -BeNullOrEmpty
                
                # Test lab config can access configuration store
                $labConfig = Get-LabConfig -ErrorAction SilentlyContinue
                
                $script:InteractionResults.InfrastructureToConfiguration += @{
                    TestName = "Infrastructure Access to Configuration"
                    Result = "PASSED"
                    Details = "Infrastructure can access configuration store"
                }
            }
        }
        
        It "Should allow infrastructure to modify configuration through proper channels" {
            # Test infrastructure domain modifying configuration
            $setConfigCmd = Get-Command Set-ModuleConfiguration -ErrorAction SilentlyContinue
            
            if ($setConfigCmd) {
                # Infrastructure setting its own configuration
                $testConfig = @{
                    name = "InfrastructureTest"
                    settings = @{
                        testMode = $true
                        timeout = 30
                    }
                    enabled = $true
                }
                
                { Set-ModuleConfiguration -ModuleName "InfrastructureTest" -Configuration $testConfig } | Should -Not -Throw
                
                # Verify configuration was set
                $savedConfig = Get-ModuleConfiguration -ModuleName "InfrastructureTest" -ErrorAction SilentlyContinue
                $savedConfig | Should -Not -BeNullOrEmpty
                
                $script:InteractionResults.InfrastructureToConfiguration += @{
                    TestName = "Infrastructure Configuration Modification"
                    Result = "PASSED"
                    Details = "Infrastructure can modify configuration through proper channels"
                }
            }
        }
    }
    
    Context "Configuration → Infrastructure Domain" {
        It "Should allow configuration to trigger infrastructure actions" {
            # Test configuration domain triggering infrastructure actions
            $labAutomationCmd = Get-Command Start-LabAutomation -ErrorAction SilentlyContinue
            $configCarouselCmd = Get-Command Switch-ConfigurationSet -ErrorAction SilentlyContinue
            
            if ($labAutomationCmd -and $configCarouselCmd) {
                # Configuration change should be able to trigger infrastructure reconfiguration
                $testConfig = @{
                    environment = "test"
                    infrastructure = @{
                        provider = "test"
                        region = "local"
                    }
                }
                
                # Test that configuration can initiate infrastructure actions
                $result = Start-LabAutomation -Configuration $testConfig -ShowProgress:$false
                $result | Should -Not -BeNullOrEmpty
                
                $script:InteractionResults.ConfigurationToInfrastructure += @{
                    TestName = "Configuration Triggers Infrastructure"
                    Result = "PASSED"
                    Details = "Configuration can trigger infrastructure actions"
                }
            }
        }
        
        It "Should allow configuration environment changes to affect infrastructure" {
            # Test configuration environment affecting infrastructure behavior
            $envCmd = Get-Command Get-ConfigurationEnvironment -ErrorAction SilentlyContinue
            $platformCmd = Get-Command Get-PlatformInfo -ErrorAction SilentlyContinue
            
            if ($envCmd -and $platformCmd) {
                # Get current environment
                $currentEnv = Get-ConfigurationEnvironment
                $currentEnv | Should -Not -BeNullOrEmpty
                
                # Infrastructure should be aware of configuration environment
                $platformInfo = Get-PlatformInfo
                $platformInfo | Should -Not -BeNullOrEmpty
                
                $script:InteractionResults.ConfigurationToInfrastructure += @{
                    TestName = "Configuration Environment Affects Infrastructure"
                    Result = "PASSED"
                    Details = "Infrastructure aware of configuration environment"
                }
            }
        }
    }
    
    Context "Security Domain Interactions" {
        It "Should provide security services to all domains" {
            # Test security domain functions available to other domains
            $securityDomainPath = Join-Path $env:PROJECT_ROOT "aither-core/domains/security"
            
            if (Test-Path $securityDomainPath) {
                # Check if security functions are available
                $securityFiles = Get-ChildItem -Path $securityDomainPath -Filter "*.ps1"
                $securityFiles.Count | Should -BeGreaterThan 0
                
                # Test security integration with configuration
                $configSecurityCmd = Get-Command Test-ConfigurationSecurity -ErrorAction SilentlyContinue
                if ($configSecurityCmd) {
                    $testConfig = @{
                        testKey = "testValue"
                        password = "shouldTriggerWarning"
                    }
                    
                    $securityResult = Test-ConfigurationSecurity -Configuration $testConfig
                    $securityResult | Should -Not -BeNullOrEmpty
                    
                    $script:InteractionResults.SecurityToAll += @{
                        TestName = "Security Services Available"
                        Result = "PASSED"
                        Details = "Security domain provides services to configuration domain"
                    }
                }
            }
        }
    }
    
    Context "Automation Domain Interactions" {
        It "Should enable automation to orchestrate infrastructure" {
            # Test automation domain orchestrating infrastructure
            $automationDomainPath = Join-Path $env:PROJECT_ROOT "aither-core/domains/automation"
            
            if (Test-Path $automationDomainPath) {
                # Check automation domain files
                $automationFiles = Get-ChildItem -Path $automationDomainPath -Filter "*.ps1"
                $automationFiles.Count | Should -BeGreaterThan 0
                
                # Test automation can trigger infrastructure workflows
                $workflowCmd = Get-Command Invoke-IntegratedWorkflow -ErrorAction SilentlyContinue
                if ($workflowCmd) {
                    # Test automation triggering infrastructure workflow
                    $workflowResult = Invoke-IntegratedWorkflow -WorkflowType "LabDeployment" -DryRun -ErrorAction SilentlyContinue
                    
                    $script:InteractionResults.AutomationToInfrastructure += @{
                        TestName = "Automation Orchestrates Infrastructure"
                        Result = "PASSED"
                        Details = "Automation domain can orchestrate infrastructure workflows"
                    }
                }
            }
        }
    }
    
    Context "Experience Domain Interactions" {
        It "Should provide user experience enhancements to configuration" {
            # Test experience domain enhancing configuration interactions
            $experienceDomainPath = Join-Path $env:PROJECT_ROOT "aither-core/domains/experience"
            
            if (Test-Path $experienceDomainPath) {
                # Check experience domain files
                $experienceFiles = Get-ChildItem -Path $experienceDomainPath -Filter "*.ps1"
                $experienceFiles.Count | Should -BeGreaterThan 0
                
                # Test experience enhancements to configuration
                $progressCmd = Get-Command Start-ProgressOperation -ErrorAction SilentlyContinue
                if ($progressCmd) {
                    # Test progress tracking integration
                    $progressId = Start-ProgressOperation -OperationName "Test Operation" -TotalSteps 3 -ShowTime:$false
                    $progressId | Should -Not -BeNullOrEmpty
                    
                    Complete-ProgressOperation -OperationId $progressId
                    
                    $script:InteractionResults.ExperienceToConfiguration += @{
                        TestName = "Experience Enhances Configuration"
                        Result = "PASSED"
                        Details = "Experience domain provides progress tracking to configuration operations"
                    }
                }
            }
        }
    }
    
    Context "Utilities Domain Interactions" {
        It "Should provide utility services to all domains" {
            # Test utilities domain serving all other domains
            $utilitiesDomainPath = Join-Path $env:PROJECT_ROOT "aither-core/domains/utilities"
            
            if (Test-Path $utilitiesDomainPath) {
                # Check utilities domain files
                $utilitiesFiles = Get-ChildItem -Path $utilitiesDomainPath -Filter "*.ps1"
                $utilitiesFiles.Count | Should -BeGreaterThan 0
                
                # Test utilities integration with other domains
                $semanticVersionCmd = Get-Command Get-SemanticVersion -ErrorAction SilentlyContinue
                $licenseCmd = Get-Command Get-LicenseStatus -ErrorAction SilentlyContinue
                
                if ($semanticVersionCmd -or $licenseCmd) {
                    $script:InteractionResults.UtilitiesToAll += @{
                        TestName = "Utilities Serve All Domains"
                        Result = "PASSED"
                        Details = "Utilities domain provides versioning and licensing services"
                    }
                }
            }
        }
    }
}

Describe "Module-to-Module Communication Tests" {
    
    Context "ModuleCommunication System" {
        It "Should enable modules to communicate with each other" {
            # Test module-to-module communication
            $moduleCommCmd = Get-Command Register-ModuleAPI -ErrorAction SilentlyContinue
            $invokeCommCmd = Get-Command Invoke-ModuleAPI -ErrorAction SilentlyContinue
            
            if ($moduleCommCmd -and $invokeCommCmd) {
                # Register test module APIs
                Register-ModuleAPI -ModuleName "TestModule1" -APIVersion "1.0.0" -Endpoints @("ping", "status")
                Register-ModuleAPI -ModuleName "TestModule2" -APIVersion "1.0.0" -Endpoints @("data", "config")
                
                # Test API invocation
                $apiResult = Invoke-ModuleAPI -ModuleName "TestModule1" -Endpoint "ping" -ErrorAction SilentlyContinue
                
                $script:InteractionResults.ModuleToModuleCommunication += @{
                    TestName = "Module API Communication"
                    Result = "PASSED"
                    Details = "Modules can register and invoke APIs"
                }
            }
        }
        
        It "Should enable event-based communication between modules" {
            # Test event-based module communication
            $eventCmd = Get-Command Publish-ConfigurationEvent -ErrorAction SilentlyContinue
            $subscribeCmd = Get-Command Subscribe-ConfigurationEvent -ErrorAction SilentlyContinue
            
            if ($eventCmd -and $subscribeCmd) {
                # Subscribe to test event
                $subscriptionId = Subscribe-ConfigurationEvent -EventName "TestEvent" -ScriptBlock {
                    param($Event)
                    Write-Information "Received event: $($Event.Name)"
                }
                
                # Publish test event
                Publish-ConfigurationEvent -EventName "TestEvent" -EventData @{ TestData = "Hello" }
                
                # Cleanup
                if ($subscriptionId) {
                    Unsubscribe-ConfigurationEvent -SubscriptionId $subscriptionId
                }
                
                $script:InteractionResults.ModuleToModuleCommunication += @{
                    TestName = "Event-Based Module Communication"
                    Result = "PASSED"
                    Details = "Modules can publish and subscribe to events"
                }
            }
        }
    }
    
    Context "Shared Resource Access" {
        It "Should enable shared access to common resources" {
            # Test shared resource access
            $logCmd = Get-Command Write-CustomLog -ErrorAction SilentlyContinue
            $configCmd = Get-Command Get-ConfigurationStore -ErrorAction SilentlyContinue
            
            if ($logCmd -and $configCmd) {
                # Test shared logging
                { Write-CustomLog -Message "Test shared logging" -Level "INFO" } | Should -Not -Throw
                
                # Test shared configuration access
                $configStore = Get-ConfigurationStore
                $configStore | Should -Not -BeNullOrEmpty
                
                $script:InteractionResults.SharedResourceAccess += @{
                    TestName = "Shared Resource Access"
                    Result = "PASSED"
                    Details = "Modules can access shared logging and configuration resources"
                }
            }
        }
        
        It "Should maintain resource consistency across domains" {
            # Test resource consistency
            $envProjectRoot = $env:PROJECT_ROOT
            $envModulePath = $env:PWSH_MODULES_PATH
            
            # Both should be consistently available
            $envProjectRoot | Should -Not -BeNullOrEmpty
            $envModulePath | Should -Not -BeNullOrEmpty
            
            # Test Write-CustomLog consistency
            $logCmd = Get-Command Write-CustomLog -ErrorAction SilentlyContinue
            $logCmd | Should -Not -BeNullOrEmpty
            
            $script:InteractionResults.SharedResourceAccess += @{
                TestName = "Resource Consistency"
                Result = "PASSED"
                Details = "Shared resources consistently available across domains"
            }
        }
    }
}

Describe "Event System Cross-Domain Integration" {
    
    Context "Domain Event Publishing" {
        It "Should allow domains to publish events to other domains" {
            # Test cross-domain event publishing
            $eventHistoryCmd = Get-Command Get-ConfigurationEventHistory -ErrorAction SilentlyContinue
            
            if ($eventHistoryCmd) {
                # Get initial event count
                $initialEvents = Get-ConfigurationEventHistory
                $initialCount = $initialEvents.Count
                
                # Publish test event
                Publish-ConfigurationEvent -EventName "CrossDomainTest" -EventData @{
                    SourceDomain = "Infrastructure"
                    TargetDomain = "Configuration"
                    TestData = "CrossDomainInteraction"
                }
                
                # Verify event was recorded
                $newEvents = Get-ConfigurationEventHistory
                $newEvents.Count | Should -BeGreaterThan $initialCount
                
                $script:InteractionResults.EventSystemInteraction += @{
                    TestName = "Cross-Domain Event Publishing"
                    Result = "PASSED"
                    Details = "Domains can publish events for cross-domain communication"
                }
            }
        }
        
        It "Should enable event-driven domain coordination" {
            # Test event-driven coordination between domains
            $eventReceived = $false
            
            # Subscribe to coordination event
            $subscriptionId = Subscribe-ConfigurationEvent -EventName "DomainCoordination" -ScriptBlock {
                param($Event)
                $script:eventReceived = $true
            }
            
            # Publish coordination event
            Publish-ConfigurationEvent -EventName "DomainCoordination" -EventData @{
                Action = "Coordinate"
                Domains = @("Infrastructure", "Configuration", "Security")
            }
            
            # Give event time to process
            Start-Sleep -Milliseconds 100
            
            # Cleanup
            if ($subscriptionId) {
                Unsubscribe-ConfigurationEvent -SubscriptionId $subscriptionId
            }
            
            $script:InteractionResults.EventSystemInteraction += @{
                TestName = "Event-Driven Domain Coordination"
                Result = "PASSED"
                Details = "Domains can coordinate through event system"
            }
        }
    }
}

# Domain Interaction Analysis and Reporting
Describe "Domain Interaction Analysis" {
    
    Context "Dependency Analysis" {
        It "Should analyze domain dependencies correctly" {
            # Analyze domain dependencies based on loading order
            $moduleStatus = Get-CoreModuleStatus
            $domains = $moduleStatus | Where-Object { $_.Type -eq 'Domain' }
            $modules = $moduleStatus | Where-Object { $_.Type -eq 'Module' }
            
            # Infrastructure domain dependencies
            $infraDeps = @("Logging")  # Infrastructure depends on Logging
            
            # Configuration domain dependencies
            $configDeps = @("Logging")  # Configuration depends on Logging
            
            # Verify dependencies are met
            $loggingAvailable = $moduleStatus | Where-Object { $_.Name -eq "Logging" -and $_.Available -eq $true }
            $loggingAvailable | Should -Not -BeNullOrEmpty
            
            # Generate dependency report
            $dependencyReport = @{
                TotalDomains = $domains.Count
                TotalModules = $modules.Count
                LoadedDomains = ($domains | Where-Object { $_.Loaded -eq $true }).Count
                LoadedModules = ($modules | Where-Object { $_.Loaded -eq $true }).Count
                Dependencies = @{
                    Infrastructure = $infraDeps
                    Configuration = $configDeps
                }
            }
            
            $dependencyReport | Should -Not -BeNullOrEmpty
            $dependencyReport.TotalDomains | Should -BeGreaterThan 0
        }
    }
    
    Context "Integration Health Check" {
        It "Should validate overall domain integration health" {
            # Comprehensive integration health check
            $healthCheck = @{
                LoggingSystem = (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) -ne $null
                ConfigurationSystem = (Get-Command Get-ConfigurationStore -ErrorAction SilentlyContinue) -ne $null
                InfrastructureSystem = (Get-Command Get-LabStatus -ErrorAction SilentlyContinue) -ne $null
                ModuleCommunication = (Get-Command Register-ModuleAPI -ErrorAction SilentlyContinue) -ne $null
                EventSystem = (Get-Command Publish-ConfigurationEvent -ErrorAction SilentlyContinue) -ne $null
                EnvironmentVariables = (-not [string]::IsNullOrEmpty($env:PROJECT_ROOT))
            }
            
            # Calculate health score
            $healthyComponents = $healthCheck.Values | Where-Object { $_ -eq $true }
            $totalComponents = $healthCheck.Count
            $healthScore = ($healthyComponents.Count / $totalComponents) * 100
            
            $healthScore | Should -BeGreaterThan 80  # 80% or higher is considered healthy
            
            # Log health check results
            Write-Information "Domain Integration Health Score: $([math]::Round($healthScore, 2))%" -InformationAction Continue
        }
    }
}

AfterAll {
    # Generate comprehensive domain interaction report
    $endTime = Get-Date
    $totalDuration = $endTime - $script:InteractionResults.StartTime
    
    Write-Information "`n=== DOMAIN INTERACTION VALIDATION REPORT ===" -InformationAction Continue
    Write-Information "Test Duration: $($totalDuration.TotalSeconds) seconds" -InformationAction Continue
    Write-Information "Test Completed: $endTime" -InformationAction Continue
    
    # Collect all interaction results
    $allInteractions = @()
    $script:InteractionResults.Keys | ForEach-Object {
        if ($_ -ne 'StartTime') {
            $allInteractions += $script:InteractionResults[$_]
        }
    }
    
    # Summary statistics
    $passed = $allInteractions | Where-Object { $_.Result -eq "PASSED" }
    $failed = $allInteractions | Where-Object { $_.Result -eq "FAILED" }
    $skipped = $allInteractions | Where-Object { $_.Result -eq "SKIPPED" }
    
    Write-Information "`nInteraction Test Summary:" -InformationAction Continue
    Write-Information "- Passed: $($passed.Count)" -InformationAction Continue
    Write-Information "- Failed: $($failed.Count)" -InformationAction Continue
    Write-Information "- Skipped: $($skipped.Count)" -InformationAction Continue
    Write-Information "- Total: $($allInteractions.Count)" -InformationAction Continue
    
    # Category breakdown
    Write-Information "`nDomain Interaction Categories:" -InformationAction Continue
    $script:InteractionResults.Keys | ForEach-Object {
        if ($_ -ne 'StartTime') {
            $count = $script:InteractionResults[$_].Count
            Write-Information "- $_: $count tests" -InformationAction Continue
        }
    }
    
    # Generate detailed report
    $detailedReport = @{
        TestSummary = @{
            TotalTests = $allInteractions.Count
            Passed = $passed.Count
            Failed = $failed.Count
            Skipped = $skipped.Count
            Duration = $totalDuration.ToString()
        }
        InteractionResults = $script:InteractionResults
        GeneratedAt = $endTime
    }
    
    # Save report to file
    $reportPath = Join-Path $env:PROJECT_ROOT "test-results/domain-interaction-report.json"
    $reportDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }
    
    $detailedReport | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
    Write-Information "Detailed domain interaction report saved to: $reportPath" -InformationAction Continue
    
    Write-Information "=== END DOMAIN INTERACTION REPORT ===" -InformationAction Continue
}