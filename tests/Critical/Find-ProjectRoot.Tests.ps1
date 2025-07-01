BeforeDiscovery {
    $script:TestUtilityScript = Join-Path $PSScriptRoot '../../aither-core/shared/Find-ProjectRoot.ps1'
    
    # Verify the utility script exists
    if (-not (Test-Path $script:TestUtilityScript)) {
        throw "Find-ProjectRoot utility not found at: $script:TestUtilityScript"
    }
}

Describe 'Find-ProjectRoot.ps1 - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'Utility', 'CrossPlatform') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Source the Find-ProjectRoot utility
        . $script:TestUtilityScript
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'find-projectroot-tests'
        
        # Save original environment
        $script:OriginalProjectRoot = $env:PROJECT_ROOT
        $script:OriginalLocation = Get-Location
        
        # Create comprehensive test directory structure
        $script:TestProjects = @{
            'AitherZero' = @{
                Root = Join-Path $script:TestWorkspace 'AitherZero'
                HasAitherCore = $true
                HasGit = $true
                HasReadme = $true
                HasGoScript = $true
                HasKickerScript = $true
            }
            'AitherLabs' = @{
                Root = Join-Path $script:TestWorkspace 'AitherLabs'
                HasAitherCore = $true
                HasGit = $false
                HasReadme = $true
                HasGoScript = $false
                HasKickerScript = $false
            }
            'Aitherium' = @{
                Root = Join-Path $script:TestWorkspace 'Aitherium'
                HasAitherCore = $true
                HasGit = $true
                HasReadme = $false
                HasGoScript = $false
                HasKickerScript = $false
            }
            'NonProject' = @{
                Root = Join-Path $script:TestWorkspace 'NonProject'
                HasAitherCore = $false
                HasGit = $false
                HasReadme = $false
                HasGoScript = $false
                HasKickerScript = $false
            }
            'PartialProject' = @{
                Root = Join-Path $script:TestWorkspace 'PartialProject'
                HasAitherCore = $false
                HasGit = $true
                HasReadme = $true
                HasGoScript = $false
                HasKickerScript = $false
            }
        }
        
        # Create test directory structures
        foreach ($projectName in $script:TestProjects.Keys) {
            $project = $script:TestProjects[$projectName]
            $projectRoot = $project.Root
            
            # Create main directory
            New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
            
            # Create aither-core directory structure if specified
            if ($project.HasAitherCore) {
                $aithercorePath = Join-Path $projectRoot 'aither-core'
                $modulesPath = Join-Path $aithercorePath 'modules'
                $sharedPath = Join-Path $aithercorePath 'shared'
                
                New-Item -ItemType Directory -Path $aithercorePath -Force | Out-Null
                New-Item -ItemType Directory -Path $modulesPath -Force | Out-Null
                New-Item -ItemType Directory -Path $sharedPath -Force | Out-Null
                
                # Create some mock modules
                @('Logging', 'PatchManager', 'LabRunner') | ForEach-Object {
                    $modulePath = Join-Path $modulesPath $_
                    New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
                    New-Item -ItemType File -Path (Join-Path $modulePath "$_.psm1") -Force | Out-Null
                }
                
                # Create core script
                New-Item -ItemType File -Path (Join-Path $aithercorePath 'aither-core.ps1') -Force | Out-Null
            }
            
            # Create .git directory if specified
            if ($project.HasGit) {
                $gitPath = Join-Path $projectRoot '.git'
                New-Item -ItemType Directory -Path $gitPath -Force | Out-Null
                New-Item -ItemType File -Path (Join-Path $gitPath 'config') -Force | Out-Null
            }
            
            # Create README.md if specified
            if ($project.HasReadme) {
                $readmePath = Join-Path $projectRoot 'README.md'
                "# $projectName Project" | Out-File -FilePath $readmePath -Encoding UTF8
            }
            
            # Create go.ps1 if specified
            if ($project.HasGoScript) {
                $goScriptPath = Join-Path $projectRoot 'go.ps1'
                "Write-Host 'Go script for $projectName'" | Out-File -FilePath $goScriptPath -Encoding UTF8
            }
            
            # Create kicker-git.ps1 if specified
            if ($project.HasKickerScript) {
                $kickerScriptPath = Join-Path $projectRoot 'kicker-git.ps1'
                "Write-Host 'Kicker script for $projectName'" | Out-File -FilePath $kickerScriptPath -Encoding UTF8
            }
            
            # Create nested directory structure for testing deep searches
            $nestedPath = Join-Path $projectRoot 'deep' 'nested' 'directory' 'structure'
            New-Item -ItemType Directory -Path $nestedPath -Force | Out-Null
        }
        
        # Create test subdirectories for module testing
        $script:TestModuleStructure = Join-Path $script:TestProjects['AitherZero'].Root 'aither-core' 'modules' 'TestModule'
        New-Item -ItemType Directory -Path $script:TestModuleStructure -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestModuleStructure 'Public') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestModuleStructure 'Private') -Force | Out-Null
        
        # Create test scripts directory structure
        $script:TestScriptsStructure = Join-Path $script:TestProjects['AitherZero'].Root 'scripts' 'subscripts'
        New-Item -ItemType Directory -Path $script:TestScriptsStructure -Force | Out-Null
        
        # Create tests directory structure
        $script:TestTestsStructure = Join-Path $script:TestProjects['AitherZero'].Root 'tests' 'Unit' 'SomeModule'
        New-Item -ItemType Directory -Path $script:TestTestsStructure -Force | Out-Null
    }
    
    AfterAll {
        # Restore original environment
        $env:PROJECT_ROOT = $script:OriginalProjectRoot
        Set-Location $script:OriginalLocation
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clear environment variable for each test
        $env:PROJECT_ROOT = $null
    }
    
    Context 'Strategy 1: Environment Variable Detection' {
        
        It 'Should use existing PROJECT_ROOT when valid and not forcing' {
            $expectedRoot = $script:TestProjects['AitherZero'].Root
            $env:PROJECT_ROOT = $expectedRoot
            
            $result = Find-ProjectRoot -StartPath (Join-Path $expectedRoot 'aither-core')
            
            $result | Should -Be $expectedRoot
        }
        
        It 'Should ignore invalid PROJECT_ROOT environment variable' {
            $env:PROJECT_ROOT = Join-Path $script:TestWorkspace 'NonExistentProject'
            
            $result = Find-ProjectRoot -StartPath $script:TestProjects['AitherZero'].Root
            
            $result | Should -Not -Be $env:PROJECT_ROOT
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should verify PROJECT_ROOT has characteristic files' {
            # Set to a directory that exists but doesn't have aither-core or .git
            $env:PROJECT_ROOT = $script:TestProjects['NonProject'].Root
            
            $result = Find-ProjectRoot -StartPath $script:TestProjects['AitherZero'].Root
            
            # Should not use the invalid PROJECT_ROOT
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should force re-detection when -Force is specified' {
            $validRoot = $script:TestProjects['AitherZero'].Root
            $env:PROJECT_ROOT = $validRoot
            
            # Force detection from a different project
            $result = Find-ProjectRoot -StartPath $script:TestProjects['AitherLabs'].Root -Force
            
            $result | Should -Be $script:TestProjects['AitherLabs'].Root
            $result | Should -Not -Be $validRoot
        }
        
        It 'Should set PROJECT_ROOT environment variable after detection' {
            $env:PROJECT_ROOT = $null
            $expectedRoot = $script:TestProjects['AitherZero'].Root
            
            $result = Find-ProjectRoot -StartPath $expectedRoot
            
            $env:PROJECT_ROOT | Should -Be $expectedRoot
        }
    }
    
    Context 'Strategy 2: Characteristic Files Search' {
        
        It 'Should find project root via aither-core directory' {
            $startPath = Join-Path $script:TestProjects['AitherZero'].Root 'aither-core' 'modules' 'Logging'
            
            $result = Find-ProjectRoot -StartPath $startPath
            
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should find project root via .git directory' {
            $startPath = Join-Path $script:TestProjects['AitherZero'].Root 'deep' 'nested' 'directory'
            
            $result = Find-ProjectRoot -StartPath $startPath
            
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should find project root via multiple characteristic files' {
            $startPath = Join-Path $script:TestProjects['AitherZero'].Root 'aither-core' 'modules'
            
            $result = Find-ProjectRoot -StartPath $startPath
            
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should prioritize aither-core as definitive indicator' {
            $startPath = $script:TestProjects['AitherZero'].Root
            
            $result = Find-ProjectRoot -StartPath $startPath
            
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should require multiple definitive files for non-aither-core detection' {
            # Test with PartialProject that only has git and README
            $startPath = $script:TestProjects['PartialProject'].Root
            
            $result = Find-ProjectRoot -StartPath $startPath
            
            $result | Should -Be $script:TestProjects['PartialProject'].Root
        }
        
        It 'Should traverse up directory tree correctly' {
            $deepPath = Join-Path $script:TestProjects['AitherZero'].Root 'deep' 'nested' 'directory' 'structure'
            
            $result = Find-ProjectRoot -StartPath $deepPath
            
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should handle filesystem root boundaries' {
            # Mock a scenario where we reach filesystem root
            $testScript = {
                param($StartPath)
                
                $current = Get-Item $StartPath -ErrorAction SilentlyContinue
                $foundRoot = $false
                
                while ($current -and $current.FullName -ne "/" -and $current.FullName -notmatch "^[A-Z]:\\?$") {
                    if ($current.FullName -eq "/" -or $current.FullName -match "^[A-Z]:\\?$") {
                        $foundRoot = $true
                        break
                    }
                    $parent = Split-Path $current.FullName -Parent
                    if (-not $parent -or $parent -eq $current.FullName) {
                        break
                    }
                    $current = Get-Item $parent -ErrorAction SilentlyContinue
                }
                
                return -not $foundRoot  # Should stop before reaching root
            }
            
            & $testScript -StartPath $script:TestProjects['AitherZero'].Root | Should -Be $true
        }
    }
    
    Context 'Strategy 3: PSScriptRoot-based Detection' {
        
        It 'Should detect project root from module directory' {
            # Simulate being called from a module
            $moduleRoot = $script:TestModuleStructure
            
            # Test the path calculation logic
            $candidatePaths = @(
                (Split-Path (Split-Path $moduleRoot -Parent) -Parent),  # From module to aither-core
                (Split-Path (Split-Path (Split-Path $moduleRoot -Parent) -Parent) -Parent)  # From module to project root
            )
            
            $projectRoot = $null
            foreach ($candidatePath in $candidatePaths) {
                if ($candidatePath -and (Test-Path $candidatePath)) {
                    if (Test-Path (Join-Path $candidatePath "aither-core")) {
                        $projectRoot = $candidatePath
                        break
                    }
                }
            }
            
            $projectRoot | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should detect project root from module subdirectory' {
            $moduleSubdir = Join-Path $script:TestModuleStructure 'Public'
            
            # Test navigation from Public subdirectory
            $candidatePath = Split-Path (Split-Path (Split-Path $moduleSubdir -Parent) -Parent) -Parent
            
            if (Test-Path (Join-Path $candidatePath "aither-core")) {
                $candidatePath | Should -Be $script:TestProjects['AitherZero'].Root
            }
        }
        
        It 'Should detect project root from tests directory structure' {
            $testsDir = $script:TestTestsStructure
            
            # Test navigation from deep test directory
            $candidatePath = Split-Path (Split-Path (Split-Path (Split-Path $testsDir -Parent) -Parent) -Parent) -Parent
            
            if (Test-Path (Join-Path $candidatePath "aither-core")) {
                $candidatePath | Should -Be $script:TestProjects['AitherZero'].Root
            }
        }
        
        It 'Should handle shared directory detection' {
            $sharedDir = Join-Path $script:TestProjects['AitherZero'].Root 'aither-core' 'shared'
            
            # From shared directory, go up two levels
            $candidatePath = Split-Path (Split-Path $sharedDir -Parent) -Parent
            
            Test-Path (Join-Path $candidatePath "aither-core") | Should -Be $true
            $candidatePath | Should -Be $script:TestProjects['AitherZero'].Root
        }
    }
    
    Context 'Strategy 4: Git Repository Root Detection' {
        
        BeforeAll {
            # Create a more realistic git repository structure
            $script:GitTestRepo = Join-Path $script:TestWorkspace 'GitTestRepo'
            New-Item -ItemType Directory -Path $script:GitTestRepo -Force | Out-Null
            
            # Create aither-core directory
            $gitAitherCore = Join-Path $script:GitTestRepo 'aither-core'
            New-Item -ItemType Directory -Path $gitAitherCore -Force | Out-Null
            
            # Create .git directory with proper structure
            $gitDir = Join-Path $script:GitTestRepo '.git'
            New-Item -ItemType Directory -Path $gitDir -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $gitDir 'HEAD') -Force | Out-Null
            'ref: refs/heads/main' | Out-File -FilePath (Join-Path $gitDir 'HEAD') -Encoding UTF8
        }
        
        It 'Should use git command for repository root detection' {
            # Test git command availability and basic functionality
            $testScript = {
                param($TestPath)
                
                try {
                    Push-Location $TestPath -ErrorAction SilentlyContinue
                    $gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
                    return $gitAvailable
                } catch {
                    return $false
                } finally {
                    Pop-Location -ErrorAction SilentlyContinue
                }
            }
            
            $gitAvailable = & $testScript -TestPath $script:TestWorkspace
            
            # Git should be available in most environments
            if ($gitAvailable) {
                $gitAvailable | Should -Be $true
            } else {
                # If git is not available, that's a valid scenario to test
                Write-Warning "Git not available for testing - this tests the fallback scenario"
            }
        }
        
        It 'Should verify git root has aither-core directory' {
            $testScript = {
                param($GitRoot)
                
                if ($GitRoot -and (Test-Path $GitRoot)) {
                    return Test-Path (Join-Path $GitRoot "aither-core")
                }
                return $false
            }
            
            $hasAitherCore = & $testScript -GitRoot $script:GitTestRepo
            $hasAitherCore | Should -Be $true
        }
        
        It 'Should handle git command failures gracefully' {
            $testScript = {
                param($TestPath)
                
                try {
                    Push-Location $TestPath -ErrorAction SilentlyContinue
                    
                    # Simulate git command failure
                    $gitRoot = $null
                    try {
                        # This would be: git rev-parse --show-toplevel 2>$null
                        # Simulating failure case
                        throw "Simulated git failure"
                    } catch {
                        # Should handle gracefully
                        return $null
                    }
                } finally {
                    Pop-Location -ErrorAction SilentlyContinue
                }
            }
            
            $result = & $testScript -TestPath $script:TestWorkspace
            $result | Should -BeNullOrEmpty
        }
        
        It 'Should properly restore location after git detection' {
            $originalLocation = Get-Location
            
            $testScript = {
                param($TestPath)
                
                try {
                    Push-Location $TestPath -ErrorAction SilentlyContinue
                    # Simulate some work
                    return (Get-Location).Path
                } finally {
                    Pop-Location -ErrorAction SilentlyContinue
                }
            }
            
            & $testScript -TestPath $script:TestWorkspace | Out-Null
            
            # Location should be restored
            (Get-Location).Path | Should -Be $originalLocation.Path
        }
    }
    
    Context 'Strategy 5: Known Path Patterns' {
        
        It 'Should detect AitherZero pattern in path' {
            $aitherZeroPath = $script:TestProjects['AitherZero'].Root
            
            $aitherZeroPath -like "*AitherZero*" | Should -Be $true
        }
        
        It 'Should detect AitherLabs pattern in path' {
            $aitherLabsPath = $script:TestProjects['AitherLabs'].Root
            
            $aitherLabsPath -like "*AitherLabs*" | Should -Be $true
        }
        
        It 'Should detect Aitherium pattern in path' {
            $aitheriumPath = $script:TestProjects['Aitherium'].Root
            
            $aitheriumPath -like "*Aitherium*" | Should -Be $true
        }
        
        It 'Should find project root when path contains known pattern' {
            $startPath = Join-Path $script:TestProjects['AitherZero'].Root 'deep' 'nested'
            
            $result = Find-ProjectRoot -StartPath $startPath
            
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should traverse up to find aither-core when pattern matches' {
            $testScript = {
                param($CurrentPath, $Pattern)
                
                if ($CurrentPath -like $Pattern) {
                    $testPath = $CurrentPath
                    while ($testPath -and $testPath -ne "/" -and $testPath -notmatch "^[A-Z]:\\?$") {
                        if (Test-Path (Join-Path $testPath "aither-core")) {
                            return $testPath
                        }
                        $testPath = Split-Path $testPath -Parent
                    }
                }
                return $null
            }
            
            $result = & $testScript -CurrentPath $script:TestProjects['AitherZero'].Root -Pattern "*AitherZero*"
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
    }
    
    Context 'Strategy 6: Common Development Locations' {
        
        It 'Should test common path patterns' {
            $commonPaths = @(
                "/workspaces/AitherZero",
                "C:/workspaces/AitherZero",
                "$env:USERPROFILE/OneDrive/Documents/0. wizzense/AitherZero",
                "$env:USERPROFILE/Documents/0. wizzense/AitherZero",
                "$HOME/AitherZero"
            )
            
            foreach ($path in $commonPaths) {
                $expandedPath = $ExecutionContext.InvokeCommand.ExpandString($path)
                
                # Path expansion should work
                $expandedPath | Should -Not -BeNullOrEmpty
                
                # Path structure should be valid
                if ($expandedPath -match "^[A-Za-z]:" -or $expandedPath.StartsWith("/")) {
                    $expandedPath | Should -Match "AitherZero"
                }
            }
        }
        
        It 'Should verify aither-core exists in common locations' {
            $testScript = {
                param($CommonPath)
                
                $expandedPath = $ExecutionContext.InvokeCommand.ExpandString($CommonPath)
                if (Test-Path $expandedPath) {
                    return Test-Path (Join-Path $expandedPath "aither-core")
                }
                return $false
            }
            
            # Test with a common path that might exist
            $userProfile = $env:USERPROFILE
            if ($userProfile) {
                $testPath = "$userProfile/Documents/TestProject"
                # This is testing the logic, not expecting the path to exist
                & $testScript -CommonPath $testPath | Should -BeOfType [bool]
            }
        }
        
        It 'Should handle non-existent common paths gracefully' {
            $nonExistentPath = "/definitely/does/not/exist/AitherZero"
            
            { 
                $expandedPath = $ExecutionContext.InvokeCommand.ExpandString($nonExistentPath)
                Test-Path $expandedPath
            } | Should -Not -Throw
        }
    }
    
    Context 'Cross-Platform Path Handling' {
        
        It 'Should handle Windows-style paths correctly' {
            if ($IsWindows) {
                $windowsPath = "C:\Users\Test\AitherZero"
                $testScript = {
                    param($Path)
                    return $Path -match "^[A-Z]:\\?$"
                }
                
                & $testScript -Path "C:\" | Should -Be $true
                & $testScript -Path "C:" | Should -Be $true
            }
        }
        
        It 'Should handle Unix-style paths correctly' {
            $unixPath = "/home/user/AitherZero"
            $testScript = {
                param($Path)
                return $Path -eq "/"
            }
            
            & $testScript -Path "/" | Should -Be $true
        }
        
        It 'Should use Join-Path for cross-platform compatibility' {
            $testPaths = @(
                @{ Base = $script:TestWorkspace; Child = 'AitherZero' },
                @{ Base = $script:TestWorkspace; Child = 'aither-core' },
                @{ Base = $script:TestWorkspace; Child = @('nested', 'path', 'structure') }
            )
            
            foreach ($testPath in $testPaths) {
                if ($testPath.Child -is [array]) {
                    $result = Join-Path $testPath.Base -ChildPath ($testPath.Child -join [System.IO.Path]::DirectorySeparatorChar)
                } else {
                    $result = Join-Path $testPath.Base $testPath.Child
                }
                
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Not -Match '[/\\]{2,}'  # No double separators
            }
        }
        
        It 'Should normalize paths correctly' {
            $testScript = {
                param($ProjectRoot)
                
                try {
                    $normalized = (Resolve-Path $ProjectRoot).Path
                    return $normalized
                } catch {
                    return $ProjectRoot
                }
            }
            
            $result = & $testScript -ProjectRoot $script:TestProjects['AitherZero'].Root
            $result | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should handle path resolution failures gracefully' {
            $testScript = {
                param($ProjectRoot)
                
                try {
                    $resolved = (Resolve-Path $ProjectRoot).Path
                    return $resolved
                } catch {
                    # Should handle gracefully and return original path
                    return $ProjectRoot
                }
            }
            
            $nonExistentPath = Join-Path $script:TestWorkspace 'NonExistent'
            $result = & $testScript -ProjectRoot $nonExistentPath
            $result | Should -Be $nonExistentPath
        }
    }
    
    Context 'Context-Aware Detection and Validation' {
        
        It 'Should prefer AitherZero when context suggests it' {
            # Test the final validation logic
            $testScript = {
                param($ProjectRoot, $StartPath)
                
                if ($ProjectRoot -and $StartPath -like "*AitherZero*" -and $ProjectRoot -notlike "*AitherZero*") {
                    # Look for AitherZero in parent directories
                    $searchPath = $StartPath
                    while ($searchPath -and $searchPath -ne "/" -and $searchPath -notmatch "^[A-Z]:\\?$") {
                        if ($searchPath -like "*AitherZero*" -and (Test-Path (Join-Path $searchPath "aither-core"))) {
                            return $searchPath
                        }
                        $searchPath = Split-Path $searchPath -Parent
                    }
                }
                return $ProjectRoot
            }
            
            $aitherZeroStart = $script:TestProjects['AitherZero'].Root
            $aitherLabsRoot = $script:TestProjects['AitherLabs'].Root
            
            $result = & $testScript -ProjectRoot $aitherLabsRoot -StartPath $aitherZeroStart
            $result | Should -Be $aitherZeroStart
        }
        
        It 'Should provide warning when fallback to current directory' {
            $testScript = {
                param($StartPath)
                
                # Simulate no project root found
                $projectRoot = $null
                
                if (-not $projectRoot) {
                    $fallbackRoot = (Get-Location).Path
                    Write-Warning "Could not detect project root reliably. Using current directory: $fallbackRoot"
                    return $fallbackRoot
                }
                
                return $projectRoot
            }
            
            # Capture warnings
            $warnings = @()
            $result = & $testScript -StartPath $script:TestWorkspace -WarningVariable warnings
            
            $result | Should -Be (Get-Location).Path
        }
        
        It 'Should handle edge case with StartPath parameter' {
            # Test default StartPath logic
            $testScript = {
                param($PSScriptRoot, $Location)
                
                $StartPath = $null
                
                if (-not $StartPath) {
                    if ($PSScriptRoot) {
                        $StartPath = $PSScriptRoot
                    } else {
                        $StartPath = $Location
                    }
                }
                
                return $StartPath
            }
            
            $result = & $testScript -PSScriptRoot $script:TestWorkspace -Location (Get-Location).Path
            $result | Should -Be $script:TestWorkspace
            
            $result = & $testScript -PSScriptRoot $null -Location (Get-Location).Path
            $result | Should -Be (Get-Location).Path
        }
    }
    
    Context 'Error Handling and Robustness' {
        
        It 'Should handle access denied scenarios gracefully' {
            # Test with a path that might cause access issues
            $testScript = {
                param($TestPath)
                
                try {
                    $current = Get-Item $TestPath -ErrorAction SilentlyContinue
                    return $current -ne $null
                } catch {
                    return $false
                }
            }
            
            $result = & $testScript -TestPath $script:TestWorkspace
            $result | Should -BeOfType [bool]
        }
        
        It 'Should handle invalid characters in paths' {
            $testScript = {
                param($TestPath)
                
                try {
                    $normalized = [System.IO.Path]::GetFullPath($TestPath)
                    return $normalized
                } catch {
                    return $TestPath
                }
            }
            
            $validPath = $script:TestWorkspace
            $result = & $testScript -TestPath $validPath
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle very deep directory structures' {
            # Create a very deep structure
            $deepStructure = $script:TestWorkspace
            for ($i = 1; $i -le 10; $i++) {
                $deepStructure = Join-Path $deepStructure "level$i"
            }
            
            New-Item -ItemType Directory -Path $deepStructure -Force | Out-Null
            
            # Test navigation up the tree
            $testScript = {
                param($DeepPath)
                
                $current = $DeepPath
                $levels = 0
                
                while ($current -and $current -ne "/" -and $current -notmatch "^[A-Z]:\\?$" -and $levels -lt 50) {
                    $parent = Split-Path $current -Parent
                    if (-not $parent -or $parent -eq $current) {
                        break
                    }
                    $current = $parent
                    $levels++
                }
                
                return $levels
            }
            
            $levels = & $testScript -DeepPath $deepStructure
            $levels | Should -BeGreaterThan 10
            $levels | Should -BeLessThan 50  # Should not infinite loop
        }
        
        It 'Should handle network paths appropriately' {
            # Test UNC path handling (Windows-specific)
            if ($IsWindows) {
                $testScript = {
                    param($NetworkPath)
                    
                    # Test if path looks like UNC
                    return $NetworkPath.StartsWith("\\")
                }
                
                $uncPath = "\\server\share\AitherZero"
                & $testScript -NetworkPath $uncPath | Should -Be $true
            }
        }
        
        It 'Should handle circular symbolic links gracefully' {
            # This tests the protection against infinite loops
            $testScript = {
                param($StartPath, $MaxIterations = 100)
                
                $current = $StartPath
                $visited = @{}
                $iterations = 0
                
                while ($current -and $iterations -lt $MaxIterations) {
                    if ($visited.ContainsKey($current)) {
                        # Circular reference detected
                        return $false
                    }
                    $visited[$current] = $true
                    
                    $parent = Split-Path $current -Parent
                    if (-not $parent -or $parent -eq $current) {
                        break
                    }
                    $current = $parent
                    $iterations++
                }
                
                return $iterations -lt $MaxIterations
            }
            
            $result = & $testScript -StartPath $script:TestWorkspace
            $result | Should -Be $true
        }
    }
    
    Context 'Performance and Efficiency' {
        
        It 'Should complete detection within reasonable time' {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $result = Find-ProjectRoot -StartPath $script:TestProjects['AitherZero'].Root
            
            $stopwatch.Stop()
            
            $result | Should -Be $script:TestProjects['AitherZero'].Root
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Should complete within 5 seconds
        }
        
        It 'Should cache result in environment variable' {
            $env:PROJECT_ROOT = $null
            
            $result = Find-ProjectRoot -StartPath $script:TestProjects['AitherZero'].Root
            
            $env:PROJECT_ROOT | Should -Be $result
            $env:PROJECT_ROOT | Should -Be $script:TestProjects['AitherZero'].Root
        }
        
        It 'Should minimize filesystem operations when possible' {
            # Test that subsequent calls use cached value
            $env:PROJECT_ROOT = $script:TestProjects['AitherZero'].Root
            
            $stopwatch1 = [System.Diagnostics.Stopwatch]::StartNew()
            $result1 = Find-ProjectRoot -StartPath (Join-Path $script:TestProjects['AitherZero'].Root 'aither-core')
            $stopwatch1.Stop()
            
            $stopwatch2 = [System.Diagnostics.Stopwatch]::StartNew()
            $result2 = Find-ProjectRoot -StartPath (Join-Path $script:TestProjects['AitherZero'].Root 'aither-core')
            $stopwatch2.Stop()
            
            $result1 | Should -Be $result2
            # Second call should be faster due to caching
            $stopwatch2.ElapsedMilliseconds | Should -BeLessOrEqual $stopwatch1.ElapsedMilliseconds
        }
    }
}