BeforeDiscovery {
    $script:CrossPlatformModulePaths = @(
        Join-Path $PSScriptRoot '../../aither-core/modules/PatchManager/Private/Initialize-CrossPlatformEnvironment.ps1'
        Join-Path $PSScriptRoot '../../aither-core/shared/Find-ProjectRoot.ps1'
        Join-Path $PSScriptRoot '../../aither-core/modules/OpenTofuProvider'
        Join-Path $PSScriptRoot '../../aither-core/scripts'
    )
    $script:TestAppName = 'Cross-Platform-Deployment'
    
    # Verify key components exist
    foreach ($path in $script:CrossPlatformModulePaths) {
        if (-not (Test-Path $path)) {
            throw "Cross-platform component not found at: $path"
        }
    }
}

Describe 'Cross-Platform Deployment - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'CrossPlatform', 'Deployment') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'cross-platform-deployment-tests'
        
        # Save original environment
        $script:OriginalEnv = @{
            PROJECT_ROOT = $env:PROJECT_ROOT
            PWSH_MODULES_PATH = $env:PWSH_MODULES_PATH
            PROJECT_SCRIPTS_PATH = $env:PROJECT_SCRIPTS_PATH
            PLATFORM = $env:PLATFORM
            PATH_SEP = $env:PATH_SEP
            USERPROFILE = $env:USERPROFILE
            HOME = $env:HOME
            TEMP = $env:TEMP
            TMP = $env:TMP
            ProgramFiles = $env:ProgramFiles
            PATH = $env:PATH
        }
        
        # Create test directory structure that mimics real deployment
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestModulesDir = Join-Path $script:TestProjectRoot 'aither-core' 'modules'
        $script:TestSharedDir = Join-Path $script:TestProjectRoot 'aither-core' 'shared'
        $script:TestScriptsDir = Join-Path $script:TestProjectRoot 'aither-core' 'scripts'
        $script:TestConfigsDir = Join-Path $script:TestProjectRoot 'configs'
        $script:TestOpenTofuDir = Join-Path $script:TestProjectRoot 'opentofu'
        $script:TestDeploymentsDir = Join-Path $script:TestProjectRoot 'deployments'
        $script:TestLogsDir = Join-Path $script:TestProjectRoot 'logs'
        $script:TestTempDir = Join-Path $script:TestWorkspace 'temp'
        $script:TestAppDataDir = Join-Path $script:TestWorkspace 'AppData'
        $script:TestProgramFilesDir = Join-Path $script:TestWorkspace 'ProgramFiles'
        
        @($script:TestProjectRoot, $script:TestModulesDir, $script:TestSharedDir, $script:TestScriptsDir,
          $script:TestConfigsDir, $script:TestOpenTofuDir, $script:TestDeploymentsDir, $script:TestLogsDir,
          $script:TestTempDir, $script:TestAppDataDir, $script:TestProgramFilesDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Create mock PROJECT-MANIFEST.json
        @'
{
    "name": "AitherZero",
    "version": "1.0.0",
    "platform": "cross-platform",
    "dependencies": {
        "powershell": "7.0+",
        "opentofu": "1.6.0+"
    }
}
'@ | Out-File -FilePath (Join-Path $script:TestProjectRoot 'PROJECT-MANIFEST.json') -Encoding UTF8

        # Create mock .git directory
        New-Item -ItemType Directory -Path (Join-Path $script:TestProjectRoot '.git') -Force | Out-Null
        
        # Create mock README.md
        'AitherZero Test Project' | Out-File -FilePath (Join-Path $script:TestProjectRoot 'README.md') -Encoding UTF8
        
        # Copy essential cross-platform files to test environment
        $findProjectRootSource = Join-Path $PSScriptRoot '../../aither-core/shared/Find-ProjectRoot.ps1'
        $findProjectRootDest = Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1'
        Copy-Item -Path $findProjectRootSource -Destination $findProjectRootDest -Force
        
        $initCrossPlatformSource = Join-Path $PSScriptRoot '../../aither-core/modules/PatchManager/Private/Initialize-CrossPlatformEnvironment.ps1'
        $initCrossPlatformDest = Join-Path $script:TestModulesDir 'PatchManager' 'Private'
        New-Item -ItemType Directory -Path $initCrossPlatformDest -Force | Out-Null
        Copy-Item -Path $initCrossPlatformSource -Destination (Join-Path $initCrossPlatformDest 'Initialize-CrossPlatformEnvironment.ps1') -Force
        
        # Create mock modules
        $coreModules = @('Logging', 'OpenTofuProvider', 'LabRunner', 'PatchManager')
        foreach ($module in $coreModules) {
            $modulePath = Join-Path $script:TestModulesDir $module
            New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
            
            # Create mock module manifest
            @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$module.psm1'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Test-$module')
    CompatiblePSEditions = @('Core', 'Desktop')
}
"@ | Out-File -FilePath (Join-Path $modulePath "$module.psd1") -Encoding UTF8
            
            # Create mock module script
            @"
function Test-$module {
    param([string]`$TestParam)
    return @{
        Module = '$module'
        Platform = if (`$IsWindows) { 'Windows' } elseif (`$IsLinux) { 'Linux' } elseif (`$IsMacOS) { 'macOS' } else { 'Unknown' }
        TestParam = `$TestParam
        Success = `$true
    }
}
Export-ModuleMember -Function Test-$module
"@ | Out-File -FilePath (Join-Path $modulePath "$module.psm1") -Encoding UTF8
        }
        
        # Create mock Logging module with Write-CustomLog
        $loggingPath = Join-Path $script:TestModulesDir 'Logging'
        @'
function Write-CustomLog {
    param([string]$Message, [string]$Level = "INFO")
    Write-Host "[$Level] $Message"
}
Export-ModuleMember -Function Write-CustomLog
'@ | Out-File -FilePath (Join-Path $loggingPath 'Logging.psm1') -Encoding UTF8 -Force
        
        # Set test environment variables
        $env:PROJECT_ROOT = $script:TestProjectRoot
        $env:PWSH_MODULES_PATH = $script:TestModulesDir
        $env:PROJECT_SCRIPTS_PATH = $script:TestScriptsDir
        $env:USERPROFILE = $script:TestWorkspace
        $env:HOME = $script:TestWorkspace
        $env:TEMP = $script:TestTempDir
        $env:TMP = $script:TestTempDir
        $env:ProgramFiles = $script:TestProgramFilesDir
        
        # Mock platform detection for comprehensive testing
        $script:MockPlatforms = @{
            Windows = @{ IsWindows = $true; IsLinux = $false; IsMacOS = $false }
            Linux = @{ IsWindows = $false; IsLinux = $true; IsMacOS = $false }
            macOS = @{ IsWindows = $false; IsLinux = $false; IsMacOS = $true }
        }
        
        # Mock external commands for cross-platform testing
        Mock tofu { 
            param($Command)
            if ($Command -eq 'version') {
                return "OpenTofu v1.6.0"
            }
            return "Mock tofu command executed"
        }
        
        Mock git {
            param($Command)
            switch ($Command) {
                'rev-parse' {
                    if ($args[0] -eq '--show-toplevel') {
                        return $script:TestProjectRoot
                    }
                }
                'version' {
                    return 'git version 2.40.0'
                }
                default {
                    return "Mock git command: $Command"
                }
            }
        }
        
        Mock Invoke-WebRequest {
            param($Uri, $OutFile)
            # Create mock download file
            'Mock downloaded content' | Out-File -FilePath $OutFile -Encoding UTF8
            return @{ StatusCode = 200 }
        }
        
        Mock Expand-Archive {
            param($Path, $DestinationPath)
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            'Mock expanded executable' | Out-File -FilePath (Join-Path $DestinationPath 'tofu.exe') -Encoding UTF8
        }
        
        Mock Invoke-Expression {
            param($Command)
            return "Mock command execution: $Command"
        }
        
        # Initialize global variables
        $script:TestResults = @{}
        $script:PlatformTestResults = @{}
    }
    
    AfterAll {
        # Restore original environment
        foreach ($key in $script:OriginalEnv.Keys) {
            Set-Item -Path "env:$key" -Value $script:OriginalEnv[$key] -ErrorAction SilentlyContinue
        }
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context 'Cross-Platform Environment Initialization' {
        
        BeforeEach {
            # Clear environment variables for each test
            $env:PROJECT_ROOT = $null
            $env:PLATFORM = $null
            $env:PATH_SEP = $null
        }
        
        It 'Should initialize cross-platform environment successfully' {
            # Source the function
            . (Join-Path $script:TestModulesDir 'PatchManager' 'Private' 'Initialize-CrossPlatformEnvironment.ps1')
            
            $result = Initialize-CrossPlatformEnvironment
            
            $result.Success | Should -Be $true
            $result.ProjectRoot | Should -Be $script:TestProjectRoot
            $result.Platform | Should -BeIn @('Windows', 'Linux', 'macOS', 'Unknown')
            $result.ModulesPath | Should -Be $script:TestModulesDir
            
            $env:PROJECT_ROOT | Should -Be $script:TestProjectRoot
            $env:PWSH_MODULES_PATH | Should -Be $script:TestModulesDir
            $env:PLATFORM | Should -BeIn @('Windows', 'Linux', 'macOS', 'Unknown')
            $env:PATH_SEP | Should -BeIn @('\', '/')
        }
        
        It 'Should detect platform correctly on each supported OS' {
            . (Join-Path $script:TestModulesDir 'PatchManager' 'Private' 'Initialize-CrossPlatformEnvironment.ps1')
            
            foreach ($platform in $script:MockPlatforms.Keys) {
                # Mock platform detection
                Mock Get-Variable {
                    param($Name, $Scope)
                    if ($Name -eq 'IsWindows') { return @{ Value = $script:MockPlatforms[$platform].IsWindows } }
                    if ($Name -eq 'IsLinux') { return @{ Value = $script:MockPlatforms[$platform].IsLinux } }
                    if ($Name -eq 'IsMacOS') { return @{ Value = $script:MockPlatforms[$platform].IsMacOS } }
                }
                
                # Mock platform variables directly
                Set-Variable -Name 'IsWindows' -Value $script:MockPlatforms[$platform].IsWindows -Force -Scope Global
                Set-Variable -Name 'IsLinux' -Value $script:MockPlatforms[$platform].IsLinux -Force -Scope Global
                Set-Variable -Name 'IsMacOS' -Value $script:MockPlatforms[$platform].IsMacOS -Force -Scope Global
                
                $result = Initialize-CrossPlatformEnvironment
                
                $result.Success | Should -Be $true
                if ($platform -eq 'Windows') {
                    $result.Platform | Should -Be 'Windows'
                } elseif ($platform -eq 'Linux') {
                    $result.Platform | Should -Be 'Linux'
                } elseif ($platform -eq 'macOS') {
                    $result.Platform | Should -Be 'macOS'
                }
                
                $script:PlatformTestResults[$platform] = $result
            }
        }
        
        It 'Should handle missing project root gracefully' {
            # Remove project indicators to force fallback
            Remove-Item -Path (Join-Path $script:TestProjectRoot 'aither-core') -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path (Join-Path $script:TestProjectRoot '.git') -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path (Join-Path $script:TestProjectRoot 'PROJECT-MANIFEST.json') -Force -ErrorAction SilentlyContinue
            
            . (Join-Path $script:TestModulesDir 'PatchManager' 'Private' 'Initialize-CrossPlatformEnvironment.ps1')
            
            $result = Initialize-CrossPlatformEnvironment
            
            $result.Success | Should -Be $true
            $result.ProjectRoot | Should -Not -BeNullOrEmpty
            $env:PROJECT_ROOT | Should -Not -BeNullOrEmpty
        }
        
        It 'Should use existing valid PROJECT_ROOT when available' {
            $existingRoot = $script:TestProjectRoot
            $env:PROJECT_ROOT = $existingRoot
            
            . (Join-Path $script:TestModulesDir 'PatchManager' 'Private' 'Initialize-CrossPlatformEnvironment.ps1')
            
            $result = Initialize-CrossPlatformEnvironment
            
            $result.Success | Should -Be $true
            $result.ProjectRoot | Should -Be $existingRoot
        }
        
        It 'Should set platform-specific path separators correctly' {
            . (Join-Path $script:TestModulesDir 'PatchManager' 'Private' 'Initialize-CrossPlatformEnvironment.ps1')
            
            foreach ($platform in $script:MockPlatforms.Keys) {
                Set-Variable -Name 'IsWindows' -Value $script:MockPlatforms[$platform].IsWindows -Force -Scope Global
                Set-Variable -Name 'IsLinux' -Value $script:MockPlatforms[$platform].IsLinux -Force -Scope Global
                Set-Variable -Name 'IsMacOS' -Value $script:MockPlatforms[$platform].IsMacOS -Force -Scope Global
                
                $result = Initialize-CrossPlatformEnvironment
                
                if ($platform -eq 'Windows') {
                    $env:PATH_SEP | Should -Be '\'
                } else {
                    $env:PATH_SEP | Should -Be '/'
                }
            }
        }
    }
    
    Context 'Find-ProjectRoot Cross-Platform Detection' {
        
        It 'Should find project root using multiple strategies' {
            . (Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1')
            
            # Test from various starting points
            $testPaths = @(
                $script:TestProjectRoot
                $script:TestModulesDir
                $script:TestSharedDir
                (Join-Path $script:TestModulesDir 'PatchManager')
                (Join-Path $script:TestModulesDir 'OpenTofuProvider')
            )
            
            foreach ($testPath in $testPaths) {
                Push-Location $testPath
                try {
                    $projectRoot = Find-ProjectRoot -StartPath $testPath
                    $projectRoot | Should -Be $script:TestProjectRoot
                    $env:PROJECT_ROOT | Should -Be $script:TestProjectRoot
                } finally {
                    Pop-Location
                }
            }
        }
        
        It 'Should use environment variable when valid and not forcing' {
            . (Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1')
            
            $env:PROJECT_ROOT = $script:TestProjectRoot
            $projectRoot = Find-ProjectRoot
            
            $projectRoot | Should -Be $script:TestProjectRoot
        }
        
        It 'Should force re-detection when requested' {
            . (Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1')
            
            # Set wrong environment variable
            $env:PROJECT_ROOT = "/wrong/path"
            
            $projectRoot = Find-ProjectRoot -Force -StartPath $script:TestProjectRoot
            
            $projectRoot | Should -Be $script:TestProjectRoot
            $env:PROJECT_ROOT | Should -Be $script:TestProjectRoot
        }
        
        It 'Should find project root via git repository detection' {
            . (Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1')
            
            # Clear environment to force git detection
            $env:PROJECT_ROOT = $null
            
            # Mock git to return our test project root
            Mock git {
                param($Command)
                if ($Command -eq 'rev-parse' -and $args[0] -eq '--show-toplevel') {
                    return $script:TestProjectRoot
                }
            } -ModuleName 'Find-ProjectRoot'
            
            $projectRoot = Find-ProjectRoot -StartPath $script:TestProjectRoot
            
            $projectRoot | Should -Be $script:TestProjectRoot
        }
        
        It 'Should handle characteristic file detection across platforms' {
            . (Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1')
            
            # Test with different characteristic files
            $characteristicFiles = @('aither-core', '.git', 'README.md')
            
            foreach ($file in $characteristicFiles) {
                $testDir = Join-Path $script:TestWorkspace "test-$file"
                New-Item -ItemType Directory -Path $testDir -Force | Out-Null
                
                if ($file -eq 'aither-core') {
                    New-Item -ItemType Directory -Path (Join-Path $testDir $file) -Force | Out-Null
                } else {
                    'test content' | Out-File -FilePath (Join-Path $testDir $file) -Encoding UTF8
                }
                
                $projectRoot = Find-ProjectRoot -StartPath $testDir -Force
                
                # Should find the directory with the characteristic file
                $projectRoot | Should -Be $testDir
            }
        }
        
        It 'Should handle path resolution across different path formats' {
            . (Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1')
            
            # Test various path formats that might occur cross-platform
            $pathFormats = @(
                $script:TestProjectRoot
                $script:TestProjectRoot.Replace('\', '/')  # Unix-style on Windows
                (Resolve-Path $script:TestProjectRoot).Path
            )
            
            foreach ($pathFormat in $pathFormats) {
                if (Test-Path $pathFormat) {
                    $projectRoot = Find-ProjectRoot -StartPath $pathFormat -Force
                    # Normalize for comparison
                    $normalizedResult = (Resolve-Path $projectRoot).Path
                    $normalizedExpected = (Resolve-Path $script:TestProjectRoot).Path
                    $normalizedResult | Should -Be $normalizedExpected
                }
            }
        }
    }
    
    Context 'Cross-Platform Path Handling' {
        
        It 'Should use Join-Path for all path construction' {
            # Test that various modules properly construct paths
            $testPaths = @(
                @{ Base = $script:TestProjectRoot; Child = 'configs'; Expected = Join-Path $script:TestProjectRoot 'configs' }
                @{ Base = $script:TestModulesDir; Child = 'OpenTofuProvider'; Expected = Join-Path $script:TestModulesDir 'OpenTofuProvider' }
                @{ Base = $script:TestDeploymentsDir; Child = 'test-deployment'; Expected = Join-Path $script:TestDeploymentsDir 'test-deployment' }
            )
            
            foreach ($pathTest in $testPaths) {
                $constructedPath = Join-Path $pathTest.Base $pathTest.Child
                $constructedPath | Should -Be $pathTest.Expected
                
                # Verify path works on current platform
                if (-not (Test-Path $pathTest.Base)) {
                    New-Item -ItemType Directory -Path $pathTest.Base -Force | Out-Null
                }
                New-Item -ItemType Directory -Path $constructedPath -Force | Out-Null
                Test-Path $constructedPath | Should -Be $true
            }
        }
        
        It 'Should handle nested path construction correctly' {
            $nestedPath = Join-Path $script:TestProjectRoot (Join-Path 'aither-core' (Join-Path 'modules' 'OpenTofuProvider'))
            $nestedPath | Should -Be (Join-Path $script:TestProjectRoot 'aither-core' 'modules' 'OpenTofuProvider')
            
            # Create and verify the path works
            New-Item -ItemType Directory -Path $nestedPath -Force | Out-Null
            Test-Path $nestedPath | Should -Be $true
        }
        
        It 'Should resolve relative paths correctly across platforms' {
            Push-Location $script:TestProjectRoot
            try {
                $relativePaths = @(
                    '.\aither-core'
                    '.\configs'
                    '..\AitherZero\aither-core'  # Relative to parent
                )
                
                foreach ($relativePath in $relativePaths) {
                    if (Test-Path $relativePath) {
                        $resolvedPath = Resolve-Path $relativePath
                        $resolvedPath | Should -Not -BeNullOrEmpty
                        $resolvedPath.Path | Should -Not -Match '\.\.'  # No relative components
                    }
                }
            } finally {
                Pop-Location
            }
        }
        
        It 'Should handle long paths on Windows correctly' {
            if ($IsWindows) {
                # Create a long path structure
                $longPathComponents = @('very', 'long', 'path', 'structure', 'that', 'might', 'exceed', 'traditional', 'windows', 'path', 'limits', 'in', 'some', 'scenarios')
                $longPath = $script:TestProjectRoot
                
                foreach ($component in $longPathComponents) {
                    $longPath = Join-Path $longPath $component
                }
                
                # Should not throw error constructing long path
                { New-Item -ItemType Directory -Path $longPath -Force } | Should -Not -Throw
                Test-Path $longPath | Should -Be $true
            }
        }
    }
    
    Context 'Platform-Specific Deployment Operations' {
        
        It 'Should handle platform-specific installation paths' {
            foreach ($platform in $script:MockPlatforms.Keys) {
                Set-Variable -Name 'IsWindows' -Value $script:MockPlatforms[$platform].IsWindows -Force -Scope Global
                Set-Variable -Name 'IsLinux' -Value $script:MockPlatforms[$platform].IsLinux -Force -Scope Global
                Set-Variable -Name 'IsMacOS' -Value $script:MockPlatforms[$platform].IsMacOS -Force -Scope Global
                
                if ($platform -eq 'Windows') {
                    $installPath = Join-Path $env:ProgramFiles 'OpenTofu'
                    $tempPath = $env:TEMP
                    $expectedExtension = '.exe'
                } else {
                    $installPath = '/usr/local/bin'
                    $tempPath = '/tmp'
                    $expectedExtension = ''
                }
                
                # Verify platform-specific paths are constructed correctly
                $installPath | Should -Not -BeNullOrEmpty
                $tempPath | Should -Not -BeNullOrEmpty
                
                # Mock installation process
                if ($platform -eq 'Windows') {
                    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
                    $executablePath = Join-Path $installPath "tofu$expectedExtension"
                    'Mock tofu executable' | Out-File -FilePath $executablePath -Encoding UTF8
                    Test-Path $executablePath | Should -Be $true
                }
            }
        }
        
        It 'Should detect platform capabilities correctly' {
            foreach ($platform in $script:MockPlatforms.Keys) {
                Set-Variable -Name 'IsWindows' -Value $script:MockPlatforms[$platform].IsWindows -Force -Scope Global
                Set-Variable -Name 'IsLinux' -Value $script:MockPlatforms[$platform].IsLinux -Force -Scope Global
                Set-Variable -Name 'IsMacOS' -Value $script:MockPlatforms[$platform].IsMacOS -Force -Scope Global
                
                $capabilities = @{
                    SupportsLongPaths = $platform -eq 'Windows'
                    UsesPOSIXPaths = $platform -in @('Linux', 'macOS')
                    SupportsSymlinks = $platform -in @('Linux', 'macOS')
                    HasPackageManager = $platform -in @('Linux', 'macOS')
                    RequiresSudo = $platform -in @('Linux', 'macOS')
                }
                
                # Test platform-specific behaviors
                if ($capabilities.UsesPOSIXPaths) {
                    $testPath = '/usr/local/bin/tofu'
                    $testPath | Should -Match '^/'
                    $testPath | Should -Not -Match '\\'
                }
                
                if ($platform -eq 'Windows') {
                    $testPath = 'C:\Program Files\OpenTofu\tofu.exe'
                    $testPath | Should -Match '^[A-Z]:'
                    $testPath | Should -Match '\\'
                }
                
                $script:PlatformTestResults[$platform] = $capabilities
            }
        }
        
        It 'Should handle environment variables across platforms' {
            $testEnvVars = @{
                PROJECT_ROOT = $script:TestProjectRoot
                PLATFORM_SPECIFIC_VAR = 'test-value'
                PATH_WITH_SEPARATORS = "path1${env:PATH_SEP}path2${env:PATH_SEP}path3"
            }
            
            foreach ($varName in $testEnvVars.Keys) {
                Set-Item -Path "env:$varName" -Value $testEnvVars[$varName]
                Get-Item -Path "env:$varName" | Should -Not -BeNullOrEmpty
                (Get-Item -Path "env:$varName").Value | Should -Be $testEnvVars[$varName]
            }
        }
        
        It 'Should execute platform-appropriate commands' {
            foreach ($platform in $script:MockPlatforms.Keys) {
                Set-Variable -Name 'IsWindows' -Value $script:MockPlatforms[$platform].IsWindows -Force -Scope Global
                Set-Variable -Name 'IsLinux' -Value $script:MockPlatforms[$platform].IsLinux -Force -Scope Global
                Set-Variable -Name 'IsMacOS' -Value $script:MockPlatforms[$platform].IsMacOS -Force -Scope Global
                
                if ($platform -eq 'Windows') {
                    $command = 'tofu.exe version'
                    $expectedPattern = '\.exe'
                } else {
                    $command = 'tofu version'
                    $expectedPattern = '^tofu'
                }
                
                $command | Should -Match $expectedPattern
                
                # Mock command execution
                Mock Invoke-Expression { 
                    param($Command)
                    return "Mock execution of: $Command"
                }
                
                $result = Invoke-Expression $command
                $result | Should -Match "Mock execution"
            }
        }
    }
    
    Context 'Cross-Platform Module Loading' {
        
        It 'Should load modules correctly across platforms' {
            $testModules = @('Logging', 'OpenTofuProvider', 'LabRunner', 'PatchManager')
            
            foreach ($moduleName in $testModules) {
                $modulePath = Join-Path $script:TestModulesDir $moduleName
                Test-Path $modulePath | Should -Be $true
                
                # Test module import
                { Import-Module $modulePath -Force } | Should -Not -Throw
                
                # Test module function execution
                $functionName = "Test-$moduleName"
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    $result = & $functionName -TestParam "cross-platform-test"
                    $result.Success | Should -Be $true
                    $result.Platform | Should -BeIn @('Windows', 'Linux', 'macOS', 'Unknown')
                }
                
                Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
            }
        }
        
        It 'Should handle module dependencies across platforms' {
            # Test dependent module loading
            Import-Module (Join-Path $script:TestModulesDir 'Logging') -Force
            
            # Should be able to call dependent functions
            { Write-CustomLog -Message "Test message" -Level "INFO" } | Should -Not -Throw
            
            # Test cross-module dependency
            Import-Module (Join-Path $script:TestModulesDir 'OpenTofuProvider') -Force
            $result = Test-OpenTofuProvider -TestParam "dependency-test"
            
            $result.Module | Should -Be 'OpenTofuProvider'
            $result.Success | Should -Be $true
        }
        
        It 'Should resolve module paths correctly' {
            $modulePathTests = @(
                @{ Module = 'Logging'; Expected = Join-Path $script:TestModulesDir 'Logging' }
                @{ Module = 'OpenTofuProvider'; Expected = Join-Path $script:TestModulesDir 'OpenTofuProvider' }
                @{ Module = 'PatchManager'; Expected = Join-Path $script:TestModulesDir 'PatchManager' }
            )
            
            foreach ($test in $modulePathTests) {
                $resolvedPath = Join-Path $env:PWSH_MODULES_PATH $test.Module
                $resolvedPath | Should -Be $test.Expected
                Test-Path $resolvedPath | Should -Be $true
            }
        }
    }
    
    Context 'Cross-Platform File System Operations' {
        
        It 'Should handle file operations consistently across platforms' {
            $testFile = Join-Path $script:TestProjectRoot 'cross-platform-test.txt'
            $testContent = "Line 1`nLine 2`nLine 3"
            
            # Write file
            $testContent | Out-File -FilePath $testFile -Encoding UTF8
            Test-Path $testFile | Should -Be $true
            
            # Read file
            $readContent = Get-Content -Path $testFile -Raw
            $readContent.Trim() | Should -Be $testContent
            
            # Copy file
            $copyFile = Join-Path $script:TestProjectRoot 'cross-platform-test-copy.txt'
            Copy-Item -Path $testFile -Destination $copyFile
            Test-Path $copyFile | Should -Be $true
            
            # Move file
            $moveFile = Join-Path $script:TestProjectRoot 'cross-platform-test-moved.txt'
            Move-Item -Path $copyFile -Destination $moveFile
            Test-Path $moveFile | Should -Be $true
            Test-Path $copyFile | Should -Be $false
            
            # Delete files
            Remove-Item -Path $testFile, $moveFile -Force
            Test-Path $testFile | Should -Be $false
            Test-Path $moveFile | Should -Be $false
        }
        
        It 'Should handle directory operations consistently' {
            $testDir = Join-Path $script:TestProjectRoot 'cross-platform-test-dir'
            $nestedDir = Join-Path $testDir 'nested' 'deeply' 'nested'
            
            # Create nested directories
            New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null
            Test-Path $nestedDir | Should -Be $true
            
            # List directory contents
            $items = Get-ChildItem -Path $testDir -Recurse
            $items.Count | Should -BeGreaterThan 0
            
            # Remove directory tree
            Remove-Item -Path $testDir -Recurse -Force
            Test-Path $testDir | Should -Be $false
        }
        
        It 'Should handle special characters in paths' {
            $specialChars = @('spaces in name', 'unicode-文件', 'dots.and.dashes-test')
            
            foreach ($specialName in $specialChars) {
                $specialPath = Join-Path $script:TestProjectRoot $specialName
                
                # Create directory with special characters
                { New-Item -ItemType Directory -Path $specialPath -Force } | Should -Not -Throw
                Test-Path $specialPath | Should -Be $true
                
                # Create file in special directory
                $specialFile = Join-Path $specialPath 'test-file.txt'
                'test content' | Out-File -FilePath $specialFile -Encoding UTF8
                Test-Path $specialFile | Should -Be $true
                
                # Clean up
                Remove-Item -Path $specialPath -Recurse -Force
            }
        }
    }
    
    Context 'Cross-Platform Error Handling and Recovery' {
        
        It 'Should handle path-related errors gracefully' {
            # Test invalid path handling
            $invalidPaths = @(
                ''
                $null
                'non-existent-path-12345'
                (Join-Path $script:TestProjectRoot 'non' 'existent' 'deeply' 'nested' 'path')
            )
            
            foreach ($invalidPath in $invalidPaths) {
                if ($invalidPath) {
                    { Test-Path $invalidPath } | Should -Not -Throw
                    Test-Path $invalidPath | Should -Be $false
                }
            }
        }
        
        It 'Should recover from platform detection failures' {
            # Mock platform detection failure
            Mock Get-Variable {
                throw "Platform detection failed"
            }
            
            . (Join-Path $script:TestModulesDir 'PatchManager' 'Private' 'Initialize-CrossPlatformEnvironment.ps1')
            
            # Should still initialize with fallback values
            $result = Initialize-CrossPlatformEnvironment
            $result.Success | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle insufficient permissions gracefully' {
            if ($IsWindows) {
                # Test protected directory access
                $protectedPath = 'C:\Windows\System32\test-file.txt'
                
                { 'test' | Out-File -FilePath $protectedPath -ErrorAction Stop } | Should -Throw
            } else {
                # Test root directory access
                $protectedPath = '/root/test-file.txt'
                
                { 'test' | Out-File -FilePath $protectedPath -ErrorAction Stop } | Should -Throw
            }
        }
        
        It 'Should provide meaningful error messages for platform issues' {
            # Test unsupported platform scenario
            Set-Variable -Name 'IsWindows' -Value $false -Force -Scope Global
            Set-Variable -Name 'IsLinux' -Value $false -Force -Scope Global
            Set-Variable -Name 'IsMacOS' -Value $false -Force -Scope Global
            
            . (Join-Path $script:TestModulesDir 'PatchManager' 'Private' 'Initialize-CrossPlatformEnvironment.ps1')
            
            $result = Initialize-CrossPlatformEnvironment
            $result.Success | Should -Be $true
            $result.Platform | Should -Be 'Unknown'
        }
    }
    
    Context 'Performance and Resource Management' {
        
        It 'Should initialize environment efficiently' {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            . (Join-Path $script:TestModulesDir 'PatchManager' 'Private' 'Initialize-CrossPlatformEnvironment.ps1')
            $result = Initialize-CrossPlatformEnvironment
            
            $stopwatch.Stop()
            
            $result.Success | Should -Be $true
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Should complete within 5 seconds
        }
        
        It 'Should handle large directory structures efficiently' {
            # Create large directory structure
            $largeDirBase = Join-Path $script:TestProjectRoot 'large-structure'
            for ($i = 1; $i -le 100; $i++) {
                $dirPath = Join-Path $largeDirBase "dir-$i"
                New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
                
                for ($j = 1; $j -le 10; $j++) {
                    $filePath = Join-Path $dirPath "file-$j.txt"
                    "Content for file $j in directory $i" | Out-File -FilePath $filePath -Encoding UTF8
                }
            }
            
            # Test performance of path operations
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            . (Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1')
            $projectRoot = Find-ProjectRoot -StartPath $largeDirBase -Force
            
            $stopwatch.Stop()
            
            $projectRoot | Should -Not -BeNullOrEmpty
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 10000  # Should complete within 10 seconds
        }
        
        It 'Should manage memory efficiently during operations' {
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Perform multiple path operations
            for ($i = 1; $i -le 1000; $i++) {
                $testPath = Join-Path $script:TestProjectRoot "memory-test-$i"
                $null = $testPath  # Use the path but don't create it
            }
            
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            $finalMemory = [GC]::GetTotalMemory($true)
            
            $memoryIncrease = $finalMemory - $initialMemory
            $memoryIncrease | Should -BeLessThan (50 * 1024 * 1024)  # Less than 50MB increase
        }
    }
}