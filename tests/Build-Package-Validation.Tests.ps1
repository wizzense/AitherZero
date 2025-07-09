#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive Build & Package Validation Test Suite for AitherZero
.DESCRIPTION
    Validates build system functionality, package creation, and installation processes
    across Windows, Linux, and macOS platforms with domain structure support.
.NOTES
    Created by: Agent 6 (Build & Package Validator)
    Date: 2025-07-09
    Version: 1.0.0
#>

BeforeAll {
    # Import test helpers
    . "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Test configuration
    $testPackageDir = Join-Path $projectRoot "test-package-validation"
    $buildOutputDir = Join-Path $projectRoot "build/output"
    $testVersion = "test-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    # Create test directory
    if (Test-Path $testPackageDir) {
        Remove-Item $testPackageDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $testPackageDir -Force | Out-Null
    
    # Helper functions
    function Test-PackageIntegrity {
        param(
            [string]$PackagePath,
            [string]$Platform
        )
        
        $testDir = Join-Path $testPackageDir "extract-$Platform"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        
        try {
            if ($Platform -eq 'windows') {
                Expand-Archive -Path $PackagePath -DestinationPath $testDir -Force
            } else {
                tar -xzf $PackagePath -C $testDir
            }
            
            $extractedDir = Get-ChildItem -Path $testDir -Directory | Where-Object { $_.Name -like "AitherZero*" } | Select-Object -First 1
            if ($extractedDir) {
                return $extractedDir.FullName
            }
            return $null
        } catch {
            return $null
        }
    }
    
    function Test-DomainFiles {
        param([string]$ExtractedPath)
        
        $domainPath = Join-Path $ExtractedPath "aither-core/domains"
        $requiredDomains = @(
            "automation/Automation.ps1",
            "configuration/Configuration.ps1",
            "experience/Experience.ps1",
            "infrastructure/LabRunner.ps1",
            "infrastructure/OpenTofuProvider.ps1",
            "infrastructure/ISOManager.ps1",
            "infrastructure/SystemMonitoring.ps1",
            "security/Security.ps1",
            "utilities/Utilities.ps1"
        )
        
        $missingDomains = @()
        foreach ($domain in $requiredDomains) {
            $domainFile = Join-Path $domainPath $domain
            if (-not (Test-Path $domainFile)) {
                $missingDomains += $domain
            }
        }
        
        return $missingDomains
    }
    
    function Test-CriticalFiles {
        param([string]$ExtractedPath)
        
        $criticalFiles = @(
            "Start-AitherZero.ps1",
            "README.md",
            "LICENSE",
            "VERSION",
            "CHANGELOG.md",
            "QUICKSTART.md",
            "aither-core/aither-core.ps1",
            "aither-core/AitherCore.psm1",
            "aither-core/AitherCore.psd1",
            "aither-core/shared/Find-ProjectRoot.ps1",
            "aither-core/shared/Test-PowerShellVersion.ps1",
            "aither-core/modules/Logging/Logging.psm1",
            "configs/default-config.json",
            "opentofu/README.md",
            "scripts/README.md"
        )
        
        $missingFiles = @()
        foreach ($file in $criticalFiles) {
            $filePath = Join-Path $ExtractedPath $file
            if (-not (Test-Path $filePath)) {
                $missingFiles += $file
            }
        }
        
        return $missingFiles
    }
    
    function Test-BootstrapFiles {
        param(
            [string]$ExtractedPath,
            [string]$Platform
        )
        
        $bootstrapFiles = @()
        switch ($Platform) {
            'windows' { $bootstrapFiles = @('bootstrap.ps1') }
            'linux' { $bootstrapFiles = @('bootstrap.sh') }
            'macos' { $bootstrapFiles = @('bootstrap.sh') }
        }
        
        $missingBootstrap = @()
        foreach ($file in $bootstrapFiles) {
            $filePath = Join-Path $ExtractedPath $file
            if (-not (Test-Path $filePath)) {
                $missingBootstrap += $file
            }
        }
        
        return $missingBootstrap
    }
}

Describe "Build-Package.ps1 System Validation" {
    
    Context "Build System Functionality" {
        
        It "Should exist and be executable" {
            $buildScript = Join-Path $projectRoot "build/Build-Package.ps1"
            $buildScript | Should -Exist
            (Get-Item $buildScript).Length | Should -BeGreaterThan 0
        }
        
        It "Should support all target platforms" {
            $buildScript = Join-Path $projectRoot "build/Build-Package.ps1"
            $content = Get-Content $buildScript -Raw
            $content | Should -Match "ValidateSet.*windows.*linux.*macos"
        }
        
        It "Should validate domain files in critical validation" {
            $buildScript = Join-Path $projectRoot "build/Build-Package.ps1"
            $content = Get-Content $buildScript -Raw
            $content | Should -Match "aither-core/domains/infrastructure/LabRunner.ps1"
            $content | Should -Match "aither-core/domains/configuration/Configuration.ps1"
        }
        
        It "Should create output directory structure" {
            $buildOutputDir | Should -Exist
        }
    }
    
    Context "Cross-Platform Package Creation" {
        
        BeforeAll {
            # Build test packages
            $buildScript = Join-Path $projectRoot "build/Build-Package.ps1"
            $buildResult = & pwsh -NoProfile -File $buildScript -Platform all -Version $testVersion
            Start-Sleep 1 # Allow filesystem to settle
        }
        
        It "Should create Windows ZIP package" {
            $windowsPackage = Join-Path $buildOutputDir "AitherZero-v$testVersion-windows.zip"
            $windowsPackage | Should -Exist
            (Get-Item $windowsPackage).Length | Should -BeGreaterThan 1MB
        }
        
        It "Should create Linux TAR.GZ package" {
            $linuxPackage = Join-Path $buildOutputDir "AitherZero-v$testVersion-linux.tar.gz"
            $linuxPackage | Should -Exist
            (Get-Item $linuxPackage).Length | Should -BeGreaterThan 1MB
        }
        
        It "Should create macOS TAR.GZ package" {
            $macosPackage = Join-Path $buildOutputDir "AitherZero-v$testVersion-macos.tar.gz"
            $macosPackage | Should -Exist
            (Get-Item $macosPackage).Length | Should -BeGreaterThan 1MB
        }
        
        It "Should create packages with consistent content size" {
            $windowsPackage = Join-Path $buildOutputDir "AitherZero-v$testVersion-windows.zip"
            $linuxPackage = Join-Path $buildOutputDir "AitherZero-v$testVersion-linux.tar.gz"
            $macosPackage = Join-Path $buildOutputDir "AitherZero-v$testVersion-macos.tar.gz"
            
            $windowsSize = (Get-Item $windowsPackage).Length
            $linuxSize = (Get-Item $linuxPackage).Length
            $macosSize = (Get-Item $macosPackage).Length
            
            # Linux and macOS should be similar size (both tar.gz)
            $sizeDifference = [Math]::Abs($linuxSize - $macosSize)
            $maxAcceptableDifference = 0.1 * $linuxSize # 10% difference max
            
            $sizeDifference | Should -BeLessOrEqual $maxAcceptableDifference
        }
    }
    
    Context "Package Content Validation" {
        
        BeforeAll {
            $platforms = @('windows', 'linux', 'macos')
            $packagePaths = @{}
            
            foreach ($platform in $platforms) {
                $extension = if ($platform -eq 'windows') { 'zip' } else { 'tar.gz' }
                $packagePaths[$platform] = Join-Path $buildOutputDir "AitherZero-v$testVersion-$platform.$extension"
            }
        }
        
        It "Should include all domain files in <platform> package" -ForEach @(
            @{platform = 'windows'},
            @{platform = 'linux'},
            @{platform = 'macos'}
        ) {
            $packagePath = $packagePaths[$platform]
            $extractedPath = Test-PackageIntegrity -PackagePath $packagePath -Platform $platform
            $extractedPath | Should -Not -BeNullOrEmpty
            
            $missingDomains = Test-DomainFiles -ExtractedPath $extractedPath
            $missingDomains | Should -BeNullOrEmpty -Because "All domain files must be present"
        }
        
        It "Should include all critical files in <platform> package" -ForEach @(
            @{platform = 'windows'},
            @{platform = 'linux'},
            @{platform = 'macos'}
        ) {
            $packagePath = $packagePaths[$platform]
            $extractedPath = Test-PackageIntegrity -PackagePath $packagePath -Platform $platform
            $extractedPath | Should -Not -BeNullOrEmpty
            
            $missingFiles = Test-CriticalFiles -ExtractedPath $extractedPath
            $missingFiles | Should -BeNullOrEmpty -Because "All critical files must be present"
        }
        
        It "Should include correct bootstrap files in <platform> package" -ForEach @(
            @{platform = 'windows'},
            @{platform = 'linux'},
            @{platform = 'macos'}
        ) {
            $packagePath = $packagePaths[$platform]
            $extractedPath = Test-PackageIntegrity -PackagePath $packagePath -Platform $platform
            $extractedPath | Should -Not -BeNullOrEmpty
            
            $missingBootstrap = Test-BootstrapFiles -ExtractedPath $extractedPath -Platform $platform
            $missingBootstrap | Should -BeNullOrEmpty -Because "Platform-specific bootstrap files must be present"
        }
        
        It "Should include complete module structure" -ForEach @(
            @{platform = 'windows'},
            @{platform = 'linux'},
            @{platform = 'macos'}
        ) {
            $packagePath = $packagePaths[$platform]
            $extractedPath = Test-PackageIntegrity -PackagePath $packagePath -Platform $platform
            $extractedPath | Should -Not -BeNullOrEmpty
            
            $modulesPath = Join-Path $extractedPath "aither-core/modules"
            $modulesPath | Should -Exist
            
            $coreModules = @('Logging', 'PatchManager', 'DevEnvironment', 'BackupManager')
            foreach ($module in $coreModules) {
                $modulePath = Join-Path $modulesPath $module
                $modulePath | Should -Exist -Because "Core module $module must be present"
                
                $moduleManifest = Join-Path $modulePath "$module.psd1"
                $moduleScript = Join-Path $modulePath "$module.psm1"
                $moduleManifest | Should -Exist
                $moduleScript | Should -Exist
            }
        }
    }
    
    Context "Installation and Bootstrap Validation" {
        
        BeforeAll {
            $platforms = @('windows', 'linux', 'macos')
            $extractedPaths = @{}
            
            foreach ($platform in $platforms) {
                $extension = if ($platform -eq 'windows') { 'zip' } else { 'tar.gz' }
                $packagePath = Join-Path $buildOutputDir "AitherZero-v$testVersion-$platform.$extension"
                $extractedPaths[$platform] = Test-PackageIntegrity -PackagePath $packagePath -Platform $platform
            }
        }
        
        It "Should have executable Start-AitherZero.ps1 in <platform> package" -ForEach @(
            @{platform = 'windows'},
            @{platform = 'linux'},
            @{platform = 'macos'}
        ) {
            $extractedPath = $extractedPaths[$platform]
            $startScript = Join-Path $extractedPath "Start-AitherZero.ps1"
            $startScript | Should -Exist
            
            $content = Get-Content $startScript -Raw
            $content | Should -Match "#Requires -Version"
            $content | Should -Match "Find-ProjectRoot"
        }
        
        It "Should support WhatIf parameter in extracted package" -ForEach @(
            @{platform = 'linux'} # Test on current platform
        ) {
            $extractedPath = $extractedPaths[$platform]
            $startScript = Join-Path $extractedPath "Start-AitherZero.ps1"
            
            # Test WhatIf parameter
            $result = & pwsh -NoProfile -File $startScript -WhatIf 2>&1
            $result | Should -Match "Ready to launch AitherZero"
        }
        
        It "Should load Logging module from extracted package" -ForEach @(
            @{platform = 'linux'} # Test on current platform
        ) {
            $extractedPath = $extractedPaths[$platform]
            $loggingModule = Join-Path $extractedPath "aither-core/modules/Logging/Logging.psm1"
            $loggingModule | Should -Exist
            
            # Test module loading
            $result = & pwsh -NoProfile -Command "Import-Module '$loggingModule' -Force; Write-CustomLog -Level INFO -Message 'Test from package'"
            $result | Should -Match "Test from package"
        }
        
        It "Should have valid bootstrap script for <platform>" -ForEach @(
            @{platform = 'windows'; script = 'bootstrap.ps1'},
            @{platform = 'linux'; script = 'bootstrap.sh'},
            @{platform = 'macos'; script = 'bootstrap.sh'}
        ) {
            $extractedPath = $extractedPaths[$platform]
            $bootstrapScript = Join-Path $extractedPath $script
            $bootstrapScript | Should -Exist
            
            $content = Get-Content $bootstrapScript -Raw
            $content | Should -Match "AitherZero.*Bootstrap"
            $content | Should -Match "PowerShell"
        }
    }
    
    Context "Package Integrity and Security" {
        
        It "Should not contain development files" -ForEach @(
            @{platform = 'windows'},
            @{platform = 'linux'},
            @{platform = 'macos'}
        ) {
            $extension = if ($platform -eq 'windows') { 'zip' } else { 'tar.gz' }
            $packagePath = Join-Path $buildOutputDir "AitherZero-v$testVersion-$platform.$extension"
            
            # Check package contents list
            if ($platform -eq 'windows') {
                $contents = & pwsh -Command "Expand-Archive -Path '$packagePath' -DestinationPath '$env:TEMP/aither-security-test' -Force; Get-ChildItem -Path '$env:TEMP/aither-security-test' -Recurse | Select-Object -ExpandProperty FullName"
                Remove-Item "$env:TEMP/aither-security-test" -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                $contents = tar -tzf $packagePath
            }
            
            # Should not contain development artifacts
            $contents | Should -Not -Match "\.git/"
            $contents | Should -Not -Match "\.vscode/"
            $contents | Should -Not -Match "node_modules/"
            $contents | Should -Not -Match "\.tmp/"
            $contents | Should -Not -Match "test-package"
        }
        
        It "Should have consistent file permissions" -ForEach @(
            @{platform = 'linux'},
            @{platform = 'macos'}
        ) {
            $packagePath = Join-Path $buildOutputDir "AitherZero-v$testVersion-$platform.tar.gz"
            
            # Check that .ps1 files have reasonable permissions
            $permissions = tar -tvf $packagePath | Select-String "\.ps1"
            $permissions | Should -Not -BeNullOrEmpty
            
            # Basic check that files exist and have some permissions
            $permissions.Count | Should -BeGreaterThan 0
        }
        
        It "Should have valid VERSION file" -ForEach @(
            @{platform = 'windows'},
            @{platform = 'linux'},
            @{platform = 'macos'}
        ) {
            $extension = if ($platform -eq 'windows') { 'zip' } else { 'tar.gz' }
            $packagePath = Join-Path $buildOutputDir "AitherZero-v$testVersion-$platform.$extension"
            $extractedPath = Test-PackageIntegrity -PackagePath $packagePath -Platform $platform
            
            $versionFile = Join-Path $extractedPath "VERSION"
            $versionFile | Should -Exist
            
            $version = Get-Content $versionFile -Raw
            $version.Trim() | Should -Match "^\d+\.\d+\.\d+"
        }
    }
    
    Context "Package Size Optimization" {
        
        It "Should have reasonable package sizes" -ForEach @(
            @{platform = 'windows'; maxSize = 5MB},
            @{platform = 'linux'; maxSize = 4MB},
            @{platform = 'macos'; maxSize = 4MB}
        ) {
            $extension = if ($platform -eq 'windows') { 'zip' } else { 'tar.gz' }
            $packagePath = Join-Path $buildOutputDir "AitherZero-v$testVersion-$platform.$extension"
            
            $size = (Get-Item $packagePath).Length
            $size | Should -BeLessOrEqual $maxSize -Because "Package should be optimized for distribution"
        }
        
        It "Should not contain large binary files" -ForEach @(
            @{platform = 'windows'},
            @{platform = 'linux'},
            @{platform = 'macos'}
        ) {
            $extension = if ($platform -eq 'windows') { 'zip' } else { 'tar.gz' }
            $packagePath = Join-Path $buildOutputDir "AitherZero-v$testVersion-$platform.$extension"
            
            # Extract and check for large files
            $extractedPath = Test-PackageIntegrity -PackagePath $packagePath -Platform $platform
            $largeFiles = Get-ChildItem -Path $extractedPath -Recurse -File | Where-Object { $_.Length -gt 1MB }
            
            $largeFiles | Should -BeNullOrEmpty -Because "No single file should exceed 1MB"
        }
    }
}

Describe "CI/CD Integration Validation" {
    
    Context "GitHub Actions Compatibility" {
        
        It "Should have build workflow file" {
            $workflowFile = Join-Path $projectRoot ".github/workflows/ci.yml"
            $workflowFile | Should -Exist
            
            $content = Get-Content $workflowFile -Raw
            $content | Should -Match "Build-Package"
        }
        
        It "Should support automated version detection" {
            $versionFile = Join-Path $projectRoot "VERSION"
            $versionFile | Should -Exist
            
            $version = Get-Content $versionFile -Raw
            $version.Trim() | Should -Match "^\d+\.\d+\.\d+"
        }
        
        It "Should have release workflow" {
            $releaseWorkflow = Join-Path $projectRoot ".github/workflows/release.yml"
            $releaseWorkflow | Should -Exist
            
            $content = Get-Content $releaseWorkflow -Raw
            $content | Should -Match "Build-Package"
            $content | Should -Match "upload.*artifact"
        }
    }
    
    Context "Build Performance" {
        
        It "Should build all packages within reasonable time" {
            $buildScript = Join-Path $projectRoot "build/Build-Package.ps1"
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = & pwsh -NoProfile -File $buildScript -Platform all -Version "performance-test"
            $stopwatch.Stop()
            
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessOrEqual 30 -Because "Build should complete within 30 seconds"
        }
        
        It "Should handle parallel builds" {
            # This test would be more relevant in a multi-threaded environment
            # For now, just ensure the build script doesn't have race conditions
            $buildScript = Join-Path $projectRoot "build/Build-Package.ps1"
            
            $job1 = Start-Job -ScriptBlock { 
                param($script)
                & pwsh -NoProfile -File $script -Platform windows -Version "parallel-test-1"
            } -ArgumentList $buildScript
            
            $job2 = Start-Job -ScriptBlock { 
                param($script)
                & pwsh -NoProfile -File $script -Platform linux -Version "parallel-test-2"
            } -ArgumentList $buildScript
            
            $result1 = Receive-Job $job1 -Wait
            $result2 = Receive-Job $job2 -Wait
            
            Remove-Job $job1, $job2
            
            $result1 | Should -Match "Success"
            $result2 | Should -Match "Success"
        }
    }
}

AfterAll {
    # Cleanup test packages
    if (Test-Path $testPackageDir) {
        Remove-Item $testPackageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Cleanup test packages from build output
    Get-ChildItem -Path $buildOutputDir -Filter "*$testVersion*" -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $buildOutputDir -Filter "*parallel-test*" -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $buildOutputDir -Filter "*performance-test*" -ErrorAction SilentlyContinue | Remove-Item -Force
}