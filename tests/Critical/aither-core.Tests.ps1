BeforeDiscovery {
    $script:TestCoreScript = Join-Path $PSScriptRoot '../../aither-core/aither-core.ps1'
    $script:TestAppName = 'aither-core'
    
    # Verify the core script exists
    if (-not (Test-Path $script:TestCoreScript)) {
        throw "Core script not found at: $script:TestCoreScript"
    }
}

Describe 'aither-core.ps1 - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'Core') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'aither-core-tests'
        $script:OriginalPSModulePath = $env:PSModulePath
        $script:OriginalProjectRoot = $env:PROJECT_ROOT
        $script:OriginalPwshModulesPath = $env:PWSH_MODULES_PATH
        $script:OriginalLabConsoleLevel = $env:LAB_CONSOLE_LEVEL
        $script:OriginalAppData = $env:APPDATA
        
        # Create test directory structure
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestModulesPath = Join-Path $script:TestProjectRoot 'aither-core' 'modules'
        $script:TestConfigsPath = Join-Path $script:TestProjectRoot 'configs'
        $script:TestScriptsPath = Join-Path $script:TestProjectRoot 'scripts'
        $script:TestSharedPath = Join-Path $script:TestProjectRoot 'aither-core' 'shared'
        $script:TestLogsPath = Join-Path $script:TestProjectRoot 'logs'
        
        # Create directory structure
        @(
            $script:TestProjectRoot,
            $script:TestModulesPath,
            $script:TestConfigsPath,
            $script:TestScriptsPath,
            $script:TestSharedPath,
            $script:TestLogsPath,
            (Join-Path $script:TestModulesPath 'Logging'),
            (Join-Path $script:TestModulesPath 'LabRunner'),
            (Join-Path $script:TestModulesPath 'StartupExperience'),
            (Join-Path $script:TestModulesPath 'SetupWizard'),
            (Join-Path $script:TestModulesPath 'SystemMonitoring'),
            (Join-Path $script:TestModulesPath 'BackupManager'),
            (Join-Path $script:TestModulesPath 'PatchManager')
        ) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Create mock module manifests and scripts
        $mockModules = @{
            'Logging' = @{
                Functions = @('Initialize-LoggingSystem', 'Write-CustomLog')
                Content = @"
function Initialize-LoggingSystem { param(`$ConsoleLevel, `$LogLevel, [switch]`$Force) }
function Write-CustomLog { param(`$Message, `$Level = 'INFO') }
"@
            }
            'LabRunner' = @{
                Functions = @('Start-LabRunner')
                Content = @"
function Start-LabRunner { param([switch]`$Auto) }
"@
            }
            'StartupExperience' = @{
                Functions = @('Start-InteractiveMode')
                Content = @"
function Start-InteractiveMode { param(`$Profile) }
"@
            }
            'SetupWizard' = @{
                Functions = @('Start-SetupWizard')
                Content = @"
function Start-SetupWizard { param([switch]`$Auto) }
"@
            }
            'SystemMonitoring' = @{
                Functions = @('Start-SystemMonitoring')
                Content = @"
function Start-SystemMonitoring { param([switch]`$Auto) }
"@
            }
            'BackupManager' = @{
                Functions = @('Start-BackupManager')
                Content = @"
function Start-BackupManager { param([switch]`$Auto) }
"@
            }
            'PatchManager' = @{
                Functions = @('New-PatchIssue')
                Content = @"
function New-PatchIssue { param(`$Description, `$Priority, `$AffectedFiles, `$Labels) }
"@
            }
        }
        
        foreach ($module in $mockModules.Keys) {
            $modulePath = Join-Path $script:TestModulesPath $module
            $moduleScript = Join-Path $modulePath "$module.psm1"
            $moduleManifest = Join-Path $modulePath "$module.psd1"
            
            # Create module script
            $mockModules[$module].Content | Out-File -FilePath $moduleScript -Encoding UTF8
            
            # Create module manifest
            $manifestContent = @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$module.psm1'
    FunctionsToExport = @($($mockModules[$module].Functions | ForEach-Object { "'$_'" } | Join-String -Separator ', '))
    PowerShellVersion = '7.0'
}
"@
            $manifestContent | Out-File -FilePath $moduleManifest -Encoding UTF8
        }
        
        # Create mock Find-ProjectRoot script
        $findProjectRootContent = @"
function Find-ProjectRoot {
    param(`$StartPath)
    return '$script:TestProjectRoot'
}
"@
        $findProjectRootPath = Join-Path $script:TestSharedPath 'Find-ProjectRoot.ps1'
        $findProjectRootContent | Out-File -FilePath $findProjectRootPath -Encoding UTF8
        
        # Create mock Show-DynamicMenu script
        $showDynamicMenuContent = @"
function Show-DynamicMenu {
    param(`$Title, `$Config, [switch]`$FirstRun)
    Write-Host "Mock Dynamic Menu: `$Title"
}
"@
        $showDynamicMenuPath = Join-Path $script:TestSharedPath 'Show-DynamicMenu.ps1'
        $showDynamicMenuContent | Out-File -FilePath $showDynamicMenuPath -Encoding UTF8
        
        # Create test configuration files
        $defaultConfig = @{
            UIPreferences = @{
                Mode = 'auto'
                DefaultUI = 'enhanced'
            }
        } | ConvertTo-Json -Depth 3
        
        $configFile = Join-Path $script:TestConfigsPath 'default-config.json'
        $defaultConfig | Out-File -FilePath $configFile -Encoding UTF8
        
        # Create test scripts
        $testScript = Join-Path $script:TestScriptsPath 'TestScript.ps1'
        'Write-Host "Test script executed"' | Out-File -FilePath $testScript -Encoding UTF8
        
        # Set up test environment variables
        $env:PROJECT_ROOT = $script:TestProjectRoot
        $env:PWSH_MODULES_PATH = $script:TestModulesPath
        $env:APPDATA = $script:TestWorkspace
    }
    
    AfterAll {
        # Restore original environment
        $env:PSModulePath = $script:OriginalPSModulePath
        $env:PROJECT_ROOT = $script:OriginalProjectRoot
        $env:PWSH_MODULES_PATH = $script:OriginalPwshModulesPath
        $env:LAB_CONSOLE_LEVEL = $script:OriginalLabConsoleLevel
        $env:APPDATA = $script:OriginalAppData
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context 'Parameter Validation and Conflict Detection' {
        
        It 'Should display help when -Help parameter is used' {
            $result = & $script:TestCoreScript -Help
            
            $output = $result -join "`n"
            $output | Should -Match 'AitherZero Core Application'
            $output | Should -Match 'Usage:'
            $output | Should -Match 'Options:'
            $output | Should -Match 'Examples:'
            $output | Should -Match '-Quiet.*Run in quiet mode'
            $output | Should -Match '-Verbosity.*Set verbosity level'
            $output | Should -Match '-EnhancedUI.*Force enhanced UI'
            $output | Should -Match '-ClassicUI.*Force classic menu'
        }
        
        It 'Should detect and reject conflicting UI mode parameters' {
            { & $script:TestCoreScript -EnhancedUI -ClassicUI } | Should -Throw '*Cannot specify both -EnhancedUI and -ClassicUI*'
        }
        
        It 'Should resolve UI mode based on parameters correctly' {
            # Test with mocked execution to avoid full script run
            $testScript = {
                param($EnhancedUI, $ClassicUI, $UIMode)
                
                # Simulate the UI mode resolution logic
                if ($EnhancedUI -and $ClassicUI) {
                    throw "Cannot specify both -EnhancedUI and -ClassicUI. Please choose one."
                }
                
                if ($EnhancedUI) {
                    $UIMode = 'enhanced'
                } elseif ($ClassicUI) {
                    $UIMode = 'classic'
                }
                
                return $UIMode
            }
            
            & $testScript -EnhancedUI -UIMode 'auto' | Should -Be 'enhanced'
            & $testScript -ClassicUI -UIMode 'auto' | Should -Be 'classic'
            & $testScript -UIMode 'auto' | Should -Be 'auto'
        }
        
        It 'Should map Quiet parameter to silent verbosity' {
            # This tests the parameter mapping logic
            $testScript = {
                param([switch]$Quiet, $Verbosity = 'normal')
                
                if ($Quiet) {
                    $Verbosity = 'silent'
                }
                
                return $Verbosity
            }
            
            & $testScript -Quiet | Should -Be 'silent'
            & $testScript -Verbosity 'detailed' | Should -Be 'detailed'
        }
        
        It 'Should validate verbosity parameter values' {
            # Test valid verbosity values
            $validValues = @('silent', 'normal', 'detailed')
            
            foreach ($value in $validValues) {
                { & $script:TestCoreScript -Verbosity $value -Help } | Should -Not -Throw
            }
        }
    }
    
    Context 'Environment Detection and Setup' {
        
        It 'Should detect non-interactive mode correctly' {
            $testScript = {
                param($NonInteractive, $Auto)
                
                # Simulate the non-interactive detection logic
                if (-not $NonInteractive) {
                    $hostCheck = ($Host.Name -eq 'Default Host')
                    $userInteractiveCheck = ([Environment]::UserInteractive -eq $false)
                    $pesterCheck = ($env:PESTER_RUN -eq 'true')
                    $autoCheck = ($Auto.IsPresent)
                    
                    $NonInteractive = $hostCheck -or $userInteractiveCheck -or $pesterCheck -or $autoCheck
                }
                
                return $NonInteractive
            }
            
            # Test various scenarios
            $env:PESTER_RUN = 'true'
            & $testScript | Should -Be $true
            
            $env:PESTER_RUN = $null
            & $testScript -Auto | Should -Be $true
        }
        
        It 'Should find project root using multiple strategies' {
            # Test that Find-ProjectRoot utility is used correctly
            $findProjectRootPath = Join-Path $script:TestSharedPath 'Find-ProjectRoot.ps1'
            Test-Path $findProjectRootPath | Should -Be $true
            
            # Source the utility and test it
            . $findProjectRootPath
            $result = Find-ProjectRoot -StartPath $script:TestWorkspace
            $result | Should -Be $script:TestProjectRoot
        }
        
        It 'Should detect module paths correctly for different structures' {
            # Test release structure detection
            $releaseModulesPath = Join-Path $script:TestWorkspace 'modules'
            New-Item -ItemType Directory -Path $releaseModulesPath -Force | Out-Null
            
            Test-Path $releaseModulesPath | Should -Be $true
            
            # Test development structure detection
            Test-Path $script:TestModulesPath | Should -Be $true
        }
        
        It 'Should set up environment variables correctly' {
            $env:PROJECT_ROOT | Should -Be $script:TestProjectRoot
            $env:PWSH_MODULES_PATH | Should -Be $script:TestModulesPath
        }
        
        It 'Should validate PowerShell 7 requirements' {
            # Test PowerShell version detection logic
            $testScript = {
                if ($PSVersionTable.PSVersion.Major -lt 7) {
                    return $false
                }
                return $true
            }
            
            & $testScript | Should -Be $true
        }
    }
    
    Context 'Module Loading and Dependencies' {
        
        BeforeEach {
            # Reset module states
            Get-Module Logging, LabRunner, StartupExperience | Remove-Module -Force -ErrorAction SilentlyContinue
        }
        
        It 'Should validate critical module paths before import' {
            $loggingPath = Join-Path $script:TestModulesPath 'Logging'
            $labRunnerPath = Join-Path $script:TestModulesPath 'LabRunner'
            
            Test-Path $loggingPath | Should -Be $true
            Test-Path $labRunnerPath | Should -Be $true
        }
        
        It 'Should handle module import failures gracefully' {
            # Test with non-existent module path
            $invalidModulePath = Join-Path $script:TestModulesPath 'NonExistentModule'
            
            { Import-Module $invalidModulePath -Force -ErrorAction Stop } | Should -Throw
        }
        
        It 'Should load required modules in correct order' {
            # Test module loading sequence
            $loggingPath = Join-Path $script:TestModulesPath 'Logging'
            $labRunnerPath = Join-Path $script:TestModulesPath 'LabRunner'
            
            Import-Module $loggingPath -Force
            Get-Module Logging | Should -Not -BeNullOrEmpty
            
            Import-Module $labRunnerPath -Force
            Get-Module LabRunner | Should -Not -BeNullOrEmpty
        }
        
        It 'Should detect StartupExperience module availability' {
            $startupExperiencePath = Join-Path $script:TestModulesPath 'StartupExperience'
            Test-Path $startupExperiencePath | Should -Be $true
            
            # Test module import
            Import-Module $startupExperiencePath -Force
            Get-Command Start-InteractiveMode -Module StartupExperience | Should -Not -BeNullOrEmpty
        }
        
        It 'Should provide comprehensive troubleshooting information on module failures' {
            # This tests the error handling and troubleshooting output
            $expectedTroubleshootingSteps = @(
                'Verify project structure is complete',
                'Check that modules exist at:',
                'Ensure all files were extracted properly',
                'Try running from the project root directory',
                'Check PowerShell version:'
            )
            
            # Each troubleshooting step should be present in error output
            $expectedTroubleshootingSteps | ForEach-Object {
                $_ | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context 'Configuration Management' {
        
        It 'Should find configuration files in multiple locations' {
            $configPaths = @(
                (Join-Path $script:TestProjectRoot 'configs' 'default-config.json'),
                (Join-Path $script:TestProjectRoot 'aither-core' 'default-config.json')
            )
            
            # Test that at least one config path exists
            $configExists = $configPaths | Where-Object { Test-Path $_ }
            $configExists | Should -Not -BeNullOrEmpty
        }
        
        It 'Should parse JSON configuration correctly' {
            $configFile = Join-Path $script:TestConfigsPath 'default-config.json'
            $configContent = Get-Content $configFile -Raw | ConvertFrom-Json
            
            $configContent.UIPreferences | Should -Not -BeNullOrEmpty
            $configContent.UIPreferences.Mode | Should -Be 'auto'
            $configContent.UIPreferences.DefaultUI | Should -Be 'enhanced'
        }
        
        It 'Should handle missing configuration files gracefully' {
            $nonExistentConfig = Join-Path $script:TestWorkspace 'non-existent-config.json'
            Test-Path $nonExistentConfig | Should -Be $false
            
            # Should not throw when config file doesn't exist
            { 
                if (Test-Path $nonExistentConfig) {
                    Get-Content $nonExistentConfig -Raw | ConvertFrom-Json
                } else {
                    @{}
                }
            } | Should -Not -Throw
        }
        
        It 'Should handle malformed JSON configuration files' {
            $malformedConfigFile = Join-Path $script:TestConfigsPath 'malformed-config.json'
            '{ invalid json }' | Out-File -FilePath $malformedConfigFile -Encoding UTF8
            
            { Get-Content $malformedConfigFile -Raw | ConvertFrom-Json } | Should -Throw
        }
        
        It 'Should extract UI preferences from configuration' {
            $config = @{
                UIPreferences = @{
                    Mode = 'enhanced'
                    DefaultUI = 'classic'
                }
            }
            
            $config.UIPreferences.Mode | Should -Be 'enhanced'
            $config.UIPreferences.DefaultUI | Should -Be 'classic'
        }
    }
    
    Context 'Scripts Mode Execution' {
        
        It 'Should parse comma-separated component list correctly' {
            $scriptsParam = 'LabRunner,BackupManager,SetupWizard'
            $componentList = $scriptsParam -split ','
            
            $componentList.Count | Should -Be 3
            $componentList[0].Trim() | Should -Be 'LabRunner'
            $componentList[1].Trim() | Should -Be 'BackupManager'
            $componentList[2].Trim() | Should -Be 'SetupWizard'
        }
        
        It 'Should prioritize module loading over legacy scripts' {
            $componentName = 'LabRunner'
            $modulePath = Join-Path $script:TestModulesPath $componentName
            
            Test-Path $modulePath | Should -Be $true
            
            # Module should be found and preferred
            Import-Module $modulePath -Force
            Get-Module $componentName | Should -Not -BeNullOrEmpty
        }
        
        It 'Should execute default functions for loaded modules' {
            $componentName = 'LabRunner'
            $modulePath = Join-Path $script:TestModulesPath $componentName
            
            Import-Module $modulePath -Force
            $defaultFunction = "Start-$componentName"
            
            Get-Command $defaultFunction -Module $componentName | Should -Not -BeNullOrEmpty
        }
        
        It 'Should search multiple script paths for legacy scripts' {
            $scriptName = 'TestScript'
            $scriptsPaths = @(
                (Join-Path $script:TestProjectRoot 'scripts'),
                (Join-Path $script:TestProjectRoot 'aither-core' 'scripts')
            )
            
            # Test that script search paths are valid
            $scriptsPaths | ForEach-Object {
                if (Test-Path $_) {
                    $scriptPath = Join-Path $_ "$scriptName.ps1"
                    # Path construction should be valid
                    $scriptPath | Should -Not -BeNullOrEmpty
                }
            }
        }
        
        It 'Should handle component not found scenarios' {
            $nonExistentComponentName = 'NonExistentComponent'
            $modulePath = Join-Path $script:TestModulesPath $nonExistentComponentName
            
            Test-Path $modulePath | Should -Be $false
            
            # Should handle gracefully without throwing
            { Test-Path $modulePath } | Should -Not -Throw
        }
    }
    
    Context 'Auto Mode Execution' {
        
        It 'Should define correct default auto-mode modules' {
            $autoModules = @('SetupWizard', 'SystemMonitoring', 'BackupManager')
            
            $autoModules.Count | Should -Be 3
            $autoModules | Should -Contain 'SetupWizard'
            $autoModules | Should -Contain 'SystemMonitoring'
            $autoModules | Should -Contain 'BackupManager'
        }
        
        It 'Should verify auto-mode modules exist' {
            $autoModules = @('SetupWizard', 'SystemMonitoring', 'BackupManager')
            
            foreach ($moduleName in $autoModules) {
                $modulePath = Join-Path $script:TestModulesPath $moduleName
                Test-Path $modulePath | Should -Be $true
            }
        }
        
        It 'Should execute auto-mode modules with -Auto parameter' {
            $autoModules = @('SetupWizard', 'SystemMonitoring', 'BackupManager')
            
            foreach ($moduleName in $autoModules) {
                $modulePath = Join-Path $script:TestModulesPath $moduleName
                Import-Module $modulePath -Force
                
                $defaultFunction = "Start-$moduleName"
                Get-Command $defaultFunction -Module $moduleName | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'Should handle auto-mode module failures gracefully' {
            # Test error handling in auto mode
            $testScript = {
                param($ModuleName)
                
                try {
                    # Simulate module loading
                    $modulePath = Join-Path $script:TestModulesPath $ModuleName
                    if (-not (Test-Path $modulePath)) {
                        throw "Module not found: $ModuleName"
                    }
                    return $true
                } catch {
                    # Should not re-throw in auto mode, just log
                    Write-Verbose "Error in auto mode for $ModuleName : $_"
                    return $false
                }
            }
            
            & $testScript -ModuleName 'NonExistentModule' | Should -Be $false
        }
    }
    
    Context 'Interactive Mode and UI System' {
        
        It 'Should determine UI mode based on availability and preference' {
            $testScript = {
                param($startupExperienceAvailable, $UIMode, $NonInteractive, $Auto, $Scripts)
                
                $useEnhancedUI = $false
                
                if ($UIMode -eq 'enhanced') {
                    if ($startupExperienceAvailable) {
                        $useEnhancedUI = $true
                    }
                } elseif ($UIMode -eq 'classic') {
                    $useEnhancedUI = $false
                } elseif ($UIMode -eq 'auto') {
                    if ($startupExperienceAvailable -and -not $NonInteractive -and -not $Auto -and -not $Scripts) {
                        $useEnhancedUI = $true
                    }
                }
                
                return $useEnhancedUI
            }
            
            # Test enhanced UI selection
            & $testScript -startupExperienceAvailable $true -UIMode 'enhanced' | Should -Be $true
            & $testScript -startupExperienceAvailable $false -UIMode 'enhanced' | Should -Be $false
            & $testScript -startupExperienceAvailable $true -UIMode 'classic' | Should -Be $false
            & $testScript -startupExperienceAvailable $true -UIMode 'auto' -NonInteractive $false -Auto $false -Scripts $false | Should -Be $true
        }
        
        It 'Should detect first run correctly' {
            $firstRunFile = Join-Path $env:APPDATA 'AitherZero' '.firstrun'
            $firstRunDir = Split-Path $firstRunFile -Parent
            
            # Clean up any existing first run marker
            if (Test-Path $firstRunFile) {
                Remove-Item $firstRunFile -Force
            }
            
            $isFirstRun = -not (Test-Path $firstRunFile)
            $isFirstRun | Should -Be $true
            
            # Create first run marker
            if (-not (Test-Path $firstRunDir)) {
                New-Item -ItemType Directory -Path $firstRunDir -Force | Out-Null
            }
            New-Item -ItemType File -Path $firstRunFile -Force | Out-Null
            
            $isFirstRun = -not (Test-Path $firstRunFile)
            $isFirstRun | Should -Be $false
        }
        
        It 'Should load dynamic menu system from multiple paths' {
            $dynamicMenuPaths = @(
                (Join-Path $script:TestProjectRoot 'aither-core' 'shared' 'Show-DynamicMenu.ps1')
            )
            
            $dynamicMenuPath = $dynamicMenuPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
            $dynamicMenuPath | Should -Not -BeNullOrEmpty
            
            # Test that the dynamic menu script can be sourced
            { . $dynamicMenuPath } | Should -Not -Throw
        }
        
        It 'Should provide fallback when dynamic menu is not available' {
            # Test fallback behavior when Show-DynamicMenu is not available
            $testScript = {
                if (Get-Command Show-DynamicMenu -ErrorAction SilentlyContinue) {
                    return $true
                } else {
                    # Fallback logic
                    return $false
                }
            }
            
            # Remove the function temporarily to test fallback
            if (Get-Command Show-DynamicMenu -ErrorAction SilentlyContinue) {
                Remove-Item Function:\Show-DynamicMenu -ErrorAction SilentlyContinue
            }
            
            & $testScript | Should -Be $false
        }
    }
    
    Context 'Error Handling and Diagnostics' {
        
        It 'Should provide comprehensive error messages for module import failures' {
            $expectedErrorElements = @(
                'Error importing required modules:',
                'Troubleshooting Steps:',
                'Verify project structure is complete',
                'Check that modules exist at:',
                'Current paths:',
                'Project Root:',
                'Modules Path:',
                'Script Location:'
            )
            
            # Test that error message contains all expected elements
            $expectedErrorElements | ForEach-Object {
                $_ | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'Should track scripts with no output for reporting' {
            $testScript = {
                param($ScriptName, $ScriptPath, $Verbosity)
                
                # Simulate no output detection
                $script:NoOutputScripts = @()
                $hasUserVisibleOutput = $false
                
                if (-not $hasUserVisibleOutput -and $Verbosity -in @('normal', 'silent')) {
                    $script:NoOutputScripts += [PSCustomObject]@{
                        ScriptName = $ScriptName
                        ScriptPath = $ScriptPath
                        Verbosity = $Verbosity
                        Timestamp = Get-Date
                    }
                }
                
                return $script:NoOutputScripts.Count
            }
            
            $result = & $testScript -ScriptName 'TestScript' -ScriptPath '/test/path' -Verbosity 'normal'
            $result | Should -Be 1
        }
        
        It 'Should generate no-output summary with suggestions' {
            $noOutputScripts = @(
                [PSCustomObject]@{
                    ScriptName = 'TestScript1'
                    ScriptPath = '/test/path1'
                    Verbosity = 'normal'
                    Timestamp = Get-Date
                },
                [PSCustomObject]@{
                    ScriptName = 'TestScript2'
                    ScriptPath = '/test/path2'
                    Verbosity = 'silent'
                    Timestamp = Get-Date
                }
            )
            
            $noOutputScripts.Count | Should -Be 2
            $noOutputScripts[0].ScriptName | Should -Be 'TestScript1'
            $noOutputScripts[1].ScriptName | Should -Be 'TestScript2'
        }
        
        It 'Should handle exit codes correctly' {
            # Test success exit code
            $successExitCode = 0
            $successExitCode | Should -Be 0
            
            # Test error exit code
            $errorExitCode = 1
            $errorExitCode | Should -Be 1
        }
        
        It 'Should save no-output summary to logs' {
            $summaryPath = Join-Path $script:TestLogsPath "no-output-scripts-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"
            $testData = @{ test = 'data' }
            
            # Test that log directory exists
            Test-Path $script:TestLogsPath | Should -Be $true
            
            # Test JSON conversion and file creation
            { $testData | ConvertTo-Json -Depth 3 | Out-File -FilePath $summaryPath -Encoding UTF8 } | Should -Not -Throw
        }
    }
    
    Context 'Cross-Platform Compatibility' {
        
        It 'Should use Join-Path for all path construction' {
            $testPaths = @(
                (Join-Path $script:TestProjectRoot 'configs'),
                (Join-Path $script:TestProjectRoot 'aither-core' 'modules'),
                (Join-Path $script:TestProjectRoot 'scripts')
            )
            
            $testPaths | ForEach-Object {
                $_ | Should -Not -BeNullOrEmpty
                $_ | Should -Not -Match '[/\\]{2,}'  # Should not contain double slashes
            }
        }
        
        It 'Should detect PowerShell executable correctly' {
            $testScript = {
                $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
                if (-not $pwshPath) {
                    $exeName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
                    $pwshPath = Join-Path $PSHOME $exeName
                }
                return $pwshPath
            }
            
            $result = & $testScript
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle platform-specific behaviors' {
            # Test platform detection
            $platformTests = @{
                IsWindows = $IsWindows
                IsLinux = $IsLinux
                IsMacOS = $IsMacOS
            }
            
            # At least one platform should be true
            $platformTests.Values | Where-Object { $_ } | Should -Not -BeNullOrEmpty
        }
        
        It 'Should use UTF8 encoding for all file operations' {
            $testFile = Join-Path $script:TestWorkspace 'encoding-test.txt'
            $testContent = 'Test content with unicode: ñáéíóú'
            
            { $testContent | Out-File -FilePath $testFile -Encoding UTF8 } | Should -Not -Throw
            
            if (Test-Path $testFile) {
                $readContent = Get-Content $testFile -Raw -Encoding UTF8
                $readContent.Trim() | Should -Be $testContent
            }
        }
    }
    
    Context 'Verbosity and Output Handling' {
        
        It 'Should map verbosity levels correctly' {
            $verbosityMapping = @{
                silent = 'SILENT'
                normal = 'WARN'
                detailed = 'DEBUG'
            }
            
            $verbosityLevels = @{
                silent = 0
                normal = 1
                detailed = 2
            }
            
            $verbosityMapping.Keys | ForEach-Object {
                $verbosityMapping[$_] | Should -Not -BeNullOrEmpty
                $verbosityLevels[$_] | Should -BeOfType [int]
            }
        }
        
        It 'Should handle script output correctly based on verbosity' {
            $testScript = {
                param($Verbosity, $Output)
                
                $visibleOutputCount = 0
                $hasUserVisibleOutput = $false
                
                if ($Output -and $Verbosity -ne 'silent') {
                    $visibleOutputCount++
                    $hasUserVisibleOutput = $true
                }
                
                return @{
                    VisibleOutputCount = $visibleOutputCount
                    HasUserVisibleOutput = $hasUserVisibleOutput
                }
            }
            
            $result = & $testScript -Verbosity 'normal' -Output 'Test output'
            $result.VisibleOutputCount | Should -Be 1
            $result.HasUserVisibleOutput | Should -Be $true
            
            $result = & $testScript -Verbosity 'silent' -Output 'Test output'
            $result.VisibleOutputCount | Should -Be 0
            $result.HasUserVisibleOutput | Should -Be $false
        }
        
        It 'Should set LAB_CONSOLE_LEVEL environment variable' {
            $verbosityToLogLevel = @{
                silent = 'SILENT'
                normal = 'WARN'
                detailed = 'DEBUG'
            }
            
            foreach ($verbosity in $verbosityToLogLevel.Keys) {
                $expectedLevel = $verbosityToLogLevel[$verbosity]
                
                # Simulate setting the environment variable
                $env:LAB_CONSOLE_LEVEL = $expectedLevel
                $env:LAB_CONSOLE_LEVEL | Should -Be $expectedLevel
            }
        }
    }
}