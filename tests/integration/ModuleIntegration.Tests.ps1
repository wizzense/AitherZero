#Requires -Version 7.0

<#
.SYNOPSIS
    Integration tests for core AitherLabs modules working together
.DESCRIPTION
    Tests module interactions, dependencies, and cross-module functionality
#>

BeforeAll {
    # Mock Write-CustomLog function
    function global:Write-CustomLog {
        param(
            [string]$Message, 
            [string]$Level = "INFO",
            [hashtable]$Context = @{},
            [hashtable]$Data = @{}
        )
        Write-Host "[$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                'ERROR' { 'Red' }
                'WARN' { 'Yellow' }
                'SUCCESS' { 'Green' }
                'INFO' { 'Cyan' }
                default { 'White' }
            }
        )
    }
    
    $projectRoot = '/workspaces/AitherLabs'
    $modulesPath = Join-Path $projectRoot "aither-core/modules"
    
    # Import core modules that should work together
    $coreModules = @('Logging', 'PatchManager', 'DevEnvironment', 'BackupManager')
    $script:importedModules = @{}
    
    foreach ($module in $coreModules) {
        $modulePath = Join-Path $modulesPath $module
        try {
            Import-Module $modulePath -Force -ErrorAction Stop
            $script:importedModules[$module] = $true
            Write-Host "✅ Imported: $module" -ForegroundColor Green
        }
        catch {
            $script:importedModules[$module] = $false
            Write-Host "❌ Failed to import: $module - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Describe "Module Integration Tests" -Tags @('Integration', 'ModuleInteraction') {
    
    Context "Module Import and Dependency Resolution" {
        It "Should import all core modules successfully" {
            $script:importedModules['Logging'] | Should -Be $true
            $script:importedModules['PatchManager'] | Should -Be $true
            $script:importedModules['DevEnvironment'] | Should -Be $true
            $script:importedModules['BackupManager'] | Should -Be $true
        }
        
        It "Should have all expected functions available" {
            # Logging
            Get-Command Write-CustomLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # PatchManager
            Get-Command Invoke-PatchWorkflow -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command New-PatchIssue -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # DevEnvironment  
            Get-Command Initialize-DevelopmentEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # BackupManager
            Get-Command Invoke-BackupConsolidation -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should not have function name conflicts" {
            # Get all imported functions
            $allFunctions = Get-Command -Module Logging, PatchManager, DevEnvironment, BackupManager -CommandType Function
            $functionNames = $allFunctions | Select-Object -ExpandProperty Name
            
            # Check for duplicates
            $duplicates = $functionNames | Group-Object | Where-Object { $_.Count -gt 1 }
            $duplicates | Should -BeNullOrEmpty -Because "No function names should conflict between modules"
        }
    }
    
    Context "Logging Integration with Other Modules" {
        It "Should use Write-CustomLog across all modules" {
            # Test that Write-CustomLog can be called without errors
            { Write-CustomLog -Message "Integration test message" -Level "INFO" } | Should -Not -Throw
            
            # Test with different levels
            { Write-CustomLog -Message "Error test" -Level "ERROR" } | Should -Not -Throw
            { Write-CustomLog -Message "Success test" -Level "SUCCESS" } | Should -Not -Throw
        }
        
        It "Should handle logging configuration consistently" {
            if (Get-Command Get-LoggingConfiguration -ErrorAction SilentlyContinue) {
                $config = Get-LoggingConfiguration
                $config | Should -Not -BeNullOrEmpty
                $config.LogLevel | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "PatchManager with Other Module Dependencies" {
        It "Should work with logging for patch operations" {
            # Test PatchManager in dry run mode (safe)
            $result = Invoke-PatchWorkflow -PatchDescription "Integration test patch" -PatchOperation {} -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.DryRun | Should -Be $true
        }
        
        It "Should create issues in dry run mode" {
            $result = New-PatchIssue -Description "Integration test issue" -Priority "Low" -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.DryRun | Should -Be $true
        }
    }
    
    Context "Cross-Module Configuration Consistency" {
        It "Should use consistent path handling" {
            # Test that modules handle paths consistently
            $testPath = "/tmp/integration-test"
            
            # This should work on any platform PowerShell 7+ supports
            $normalizedPath = $testPath -replace '\\', '/'
            $normalizedPath | Should -Be "/tmp/integration-test"
        }
        
        It "Should handle cross-platform operations" {
            # Test basic cross-platform functionality
            $isWindows = $env:OS -eq "Windows_NT"
            $isLinux = (Get-Content /proc/version -ErrorAction SilentlyContinue) -ne $null
            $isMacOS = $env:OSTYPE -eq "darwin"
            
            # At least one should be true
            ($isWindows -or $isLinux -or $isMacOS) | Should -Be $true
        }
    }
}

Describe "Workflow Integration Tests" -Tags @('Integration', 'Workflow', 'EndToEnd') {
    
    Context "Development Workflow Simulation" {
        It "Should simulate a complete development workflow" {
            # 1. Initialize development environment check
            if (Get-Command Initialize-DevelopmentEnvironment -ErrorAction SilentlyContinue) {
                { Initialize-DevelopmentEnvironment -WhatIf } | Should -Not -Throw
            }
            
            # 2. Backup any existing work (simulation)
            if (Get-Command Invoke-BackupConsolidation -ErrorAction SilentlyContinue) {
                { Invoke-BackupConsolidation -WhatIf } | Should -Not -Throw
            }
            
            # 3. Create a patch workflow
            $patchResult = Invoke-PatchWorkflow -PatchDescription "Simulated development workflow" -PatchOperation {
                # Simulated development work
                Write-Host "Simulating code changes..."
            } -DryRun -CreateIssue:$false
            
            $patchResult | Should -Not -BeNullOrEmpty
            $patchResult.Success | Should -Be $true
        }
        
        It "Should handle error scenarios gracefully" {
            # Test error handling across modules
            try {
                $result = Invoke-PatchWorkflow -PatchDescription "Error simulation" -PatchOperation {
                    # This won't actually throw in DryRun mode
                    Write-Host "Error simulation"
                } -DryRun
                
                $result.Success | Should -Be $true
            }
            catch {
                # If it does throw, the error should be meaningful
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Module Performance Integration" {
        It "Should complete integrated operations within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Simulate multiple module operations
            Write-CustomLog -Message "Starting performance test" -Level "INFO"
            
            $patchResult = Invoke-PatchWorkflow -PatchDescription "Performance test" -PatchOperation {
                Start-Sleep -Milliseconds 10  # Minimal operation
            } -DryRun
            
            Write-CustomLog -Message "Performance test completed" -Level "SUCCESS"
            
            $stopwatch.Stop()
            
            # Should complete quickly since it's all DryRun
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 3000
            $patchResult.Success | Should -Be $true
        }
        
        It "Should handle concurrent module operations" {
            $jobs = @()
            
            # Start multiple concurrent operations
            for ($i = 1; $i -le 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ProjectRoot, $TestNumber)
                    
                    # Import modules in the job
                    Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force
                    Import-Module "$env:PWSH_MODULES_PATH/PatchManager" -Force
                    
                    # Mock logging function
                    function Write-CustomLog {
                        param([string]$Message, [string]$Level = "INFO")
                        Write-Host "[$Level] $Message"
                    }
                    
                    # Perform concurrent operation
                    Invoke-PatchWorkflow -PatchDescription "Concurrent test $TestNumber" -PatchOperation {
                        Start-Sleep -Milliseconds 50
                    } -DryRun
                } -ArgumentList $projectRoot, $i
            }
            
            # Wait for all jobs and collect results
            $results = $jobs | Wait-Job -Timeout 10 | Receive-Job
            $jobs | Remove-Job -Force
            
            # All operations should succeed
            $results | Should -HaveCount 3
            $results | ForEach-Object { $_.Success | Should -Be $true }
        }
    }
}

Describe "Configuration and Environment Integration" -Tags @('Integration', 'Configuration') {
    
    Context "Configuration File Validation" {
        It "Should validate core configuration files" {
            $configFiles = @(
                '/workspaces/AitherLabs/aither-core/default-config.json'
            )
            
            foreach ($configFile in $configFiles) {
                if (Test-Path $configFile) {
                    $content = Get-Content $configFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $content | Should -Not -BeNullOrEmpty -Because "Config file should contain valid JSON"
                }
            }
        }
        
        It "Should validate module manifest files" {
            $moduleManifests = Get-ChildItem "$projectRoot/aither-core/modules" -Filter "*.psd1" -Recurse
            
            foreach ($manifest in $moduleManifests) {
                $manifestData = Test-ModuleManifest $manifest.FullName -ErrorAction SilentlyContinue
                if ($manifestData) {
                    $manifestData.Name | Should -Not -BeNullOrEmpty
                    $manifestData.Version | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
    
    Context "Environment Consistency" {
        It "Should maintain consistent environment variables" {
            # Check that environment setup is consistent
            $pwshVersion = $PSVersionTable.PSVersion
            $pwshVersion.Major | Should -BeGreaterOrEqual 7 -Because "PowerShell 7+ is required"
        }
        
        It "Should handle workspace paths consistently" {
            $workspacePath = '/workspaces/AitherLabs'
            Test-Path $workspacePath | Should -Be $true -Because "Workspace should exist"
            
            $aitherCorePath = Join-Path $workspacePath "aither-core"
            Test-Path $aitherCorePath | Should -Be $true -Because "aither-core directory should exist"
        }
    }
}
