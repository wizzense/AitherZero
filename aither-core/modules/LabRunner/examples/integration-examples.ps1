# LabRunner Integration Examples
# Demonstrates integration with other AitherZero modules

#Requires -Version 7.0

# ============================================================================
# OPENTOFU PROVIDER INTEGRATION
# ============================================================================

function Example-OpenTofuIntegration {
    <#
    .SYNOPSIS
        Demonstrates LabRunner integration with OpenTofuProvider for infrastructure deployment

    .DESCRIPTION
        Shows how to use LabRunner to orchestrate complex OpenTofu deployments with
        dependency management and parallel execution
    #>

    Write-Host "=== OpenTofu Provider Integration Example ===" -ForegroundColor Cyan

    # Import required modules
    Import-Module ./aither-core/modules/LabRunner -Force
    Import-Module ./aither-core/modules/OpenTofuProvider -Force -ErrorAction SilentlyContinue

    # Define infrastructure deployment operations
    $infrastructureOps = @(
        @{
            Name = 'Plan-NetworkInfrastructure'
            Type = 'plan'
            Provider = 'opentofu'
            Script = {
                param($Parameters)

                # Use OpenTofuProvider to create deployment plan
                if (Get-Command "New-DeploymentPlan" -ErrorAction SilentlyContinue) {
                    $plan = New-DeploymentPlan -ConfigPath $Parameters.ConfigPath -Environment $Parameters.Environment
                    return @{
                        Success = $true
                        Plan = $plan
                        Message = "Infrastructure plan created successfully"
                    }
                } else {
                    # Simulate planning if OpenTofuProvider not available
                    Write-Host "Planning network infrastructure..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 3
                    return @{
                        Success = $true
                        Message = "Network infrastructure planning completed (simulated)"
                    }
                }
            }
            Parameters = @{
                ConfigPath = './opentofu/network/main.tf'
                Environment = 'production'
            }
            Priority = 1
            Timeout = 15
        },
        @{
            Name = 'Deploy-NetworkInfrastructure'
            Type = 'deploy'
            Provider = 'opentofu'
            Script = {
                param($Parameters)

                if (Get-Command "Start-InfrastructureDeployment" -ErrorAction SilentlyContinue) {
                    $deployment = Start-InfrastructureDeployment -ConfigPath $Parameters.ConfigPath -Environment $Parameters.Environment
                    return @{
                        Success = $deployment.Success
                        Resources = $deployment.Resources
                        Message = "Infrastructure deployment completed"
                    }
                } else {
                    Write-Host "Deploying network infrastructure..." -ForegroundColor Green
                    Start-Sleep -Seconds 8
                    return @{
                        Success = $true
                        Message = "Network infrastructure deployed successfully (simulated)"
                        Resources = @{
                            VPC = "vpc-12345"
                            Subnets = @("subnet-11111", "subnet-22222")
                            SecurityGroups = @("sg-web", "sg-db")
                        }
                    }
                }
            }
            Parameters = @{
                ConfigPath = './opentofu/network/main.tf'
                Environment = 'production'
            }
            Dependencies = @('Plan-NetworkInfrastructure')
            Priority = 2
            Timeout = 30
        },
        @{
            Name = 'Plan-ComputeInfrastructure'
            Type = 'plan'
            Provider = 'opentofu'
            Script = {
                param($Parameters)

                Write-Host "Planning compute infrastructure..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                return @{
                    Success = $true
                    Message = "Compute infrastructure planning completed"
                }
            }
            Parameters = @{
                ConfigPath = './opentofu/compute/main.tf'
                Environment = 'production'
            }
            Dependencies = @('Deploy-NetworkInfrastructure')
            Priority = 3
            Timeout = 10
        },
        @{
            Name = 'Deploy-ComputeInfrastructure'
            Type = 'deploy'
            Provider = 'opentofu'
            Script = {
                param($Parameters)

                Write-Host "Deploying compute infrastructure..." -ForegroundColor Green
                Start-Sleep -Seconds 12
                return @{
                    Success = $true
                    Message = "Compute infrastructure deployed successfully"
                    Resources = @{
                        LoadBalancer = "lb-web-001"
                        AutoScalingGroup = "asg-web-001"
                        Instances = @("i-111", "i-222", "i-333")
                    }
                }
            }
            Parameters = @{
                ConfigPath = './opentofu/compute/main.tf'
                Environment = 'production'
            }
            Dependencies = @('Plan-ComputeInfrastructure')
            Priority = 4
            Timeout = 25
        }
    )

    # Execute infrastructure deployment with enhanced progress tracking
    Write-Host "Starting infrastructure deployment with LabRunner orchestration..." -ForegroundColor White

    $deploymentResult = Invoke-ParallelLabRunner -Scripts $infrastructureOps -MaxConcurrency 2 -ShowProgress -SafeMode

    # Display results
    Write-Host "`nInfrastructure Deployment Results:" -ForegroundColor Cyan
    Write-Host "Total Operations: $($deploymentResult.TotalScripts)"
    Write-Host "Successful: $($deploymentResult.CompletedSuccessfully)"
    Write-Host "Failed: $($deploymentResult.Failed)"
    Write-Host "Average Duration: $([Math]::Round($deploymentResult.AverageDuration, 2)) seconds"

    if ($deploymentResult.Failed -eq 0) {
        Write-Host "✅ Infrastructure deployment completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Infrastructure deployment completed with errors." -ForegroundColor Red
    }

    return $deploymentResult
}

# ============================================================================
# ISOMANAGER INTEGRATION
# ============================================================================

function Example-ISOManagerIntegration {
    <#
    .SYNOPSIS
        Demonstrates LabRunner integration with ISOManager for automated OS deployment

    .DESCRIPTION
        Shows how to orchestrate ISO downloads, customization, and VM deployment
        using LabRunner's parallel execution capabilities
    #>

    Write-Host "=== ISO Manager Integration Example ===" -ForegroundColor Cyan

    # Define ISO management and deployment operations
    $isoOps = @(
        @{
            Name = 'Download-WindowsServerISO'
            Type = 'download'
            Provider = 'iso'
            Script = {
                param($Parameters)

                # Simulate ISO download (would use ISOManager in practice)
                Write-Host "Downloading Windows Server 2025 ISO..." -ForegroundColor Yellow
                for ($i = 1; $i -le 10; $i++) {
                    Write-Progress -Activity "Downloading ISO" -Status "$($i*10)% Complete" -PercentComplete ($i*10)
                    Start-Sleep -Seconds 1
                }
                Write-Progress -Activity "Downloading ISO" -Completed

                return @{
                    Success = $true
                    Message = "Windows Server 2025 ISO downloaded successfully"
                    ISOPath = "/tmp/windows-server-2025.iso"
                    Size = "5.2 GB"
                }
            }
            Parameters = @{
                ISOUrl = 'https://example.com/windows-server-2025.iso'
                DestinationPath = '/tmp/'
            }
            Priority = 1
            Timeout = 300  # 5 minutes for large download
        },
        @{
            Name = 'Download-UbuntuISO'
            Type = 'download'
            Provider = 'iso'
            Script = {
                param($Parameters)

                Write-Host "Downloading Ubuntu 24.04 LTS ISO..." -ForegroundColor Yellow
                for ($i = 1; $i -le 8; $i++) {
                    Write-Progress -Activity "Downloading Ubuntu ISO" -Status "$($i*12.5)% Complete" -PercentComplete ($i*12.5)
                    Start-Sleep -Seconds 1
                }
                Write-Progress -Activity "Downloading Ubuntu ISO" -Completed

                return @{
                    Success = $true
                    Message = "Ubuntu 24.04 LTS ISO downloaded successfully"
                    ISOPath = "/tmp/ubuntu-24.04-server.iso"
                    Size = "1.8 GB"
                }
            }
            Parameters = @{
                ISOUrl = 'https://releases.ubuntu.com/24.04/ubuntu-24.04-server-amd64.iso'
                DestinationPath = '/tmp/'
            }
            Priority = 1
            Timeout = 180
        },
        @{
            Name = 'Customize-WindowsISO'
            Type = 'customize'
            Provider = 'iso'
            Script = {
                param($Parameters)

                Write-Host "Customizing Windows Server ISO with automated installation..." -ForegroundColor Yellow
                Start-Sleep -Seconds 8

                return @{
                    Success = $true
                    Message = "Windows ISO customized with unattended installation"
                    CustomISOPath = "/tmp/windows-server-2025-custom.iso"
                    Features = @("AutoLogon", "JoinDomain", "InstallRoles")
                }
            }
            Parameters = @{
                SourceISO = "/tmp/windows-server-2025.iso"
                UnattendedXml = "./configs/windows-unattended.xml"
            }
            Dependencies = @('Download-WindowsServerISO')
            Priority = 2
            Timeout = 20
        },
        @{
            Name = 'Customize-UbuntuISO'
            Type = 'customize'
            Provider = 'iso'
            Script = {
                param($Parameters)

                Write-Host "Customizing Ubuntu ISO with cloud-init configuration..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5

                return @{
                    Success = $true
                    Message = "Ubuntu ISO customized with cloud-init"
                    CustomISOPath = "/tmp/ubuntu-24.04-custom.iso"
                    Features = @("SSH Keys", "User Config", "Package Installation")
                }
            }
            Parameters = @{
                SourceISO = "/tmp/ubuntu-24.04-server.iso"
                CloudInitConfig = "./configs/cloud-init.yaml"
            }
            Dependencies = @('Download-UbuntuISO')
            Priority = 2
            Timeout = 15
        },
        @{
            Name = 'Deploy-WindowsVMs'
            Type = 'deploy'
            Provider = 'hyperv'
            Script = {
                param($Parameters)

                Write-Host "Deploying Windows Server VMs..." -ForegroundColor Green
                Start-Sleep -Seconds 15

                return @{
                    Success = $true
                    Message = "Windows Server VMs deployed successfully"
                    VMs = @("WS-DC-01", "WS-APP-01", "WS-SQL-01")
                    Status = "Running"
                }
            }
            Parameters = @{
                CustomISO = "/tmp/windows-server-2025-custom.iso"
                VMCount = 3
                VMPrefix = "WS"
            }
            Dependencies = @('Customize-WindowsISO')
            Priority = 3
            Timeout = 45
        },
        @{
            Name = 'Deploy-UbuntuVMs'
            Type = 'deploy'
            Provider = 'hyperv'
            Script = {
                param($Parameters)

                Write-Host "Deploying Ubuntu Server VMs..." -ForegroundColor Green
                Start-Sleep -Seconds 12

                return @{
                    Success = $true
                    Message = "Ubuntu Server VMs deployed successfully"
                    VMs = @("UB-WEB-01", "UB-WEB-02", "UB-LB-01")
                    Status = "Running"
                }
            }
            Parameters = @{
                CustomISO = "/tmp/ubuntu-24.04-custom.iso"
                VMCount = 3
                VMPrefix = "UB"
            }
            Dependencies = @('Customize-UbuntuISO')
            Priority = 3
            Timeout = 35
        }
    )

    # Execute ISO operations with resource optimization
    Write-Host "Starting ISO management and VM deployment workflow..." -ForegroundColor White

    $isoResult = Invoke-ParallelLabRunner -Scripts $isoOps -MaxConcurrency 3 -ShowProgress

    # Display results
    Write-Host "`nISO Management and Deployment Results:" -ForegroundColor Cyan
    Write-Host "Total Operations: $($isoResult.TotalScripts)"
    Write-Host "Successful: $($isoResult.CompletedSuccessfully)"
    Write-Host "Failed: $($isoResult.Failed)"
    Write-Host "Total Duration: $([Math]::Round($isoResult.TotalDuration, 2)) seconds"

    return $isoResult
}

# ============================================================================
# LOGGING AND PROGRESS TRACKING INTEGRATION
# ============================================================================

function Example-LoggingProgressIntegration {
    <#
    .SYNOPSIS
        Demonstrates advanced logging and progress tracking integration

    .DESCRIPTION
        Shows how to use LabRunner with comprehensive logging and real-time
        progress tracking for complex deployment scenarios
    #>

    Write-Host "=== Logging and Progress Tracking Integration Example ===" -ForegroundColor Cyan

    # Import modules with enhanced logging
    Import-Module ./aither-core/modules/LabRunner -Force
    
    # Write-CustomLog is guaranteed to be available from AitherCore orchestration
    # No explicit Logging import needed - trust the orchestration system
    Import-Module ./aither-core/modules/ProgressTracking -Force -ErrorAction SilentlyContinue

    # Define operations with comprehensive logging
    $loggingOps = @(
        @{
            Name = 'Initialize-DeploymentEnvironment'
            Type = 'setup'
            Script = {
                Write-CustomLog -Level 'INFO' -Message "Initializing deployment environment..."

                # Simulate environment setup with detailed logging
                $steps = @(
                    "Validating prerequisites",
                    "Setting up temporary directories",
                    "Loading configuration files",
                    "Establishing connections",
                    "Preparing deployment workspace"
                )

                foreach ($step in $steps) {
                    Write-CustomLog -Level 'DEBUG' -Message "Step: $step"
                    Start-Sleep -Seconds 1
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Deployment environment initialized successfully"

                return @{
                    Success = $true
                    Message = "Environment initialization completed"
                    Resources = @{
                        TempDir = "/tmp/deployment-12345"
                        ConfigFiles = 15
                        Connections = 3
                    }
                }
            }
            Priority = 1
            Timeout = 20
        },
        @{
            Name = 'Deploy-ApplicationTier'
            Type = 'application'
            Script = {
                Write-CustomLog -Level 'INFO' -Message "Deploying application tier..."

                # Simulate application deployment with progress updates
                $components = @("Frontend", "Backend API", "Message Queue", "Cache Layer")

                foreach ($component in $components) {
                    Write-CustomLog -Level 'INFO' -Message "Deploying component: $component"

                    # Simulate component deployment
                    for ($i = 1; $i -le 5; $i++) {
                        Write-CustomLog -Level 'DEBUG' -Message "$component deployment progress: $($i*20)%"
                        Start-Sleep -Seconds 1
                    }

                    Write-CustomLog -Level 'SUCCESS' -Message "$component deployed successfully"
                }

                return @{
                    Success = $true
                    Message = "Application tier deployed successfully"
                    Components = $components
                }
            }
            Dependencies = @('Initialize-DeploymentEnvironment')
            Priority = 2
            Timeout = 30
        },
        @{
            Name = 'Deploy-DatabaseTier'
            Type = 'database'
            Script = {
                Write-CustomLog -Level 'INFO' -Message "Deploying database tier..."

                # Simulate database deployment with performance metrics
                $dbOperations = @(
                    @{Name = "Create database cluster"; Duration = 8},
                    @{Name = "Configure replication"; Duration = 5},
                    @{Name = "Import initial data"; Duration = 12},
                    @{Name = "Setup monitoring"; Duration = 3}
                )

                foreach ($operation in $dbOperations) {
                    $startTime = Get-Date
                    Write-CustomLog -Level 'INFO' -Message "Starting: $($operation.Name)"

                    Start-Sleep -Seconds $operation.Duration

                    $endTime = Get-Date
                    $actualDuration = ($endTime - $startTime).TotalSeconds
                    Write-CustomLog -Level 'SUCCESS' -Message "Completed: $($operation.Name) (${actualDuration}s)"
                }

                return @{
                    Success = $true
                    Message = "Database tier deployed successfully"
                    ClusterNodes = 3
                    ReplicationLag = "< 1ms"
                }
            }
            Dependencies = @('Initialize-DeploymentEnvironment')
            Priority = 2
            Timeout = 35
        },
        @{
            Name = 'Configure-LoadBalancing'
            Type = 'networking'
            Script = {
                Write-CustomLog -Level 'INFO' -Message "Configuring load balancing..."

                # Simulate load balancer configuration
                $lbSteps = @(
                    "Creating load balancer instance",
                    "Configuring health checks",
                    "Adding backend targets",
                    "Setting up SSL termination",
                    "Configuring routing rules"
                )

                foreach ($step in $lbSteps) {
                    Write-CustomLog -Level 'INFO' -Message "Load balancer step: $step"
                    Start-Sleep -Seconds 2
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Load balancing configured successfully"

                return @{
                    Success = $true
                    Message = "Load balancing configuration completed"
                    BackendTargets = 3
                    HealthCheckInterval = "30s"
                }
            }
            Dependencies = @('Deploy-ApplicationTier', 'Deploy-DatabaseTier')
            Priority = 3
            Timeout = 25
        },
        @{
            Name = 'Run-IntegrationValidation'
            Type = 'validation'
            Script = {
                Write-CustomLog -Level 'INFO' -Message "Running integration validation..."

                # Simulate comprehensive validation
                $validationTests = @(
                    @{Name = "API endpoint connectivity"; Expected = "Pass"},
                    @{Name = "Database connection pooling"; Expected = "Pass"},
                    @{Name = "Load balancer health checks"; Expected = "Pass"},
                    @{Name = "SSL certificate validation"; Expected = "Pass"},
                    @{Name = "Performance baseline test"; Expected = "Pass"}
                )

                $testResults = @()
                foreach ($test in $validationTests) {
                    Write-CustomLog -Level 'INFO' -Message "Running test: $($test.Name)"
                    Start-Sleep -Seconds 3

                    # Simulate occasional test failures for demonstration
                    $result = if ((Get-Random -Maximum 100) -gt 95) { "Fail" } else { "Pass" }

                    if ($result -eq "Pass") {
                        Write-CustomLog -Level 'SUCCESS' -Message "✅ $($test.Name): PASSED"
                    } else {
                        Write-CustomLog -Level 'ERROR' -Message "❌ $($test.Name): FAILED"
                    }

                    $testResults += @{
                        Test = $test.Name
                        Result = $result
                        Expected = $test.Expected
                    }
                }

                $passedTests = ($testResults | Where-Object { $_.Result -eq "Pass" }).Count
                $totalTests = $testResults.Count

                Write-CustomLog -Level 'INFO' -Message "Validation complete: $passedTests/$totalTests tests passed"

                return @{
                    Success = $passedTests -eq $totalTests
                    Message = "Integration validation completed"
                    TestResults = $testResults
                    PassRate = [Math]::Round(($passedTests / $totalTests) * 100, 2)
                }
            }
            Dependencies = @('Configure-LoadBalancing')
            Priority = 4
            Timeout = 40
        }
    )

    # Execute with enhanced monitoring
    Write-Host "Starting deployment with comprehensive logging and progress tracking..." -ForegroundColor White

    $result = Invoke-ParallelLabRunner -Scripts $loggingOps -MaxConcurrency 2 -ShowProgress -ProgressStyle 'Detailed'

    # Generate comprehensive summary
    Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
    Write-Host "Total Operations: $($result.TotalScripts)"
    Write-Host "Successful Operations: $($result.CompletedSuccessfully)" -ForegroundColor Green
    Write-Host "Failed Operations: $($result.Failed)" -ForegroundColor $(if ($result.Failed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Average Execution Time: $([Math]::Round($result.AverageDuration, 2)) seconds"
    Write-Host "Total Execution Time: $([Math]::Round($result.TotalDuration, 2)) seconds"

    if ($result.ProgressTrackingEnabled) {
        Write-Host "Progress Tracking: Enabled ✅" -ForegroundColor Green
    } else {
        Write-Host "Progress Tracking: Disabled ⚠️" -ForegroundColor Yellow
    }

    return $result
}

# ============================================================================
# SECUECREDENTIALS INTEGRATION
# ============================================================================

function Example-SecureCredentialsIntegration {
    <#
    .SYNOPSIS
        Demonstrates secure credential management integration with LabRunner

    .DESCRIPTION
        Shows how to use LabRunner with SecureCredentials module for
        enterprise-grade credential management during deployments
    #>

    Write-Host "=== Secure Credentials Integration Example ===" -ForegroundColor Cyan

    # Define operations that require secure credentials
    $secureOps = @(
        @{
            Name = 'Deploy-DomainController'
            Type = 'infrastructure'
            Script = {
                param($Parameters)

                Write-Host "Deploying domain controller with secure credentials..." -ForegroundColor Yellow

                # Simulate credential retrieval (would use SecureCredentials module)
                Write-Host "  - Retrieving domain admin credentials from secure vault"
                Write-Host "  - Validating certificate for domain controller"
                Write-Host "  - Applying security policies"

                Start-Sleep -Seconds 10

                return @{
                    Success = $true
                    Message = "Domain controller deployed with enterprise security"
                    Domain = $Parameters.DomainName
                    SecurityLevel = "Enterprise"
                }
            }
            Parameters = @{
                DomainName = "corp.local"
                AdminUser = "administrator"
                # Credentials would be retrieved securely
            }
            Priority = 1
            Timeout = 30
        },
        @{
            Name = 'Setup-DatabaseSecurity'
            Type = 'security'
            Script = {
                param($Parameters)

                Write-Host "Setting up database security with encrypted connections..." -ForegroundColor Yellow

                # Simulate secure database configuration
                Write-Host "  - Generating database encryption keys"
                Write-Host "  - Configuring TDE (Transparent Data Encryption)"
                Write-Host "  - Setting up service accounts with least privileges"
                Write-Host "  - Configuring Always Encrypted for sensitive columns"

                Start-Sleep -Seconds 8

                return @{
                    Success = $true
                    Message = "Database security configured successfully"
                    EncryptionLevel = "AES-256"
                    TDEEnabled = $true
                    AlwaysEncrypted = $true
                }
            }
            Parameters = @{
                DatabaseServer = "sql-cluster.corp.local"
                ServiceAccount = "sql-service"
            }
            Dependencies = @('Deploy-DomainController')
            Priority = 2
            Timeout = 25
        },
        @{
            Name = 'Configure-ApplicationSecurity'
            Type = 'application'
            Script = {
                param($Parameters)

                Write-Host "Configuring application security with OAuth and certificates..." -ForegroundColor Yellow

                # Simulate application security setup
                Write-Host "  - Deploying SSL certificates from enterprise CA"
                Write-Host "  - Configuring OAuth 2.0 / OpenID Connect"
                Write-Host "  - Setting up API key management"
                Write-Host "  - Implementing rate limiting and WAF rules"

                Start-Sleep -Seconds 12

                return @{
                    Success = $true
                    Message = "Application security configured successfully"
                    SSLGrade = "A+"
                    OAuthEnabled = $true
                    WAFRules = 25
                }
            }
            Parameters = @{
                ApplicationUrl = "https://app.corp.local"
                CertificateThumbprint = "ABC123..."
            }
            Dependencies = @('Setup-DatabaseSecurity')
            Priority = 3
            Timeout = 30
        }
    )

    # Execute with security focus
    Write-Host "Starting secure enterprise deployment..." -ForegroundColor White

    $secureResult = Invoke-ParallelLabRunner -Scripts $secureOps -MaxConcurrency 1 -SafeMode -ShowProgress

    # Security summary
    Write-Host "`n=== Security Deployment Summary ===" -ForegroundColor Cyan
    Write-Host "Operations Completed: $($secureResult.CompletedSuccessfully)/$($secureResult.TotalScripts)"
    Write-Host "Security Mode: Enterprise Grade ✅" -ForegroundColor Green
    Write-Host "Safe Mode: Enabled ✅" -ForegroundColor Green

    return $secureResult
}

# ============================================================================
# COMPREHENSIVE INTEGRATION EXAMPLE
# ============================================================================

function Example-ComprehensiveIntegration {
    <#
    .SYNOPSIS
        Comprehensive example combining multiple module integrations

    .DESCRIPTION
        Demonstrates a complete enterprise deployment using LabRunner to orchestrate
        multiple AitherZero modules in a complex, real-world scenario
    #>

    Write-Host "=== Comprehensive Multi-Module Integration Example ===" -ForegroundColor Cyan

    # Configuration for comprehensive deployment
    $comprehensiveConfig = @{
        Environment = "Production"
        Region = "East-US"
        DeploymentId = "PROD-$(Get-Date -Format 'yyyyMMdd-HHmm')"
        SecurityLevel = "Enterprise"
        Compliance = "SOC2-TypeII"
    }

    Write-Host "Deployment Configuration:" -ForegroundColor White
    $comprehensiveConfig | Format-Table -AutoSize

    # Execute each integration example
    Write-Host "`n🚀 Phase 1: Infrastructure Deployment (OpenTofu Integration)" -ForegroundColor Magenta
    $infraResult = Example-OpenTofuIntegration

    Write-Host "`n🔧 Phase 2: OS and VM Deployment (ISO Manager Integration)" -ForegroundColor Magenta
    $isoResult = Example-ISOManagerIntegration

    Write-Host "`n🔒 Phase 3: Security Configuration (Secure Credentials Integration)" -ForegroundColor Magenta
    $securityResult = Example-SecureCredentialsIntegration

    Write-Host "`n📊 Phase 4: Application Deployment (Logging & Progress Integration)" -ForegroundColor Magenta
    $appResult = Example-LoggingProgressIntegration

    # Comprehensive summary
    $overallResults = @{
        Infrastructure = $infraResult
        OSDeployment = $isoResult
        Security = $securityResult
        Application = $appResult
        OverallSuccess = (
            $infraResult.Failed -eq 0 -and
            $isoResult.Failed -eq 0 -and
            $securityResult.Failed -eq 0 -and
            $appResult.Failed -eq 0
        )
        TotalOperations = $infraResult.TotalScripts + $isoResult.TotalScripts + $securityResult.TotalScripts + $appResult.TotalScripts
        TotalSuccessful = $infraResult.CompletedSuccessfully + $isoResult.CompletedSuccessfully + $securityResult.CompletedSuccessfully + $appResult.CompletedSuccessfully
        TotalFailed = $infraResult.Failed + $isoResult.Failed + $securityResult.Failed + $appResult.Failed
    }

    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    Write-Host "COMPREHENSIVE DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "="*80 -ForegroundColor Cyan
    Write-Host "Deployment ID: $($comprehensiveConfig.DeploymentId)"
    Write-Host "Environment: $($comprehensiveConfig.Environment)"
    Write-Host "Security Level: $($comprehensiveConfig.SecurityLevel)"
    Write-Host "Compliance: $($comprehensiveConfig.Compliance)"
    Write-Host ""
    Write-Host "Phase Results:" -ForegroundColor Yellow
    Write-Host "  Infrastructure: $(if ($infraResult.Failed -eq 0) { '✅ SUCCESS' } else { '❌ FAILED' })" -ForegroundColor $(if ($infraResult.Failed -eq 0) { 'Green' } else { 'Red' })
    Write-Host "  OS Deployment: $(if ($isoResult.Failed -eq 0) { '✅ SUCCESS' } else { '❌ FAILED' })" -ForegroundColor $(if ($isoResult.Failed -eq 0) { 'Green' } else { 'Red' })
    Write-Host "  Security Config: $(if ($securityResult.Failed -eq 0) { '✅ SUCCESS' } else { '❌ FAILED' })" -ForegroundColor $(if ($securityResult.Failed -eq 0) { 'Green' } else { 'Red' })
    Write-Host "  Application Deploy: $(if ($appResult.Failed -eq 0) { '✅ SUCCESS' } else { '❌ FAILED' })" -ForegroundColor $(if ($appResult.Failed -eq 0) { 'Green' } else { 'Red' })
    Write-Host ""
    Write-Host "Overall Statistics:" -ForegroundColor Yellow
    Write-Host "  Total Operations: $($overallResults.TotalOperations)"
    Write-Host "  Successful: $($overallResults.TotalSuccessful)" -ForegroundColor Green
    Write-Host "  Failed: $($overallResults.TotalFailed)" -ForegroundColor $(if ($overallResults.TotalFailed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Success Rate: $([Math]::Round(($overallResults.TotalSuccessful / $overallResults.TotalOperations) * 100, 2))%"
    Write-Host ""
    Write-Host "Final Status: $(if ($overallResults.OverallSuccess) { '🎉 DEPLOYMENT SUCCESSFUL' } else { '⚠️ DEPLOYMENT COMPLETED WITH ERRORS' })" -ForegroundColor $(if ($overallResults.OverallSuccess) { 'Green' } else { 'Yellow' })
    Write-Host "="*80 -ForegroundColor Cyan

    return $overallResults
}

# ============================================================================
# EXAMPLE EXECUTION
# ============================================================================

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "LabRunner Integration Examples" -ForegroundColor Green
    Write-Host "Choose an example to run:" -ForegroundColor White
    Write-Host "1. OpenTofu Provider Integration"
    Write-Host "2. ISO Manager Integration"
    Write-Host "3. Logging and Progress Tracking Integration"
    Write-Host "4. Secure Credentials Integration"
    Write-Host "5. Comprehensive Multi-Module Integration"
    Write-Host "0. Exit"

    do {
        $choice = Read-Host "`nEnter your choice (0-5)"

        switch ($choice) {
            "1" { Example-OpenTofuIntegration }
            "2" { Example-ISOManagerIntegration }
            "3" { Example-LoggingProgressIntegration }
            "4" { Example-SecureCredentialsIntegration }
            "5" { Example-ComprehensiveIntegration }
            "0" { Write-Host "Exiting..." -ForegroundColor Yellow; break }
            default { Write-Host "Invalid choice. Please enter 0-5." -ForegroundColor Red }
        }
    } while ($choice -ne "0")
}
