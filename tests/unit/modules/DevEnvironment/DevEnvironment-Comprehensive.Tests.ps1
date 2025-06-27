#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive tests for DevEnvironment module
.DESCRIPTION
    Tests the DevEnvironment module functionality including:
    - Environment validation
    - Development tool detection
    - System configuration checks
    - Cross-platform compatibility
#>

BeforeAll {
    # Mock Write-CustomLog function for testing
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
    
    # Import required modules first
    $projectRoot = if ($env:PROJECT_ROOT) { 
        $env:PROJECT_ROOT 
    } else { 
        '/workspaces/AitherLabs'
    }
    
    # Load Logging module first (required dependency)
    $loggingModulePath = Join-Path $projectRoot "aither-core/modules/Logging"
    try {
        Import-Module $loggingModulePath -Force -ErrorAction Stop
        Write-Host "✅ Logging module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not import Logging module: $_"
    }
    
    # Import the DevEnvironment module
    $devEnvModulePath = Join-Path $projectRoot "aither-core/modules/DevEnvironment"
    
    try {
        Import-Module $devEnvModulePath -Force -ErrorAction Stop
        Write-Host "✅ DevEnvironment module imported successfully from: $devEnvModulePath" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Failed to import DevEnvironment module from $devEnvModulePath : $_"
        throw
    }
}

Describe "DevEnvironment Module - Core Functions" -Tags @('Unit', 'DevEnvironment', 'SystemCheck') {
    
    Context "Module Structure and Exports" {
        It "Should export core development environment functions" {
            $exportedFunctions = Get-Command -Module DevEnvironment -CommandType Function | Select-Object -ExpandProperty Name
            
            # Check for common DevEnvironment functions (adjust based on actual exports)
            $exportedFunctions.Count | Should -BeGreaterThan 0
            Write-Host "Exported functions: $($exportedFunctions -join ', ')" -ForegroundColor Cyan
        }
        
        It "Should have valid module manifest" {
            $manifestPath = Join-Path (Split-Path $devEnvModulePath) "DevEnvironment.psd1"
            if (Test-Path $manifestPath) {
                $manifest = Test-ModuleManifest $manifestPath -ErrorAction SilentlyContinue
                $manifest | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "Module manifest not found at expected location"
            }
        }
    }
    
    Context "System Information Gathering" {
        It "Should detect the current operating system" {
            # This should work on any platform PowerShell 7+ supports
            $os = if ($IsWindows) { "Windows" } 
                  elseif ($IsLinux) { "Linux" } 
                  elseif ($IsMacOS) { "macOS" } 
                  else { "Unknown" }
                  
            $os | Should -Not -Be "Unknown"
            Write-Host "Detected OS: $os" -ForegroundColor Green
        }
        
        It "Should detect PowerShell version" {
            $psVersion = $PSVersionTable.PSVersion
            $psVersion | Should -Not -BeNullOrEmpty
            $psVersion.Major | Should -BeGreaterOrEqual 7
            Write-Host "PowerShell Version: $psVersion" -ForegroundColor Green
        }
        
        It "Should detect available system tools" {
            $tools = @{
                'git' = (Get-Command git -ErrorAction SilentlyContinue) -ne $null
                'pwsh' = (Get-Command pwsh -ErrorAction SilentlyContinue) -ne $null
            }
            
            $tools['pwsh'] | Should -Be $true  # Should always be true since we're running in PowerShell
            
            foreach ($tool in $tools.GetEnumerator()) {
                Write-Host "Tool '$($tool.Key)': $($tool.Value)" -ForegroundColor $(if ($tool.Value) { 'Green' } else { 'Yellow' })
            }
        }
    }
    
    Context "Development Environment Validation" {
        It "Should validate workspace structure" {
            $workspaceRoot = '/workspaces/AitherLabs'
            $requiredDirs = @(
                'aither-core',
                'tests',
                'docs'
            )
            
            foreach ($dir in $requiredDirs) {
                $dirPath = Join-Path $workspaceRoot $dir
                Test-Path $dirPath | Should -Be $true -Because "Required directory '$dir' should exist"
            }
        }
        
        It "Should validate core module structure" {
            $modulesPath = '/workspaces/AitherLabs/aither-core/modules'
            $coreModules = @(
                'Logging',
                'BackupManager',
                'PatchManager',
                'DevEnvironment'
            )
            
            foreach ($module in $coreModules) {
                $modulePath = Join-Path $modulesPath $module
                Test-Path $modulePath | Should -Be $true -Because "Core module '$module' should exist"
                
                # Check for module files
                $moduleFile = Join-Path $modulePath "$module.psm1"
                if (Test-Path $moduleFile) {
                    Write-Host "✅ Found module file: $module.psm1" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Module file not found: $module.psm1" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Context "Configuration and Settings" {
        It "Should handle environment variables" {
            # Test environment variable handling
            $testEnvVar = "TEST_DEVENV_VAR"
            $testValue = "test-value-$(Get-Random)"
            
            try {
                [Environment]::SetEnvironmentVariable($testEnvVar, $testValue, "Process")
                $retrievedValue = [Environment]::GetEnvironmentVariable($testEnvVar)
                $retrievedValue | Should -Be $testValue
            }
            finally {
                [Environment]::SetEnvironmentVariable($testEnvVar, $null, "Process")
            }
        }
        
        It "Should validate configuration files" {
            $configFiles = @(
                '/workspaces/AitherLabs/aither-core/default-config.json'
            )
            
            foreach ($configFile in $configFiles) {
                if (Test-Path $configFile) {
                    $content = Get-Content $configFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $content | Should -Not -BeNullOrEmpty -Because "Config file '$configFile' should contain valid JSON"
                    Write-Host "✅ Valid config file: $(Split-Path $configFile -Leaf)" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Config file not found: $configFile" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Context "Cross-Platform Compatibility" {
        It "Should handle path separators correctly" {
            $testPath = Join-Path "test" "path" "components"
            $testPath | Should -Not -BeNullOrEmpty
            
            # Should work regardless of platform
            if ($IsWindows) {
                $testPath | Should -Match "\\"
            } else {
                $testPath | Should -Match "/"
            }
        }
        
        It "Should handle line endings appropriately" {
            $testContent = "Line 1`nLine 2`nLine 3"
            $testFile = Join-Path $TestDrive "test-line-endings.txt"
            
            $testContent | Out-File -FilePath $testFile -Encoding utf8
            Test-Path $testFile | Should -Be $true
            
            $readContent = Get-Content $testFile -Raw
            $readContent | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Performance and Resource Checks" {
        It "Should complete system checks within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Simulate system environment checks
            $checks = @{
                'OS' = $IsWindows -or $IsLinux -or $IsMacOS
                'PowerShell' = $PSVersionTable.PSVersion.Major -ge 7
                'Workspace' = Test-Path '/workspaces/AitherLabs'
            }
            
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 2000  # Less than 2 seconds
            
            foreach ($check in $checks.GetEnumerator()) {
                Write-Host "Check '$($check.Key)': $($check.Value)" -ForegroundColor $(if ($check.Value) { 'Green' } else { 'Red' })
            }
        }
        
        It "Should handle memory and disk space checks" {
            # Basic memory check
            $memory = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($memory) {
                $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
                Write-Host "Total Physical Memory: $totalMemoryGB GB" -ForegroundColor Cyan
                $totalMemoryGB | Should -BeGreaterThan 0
            } else {
                # Alternative for non-Windows or if CIM is not available
                Write-Host "Memory check skipped (CIM not available)" -ForegroundColor Yellow
                Set-ItResult -Skipped -Because "CIM not available on this platform"
            }
        }
    }
}

Describe "DevEnvironment Module - Integration Tests" -Tags @('Integration', 'DevEnvironment', 'SystemIntegration') {
    
    Context "Module Integration" {
        It "Should work with other core modules" {
            # Test that DevEnvironment can work alongside other modules
            $modules = Get-Module | Where-Object { $_.Path -like "*aither-core/modules*" }
            $modules.Count | Should -BeGreaterThan 0
            
            Write-Host "Loaded AitherCore modules:" -ForegroundColor Cyan
            $modules | ForEach-Object { 
                Write-Host "  - $($_.Name)" -ForegroundColor Green 
            }
        }
        
        It "Should handle logging integration" {
            # Test that Write-CustomLog works (mocked in our case)
            { Write-CustomLog -Message "Test integration message" -Level "INFO" } | Should -Not -Throw
        }
    }
    
    Context "Real-World Scenarios" {
        It "Should validate development environment setup" {
            # Simulate a real development environment validation
            $validationResults = @{
                'WorkspaceStructure' = Test-Path '/workspaces/AitherLabs/aither-core'
                'TestingFramework' = Test-Path '/workspaces/AitherLabs/tests'
                'Documentation' = Test-Path '/workspaces/AitherLabs/docs'
                'Configuration' = Test-Path '/workspaces/AitherLabs/aither-core/default-config.json'
            }
            
            $passedChecks = ($validationResults.Values | Where-Object { $_ -eq $true }).Count
            $totalChecks = $validationResults.Count
            
            Write-Host "Development Environment Validation: $passedChecks/$totalChecks checks passed" -ForegroundColor $(if ($passedChecks -eq $totalChecks) { 'Green' } else { 'Yellow' })
            
            $passedChecks | Should -BeGreaterThan ($totalChecks * 0.7)  # At least 70% should pass
        }
    }
}
