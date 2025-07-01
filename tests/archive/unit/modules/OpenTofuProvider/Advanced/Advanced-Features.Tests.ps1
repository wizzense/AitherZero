BeforeAll {
    # Find project root and import module
    . "$PSScriptRoot/../../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force
    
    # Mock environment
    $env:PROJECT_ROOT = $TestDrive
    
    # Create test deployment structure
    $script:testDeploymentId = [Guid]::NewGuid().ToString()
    $script:deploymentPath = Join-Path $TestDrive "deployments" $script:testDeploymentId
    New-Item -Path $script:deploymentPath -ItemType Directory -Force | Out-Null
    
    # Create test deployment state
    $testState = @{
        Id = $script:testDeploymentId
        StartTime = (Get-Date).AddHours(-2)
        EndTime = (Get-Date).AddHours(-1)
        Status = "Completed"
        CompletedStages = @("Prepare", "Validate", "Plan", "Apply")
        Errors = @()
        Warnings = @()
        ConfigurationPath = Join-Path $TestDrive "test-config.yaml"
    }
    $testState | ConvertTo-Json | Set-Content -Path (Join-Path $script:deploymentPath "state.json")
    
    # Create test configuration
    $testConfig = @{
        version = "1.0"
        repository = @{ name = "test-repo"; version = "1.0.0" }
        template = @{ name = "test-template" }
        infrastructure = @{
            virtual_machine = @{
                name = "test-vm"
                memory_mb = 2048
                cpu_count = 2
            }
        }
    }
    $testConfig | ConvertTo-Json | Set-Content -Path $testState.ConfigurationPath
    $testConfig | ConvertTo-Json | Set-Content -Path (Join-Path $script:deploymentPath "deployment-config.json")
}

Describe "Test-InfrastructureDrift Tests" {
    BeforeEach {
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Get-DeploymentStatus {
            [PSCustomObject]@{
                DeploymentId = $script:testDeploymentId
                Success = $true
                Status = "Completed"
            }
        } -ModuleName OpenTofuProvider
        
        Mock Get-DeploymentProvider {
            [PSCustomObject]@{
                Name = "Hyper-V"
            }
        } -ModuleName OpenTofuProvider
        
        Mock Get-ActualInfrastructureState {
            @{
                "test-vm" = @{
                    Name = "test-vm"
                    Type = "virtual_machine"
                    Configuration = @{
                        memory_mb = 4096  # Different from desired (2048)
                        cpu_count = 2
                    }
                }
            }
        } -ModuleName OpenTofuProvider
    }
    
    Context "Drift Detection" {
        It "Should detect drift when infrastructure differs from configuration" {
            $result = Test-InfrastructureDrift -DeploymentId $script:testDeploymentId
            
            $result.DriftDetected | Should -Be $true
            $result.Summary.DriftedResources | Should -Be 1
            $result.DriftItems | Should -HaveCount 1
            $result.DriftItems[0].DriftType | Should -Be "Modified"
        }
        
        It "Should not detect drift when infrastructure matches configuration" {
            Mock Get-ActualInfrastructureState {
                @{
                    "test-vm" = @{
                        Name = "test-vm"
                        Type = "virtual_machine"
                        Configuration = @{
                            memory_mb = 2048  # Matches desired
                            cpu_count = 2
                        }
                    }
                }
            } -ModuleName OpenTofuProvider
            
            $result = Test-InfrastructureDrift -DeploymentId $script:testDeploymentId
            
            $result.DriftDetected | Should -Be $false
            $result.Summary.DriftedResources | Should -Be 0
        }
        
        It "Should include detailed information when requested" {
            $result = Test-InfrastructureDrift -DeploymentId $script:testDeploymentId -IncludeDetails
            
            $result.DriftItems[0].Details | Should -Not -BeNullOrEmpty
            $result.DriftItems[0].Details.DesiredConfiguration | Should -Not -BeNullOrEmpty
            $result.DriftItems[0].Details.ActualConfiguration | Should -Not -BeNullOrEmpty
        }
        
        It "Should save report when requested" {
            Mock Save-DriftReport {
                return Join-Path $TestDrive "drift-report.html"
            } -ModuleName OpenTofuProvider
            
            $result = Test-InfrastructureDrift -DeploymentId $script:testDeploymentId -SaveReport
            
            $result.ReportPath | Should -Not -BeNullOrEmpty
            Should -Invoke Save-DriftReport -ModuleName OpenTofuProvider
        }
    }
    
    Context "Output Formats" {
        It "Should support different output formats" {
            Mock Format-DriftReport {
                return "Formatted report"
            } -ModuleName OpenTofuProvider
            
            $result = Test-InfrastructureDrift -DeploymentId $script:testDeploymentId -OutputFormat "HTML"
            
            Should -Invoke Format-DriftReport -ModuleName OpenTofuProvider -ParameterFilter {
                $OutputFormat -eq "HTML"
            }
        }
    }
}

Describe "Start-DeploymentRollback Tests" {
    BeforeEach {
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Get-DeploymentStatus {
            [PSCustomObject]@{
                DeploymentId = $script:testDeploymentId
                Success = $true
                Status = "Completed"
            }
        } -ModuleName OpenTofuProvider
        
        Mock Get-LastGoodDeployment {
            @{
                IsValid = $true
                Type = "LastGood"
                Description = "Last successful deployment"
                StateData = @{ Status = "Completed" }
                ConfigurationPath = Join-Path $TestDrive "test-config.yaml"
            }
        } -ModuleName OpenTofuProvider
        
        Mock New-RollbackPlan {
            @{
                IsValid = $true
                ValidationErrors = @()
                Actions = @(
                    @{ Type = "Modify"; Description = "Update VM memory" }
                )
                EstimatedDuration = [TimeSpan]::FromMinutes(5)
            }
        } -ModuleName OpenTofuProvider
        
        Mock Invoke-RollbackPlan {
            @{
                Success = $true
                Errors = @()
                Warnings = @()
                CompletedActions = 1
                FailedActions = 0
            }
        } -ModuleName OpenTofuProvider
    }
    
    Context "Rollback Operations" {
        It "Should perform rollback to last good deployment" {
            $result = Start-DeploymentRollback -DeploymentId $script:testDeploymentId -RollbackType "LastGood" -Force
            
            $result.Success | Should -Be $true
            $result.RollbackType | Should -Be "LastGood"
            Should -Invoke Invoke-RollbackPlan -ModuleName OpenTofuProvider
        }
        
        It "Should create backup when requested" {
            Mock New-DeploymentSnapshot {
                @{
                    Success = $true
                    SnapshotPath = "backup-path"
                }
            } -ModuleName OpenTofuProvider
            
            $result = Start-DeploymentRollback -DeploymentId $script:testDeploymentId -CreateBackup -Force
            
            $result.BackupCreated | Should -Be $true
            $result.BackupPath | Should -Be "backup-path"
            Should -Invoke New-DeploymentSnapshot -ModuleName OpenTofuProvider
        }
        
        It "Should support dry-run mode" {
            $result = Start-DeploymentRollback -DeploymentId $script:testDeploymentId -DryRun
            
            $result.Success | Should -Be $true
            $result.DryRun | Should -Be $true
            Should -Not -Invoke Invoke-RollbackPlan -ModuleName OpenTofuProvider
        }
        
        It "Should handle rollback plan validation failures" {
            Mock New-RollbackPlan {
                @{
                    IsValid = $false
                    ValidationErrors = @("Invalid plan")
                }
            } -ModuleName OpenTofuProvider
            
            { Start-DeploymentRollback -DeploymentId $script:testDeploymentId -Force } |
                Should -Throw "*Invalid plan*"
        }
    }
    
    Context "Target Selection" {
        It "Should rollback to specific snapshot" {
            Mock Get-SnapshotInfo {
                @{
                    IsValid = $true
                    Type = "Snapshot"
                    Name = "test-snapshot"
                    Description = "Test snapshot"
                }
            } -ModuleName OpenTofuProvider
            
            $result = Start-DeploymentRollback -DeploymentId $script:testDeploymentId -TargetSnapshot "test-snapshot" -Force
            
            Should -Invoke Get-SnapshotInfo -ModuleName OpenTofuProvider -ParameterFilter {
                $SnapshotName -eq "test-snapshot"
            }
        }
        
        It "Should rollback to specific version" {
            Mock Get-VersionInfo {
                @{
                    IsValid = $true
                    Type = "Version"
                    Name = "1.0.0"
                    Description = "Version 1.0.0"
                }
            } -ModuleName OpenTofuProvider
            
            $result = Start-DeploymentRollback -DeploymentId $script:testDeploymentId -TargetVersion "1.0.0" -Force
            
            Should -Invoke Get-VersionInfo -ModuleName OpenTofuProvider -ParameterFilter {
                $Version -eq "1.0.0"
            }
        }
    }
}

Describe "New-DeploymentSnapshot Tests" {
    BeforeEach {
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Get-DeploymentStatus {
            [PSCustomObject]@{
                DeploymentId = $script:testDeploymentId
                Success = $true
                Status = "Completed"
            }
        } -ModuleName OpenTofuProvider
        
        Mock Get-DeploymentProvider {
            [PSCustomObject]@{ Name = "Hyper-V" }
        } -ModuleName OpenTofuProvider
        
        Mock Get-ActualInfrastructureState {
            @{ "test-vm" = @{ Name = "test-vm"; Type = "virtual_machine" } }
        } -ModuleName OpenTofuProvider
        
        # Create snapshots directory
        $snapshotsDir = Join-Path $script:deploymentPath "snapshots"
        New-Item -Path $snapshotsDir -ItemType Directory -Force | Out-Null
    }
    
    Context "Snapshot Creation" {
        It "Should create deployment snapshot successfully" {
            $result = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "test-snapshot"
            
            $result.Success | Should -Be $true
            $result.SnapshotName | Should -Be "test-snapshot"
            $result.SnapshotPath | Should -Not -BeNullOrEmpty
        }
        
        It "Should include configuration when requested" {
            $result = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "config-snapshot" -IncludeConfiguration
            
            $result.Success | Should -Be $true
            
            # Verify snapshot file was created
            $snapshotPath = Join-Path $script:deploymentPath "snapshots" "config-snapshot.json"
            Test-Path $snapshotPath | Should -Be $true
        }
        
        It "Should include infrastructure state when requested" {
            $result = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "state-snapshot" -IncludeState
            
            $result.Success | Should -Be $true
            Should -Invoke Get-ActualInfrastructureState -ModuleName OpenTofuProvider
        }
        
        It "Should return snapshot object when PassThru is specified" {
            $result = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "passthru-snapshot" -PassThru
            
            $result.Snapshot | Should -Not -BeNullOrEmpty
            $result.Snapshot.Name | Should -Be "passthru-snapshot"
        }
        
        It "Should validate snapshot name format" {
            { New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "invalid name!" } |
                Should -Throw
        }
    }
    
    Context "Snapshot Content" {
        It "Should include description when provided" {
            $description = "Test snapshot description"
            $result = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "desc-snapshot" -Description $description -PassThru
            
            $result.Snapshot.Description | Should -Be $description
        }
        
        It "Should include metadata" {
            $result = New-DeploymentSnapshot -DeploymentId $script:testDeploymentId -Name "meta-snapshot" -PassThru
            
            $result.Snapshot.Metadata | Should -Not -BeNullOrEmpty
            $result.Snapshot.Metadata.Size | Should -BeGreaterThan 0
            $result.Snapshot.Metadata.Checksum | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Get-DeploymentHistory Tests" {
    BeforeEach {
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        
        # Create additional test deployments
        $deployment2Id = [Guid]::NewGuid().ToString()
        $deployment2Path = Join-Path $TestDrive "deployments" $deployment2Id
        New-Item -Path $deployment2Path -ItemType Directory -Force | Out-Null
        
        $state2 = @{
            Id = $deployment2Id
            StartTime = (Get-Date).AddDays(-1)
            EndTime = (Get-Date).AddDays(-1).AddHours(1)
            Status = "Failed"
            CompletedStages = @("Prepare", "Validate")
            Errors = @("Test error")
            Warnings = @()
        }
        $state2 | ConvertTo-Json | Set-Content -Path (Join-Path $deployment2Path "state.json")
    }
    
    Context "History Retrieval" {
        It "Should get history for specific deployment" {
            $history = Get-DeploymentHistory -DeploymentId $script:testDeploymentId
            
            $history.Count | Should -Be 1
            $history[0].DeploymentId | Should -Be $script:testDeploymentId
            $history[0].Status | Should -Be "Completed"
        }
        
        It "Should get history for all deployments" {
            $history = Get-DeploymentHistory
            
            $history.Count | Should -Be 2
            $history[0].Status | Should -BeIn @("Completed", "Failed")
        }
        
        It "Should filter by status" {
            $history = Get-DeploymentHistory -Status "Completed"
            
            $history.Count | Should -Be 1
            $history[0].Status | Should -Be "Completed"
        }
        
        It "Should filter by time range" {
            $history = Get-DeploymentHistory -TimeRange "Last24Hours"
            
            $history.Count | Should -BeGreaterOrEqual 1
        }
        
        It "Should include details when requested" {
            Mock Get-SingleDeploymentHistory {
                [PSCustomObject]@{
                    DeploymentId = $script:testDeploymentId
                    Status = "Completed"
                    Plan = @{ TotalStages = 5 }
                    Changes = @()
                }
            } -ModuleName OpenTofuProvider
            
            $history = Get-DeploymentHistory -DeploymentId $script:testDeploymentId -IncludeDetails
            
            Should -Invoke Get-SingleDeploymentHistory -ModuleName OpenTofuProvider -ParameterFilter {
                $IncludeDetails -eq $true
            }
        }
    }
    
    Context "Output Formats" {
        It "Should support table format" {
            Mock Format-DeploymentHistory {
                return "Table format"
            } -ModuleName OpenTofuProvider
            
            $result = Get-DeploymentHistory -OutputFormat "Table"
            
            Should -Invoke Format-DeploymentHistory -ModuleName OpenTofuProvider -ParameterFilter {
                $OutputFormat -eq "Table"
            }
        }
        
        It "Should support timeline format" {
            Mock Format-DeploymentTimeline {} -ModuleName OpenTofuProvider
            
            Get-DeploymentHistory -OutputFormat "Timeline"
            
            Should -Invoke Format-DeploymentTimeline -ModuleName OpenTofuProvider
        }
        
        It "Should export when requested" {
            Mock Export-DeploymentHistory {} -ModuleName OpenTofuProvider
            
            $exportPath = Join-Path $TestDrive "history.csv"
            Get-DeploymentHistory -ExportPath $exportPath
            
            Should -Invoke Export-DeploymentHistory -ModuleName OpenTofuProvider
        }
    }
}

Describe "Start-DeploymentAutomation Tests" {
    BeforeEach {
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Get-DeploymentStatus {
            [PSCustomObject]@{
                DeploymentId = $script:testDeploymentId
                Success = $true
                Status = "Completed"
            }
        } -ModuleName OpenTofuProvider
        
        Mock New-AutomationTasks {} -ModuleName OpenTofuProvider
        Mock Register-AutomationTasks {} -ModuleName OpenTofuProvider
        Mock Update-DeploymentForAutomation {} -ModuleName OpenTofuProvider
    }
    
    Context "Automation Configuration" {
        It "Should configure scheduled automation" {
            $result = Start-DeploymentAutomation -DeploymentId $script:testDeploymentId -AutomationType "Scheduled" -EnableDriftDetection
            
            $result.Success | Should -Be $true
            $result.AutomationType | Should -Be "Scheduled"
            $result.EnabledFeatures | Should -Contain "DriftDetection"
        }
        
        It "Should configure monitoring automation" {
            $result = Start-DeploymentAutomation -DeploymentId $script:testDeploymentId -AutomationType "Monitoring" -DriftCheckInterval 6
            
            $result.Success | Should -Be $true
            $result.AutomationType | Should -Be "Monitoring"
        }
        
        It "Should enable auto backup when requested" {
            $result = Start-DeploymentAutomation -DeploymentId $script:testDeploymentId -AutomationType "Maintenance" -EnableAutoBackup -BackupRetention 5
            
            $result.EnabledFeatures | Should -Contain "AutoBackup"
        }
        
        It "Should enable notifications when endpoint provided" {
            $result = Start-DeploymentAutomation -DeploymentId $script:testDeploymentId -AutomationType "Monitoring" -NotificationEndpoint "https://webhook.example.com"
            
            $result.EnabledFeatures | Should -Contain "Notifications"
        }
    }
    
    Context "Task Creation" {
        It "Should create automation tasks" {
            Start-DeploymentAutomation -DeploymentId $script:testDeploymentId -AutomationType "Scheduled"
            
            Should -Invoke New-AutomationTasks -ModuleName OpenTofuProvider
        }
        
        It "Should register scheduled tasks on Windows" {
            $IsWindows = $true
            
            Start-DeploymentAutomation -DeploymentId $script:testDeploymentId -AutomationType "Scheduled"
            
            Should -Invoke Register-AutomationTasks -ModuleName OpenTofuProvider
        }
        
        It "Should update deployment state" {
            Start-DeploymentAutomation -DeploymentId $script:testDeploymentId -AutomationType "Monitoring"
            
            Should -Invoke Update-DeploymentForAutomation -ModuleName OpenTofuProvider
        }
    }
}

Describe "Stop-DeploymentAutomation Tests" {
    BeforeEach {
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        
        # Create automation configuration
        $automationDir = Join-Path $script:deploymentPath "automation"
        New-Item -Path $automationDir -ItemType Directory -Force | Out-Null
        
        $automationConfig = @{
            DeploymentId = $script:testDeploymentId
            AutomationType = "Scheduled"
            Enabled = $true
            Status = "Active"
        }
        $automationConfig | ConvertTo-Json | Set-Content -Path (Join-Path $automationDir "automation-config.json")
    }
    
    Context "Automation Stopping" {
        It "Should stop automation successfully" {
            $result = Stop-DeploymentAutomation -DeploymentId $script:testDeploymentId
            
            $result.Success | Should -Be $true
            $result.Message | Should -Match "stopped successfully"
        }
        
        It "Should remove configuration when requested" {
            $automationDir = Join-Path $script:deploymentPath "automation"
            
            Stop-DeploymentAutomation -DeploymentId $script:testDeploymentId -RemoveConfiguration
            
            Test-Path $automationDir | Should -Be $false
        }
        
        It "Should disable automation when not removing configuration" {
            $configPath = Join-Path $script:deploymentPath "automation" "automation-config.json"
            
            Stop-DeploymentAutomation -DeploymentId $script:testDeploymentId
            
            $config = Get-Content $configPath | ConvertFrom-Json
            $config.Enabled | Should -Be $false
            $config.Status | Should -Be "Disabled"
        }
    }
}

Describe "Get-DeploymentAutomation Tests" {
    BeforeEach {
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        
        # Create automation configuration
        $automationDir = Join-Path $script:deploymentPath "automation"
        New-Item -Path $automationDir -ItemType Directory -Force | Out-Null
        
        $automationConfig = @{
            DeploymentId = $script:testDeploymentId
            AutomationType = "Scheduled"
            Enabled = $true
            History = @(
                @{ Timestamp = Get-Date; Action = "Test" }
            )
        }
        $automationConfig | ConvertTo-Json | Set-Content -Path (Join-Path $automationDir "automation-config.json")
    }
    
    Context "Automation Information Retrieval" {
        It "Should get automation info for specific deployment" {
            $result = Get-DeploymentAutomation -DeploymentId $script:testDeploymentId
            
            $result.Count | Should -Be 1
            $result[0].DeploymentId | Should -Be $script:testDeploymentId
            $result[0].AutomationType | Should -Be "Scheduled"
        }
        
        It "Should get automation info for all deployments" {
            $result = Get-DeploymentAutomation
            
            $result.Count | Should -BeGreaterOrEqual 1
        }
        
        It "Should include history when requested" {
            $result = Get-DeploymentAutomation -DeploymentId $script:testDeploymentId -IncludeHistory
            
            $result[0].History | Should -Not -BeNullOrEmpty
        }
        
        It "Should exclude history by default" {
            $result = Get-DeploymentAutomation -DeploymentId $script:testDeploymentId
            
            $result[0].PSObject.Properties['History'] | Should -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Restore environment
    $env:PROJECT_ROOT = $projectRoot
}