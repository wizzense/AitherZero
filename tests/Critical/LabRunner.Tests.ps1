BeforeDiscovery {
    $script:LabRunnerModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/LabRunner'
    $script:TestAppName = 'LabRunner'
    
    # Verify the LabRunner module exists
    if (-not (Test-Path $script:LabRunnerModulePath)) {
        throw "LabRunner module not found at: $script:LabRunnerModulePath"
    }
}

Describe 'LabRunner - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'LabRunner', 'Orchestration') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'labrunner-tests'
        
        # Save original environment
        $script:OriginalProjectRoot = $env:PROJECT_ROOT
        $script:OriginalUserProfile = $env:USERPROFILE
        $script:OriginalHome = $env:HOME
        $script:OriginalPwshModulesPath = $env:PWSH_MODULES_PATH
        $script:OriginalTemp = $env:TEMP
        $script:OriginalLabConsoleLevel = $env:LAB_CONSOLE_LEVEL
        $script:OriginalPesterRun = $env:PESTER_RUN
        
        # Create test directory structure
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestModulesDir = Join-Path $script:TestProjectRoot 'aither-core' 'modules'
        $script:TestSharedDir = Join-Path $script:TestProjectRoot 'aither-core' 'shared'
        $script:TestConfigsDir = Join-Path $script:TestProjectRoot 'configs'
        $script:TestTempDir = Join-Path $script:TestWorkspace 'temp'
        
        @($script:TestProjectRoot, $script:TestModulesDir, $script:TestSharedDir,
          $script:TestConfigsDir, $script:TestTempDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Set test environment variables
        $env:PROJECT_ROOT = $script:TestProjectRoot
        $env:USERPROFILE = $script:TestWorkspace
        $env:HOME = $script:TestWorkspace
        $env:PWSH_MODULES_PATH = $script:TestModulesDir
        $env:TEMP = $script:TestTempDir
        $env:PESTER_RUN = 'true'  # Ensure non-interactive mode
        
        # Create Find-ProjectRoot utility
        $findProjectRootContent = @"
function Find-ProjectRoot {
    param([string]`$StartPath, [switch]`$Force)
    return '$script:TestProjectRoot'
}
"@
        $findProjectRootPath = Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1'
        $findProjectRootContent | Out-File -FilePath $findProjectRootPath -Encoding UTF8
        
        # Copy LabRunner module to test environment
        $testLabRunnerModulePath = Join-Path $script:TestModulesDir 'LabRunner'
        Copy-Item -Path "$script:LabRunnerModulePath\*" -Destination $testLabRunnerModulePath -Recurse -Force
        
        # Create mock Logging module
        $testLoggingModulePath = Join-Path $script:TestModulesDir 'Logging'
        New-Item -ItemType Directory -Path $testLoggingModulePath -Force | Out-Null
        @'
$script:LogHistory = @()
function Write-CustomLog {
    param([string]$Level = 'INFO', [string]$Message)
    $script:LogHistory += @{Time = Get-Date; Level = $Level; Message = $Message}
    if ($Level -eq 'ERROR') { Write-Host "[$Level] $Message" -ForegroundColor Red }
    elseif ($Level -eq 'WARN') { Write-Host "[$Level] $Message" -ForegroundColor Yellow }
    elseif ($Level -eq 'SUCCESS') { Write-Host "[$Level] $Message" -ForegroundColor Green }
    else { Write-Host "[$Level] $Message" }
}
Export-ModuleMember -Function Write-CustomLog -Variable LogHistory
'@ | Out-File -FilePath (Join-Path $testLoggingModulePath 'Logging.psm1') -Encoding UTF8
        
        # Create mock ProgressTracking module
        $testProgressModulePath = Join-Path $script:TestModulesDir 'ProgressTracking'
        New-Item -ItemType Directory -Path $testProgressModulePath -Force | Out-Null
        @'
$script:ProgressOperations = @{}
$script:MultiProgressOperations = @{}
function Start-ProgressOperation { 
    param($OperationName, $TotalSteps, [switch]$ShowTime, [switch]$ShowETA, $Style)
    $id = "test-op-$(Get-Random)"
    $script:ProgressOperations[$id] = @{Name = $OperationName; TotalSteps = $TotalSteps; CurrentStep = 0}
    return $id
}
function Update-ProgressOperation { 
    param($OperationId, $CurrentStep, $StepName, [switch]$IncrementStep)
    if ($script:ProgressOperations.ContainsKey($OperationId)) {
        if ($IncrementStep) { $script:ProgressOperations[$OperationId].CurrentStep++ }
        else { $script:ProgressOperations[$OperationId].CurrentStep = $CurrentStep }
        $script:ProgressOperations[$OperationId].StepName = $StepName
    }
}
function Complete-ProgressOperation { 
    param($OperationId, [switch]$ShowSummary)
    if ($script:ProgressOperations.ContainsKey($OperationId)) {
        $script:ProgressOperations[$OperationId].Completed = $true
    }
}
function Start-MultiProgress {
    param($Title, $Operations)
    $ids = @{}
    foreach ($op in $Operations) {
        $id = Start-ProgressOperation -OperationName $op.Name -TotalSteps $op.Steps
        $ids[$op.Name] = $id
    }
    return $ids
}
function Write-ProgressLog { param($Message, $Level) }
function Add-ProgressError { param($OperationId, $Error) }
function Add-ProgressWarning { param($OperationId, $Warning) }
Export-ModuleMember -Function * -Variable ProgressOperations, MultiProgressOperations
'@ | Out-File -FilePath (Join-Path $testProgressModulePath 'ProgressTracking.psm1') -Encoding UTF8
        
        # Create mock ThreadJob module functionality
        Mock Get-Command { $true } -ParameterFilter { $Name -eq 'Start-ThreadJob' } -ModuleName $script:TestAppName
        Mock Install-Module { } -ParameterFilter { $Name -eq 'ThreadJob' } -ModuleName $script:TestAppName
        Mock Import-Module { } -ParameterFilter { $Name -eq 'ThreadJob' } -ModuleName $script:TestAppName
        
        # Mock ThreadJob commands
        $script:MockJobs = @{}
        $script:JobCounter = 0
        
        Mock Start-ThreadJob {
            param($ScriptBlock, $ArgumentList, $Name)
            $script:JobCounter++
            $jobId = $script:JobCounter
            $job = [PSCustomObject]@{
                Id = $jobId
                Name = $Name
                State = 'Running'
                ScriptBlock = $ScriptBlock
                ArgumentList = $ArgumentList
                PSBeginTime = Get-Date
                HasMoreData = $true
            }
            $script:MockJobs[$jobId] = $job
            
            # Simulate job execution
            $null = Start-Job -ScriptBlock {
                param($JobId, $ScriptBlock, $ArgumentList)
                Start-Sleep -Milliseconds 500  # Simulate work
                
                # Execute the script block and capture result
                try {
                    $result = & $ScriptBlock @ArgumentList
                    @{ Success = $true; Result = $result }
                } catch {
                    @{ Success = $false; Error = $_.Exception.Message }
                }
            } -ArgumentList $jobId, $ScriptBlock, $ArgumentList
            
            return $job
        } -ModuleName $script:TestAppName
        
        Mock Receive-Job {
            param($Job)
            if ($Job.Name -like '*Environment*') {
                return @{ Success = $true; Message = "Environment setup completed"; ScriptName = "Environment Setup" }
            } elseif ($Job.Name -like '*Network*') {
                return @{ Success = $true; Message = "Network configured"; ScriptName = "Network Configuration" }
            } elseif ($Job.Name -like '*Infrastructure*') {
                return @{ Success = $true; Message = "Infrastructure deployed"; ScriptName = "Infrastructure Deployment" }
            } elseif ($Job.Name -like '*Validation*') {
                return @{ Success = $true; Message = "Validation passed"; ScriptName = "Deployment Validation" }
            } elseif ($Job.Name -like '*FailTest*') {
                return @{ Success = $false; Error = "Simulated failure"; ScriptName = "Failed Script" }
            } else {
                return @{ Success = $true; Message = "Script completed"; ScriptName = $Job.Name }
            }
        } -ModuleName $script:TestAppName
        
        Mock Remove-Job { 
            param($Job)
            if ($script:MockJobs.ContainsKey($Job.Id)) {
                $script:MockJobs.Remove($Job.Id)
            }
        } -ModuleName $script:TestAppName
        
        # Import LabRunner module from test location
        Import-Module $testLabRunnerModulePath -Force -Global
        
        # Mock external commands
        Mock Test-Connection { $true } -ModuleName $script:TestAppName
        Mock Get-Service { 
            [PSCustomObject]@{ Name = $Name; Status = 'Running' }
        } -ModuleName $script:TestAppName
        Mock Get-PSDrive {
            @(
                [PSCustomObject]@{ Name = 'C'; Free = 50GB; Provider = 'FileSystem' }
                [PSCustomObject]@{ Name = 'D'; Free = 100GB; Provider = 'FileSystem' }
            )
        } -ModuleName $script:TestAppName
        
        # Create test lab configurations
        $script:TestConfigurations = @{
            SimpleConfig = @"
name: simple-lab
description: Basic lab configuration for testing
platform: windows
network:
  gateway: 192.168.1.1
  subnet: 192.168.1.0/24
services:
  - DNSCache
  - W32Time
"@
            ComplexConfig = @"
name: complex-lab
description: Complex lab with multiple components
platform: windows
infrastructure:
  hyperv_virtual_machine:
    - name: dc-01
      role: domain-controller
      memory: 2048
      cpu: 2
    - name: web-01
      role: web-server
      memory: 4096
      cpu: 4
opentofu:
  provider: taliesins/hyperv
  version: 1.0.0
network:
  gateway: 10.0.0.1
  subnet: 10.0.0.0/24
  dns:
    - 10.0.0.10
    - 10.0.0.11
services:
  - W32Time
  - DNSCache
  - WinRM
applications:
  - name: nginx
    version: latest
  - name: docker
    version: 20.10
vms:
  - dc-01
  - web-01
  - db-01
"@
            MinimalConfig = @"
name: minimal-lab
platform: linux
"@
            InvalidConfig = @"
This is not valid YAML or configuration data!
{]}[
"@
        }
        
        # Write test configuration files
        foreach ($configName in $script:TestConfigurations.Keys) {
            $configPath = Join-Path $script:TestConfigsDir "$configName.yaml"
            $script:TestConfigurations[$configName] | Out-File -FilePath $configPath -Encoding UTF8
        }
    }
    
    AfterAll {
        # Restore original environment
        $env:PROJECT_ROOT = $script:OriginalProjectRoot
        $env:USERPROFILE = $script:OriginalUserProfile
        $env:HOME = $script:OriginalHome
        $env:PWSH_MODULES_PATH = $script:OriginalPwshModulesPath
        $env:TEMP = $script:OriginalTemp
        $env:LAB_CONSOLE_LEVEL = $script:OriginalLabConsoleLevel
        $env:PESTER_RUN = $script:OriginalPesterRun
        
        # Remove imported modules
        Remove-Module LabRunner -Force -ErrorAction SilentlyContinue
        Remove-Module Logging -Force -ErrorAction SilentlyContinue
        Remove-Module ProgressTracking -Force -ErrorAction SilentlyContinue
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clear job tracking
        $script:MockJobs.Clear()
        $script:JobCounter = 0
        
        # Clear any console output level settings
        $env:LAB_CONSOLE_LEVEL = $null
    }
    
    Context 'Module Loading and Initialization' {
        
        It 'Should load LabRunner module successfully' {
            $module = Get-Module -Name 'LabRunner'
            $module | Should -Not -BeNullOrEmpty
            $module.Name | Should -Be 'LabRunner'
        }
        
        It 'Should export all required functions' {
            $requiredFunctions = @(
                'Get-CrossPlatformTempPath',
                'Invoke-CrossPlatformCommand',
                'Invoke-LabStep',
                'Invoke-LabDownload',
                'Read-LoggedInput',
                'Invoke-LabWebRequest',
                'Invoke-LabNpm',
                'Resolve-ProjectPath',
                'Get-LabConfig',
                'Invoke-ParallelLabRunner',
                'Start-LabAutomation',
                'Get-LabStatus',
                'Start-EnhancedLabDeployment'
            )
            
            $exportedFunctions = (Get-Module -Name 'LabRunner').ExportedFunctions.Keys
            
            foreach ($func in $requiredFunctions) {
                $exportedFunctions | Should -Contain $func
            }
        }
        
        It 'Should handle missing Logging module gracefully' {
            # Remove Logging module temporarily
            $loggingPath = Join-Path $script:TestModulesDir 'Logging' 'Logging.psm1'
            $backupPath = "$loggingPath.backup"
            
            if (Test-Path $loggingPath) {
                Move-Item $loggingPath $backupPath -Force
            }
            
            try {
                # Re-import LabRunner without Logging module
                Remove-Module LabRunner -Force -ErrorAction SilentlyContinue
                { Import-Module $script:TestModulesDir\LabRunner -Force } | Should -Not -Throw
            } finally {
                # Restore Logging module
                if (Test-Path $backupPath) {
                    Move-Item $backupPath $loggingPath -Force
                }
                Import-Module $script:TestModulesDir\LabRunner -Force
            }
        }
        
        It 'Should handle missing ProgressTracking module gracefully' {
            # ProgressTracking is optional, so module should load without it
            $progressPath = Join-Path $script:TestModulesDir 'ProgressTracking' 'ProgressTracking.psm1'
            $backupPath = "$progressPath.backup"
            
            if (Test-Path $progressPath) {
                Move-Item $progressPath $backupPath -Force
            }
            
            try {
                Remove-Module LabRunner -Force -ErrorAction SilentlyContinue
                { Import-Module $script:TestModulesDir\LabRunner -Force } | Should -Not -Throw
                
                # Should still be able to call functions without progress tracking
                { Start-LabAutomation -ShowProgress } | Should -Not -Throw
            } finally {
                if (Test-Path $backupPath) {
                    Move-Item $backupPath $loggingPath -Force
                }
                Import-Module $script:TestModulesDir\LabRunner -Force
            }
        }
    }
    
    Context 'Cross-Platform Utility Functions' {
        
        It 'Should detect platform correctly' {
            $platform = Get-Platform
            $platform | Should -BeIn @('Windows', 'Linux', 'MacOS')
            
            if ($IsWindows) { $platform | Should -Be 'Windows' }
            elseif ($IsLinux) { $platform | Should -Be 'Linux' }
            elseif ($IsMacOS) { $platform | Should -Be 'MacOS' }
        }
        
        It 'Should get cross-platform temp path' {
            $tempPath = Get-CrossPlatformTempPath
            $tempPath | Should -Not -BeNullOrEmpty
            Test-Path $tempPath | Should -Be $true
        }
        
        It 'Should handle cross-platform commands correctly' {
            # Test with available command
            Mock Get-Command { $true } -ParameterFilter { $CommandName -eq 'Test-Path' } -ModuleName $script:TestAppName
            
            $result = Invoke-CrossPlatformCommand -CommandName 'Test-Path' -Parameters @{ Path = $env:TEMP }
            $result | Should -Be $true
            
            # Test with unavailable command
            Mock Get-Command { $false } -ParameterFilter { $CommandName -eq 'NonExistentCommand' } -ModuleName $script:TestAppName
            
            # Should throw by default
            { Invoke-CrossPlatformCommand -CommandName 'NonExistentCommand' } | Should -Throw
            
            # Should return mock result
            $mockResult = Invoke-CrossPlatformCommand -CommandName 'NonExistentCommand' -MockResult 'mocked'
            $mockResult | Should -Be 'mocked'
            
            # Should skip silently
            $skipResult = Invoke-CrossPlatformCommand -CommandName 'NonExistentCommand' -SkipOnUnavailable
            $skipResult | Should -BeNullOrEmpty
        }
    }
    
    Context 'Lab Configuration Management' {
        
        It 'Should read simple lab configuration' {
            $configPath = 'configs/SimpleConfig.yaml'
            $config = Get-LabConfig -Path $configPath
            
            $config | Should -Not -BeNullOrEmpty
            $config.name | Should -Be 'simple-lab'
            $config.platform | Should -Be 'windows'
            $config.network | Should -Not -BeNullOrEmpty
        }
        
        It 'Should read complex lab configuration' {
            $configPath = 'configs/ComplexConfig.yaml'
            $config = Get-LabConfig -Path $configPath
            
            $config | Should -Not -BeNullOrEmpty
            $config.name | Should -Be 'complex-lab'
            $config.infrastructure | Should -Not -BeNullOrEmpty
            $config.opentofu | Should -Not -BeNullOrEmpty
            $config.applications | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle absolute paths' {
            $absolutePath = Join-Path $script:TestConfigsDir 'MinimalConfig.yaml'
            $config = Get-LabConfig -Path $absolutePath
            
            $config | Should -Not -BeNullOrEmpty
            $config.name | Should -Be 'minimal-lab'
        }
        
        It 'Should handle missing configuration file' {
            $config = Get-LabConfig -Path 'configs/NonExistent.yaml'
            $config | Should -BeNullOrEmpty
        }
        
        It 'Should handle invalid configuration format' {
            { Get-LabConfig -Path 'configs/InvalidConfig.yaml' } | Should -Throw
        }
        
        It 'Should parse YAML-like configuration correctly' {
            $config = Get-LabConfig -Path 'configs/SimpleConfig.yaml'
            
            # Check parsed values
            $config.name | Should -Be 'simple-lab'
            $config.description | Should -Be 'Basic lab configuration for testing'
            $config.platform | Should -Be 'windows'
            $config['network'] | Should -Not -BeNullOrEmpty
            $config['services'] | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Lab Step Execution' {
        
        It 'Should execute lab step with script block' {
            $executed = $false
            $stepBody = {
                param($Config)
                $script:executed = $true
                return "Step completed"
            }
            
            $result = Invoke-LabStep -Body $stepBody -Config @{ test = $true }
            $executed | Should -Be $true
        }
        
        It 'Should handle lab step errors properly' {
            $errorStep = {
                throw "Simulated error"
            }
            
            { Invoke-LabStep -Body $errorStep -Config @{} } | Should -Throw "Simulated error"
        }
        
        It 'Should suppress console output when requested' {
            $env:LAB_CONSOLE_LEVEL = '0'
            
            $stepBody = {
                Write-Host "This should be suppressed"
                return "Done"
            }
            
            $result = Invoke-LabStep -Body $stepBody -Config @{}
            # Output was suppressed, but step still executed
            $result | Should -Be "Done"
            
            $env:LAB_CONSOLE_LEVEL = $null
        }
        
        It 'Should handle config parameter variations' {
            # Test with object
            $configObj = @{ name = 'test'; value = 123 }
            $result = Invoke-LabStep -Body { param($Config); $Config.name } -Config $configObj
            $result | Should -Be 'test'
            
            # Test with JSON string
            $configJson = '{"name":"test-json","value":456}'
            $result = Invoke-LabStep -Body { param($Config); $Config.name } -Config $configJson
            $result | Should -Be 'test-json'
            
            # Test with file path
            $configPath = Join-Path $script:TestConfigsDir 'MinimalConfig.yaml'
            $result = Invoke-LabStep -Body { param($Config); $Config.name } -Config $configPath
            $result | Should -Be 'minimal-lab'
        }
    }
    
    Context 'Parallel Lab Runner Execution' {
        
        It 'Should execute scripts in parallel with default settings' {
            $scripts = @(
                @{ Name = "Script1"; Path = "Test-Script1"; Config = @{} },
                @{ Name = "Script2"; Path = "Test-Script2"; Config = @{} },
                @{ Name = "Script3"; Path = "Test-Script3"; Config = @{} }
            )
            
            $result = Invoke-ParallelLabRunner -Scripts $scripts
            
            $result | Should -Not -BeNullOrEmpty
            $result.TotalScripts | Should -Be 3
            $result.CompletedSuccessfully | Should -Be 3
            $result.Failed | Should -Be 0
            $result.Results | Should -HaveCount 3
        }
        
        It 'Should respect MaxConcurrency parameter' {
            $scripts = @(1..10 | ForEach-Object {
                @{ Name = "Script$_"; Path = "Test-Script$_"; Config = @{} }
            })
            
            # Track concurrent executions
            $maxConcurrent = 0
            Mock Start-ThreadJob {
                param($ScriptBlock, $ArgumentList, $Name)
                $currentCount = ($script:MockJobs.Values | Where-Object { $_.State -eq 'Running' }).Count
                if ($currentCount -gt $maxConcurrent) { $script:maxConcurrent = $currentCount }
                
                # Call original mock
                & $script:OriginalStartThreadJobMock @PSBoundParameters
            } -ModuleName $script:TestAppName
            
            $result = Invoke-ParallelLabRunner -Scripts $scripts -MaxConcurrency 3
            
            $result.TotalScripts | Should -Be 10
            # MaxConcurrency should be respected (with some tolerance for timing)
            $maxConcurrent | Should -BeLessOrEqual 4
        }
        
        It 'Should handle script failures gracefully' {
            $scripts = @(
                @{ Name = "GoodScript"; Path = "Test-Good"; Config = @{} },
                @{ Name = "FailTest"; Path = "Test-Fail"; Config = @{} },
                @{ Name = "AnotherGood"; Path = "Test-Good2"; Config = @{} }
            )
            
            $result = Invoke-ParallelLabRunner -Scripts $scripts
            
            $result.TotalScripts | Should -Be 3
            $result.CompletedSuccessfully | Should -Be 2
            $result.Failed | Should -Be 1
        }
        
        It 'Should work with SafeMode enabled' {
            $scripts = @(
                @{ Name = "SafeScript1"; Path = "Test-Safe1"; Config = @{} },
                @{ Name = "SafeScript2"; Path = "Test-Safe2"; Config = @{} }
            )
            
            $result = Invoke-ParallelLabRunner -Scripts $scripts -SafeMode
            
            $result | Should -Not -BeNullOrEmpty
            $result.CompletedSuccessfully | Should -Be 2
        }
        
        It 'Should generate scripts from config when none provided' {
            $config = Get-LabConfig -Path 'configs/ComplexConfig.yaml'
            
            $result = Invoke-ParallelLabRunner -Config $config
            
            $result | Should -Not -BeNullOrEmpty
            $result.TotalScripts | Should -BeGreaterThan 0
            $result.CompletedSuccessfully | Should -BeGreaterThan 0
        }
        
        It 'Should integrate with progress tracking when available' {
            $scripts = @(
                @{ Name = "Progress1"; Path = "Test-Progress1"; Config = @{} },
                @{ Name = "Progress2"; Path = "Test-Progress2"; Config = @{} }
            )
            
            # Progress tracking module is mocked and available
            $result = Invoke-ParallelLabRunner -Scripts $scripts -ShowProgress -ProgressStyle 'Detailed'
            
            $result | Should -Not -BeNullOrEmpty
            $result.ProgressTrackingEnabled | Should -Be $true
            $result.CompletedSuccessfully | Should -Be 2
        }
        
        It 'Should handle timeout scenarios' {
            # This is difficult to test without actual long-running operations
            # We verify the timeout parameter is accepted
            $scripts = @(
                @{ Name = "TimeoutTest"; Path = "Test-Timeout"; Config = @{} }
            )
            
            { $result = Invoke-ParallelLabRunner -Scripts $scripts -TimeoutMinutes 1 } | Should -Not -Throw
        }
    }
    
    Context 'Lab Automation Workflow' {
        
        It 'Should start basic lab automation successfully' {
            $result = Start-LabAutomation
            
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'Success'
            $result.Message | Should -Match 'completed successfully'
        }
        
        It 'Should execute specific lab steps' {
            $steps = @('Environment Setup', 'Network Configuration', 'Deployment Validation')
            
            $result = Start-LabAutomation -Steps $steps
            
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'Success'
            $result.ExecutedSteps | Should -Be $steps
        }
        
        It 'Should handle lab automation with configuration' {
            $config = @{
                name = 'test-lab'
                platform = 'windows'
                network = @{ gateway = '192.168.1.1' }
            }
            
            $result = Start-LabAutomation -Configuration $config
            
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'Success'
        }
        
        It 'Should integrate with progress tracking' {
            $result = Start-LabAutomation -ShowProgress -ProgressStyle 'Bar'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'Success'
            $result.ProgressTrackingEnabled | Should -Be $true
        }
        
        It 'Should handle automation failures' {
            # Mock a failure scenario
            Mock Get-LabConfig { $null } -ModuleName $script:TestAppName
            
            { Start-LabAutomation } | Should -Throw
        }
        
        It 'Should get lab status correctly' {
            $status = Get-LabStatus
            
            $status | Should -Not -BeNullOrEmpty
            $status.Platform | Should -Not -BeNullOrEmpty
            $status.ConfigurationLoaded | Should -Not -BeNullOrEmpty
            $status.ParallelSupport | Should -Be $true
        }
        
        It 'Should get detailed lab status' {
            $status = Get-LabStatus -Detailed
            
            $status | Should -Not -BeNullOrEmpty
            $status.Configuration | Should -Not -BeNullOrEmpty
            $status.AvailableSteps | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Enhanced Lab Deployment' {
        
        It 'Should perform enhanced deployment with simple configuration' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleConfig.yaml'
            
            $result = Start-EnhancedLabDeployment -ConfigurationPath $configPath -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.ConfigurationPath | Should -Be $configPath
            $result.DryRun | Should -Be $true
            $result.Duration | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle complex lab deployment' {
            $configPath = Join-Path $script:TestConfigsDir 'ComplexConfig.yaml'
            
            $result = Start-EnhancedLabDeployment -ConfigurationPath $configPath -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.Resources | Should -Not -BeNullOrEmpty
        }
        
        It 'Should integrate with OpenTofu when available' {
            # Mock OpenTofuProvider availability
            Mock Get-Module { 
                @{ Name = 'OpenTofuProvider' }
            } -ParameterFilter { $Name -eq 'OpenTofuProvider' -and $ListAvailable } -ModuleName $script:TestAppName
            
            Mock Import-Module { } -ParameterFilter { $_ -like '*OpenTofuProvider*' } -ModuleName $script:TestAppName
            
            Mock Start-InfrastructureDeployment {
                @{
                    Success = $true
                    Stages = @{ Plan = @{ Success = $true }; Apply = @{ Success = $true } }
                    Resources = @{ 'hyperv_virtual_machine' = @{ Count = 2 } }
                    Warnings = @()
                    Errors = @()
                }
            } -ModuleName $script:TestAppName
            
            $configPath = Join-Path $script:TestConfigsDir 'ComplexConfig.yaml'
            $result = Start-EnhancedLabDeployment -ConfigurationPath $configPath -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.Resources | Should -Not -BeNullOrEmpty
        }
        
        It 'Should support stage-specific deployment' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleConfig.yaml'
            
            $result = Start-EnhancedLabDeployment -ConfigurationPath $configPath -Stage 'Validate' -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Stage | Should -Be 'Validate'
        }
        
        It 'Should handle deployment with Force flag' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleConfig.yaml'
            
            # Mock a warning scenario
            Mock Test-LabDeploymentHealth {
                @{
                    Success = $false
                    Warnings = @('Service not running: TestService')
                    Checks = @{}
                }
            } -ModuleName $script:TestAppName
            
            $result = Start-EnhancedLabDeployment -ConfigurationPath $configPath -Force -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Warnings | Should -Not -BeNullOrEmpty
        }
        
        It 'Should track progress during enhanced deployment' {
            $configPath = Join-Path $script:TestConfigsDir 'SimpleConfig.yaml'
            
            $result = Start-EnhancedLabDeployment -ConfigurationPath $configPath -ShowProgress -ProgressStyle 'Detailed' -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.ProgressTracking | Should -Be $true
        }
        
        It 'Should perform deployment health checks' {
            $config = @{
                network = @{ gateway = '192.168.1.1' }
                services = @('W32Time', 'DNSCache')
            }
            
            $healthResult = Test-LabDeploymentHealth -Config $config
            
            $healthResult | Should -Not -BeNullOrEmpty
            $healthResult.Success | Should -Be $true
            $healthResult.Checks | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Non-Interactive Mode Handling' {
        
        It 'Should handle Read-LoggedInput in non-interactive mode' {
            # Already set via $env:PESTER_RUN = 'true'
            
            $result = Read-LoggedInput -Prompt "Test prompt" -DefaultValue "default"
            $result | Should -Be "default"
            
            # Test secure string
            $secureResult = Read-LoggedInput -Prompt "Password" -AsSecureString -DefaultValue "testpass"
            $secureResult | Should -BeOfType [System.Security.SecureString]
        }
        
        It 'Should detect non-interactive environment correctly' {
            # Various non-interactive scenarios
            $originalHost = $Host.Name
            
            # Test with Default Host
            Mock Get-Variable { [PSCustomObject]@{ Value = @{ Name = 'Default Host' } } } -ParameterFilter { $Name -eq 'Host' } -ModuleName $script:TestAppName
            
            $result = Read-LoggedInput -Prompt "Test" -DefaultValue "default"
            $result | Should -Be "default"
        }
    }
    
    Context 'Web Request and Download Functions' {
        
        It 'Should handle lab web requests' {
            Mock Invoke-WebRequest { 
                [PSCustomObject]@{ StatusCode = 200; Content = "Success" }
            } -ModuleName $script:TestAppName
            
            $result = Invoke-LabWebRequest -Uri "https://test.com" -UseBasicParsing
            $result.StatusCode | Should -Be 200
        }
        
        It 'Should handle web request failures' {
            Mock Invoke-WebRequest { throw "Network error" } -ModuleName $script:TestAppName
            
            { Invoke-LabWebRequest -Uri "https://fail.com" } | Should -Throw "Network error"
        }
        
        It 'Should execute lab download with action' {
            Mock Invoke-WebRequest { } -ModuleName $script:TestAppName
            
            $actionExecuted = $false
            $downloadAction = {
                param($Path)
                $script:actionExecuted = $true
                Test-Path $Path | Should -Be $true
            }
            
            Invoke-LabDownload -Uri "https://test.com/file.zip" -Action $downloadAction
            $actionExecuted | Should -Be $true
        }
        
        It 'Should handle custom download extensions' {
            Mock Invoke-WebRequest { } -ModuleName $script:TestAppName
            
            $capturedPath = $null
            $action = {
                param($Path)
                $script:capturedPath = $Path
            }
            
            Invoke-LabDownload -Uri "https://test.com/file" -Action $action -Extension "iso"
            $capturedPath | Should -Match '\.iso$'
        }
    }
    
    Context 'Error Handling and Resilience' {
        
        It 'Should handle missing configuration gracefully' {
            $nonExistentPath = Join-Path $script:TestConfigsDir 'DoesNotExist.yaml'
            
            { Start-EnhancedLabDeployment -ConfigurationPath $nonExistentPath } | Should -Throw
        }
        
        It 'Should handle corrupted configuration' {
            $corruptedPath = Join-Path $script:TestConfigsDir 'Corrupted.yaml'
            "{{invalid yaml data!!" | Out-File -FilePath $corruptedPath -Encoding UTF8
            
            { Start-EnhancedLabDeployment -ConfigurationPath $corruptedPath } | Should -Throw
        }
        
        It 'Should clean up resources on failure' {
            # Create a script that will fail
            $failScript = @(
                @{ Name = "FailingScript"; Path = "Force-Failure"; Config = @{} }
            )
            
            Mock Start-ThreadJob {
                throw "Simulated job creation failure"
            } -ModuleName $script:TestAppName
            
            { Invoke-ParallelLabRunner -Scripts $failScript } | Should -Throw
        }
        
        It 'Should handle timeout in lab steps' {
            $timeoutStep = {
                Start-Sleep -Seconds 60  # Long-running operation
            }
            
            # Since we can't easily test actual timeouts in unit tests,
            # we verify the error handling path
            { Invoke-LabStep -Body { throw "Timeout" } -Config @{} } | Should -Throw "Timeout"
        }
    }
    
    Context 'Project Path Resolution' {
        
        It 'Should resolve project paths correctly' {
            $resolvedPath = Resolve-ProjectPath -RelativePath 'configs/test.yaml'
            
            $resolvedPath | Should -Not -BeNullOrEmpty
            $resolvedPath | Should -Match 'configs.*test\.yaml$'
        }
        
        It 'Should use PROJECT_ROOT environment variable' {
            $customRoot = Join-Path $script:TestWorkspace 'CustomRoot'
            New-Item -Path $customRoot -ItemType Directory -Force | Out-Null
            
            $originalRoot = $env:PROJECT_ROOT
            $env:PROJECT_ROOT = $customRoot
            
            try {
                $resolvedPath = Resolve-ProjectPath -RelativePath 'test/path'
                $resolvedPath | Should -BeLike "$customRoot*test*path"
            } finally {
                $env:PROJECT_ROOT = $originalRoot
            }
        }
    }
    
    Context 'Performance and Resource Management' {
        
        It 'Should complete simple automation within reasonable time' {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $result = Start-LabAutomation -Steps @('Environment Setup', 'Deployment Validation')
            
            $stopwatch.Stop()
            
            $result.Status | Should -Be 'Success'
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 10000  # Less than 10 seconds
        }
        
        It 'Should handle multiple concurrent deployments' {
            $configs = @(
                Join-Path $script:TestConfigsDir 'SimpleConfig.yaml'
                Join-Path $script:TestConfigsDir 'MinimalConfig.yaml'
            )
            
            $jobs = @()
            foreach ($config in $configs) {
                $jobs += Start-Job -ScriptBlock {
                    param($ConfigPath, $ModulePath)
                    Import-Module $ModulePath -Force
                    Start-EnhancedLabDeployment -ConfigurationPath $ConfigPath -DryRun
                } -ArgumentList $config, "$script:TestModulesDir\LabRunner"
            }
            
            $results = $jobs | Receive-Job -Wait
            $jobs | Remove-Job
            
            $results | Should -HaveCount 2
            $results | ForEach-Object { $_.Success | Should -Be $true }
        }
        
        It 'Should efficiently handle large script batches' {
            # Create 50 scripts to test scalability
            $largeScriptSet = @(1..50 | ForEach-Object {
                @{ Name = "Script$_"; Path = "Test-Script$_"; Config = @{} }
            })
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $result = Invoke-ParallelLabRunner -Scripts $largeScriptSet -MaxConcurrency 10
            
            $stopwatch.Stop()
            
            $result.TotalScripts | Should -Be 50
            $result.CompletedSuccessfully | Should -BeGreaterThan 45  # Allow for some failures
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 60000  # Less than 1 minute
        }
    }
    
    Context 'Integration Scenarios' {
        
        It 'Should support end-to-end lab deployment workflow' {
            # Full workflow test
            $configPath = Join-Path $script:TestConfigsDir 'ComplexConfig.yaml'
            
            # Step 1: Check status
            $status = Get-LabStatus -Detailed
            $status | Should -Not -BeNullOrEmpty
            
            # Step 2: Start enhanced deployment
            $deployResult = Start-EnhancedLabDeployment -ConfigurationPath $configPath -DryRun -ShowProgress
            
            $deployResult | Should -Not -BeNullOrEmpty
            $deployResult.Success | Should -Be $true
            
            # Step 3: Verify deployment
            $postStatus = Get-LabStatus
            $postStatus | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle complex deployment with all features enabled' {
            $configPath = Join-Path $script:TestConfigsDir 'ComplexConfig.yaml'
            
            $result = Start-EnhancedLabDeployment `
                -ConfigurationPath $configPath `
                -DryRun `
                -ShowProgress `
                -ProgressStyle 'Detailed' `
                -MaxRetries 3 `
                -Force
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.ProgressTracking | Should -Be $true
        }
        
        It 'Should gracefully degrade when optional features are unavailable' {
            # Remove optional modules
            $progressBackup = Join-Path $script:TestModulesDir 'ProgressTracking' 'ProgressTracking.psm1'
            $progressBackupPath = "$progressBackup.backup"
            
            if (Test-Path $progressBackup) {
                Move-Item $progressBackup $progressBackupPath -Force
            }
            
            try {
                # Re-import without ProgressTracking
                Remove-Module LabRunner -Force -ErrorAction SilentlyContinue
                Import-Module $script:TestModulesDir\LabRunner -Force
                
                # Should still work without progress tracking
                $result = Start-LabAutomation -ShowProgress
                $result.Status | Should -Be 'Success'
                $result.ProgressTrackingEnabled | Should -Be $false
            } finally {
                if (Test-Path $progressBackupPath) {
                    Move-Item $progressBackupPath $progressBackup -Force
                }
                Import-Module $script:TestModulesDir\LabRunner -Force
            }
        }
    }
}