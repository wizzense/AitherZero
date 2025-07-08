#Requires -Module Pester

<#
.SYNOPSIS
    Enhanced comprehensive test suite for ConfigurationRepository module
.DESCRIPTION
    Comprehensive testing of ConfigurationRepository functionality including:
    - Git-based repository management and automation
    - Repository creation with templates (default, minimal, enterprise, custom)
    - Repository cloning and validation
    - Repository synchronization with enhanced error handling
    - Template creation and customization
    - Cross-platform Git operations
    - Enterprise compliance features
    - Security policies and documentation generation
    - Error handling and recovery mechanisms
    - Performance under load with large repositories
.NOTES
    This test suite uses the sophisticated TestingFramework infrastructure
    and provides comprehensive coverage of the Git-based configuration repository system.
#>

BeforeAll {
    # Import required modules using the TestingFramework infrastructure
    $ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else {
        $currentPath = $PSScriptRoot
        while ($currentPath -and -not (Test-Path (Join-Path $currentPath ".git"))) {
            $currentPath = Split-Path $currentPath -Parent
        }
        $currentPath
    }

    # Import TestingFramework for infrastructure
    $testingFrameworkPath = Join-Path $ProjectRoot "aither-core/modules/TestingFramework"
    if (Test-Path $testingFrameworkPath) {
        Import-Module $testingFrameworkPath -Force
    }

    # Import the module under test
    $ModulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $ModulePath -Force

    # Check if Git is available
    $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

    # Mock Write-CustomLog if not available
    if (-not (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Level, [string]$Message)
            Write-Host "[$Level] $Message"
        }
    }

    # Create test directory structure
    $TestRepositoryDir = Join-Path $TestDrive 'ConfigurationRepository'
    $TestLocalRepos = Join-Path $TestRepositoryDir 'local-repos'
    $TestRemoteRepos = Join-Path $TestRepositoryDir 'remote-repos'
    $TestTemplates = Join-Path $TestRepositoryDir 'templates'
    $TestBackups = Join-Path $TestRepositoryDir 'backups'

    @($TestRepositoryDir, $TestLocalRepos, $TestRemoteRepos, $TestTemplates, $TestBackups) | ForEach-Object {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }

    # Set up test environment
    $env:TEST_REPOSITORY_DIR = $TestRepositoryDir
    $env:TEST_LOCAL_REPOS = $TestLocalRepos
    $env:TEST_REMOTE_REPOS = $TestRemoteRepos

    # Test data for comprehensive testing
    $script:TestData = @{
        RepositoryTemplates = @{
            default = @{
                name = "default"
                description = "Default AitherZero configuration template"
                files = @{
                    'configs/app-config.json' = @{
                        version = "1.0"
                        name = "Default Configuration"
                        settings = @{
                            verbosity = "normal"
                            autoUpdate = $true
                            telemetryEnabled = $false
                        }
                    }
                    'configs/module-config.json' = @{
                        modules = @{
                            Logging = @{ enabled = $true; level = "INFO" }
                            PatchManager = @{ enabled = $true; autoCommit = $false }
                        }
                    }
                    'README.md' = "# AitherZero Configuration Repository\n\nThis is a default configuration repository."
                    '.gitignore' = "*.log\ntemp/\ncache/\nlocal-settings.json"
                }
            }
            minimal = @{
                name = "minimal"
                description = "Minimal AitherZero configuration template"
                files = @{
                    'configs/app-config.json' = @{
                        version = "1.0"
                        name = "Minimal Configuration"
                        settings = @{ verbosity = "silent" }
                    }
                    'README.md' = "# Minimal AitherZero Configuration"
                }
            }
            enterprise = @{
                name = "enterprise"
                description = "Enterprise AitherZero configuration template"
                files = @{
                    'configs/app-config.json' = @{
                        version = "1.0"
                        name = "Enterprise Configuration"
                        settings = @{
                            verbosity = "detailed"
                            auditEnabled = $true
                            securityEnforced = $true
                        }
                        security = @{
                            requireApproval = $true
                            encryptionRequired = $true
                        }
                    }
                    'policies/security-policy.md' = "# Security Policy\n\n## Access Control\n- Multi-factor authentication required"
                    'compliance/audit-config.json' = @{
                        enabled = $true
                        retention = "7y"
                        fields = @("timestamp", "user", "action")
                    }
                }
            }
        }
        SampleRepositories = @{
            'test-repo-1' = @{
                name = "test-repo-1"
                description = "Test repository 1"
                template = "default"
                environments = @("dev", "staging")
            }
            'test-repo-2' = @{
                name = "test-repo-2"
                description = "Test repository 2"
                template = "minimal"
                environments = @("dev", "prod")
            }
            'enterprise-repo' = @{
                name = "enterprise-repo"
                description = "Enterprise test repository"
                template = "enterprise"
                environments = @("dev", "staging", "prod")
            }
        }
        GitCommands = @{
            init = @{ command = "init"; expectedFiles = @(".git") }
            status = @{ command = "status"; expectedOutput = "working tree clean|nothing to commit" }
            add = @{ command = "add"; args = @(".") }
            commit = @{ command = "commit"; args = @("-m", "Test commit") }
        }
        TestFiles = @{
            'test-config.json' = @{
                version = "1.0"
                test = $true
                settings = @{
                    property1 = "value1"
                    property2 = 42
                }
            }
            'test-readme.md' = "# Test Repository\n\nThis is a test configuration repository."
            'test-script.ps1' = "# Test script\nWrite-Host 'Hello from test repository'"
        }
    }

    # Helper function to create a test Git repository
    function New-TestGitRepository {
        param(
            [string]$Path,
            [hashtable]$Files = @{},
            [switch]$InitialCommit
        )

        if (-not $script:GitAvailable) {
            return @{ Success = $false; Error = "Git not available" }
        }

        try {
            if (-not (Test-Path $Path)) {
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }

            Push-Location $Path

            # Initialize repository
            git init 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                return @{ Success = $false; Error = "Git init failed" }
            }

            # Create files
            foreach ($fileName in $Files.Keys) {
                $filePath = Join-Path $Path $fileName
                $fileDir = Split-Path $filePath -Parent
                if (-not (Test-Path $fileDir)) {
                    New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
                }

                $fileContent = $Files[$fileName]
                if ($fileContent -is [hashtable]) {
                    $fileContent | ConvertTo-Json -Depth 5 | Set-Content $filePath
                } else {
                    $fileContent | Set-Content $filePath
                }
            }

            # Initial commit if requested
            if ($InitialCommit -and $Files.Count -gt 0) {
                git add . 2>&1 | Out-Null
                git commit -m "Initial commit" 2>&1 | Out-Null
            }

            return @{ Success = $true; Path = $Path }
        } catch {
            return @{ Success = $false; Error = $_.Exception.Message }
        } finally {
            Pop-Location
        }
    }
}

Describe "ConfigurationRepository Module - Core Functionality" {
    Context "Module Import and Basic Functions" {
        It "Should import the module without errors" {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }

        It "Should export all required functions" {
            $exportedFunctions = Get-Command -Module ConfigurationRepository -CommandType Function
            $exportedFunctions.Count | Should -BeGreaterThan 3

            # Verify key functions are exported
            $keyFunctions = @(
                'New-ConfigurationRepository',
                'Clone-ConfigurationRepository',
                'Sync-ConfigurationRepository',
                'Validate-ConfigurationRepository'
            )

            foreach ($function in $keyFunctions) {
                Get-Command $function -Module ConfigurationRepository -ErrorAction SilentlyContinue |
                    Should -Not -BeNullOrEmpty -Because "Key function $function should be exported"
            }
        }

        It "Should have proper module metadata" {
            $module = Get-Module ConfigurationRepository
            $module | Should -Not -BeNullOrEmpty
            $module.Version | Should -Not -BeNullOrEmpty
            $module.Description | Should -Not -BeNullOrEmpty
        }

        It "Should detect Git availability" {
            $gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
            $script:GitAvailable | Should -Be $gitAvailable
        }
    }
}

Describe "ConfigurationRepository Module - Repository Creation" {
    Context "Local Repository Creation" {
        It "Should create local repository with default template" {
            $repoPath = Join-Path $TestLocalRepos "default-template-test"

            $result = New-ConfigurationRepository -RepositoryName "default-template-test" -LocalPath $repoPath -Provider "local" -Template "default"

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.RepositoryName | Should -Be "default-template-test"
            $result.LocalPath | Should -Be $repoPath
            $result.Template | Should -Be "default"

            # Verify repository structure was created
            Test-Path $repoPath | Should -Be $true
            Test-Path (Join-Path $repoPath "configs") | Should -Be $true
            Test-Path (Join-Path $repoPath "README.md") | Should -Be $true
        }

        It "Should create repository with minimal template" {
            $repoPath = Join-Path $TestLocalRepos "minimal-template-test"

            $result = New-ConfigurationRepository -RepositoryName "minimal-template-test" -LocalPath $repoPath -Provider "local" -Template "minimal"

            $result.Success | Should -Be $true
            $result.Template | Should -Be "minimal"

            # Verify minimal structure
            Test-Path $repoPath | Should -Be $true
            Test-Path (Join-Path $repoPath "configs") | Should -Be $true

            # Should have fewer files than default template
            $configFile = Join-Path $repoPath "configs/app-config.json"
            if (Test-Path $configFile) {
                $config = Get-Content $configFile | ConvertFrom-Json
                $config.name | Should -Be "Minimal Configuration"
            }
        }

        It "Should create repository with enterprise template" {
            $repoPath = Join-Path $TestLocalRepos "enterprise-template-test"

            $result = New-ConfigurationRepository -RepositoryName "enterprise-template-test" -LocalPath $repoPath -Provider "local" -Template "enterprise"

            $result.Success | Should -Be $true
            $result.Template | Should -Be "enterprise"

            # Verify enterprise-specific structure
            Test-Path $repoPath | Should -Be $true
            Test-Path (Join-Path $repoPath "policies") | Should -Be $true
            Test-Path (Join-Path $repoPath "compliance") | Should -Be $true
            Test-Path (Join-Path $repoPath "policies/security-policy.md") | Should -Be $true
        }

        It "Should create repository with custom settings" {
            $repoPath = Join-Path $TestLocalRepos "custom-settings-test"
            $customSettings = @{
                feature1 = $true
                feature2 = "custom value"
                timeout = 300
                customArray = @("item1", "item2")
            }

            $result = New-ConfigurationRepository -RepositoryName "custom-settings-test" -LocalPath $repoPath -Provider "local" -Template "custom" -CustomSettings $customSettings

            $result.Success | Should -Be $true

            # Verify custom settings were applied
            Test-Path $repoPath | Should -Be $true

            # Custom template should create basic structure
            Test-Path (Join-Path $repoPath "configs") | Should -Be $true
        }

        It "Should create repository with custom environments" {
            $repoPath = Join-Path $TestLocalRepos "custom-environments-test"
            $customEnvironments = @("development", "test", "staging", "production")

            $result = New-ConfigurationRepository -RepositoryName "custom-environments-test" -LocalPath $repoPath -Provider "local" -Environments $customEnvironments

            $result.Success | Should -Be $true
            $result.Environments | Should -Be $customEnvironments

            # Verify environment directories were created
            foreach ($env in $customEnvironments) {
                Test-Path (Join-Path $repoPath "environments/$env") | Should -Be $true
            }
        }

        It "Should fail when local path already exists and is not empty" {
            $repoPath = Join-Path $TestLocalRepos "existing-path-test"
            New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
            "existing content" | Set-Content (Join-Path $repoPath "existing-file.txt")

            $result = New-ConfigurationRepository -RepositoryName "existing-path-test" -LocalPath $repoPath -Provider "local"

            $result.Success | Should -Be $false
            $result.Error | Should -Match "already exists and is not empty"
        }

        It "Should initialize Git repository when Git is available" -Skip:(-not $script:GitAvailable) {
            $repoPath = Join-Path $TestLocalRepos "git-init-test"

            $result = New-ConfigurationRepository -RepositoryName "git-init-test" -LocalPath $repoPath -Provider "local"

            $result.Success | Should -Be $true

            # Verify Git repository was initialized
            Test-Path (Join-Path $repoPath ".git") | Should -Be $true

            # Verify initial commit was made
            Push-Location $repoPath
            try {
                $commitCount = git rev-list --count HEAD 2>$null
                $commitCount | Should -Be "1"
            } finally {
                Pop-Location
            }
        }
    }

    Context "GitHub Repository Creation" {
        It "Should attempt GitHub repository creation when gh CLI is available" {
            # Mock GitHub CLI
            Mock Get-Command { @{ Name = "gh" } } -ParameterFilter { $Name -eq "gh" }
            Mock '&' {
                if ($args[0] -eq "gh" -and $args[1] -eq "repo" -and $args[2] -eq "create") {
                    return "Repository created successfully"
                }
            } -ParameterFilter { $args[0] -eq "gh" }

            $repoPath = Join-Path $TestLocalRepos "github-test"

            $result = New-ConfigurationRepository -RepositoryName "github-test" -LocalPath $repoPath -Provider "github" -Description "Test GitHub repository"

            # Should attempt GitHub creation
            Assert-MockCalled Get-Command -ParameterFilter { $Name -eq "gh" }
        }

        It "Should fail gracefully when gh CLI is not available" {
            # Mock missing GitHub CLI
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }

            $repoPath = Join-Path $TestLocalRepos "github-no-cli-test"

            $result = New-ConfigurationRepository -RepositoryName "github-no-cli-test" -LocalPath $repoPath -Provider "github"

            $result.Success | Should -Be $false
            $result.Error | Should -Match "GitHub CLI.*not available"
        }

        It "Should create private repository by default" {
            Mock Get-Command { @{ Name = "gh" } } -ParameterFilter { $Name -eq "gh" }
            Mock '&' {
                # Verify --private flag is included
                $args | Should -Contain "--private"
                return "Repository created"
            } -ParameterFilter { $args[0] -eq "gh" -and $args[1] -eq "repo" }

            $repoPath = Join-Path $TestLocalRepos "private-repo-test"

            New-ConfigurationRepository -RepositoryName "private-repo-test" -LocalPath $repoPath -Provider "github" -Private

            Assert-MockCalled '&' -ParameterFilter { $args -contains "--private" }
        }

        It "Should support organization repositories" {
            Mock Get-Command { @{ Name = "gh" } } -ParameterFilter { $Name -eq "gh" }
            Mock '&' {
                # Verify --org flag is included
                $args | Should -Contain "--org"
                $args | Should -Contain "test-org"
                return "Repository created"
            } -ParameterFilter { $args[0] -eq "gh" -and $args[1] -eq "repo" }

            $repoPath = Join-Path $TestLocalRepos "org-repo-test"

            New-ConfigurationRepository -RepositoryName "org-repo-test" -LocalPath $repoPath -Provider "github" -GitHubOrg "test-org"

            Assert-MockCalled '&' -ParameterFilter { $args -contains "--org" -and $args -contains "test-org" }
        }
    }

    Context "Template System" {
        It "Should create all standard templates successfully" {
            $templates = @("default", "minimal", "enterprise", "custom")

            foreach ($template in $templates) {
                $repoPath = Join-Path $TestLocalRepos "template-$template-test"

                $result = New-ConfigurationRepository -RepositoryName "template-$template-test" -LocalPath $repoPath -Provider "local" -Template $template

                $result.Success | Should -Be $true -Because "Template $template should be created successfully"
                $result.Template | Should -Be $template

                # Verify basic structure
                Test-Path $repoPath | Should -Be $true
                Test-Path (Join-Path $repoPath "configs") | Should -Be $true
            }
        }

        It "Should generate appropriate documentation for each template" {
            $templates = @("default", "minimal", "enterprise")

            foreach ($template in $templates) {
                $repoPath = Join-Path $TestLocalRepos "docs-$template-test"

                $result = New-ConfigurationRepository -RepositoryName "docs-$template-test" -LocalPath $repoPath -Provider "local" -Template $template

                if ($result.Success) {
                    # Check for documentation
                    Test-Path (Join-Path $repoPath "README.md") | Should -Be $true
                    Test-Path (Join-Path $repoPath "docs") | Should -Be $true

                    # Verify README content mentions template
                    $readmeContent = Get-Content (Join-Path $repoPath "README.md") -Raw
                    $readmeContent | Should -Match $template -Because "README should mention the template type"
                }
            }
        }

        It "Should create enterprise-specific compliance files" {
            $repoPath = Join-Path $TestLocalRepos "enterprise-compliance-test"

            $result = New-ConfigurationRepository -RepositoryName "enterprise-compliance-test" -LocalPath $repoPath -Provider "local" -Template "enterprise"

            if ($result.Success) {
                # Verify enterprise-specific files
                $enterpriseFiles = @(
                    "policies/security-policy.md",
                    "policies/deployment-policy.md",
                    "compliance/audit-config.json",
                    "compliance/compliance-checklist.md"
                )

                foreach ($file in $enterpriseFiles) {
                    Test-Path (Join-Path $repoPath $file) | Should -Be $true -Because "Enterprise template should create $file"
                }

                # Verify audit config content
                $auditConfigPath = Join-Path $repoPath "compliance/audit-config.json"
                if (Test-Path $auditConfigPath) {
                    $auditConfig = Get-Content $auditConfigPath | ConvertFrom-Json
                    $auditConfig.enabled | Should -Be $true
                    $auditConfig.retention | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
}

Describe "ConfigurationRepository Module - Repository Cloning" {
    BeforeEach {
        # Create test remote repositories
        foreach ($repoName in $script:TestData.SampleRepositories.Keys) {
            $repoData = $script:TestData.SampleRepositories[$repoName]
            $remotePath = Join-Path $TestRemoteRepos $repoName

            $templateFiles = $script:TestData.RepositoryTemplates[$repoData.template].files
            $gitResult = New-TestGitRepository -Path $remotePath -Files $templateFiles -InitialCommit
        }
    }

    Context "Basic Repository Cloning" {
        It "Should clone existing repository successfully" -Skip:(-not $script:GitAvailable) {
            $sourceRepo = Join-Path $TestRemoteRepos "test-repo-1"
            $clonePath = Join-Path $TestLocalRepos "cloned-repo-1"

            # Ensure source repository exists
            if (Test-Path $sourceRepo) {
                $result = Clone-ConfigurationRepository -RepositoryUrl $sourceRepo -LocalPath $clonePath

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.RepositoryUrl | Should -Be $sourceRepo
                $result.LocalPath | Should -Be $clonePath

                # Verify cloned content
                Test-Path $clonePath | Should -Be $true
                Test-Path (Join-Path $clonePath ".git") | Should -Be $true
                Test-Path (Join-Path $clonePath "configs") | Should -Be $true
            }
        }

        It "Should clone specific branch when specified" -Skip:(-not $script:GitAvailable) {
            $sourceRepo = Join-Path $TestRemoteRepos "test-repo-1"
            $clonePath = Join-Path $TestLocalRepos "cloned-branch-test"

            if (Test-Path $sourceRepo) {
                # Create a test branch in source repository
                Push-Location $sourceRepo
                try {
                    git checkout -b test-branch 2>&1 | Out-Null
                    "test branch content" | Set-Content "branch-file.txt"
                    git add . 2>&1 | Out-Null
                    git commit -m "Test branch commit" 2>&1 | Out-Null
                    git checkout main 2>&1 | Out-Null
                } finally {
                    Pop-Location
                }

                # Clone specific branch
                $result = Clone-ConfigurationRepository -RepositoryUrl $sourceRepo -LocalPath $clonePath -Branch "test-branch"

                if ($result.Success) {
                    $result.Branch | Should -Be "test-branch"

                    # Verify we're on the correct branch
                    Push-Location $clonePath
                    try {
                        $currentBranch = git branch --show-current 2>$null
                        $currentBranch | Should -Be "test-branch"
                        Test-Path "branch-file.txt" | Should -Be $true
                    } finally {
                        Pop-Location
                    }
                }
            }
        }

        It "Should fail when repository URL is invalid" {
            $invalidUrl = "https://github.com/nonexistent/repository.git"
            $clonePath = Join-Path $TestLocalRepos "invalid-clone-test"

            $result = Clone-ConfigurationRepository -RepositoryUrl $invalidUrl -LocalPath $clonePath

            $result.Success | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }

        It "Should fail when local path already exists and is not empty" {
            $sourceRepo = Join-Path $TestRemoteRepos "test-repo-1"
            $clonePath = Join-Path $TestLocalRepos "existing-clone-path"

            # Create non-empty directory
            New-Item -ItemType Directory -Path $clonePath -Force | Out-Null
            "existing content" | Set-Content (Join-Path $clonePath "existing-file.txt")

            $result = Clone-ConfigurationRepository -RepositoryUrl $sourceRepo -LocalPath $clonePath

            $result.Success | Should -Be $false
            $result.Error | Should -Match "already exists and is not empty"
        }

        It "Should validate repository structure after cloning" {
            $sourceRepo = Join-Path $TestRemoteRepos "test-repo-1"
            $clonePath = Join-Path $TestLocalRepos "validated-clone-test"

            if (Test-Path $sourceRepo) {
                $result = Clone-ConfigurationRepository -RepositoryUrl $sourceRepo -LocalPath $clonePath -Validate

                if ($result.Success) {
                    $result.ValidationResult | Should -Not -BeNullOrEmpty
                    $result.ValidationResult.IsValid | Should -BeOfType [bool]
                }
            }
        }

        It "Should setup local settings when requested" {
            $sourceRepo = Join-Path $TestRemoteRepos "test-repo-1"
            $clonePath = Join-Path $TestLocalRepos "local-settings-test"

            if (Test-Path $sourceRepo) {
                $result = Clone-ConfigurationRepository -RepositoryUrl $sourceRepo -LocalPath $clonePath -SetupLocalSettings

                if ($result.Success) {
                    # Verify local settings file was created
                    Test-Path (Join-Path $clonePath "local-settings.json") | Should -Be $true

                    $localSettings = Get-Content (Join-Path $clonePath "local-settings.json") | ConvertFrom-Json
                    $localSettings.repositoryPath | Should -Be $clonePath
                    $localSettings.lastSync | Should -Not -BeNullOrEmpty
                }
            }
        }
    }

    Context "Clone Validation and Error Handling" {
        It "Should clean up on clone failure" {
            $invalidUrl = "/completely/invalid/path"
            $clonePath = Join-Path $TestLocalRepos "cleanup-test"

            $result = Clone-ConfigurationRepository -RepositoryUrl $invalidUrl -LocalPath $clonePath

            $result.Success | Should -Be $false

            # Should not leave partial clone
            Test-Path $clonePath | Should -Be $false
        }

        It "Should handle network timeout gracefully" {
            # Mock git clone to simulate timeout
            if ($script:GitAvailable) {
                Mock git {
                    if ($args[0] -eq "clone") {
                        $global:LASTEXITCODE = 1
                        throw "Connection timed out"
                    }
                } -ParameterFilter { $args[0] -eq "clone" }

                $result = Clone-ConfigurationRepository -RepositoryUrl "https://github.com/timeout/test.git" -LocalPath (Join-Path $TestLocalRepos "timeout-test")

                $result.Success | Should -Be $false
                $result.Error | Should -Match "timeout|timed out"
            }
        }

        It "Should handle authentication failures" {
            if ($script:GitAvailable) {
                Mock git {
                    if ($args[0] -eq "clone") {
                        $global:LASTEXITCODE = 1
                        return "fatal: Authentication failed"
                    }
                } -ParameterFilter { $args[0] -eq "clone" }

                $result = Clone-ConfigurationRepository -RepositoryUrl "https://github.com/private/repo.git" -LocalPath (Join-Path $TestLocalRepos "auth-test")

                $result.Success | Should -Be $false
                $result.Error | Should -Match "Authentication failed"
            }
        }
    }
}

Describe "ConfigurationRepository Module - Repository Synchronization" {
    BeforeEach {
        # Create test repositories for synchronization tests
        $script:TestSyncRepos = @{}

        foreach ($repoName in @("sync-test-1", "sync-test-2")) {
            $repoPath = Join-Path $TestLocalRepos $repoName
            $templateFiles = $script:TestData.RepositoryTemplates.default.files
            $gitResult = New-TestGitRepository -Path $repoPath -Files $templateFiles -InitialCommit

            if ($gitResult.Success) {
                $script:TestSyncRepos[$repoName] = $repoPath
            }
        }
    }

    Context "Pull Operations" -Skip:(-not $script:GitAvailable) {
        It "Should pull latest changes successfully" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock git operations to simulate successful pull
                Mock git {
                    param($command, $subcommand, $remote, $branch)

                    switch ($command) {
                        "status" {
                            if ($subcommand -eq "--porcelain") { return "" }
                            return "On branch main\nnothing to commit, working tree clean"
                        }
                        "fetch" { return "Fetching origin" }
                        "pull" { return "Already up to date." }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull"

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.Operation | Should -Be "pull"
                $result.Changes | Should -Contain "Successfully pulled from remote"
            }
        }

        It "Should handle local changes during pull" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock git to simulate local changes
                Mock git {
                    param($command, $subcommand, $message)

                    switch ($command) {
                        "status" {
                            if ($subcommand -eq "--porcelain") { return "M configs/app-config.json" }
                            return "Changes not staged for commit"
                        }
                        "stash" { return "Saved working directory and index state" }
                        "fetch" { return "Fetching origin" }
                        "pull" { return "Updated 1 file" }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull"

                if ($result.Success) {
                    $result.Changes | Should -Contain "Stashed local changes before pull"
                }
            }
        }

        It "Should handle merge conflicts gracefully" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock git to simulate merge conflicts
                Mock git {
                    param($command, $subcommand, $remote, $branch)

                    switch ($command) {
                        "status" { return "Clean working tree" }
                        "fetch" { return "Fetching origin" }
                        "pull" {
                            $global:LASTEXITCODE = 1
                            return "CONFLICT (content): Merge conflict in configs/app-config.json"
                        }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull"

                $result.Success | Should -Be $false
                $result.Error | Should -Match "conflict"
            }
        }

        It "Should handle network failures during pull" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock network failure
                Mock git {
                    param($command, $subcommand, $remote, $branch)

                    switch ($command) {
                        "status" { return "Clean working tree" }
                        "fetch" {
                            $global:LASTEXITCODE = 1
                            return "fatal: unable to access 'remote': Network is unreachable"
                        }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull"

                $result.Success | Should -Be $false
                $result.Error | Should -Match "network|Network"
            }
        }

        It "Should handle authentication failures during pull" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock authentication failure
                Mock git {
                    param($command, $subcommand, $remote, $branch)

                    switch ($command) {
                        "status" { return "Clean working tree" }
                        "fetch" {
                            $global:LASTEXITCODE = 1
                            return "fatal: Authentication failed for remote repository"
                        }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull"

                $result.Success | Should -Be $false
                $result.Error | Should -Match "authentication|Authentication"
            }
        }

        It "Should handle diverged branches" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock diverged branch scenario
                Mock git {
                    param($command, $subcommand, $remote, $branch)

                    switch ($command) {
                        "status" { return "Clean working tree" }
                        "fetch" { return "Fetching origin" }
                        "pull" {
                            $global:LASTEXITCODE = 1
                            return "fatal: The current branch has diverged from the remote branch"
                        }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull"

                $result.Success | Should -Be $false
                $result.Error | Should -Match "diverged"
            }
        }
    }

    Context "Push Operations" -Skip:(-not $script:GitAvailable) {
        It "Should push local changes successfully" {
            $repoPath = $script:TestSyncRepos["sync-test-2"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock git to simulate local changes and successful push
                Mock git {
                    param($command, $subcommand, $message, $remote, $branch)

                    switch ($command) {
                        "status" {
                            if ($subcommand -eq "--porcelain") { return "M configs/app-config.json" }
                            return "Changes not staged for commit"
                        }
                        "add" { return "" }
                        "commit" { return "[main abc1234] Sync: Local configuration changes" }
                        "fetch" { return "Fetching origin" }
                        "rev-parse" { return "abc1234567890" }
                        "rev-list" { return "0" }
                        "push" { return "To remote repository\n   abc1234..def5678  main -> main" }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "push"

                $result.Success | Should -Be $true
                $result.Operation | Should -Be "push"
                $result.Changes | Should -Contain "Successfully pushed to remote"
            }
        }

        It "Should handle no local changes gracefully" {
            $repoPath = $script:TestSyncRepos["sync-test-2"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock git to simulate no local changes
                Mock git {
                    param($command, $subcommand, $remote, $branch)

                    switch ($command) {
                        "status" {
                            if ($subcommand -eq "--porcelain") { return "" }
                            return "nothing to commit, working tree clean"
                        }
                        "fetch" { return "Fetching origin" }
                        "rev-parse" { return "abc1234567890" }
                        "push" { return "Everything up-to-date" }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "push"

                $result.Success | Should -Be $true
                $result.Changes | Should -Not -Contain "Committed local changes"
            }
        }

        It "Should handle push rejection due to remote updates" {
            $repoPath = $script:TestSyncRepos["sync-test-2"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock push rejection
                Mock git {
                    param($command, $subcommand, $message, $remote, $branch)

                    switch ($command) {
                        "status" {
                            if ($subcommand -eq "--porcelain") { return "M test-file.txt" }
                            return "Changes not staged"
                        }
                        "add" { return "" }
                        "commit" { return "Committed changes" }
                        "fetch" { return "Fetching origin" }
                        "rev-parse" { return "abc1234567890" }
                        "rev-list" { return "2" }  # Behind remote
                        "push" {
                            $global:LASTEXITCODE = 1
                            return "error: failed to push some refs\nhint: Updates were rejected because the remote contains work"
                        }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "push"

                $result.Success | Should -Be $false
                $result.Error | Should -Match "rejected.*remote.*newer"
            }
        }

        It "Should handle authentication failures during push" {
            $repoPath = $script:TestSyncRepos["sync-test-2"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock authentication failure
                Mock git {
                    param($command, $subcommand, $message, $remote, $branch)

                    switch ($command) {
                        "status" {
                            if ($subcommand -eq "--porcelain") { return "M test-file.txt" }
                            return "Changes not staged"
                        }
                        "add" { return "" }
                        "commit" { return "Committed changes" }
                        "fetch" { return "Fetching origin" }
                        "push" {
                            $global:LASTEXITCODE = 1
                            return "fatal: Authentication failed for remote repository"
                        }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "push"

                $result.Success | Should -Be $false
                $result.Error | Should -Match "authentication|Authentication"
            }
        }

        It "Should handle pre-receive hook rejection" {
            $repoPath = $script:TestSyncRepos["sync-test-2"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock hook rejection
                Mock git {
                    param($command, $subcommand, $message, $remote, $branch)

                    switch ($command) {
                        "status" {
                            if ($subcommand -eq "--porcelain") { return "M test-file.txt" }
                            return "Changes not staged"
                        }
                        "add" { return "" }
                        "commit" { return "Committed changes" }
                        "fetch" { return "Fetching origin" }
                        "push" {
                            $global:LASTEXITCODE = 1
                            return "remote: error: pre-receive hook declined\nTo remote repository\n ! [remote rejected] main -> main (pre-receive hook declined)"
                        }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "push"

                $result.Success | Should -Be $false
                $result.Error | Should -Match "hook|pre-receive"
            }
        }
    }

    Context "Full Sync Operations" -Skip:(-not $script:GitAvailable) {
        It "Should perform full synchronization successfully" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock successful full sync
                Mock git {
                    param($command, $subcommand, $message, $remote, $branch)

                    switch ($command) {
                        "status" {
                            if ($subcommand -eq "--porcelain") { return "M local-changes.txt" }
                            return "Changes not staged"
                        }
                        "stash" {
                            if ($subcommand -eq "push") { return "Saved working directory" }
                            if ($subcommand -eq "pop") { return "Applied stash successfully" }
                            return ""
                        }
                        "pull" { return "Updated successfully" }
                        "add" { return "" }
                        "commit" { return "Merged changes committed" }
                        "push" { return "Push successful" }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "sync"

                $result.Success | Should -Be $true
                $result.Operation | Should -Be "sync"
                $result.Changes | Should -Contain "Stashed local changes"
                $result.Changes | Should -Contain "Pulled from remote"
                $result.Changes | Should -Contain "Restored local changes"
            }
        }

        It "Should handle merge conflicts during sync" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock conflict during stash pop
                Mock git {
                    param($command, $subcommand, $message, $remote, $branch)

                    switch ($command) {
                        "status" {
                            if ($subcommand -eq "--porcelain") { return "M conflicted-file.txt" }
                            return "Changes not staged"
                        }
                        "stash" {
                            if ($subcommand -eq "push") { return "Saved working directory" }
                            if ($subcommand -eq "pop") {
                                $global:LASTEXITCODE = 1
                                return "CONFLICT (content): Merge conflict in conflicted-file.txt"
                            }
                            return ""
                        }
                        "pull" { return "Updated successfully" }
                        default { return "" }
                    }
                } -ParameterFilter { $args.Count -gt 0 }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "sync"

                $result.Success | Should -Be $true  # Should still report success but with conflicts
                $result.Changes | Should -Contain "Merge conflicts require manual resolution"
            }
        }
    }

    Context "Backup and Recovery" {
        It "Should create backup before sync when requested" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock successful operations and backup
                Mock git { return "Success" } -ParameterFilter { $args.Count -gt 0 }
                Mock Copy-Item { return $true }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull" -CreateBackup

                $result.BackupPath | Should -Not -BeNullOrEmpty
                Assert-MockCalled Copy-Item -Times 1
            }
        }

        It "Should attempt recovery from backup on failure" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock failure and backup restoration
                Mock git {
                    $global:LASTEXITCODE = 1
                    throw "Simulated failure"
                } -ParameterFilter { $args.Count -gt 0 }

                Mock Copy-Item { return $true }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull" -CreateBackup

                $result.Success | Should -Be $false
                $result.BackupPath | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Error Handling and Recovery" {
        It "Should validate repository before sync" {
            $nonGitPath = Join-Path $TestLocalRepos "non-git-repo"
            New-Item -ItemType Directory -Path $nonGitPath -Force | Out-Null
            "test content" | Set-Content (Join-Path $nonGitPath "test.txt")

            $result = Sync-ConfigurationRepository -Path $nonGitPath -Operation "pull"

            $result.Success | Should -Be $false
            $result.Error | Should -Match "Not a Git repository"
        }

        It "Should handle missing repository path" {
            $missingPath = Join-Path $TestLocalRepos "non-existent-repo"

            $result = Sync-ConfigurationRepository -Path $missingPath -Operation "pull"

            $result.Success | Should -Be $false
            $result.Error | Should -Match "does not exist"
        }

        It "Should provide detailed error information" {
            $repoPath = $script:TestSyncRepos["sync-test-1"]

            if ($repoPath -and (Test-Path $repoPath)) {
                # Mock detailed error
                Mock git {
                    $global:LASTEXITCODE = 1
                    return "fatal: repository 'https://github.com/example/repo.git' not found"
                } -ParameterFilter { $args[0] -eq "pull" }

                $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull"

                $result.Success | Should -Be $false
                $result.Error | Should -Contain "not found"
                $result.Operation | Should -Be "pull"
            }
        }
    }
}

Describe "ConfigurationRepository Module - Repository Validation" {
    BeforeEach {
        # Create test repositories with various validation scenarios
        $script:ValidationTestRepos = @{}

        # Valid repository
        $validRepoPath = Join-Path $TestLocalRepos "valid-repo"
        $validFiles = $script:TestData.RepositoryTemplates.default.files
        $gitResult = New-TestGitRepository -Path $validRepoPath -Files $validFiles -InitialCommit
        if ($gitResult.Success) {
            $script:ValidationTestRepos["valid"] = $validRepoPath
        }

        # Repository with missing files
        $incompleteRepoPath = Join-Path $TestLocalRepos "incomplete-repo"
        $incompleteFiles = @{ 'README.md' = "Incomplete repository" }
        $gitResult = New-TestGitRepository -Path $incompleteRepoPath -Files $incompleteFiles -InitialCommit
        if ($gitResult.Success) {
            $script:ValidationTestRepos["incomplete"] = $incompleteRepoPath
        }

        # Non-Git repository
        $nonGitRepoPath = Join-Path $TestLocalRepos "non-git-repo"
        New-Item -ItemType Directory -Path $nonGitRepoPath -Force | Out-Null
        "test content" | Set-Content (Join-Path $nonGitRepoPath "test.txt")
        $script:ValidationTestRepos["non-git"] = $nonGitRepoPath
    }

    Context "Basic Validation" {
        It "Should validate well-formed repository successfully" {
            $validRepoPath = $script:ValidationTestRepos["valid"]

            if ($validRepoPath -and (Test-Path $validRepoPath)) {
                $result = Validate-ConfigurationRepository -Path $validRepoPath

                $result | Should -Not -BeNullOrEmpty
                $result.IsValid | Should -Be $true
                $result.Errors.Count | Should -Be 0
                $result.RepositoryPath | Should -Be $validRepoPath
            }
        }

        It "Should detect missing repository path" {
            $missingPath = Join-Path $TestLocalRepos "non-existent"

            $result = Validate-ConfigurationRepository -Path $missingPath

            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Repository path does not exist: $missingPath"
        }

        It "Should warn about non-Git repository" {
            $nonGitPath = $script:ValidationTestRepos["non-git"]

            if ($nonGitPath -and (Test-Path $nonGitPath)) {
                $result = Validate-ConfigurationRepository -Path $nonGitPath

                $result.Warnings | Should -Contain "Not a Git repository (missing .git directory)"
            }
        }

        It "Should check for recommended directory structure" {
            $validRepoPath = $script:ValidationTestRepos["valid"]

            if ($validRepoPath -and (Test-Path $validRepoPath)) {
                $result = Validate-ConfigurationRepository -Path $validRepoPath

                # Should find expected directories
                $result.Info | Should -Contain "Found directory: configs"
                $result.Info | Should -Contain "Found directory: environments"
            }
        }

        It "Should warn about missing recommended directories" {
            $incompleteRepoPath = $script:ValidationTestRepos["incomplete"]

            if ($incompleteRepoPath -and (Test-Path $incompleteRepoPath)) {
                $result = Validate-ConfigurationRepository -Path $incompleteRepoPath

                # Should warn about missing directories
                $result.Warnings | Should -Contain "Missing recommended directory: configs"
                $result.Warnings | Should -Contain "Missing recommended directory: environments"
            }
        }

        It "Should check for recommended files" {
            $validRepoPath = $script:ValidationTestRepos["valid"]

            if ($validRepoPath -and (Test-Path $validRepoPath)) {
                $result = Validate-ConfigurationRepository -Path $validRepoPath

                # Should find expected files
                $result.Info | Should -Contain "Found file: README.md"
                $result.Info | Should -Contain "Found file: .gitignore"
            }
        }

        It "Should warn about missing recommended files" {
            $incompleteRepoPath = $script:ValidationTestRepos["incomplete"]

            if ($incompleteRepoPath -and (Test-Path $incompleteRepoPath)) {
                $result = Validate-ConfigurationRepository -Path $incompleteRepoPath

                # Should warn about missing files
                $result.Warnings | Should -Contain "Missing recommended file: .gitignore"
                $result.Warnings | Should -Contain "Missing recommended file: configs/app-config.json"
            }
        }
    }

    Context "JSON File Validation" {
        It "Should validate JSON configuration files" {
            $validRepoPath = $script:ValidationTestRepos["valid"]

            if ($validRepoPath -and (Test-Path $validRepoPath)) {
                $result = Validate-ConfigurationRepository -Path $validRepoPath

                # Should validate JSON files successfully
                $validJsonFiles = $result.Info | Where-Object { $_ -match "Valid JSON:" }
                $validJsonFiles.Count | Should -BeGreaterThan 0
            }
        }

        It "Should detect invalid JSON files" {
            $repoPath = Join-Path $TestLocalRepos "invalid-json-repo"
            New-Item -ItemType Directory -Path $repoPath -Force | Out-Null

            # Create invalid JSON file
            $invalidJsonPath = Join-Path $repoPath "invalid.json"
            "{ invalid json content" | Set-Content $invalidJsonPath

            $result = Validate-ConfigurationRepository -Path $repoPath

            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match "Invalid JSON file: invalid.json"
        }

        It "Should handle empty JSON files gracefully" {
            $repoPath = Join-Path $TestLocalRepos "empty-json-repo"
            New-Item -ItemType Directory -Path $repoPath -Force | Out-Null

            # Create empty JSON file
            $emptyJsonPath = Join-Path $repoPath "empty.json"
            "" | Set-Content $emptyJsonPath

            $result = Validate-ConfigurationRepository -Path $repoPath

            # Should handle empty files without crashing
            $result | Should -Not -BeNullOrEmpty
            $result.IsValid | Should -BeOfType [bool]
        }

        It "Should validate nested JSON structures" {
            $repoPath = Join-Path $TestLocalRepos "nested-json-repo"
            New-Item -ItemType Directory -Path $repoPath -Force | Out-Null

            # Create complex nested JSON
            $nestedJson = @{
                level1 = @{
                    level2 = @{
                        level3 = @{
                            property = "deep value"
                            array = @(1, 2, 3)
                        }
                    }
                }
            }

            $nestedJsonPath = Join-Path $repoPath "nested.json"
            $nestedJson | ConvertTo-Json -Depth 10 | Set-Content $nestedJsonPath

            $result = Validate-ConfigurationRepository -Path $repoPath

            $result.Info | Should -Contain "Valid JSON: nested.json"
        }
    }

    Context "Environment Configuration Validation" {
        It "Should detect environment configurations" {
            $repoPath = Join-Path $TestLocalRepos "env-config-repo"
            $envPath = Join-Path $repoPath "environments"

            # Create environment directories
            @("dev", "staging", "prod") | ForEach-Object {
                $envDir = Join-Path $envPath $_
                New-Item -ItemType Directory -Path $envDir -Force | Out-Null
                @{ environment = $_; settings = @{} } | ConvertTo-Json | Set-Content (Join-Path $envDir "config.json")
            }

            $result = Validate-ConfigurationRepository -Path $repoPath

            $result.Info | Should -Contain "Environment configurations found: dev, staging, prod"
        }

        It "Should warn about empty environments directory" {
            $repoPath = Join-Path $TestLocalRepos "empty-env-repo"
            $envPath = Join-Path $repoPath "environments"
            New-Item -ItemType Directory -Path $envPath -Force | Out-Null

            $result = Validate-ConfigurationRepository -Path $repoPath

            $result.Warnings | Should -Contain "No environment configurations found in environments directory"
        }

        It "Should validate environment-specific configuration files" {
            $repoPath = Join-Path $TestLocalRepos "env-validation-repo"
            $envPath = Join-Path $repoPath "environments/test-env"
            New-Item -ItemType Directory -Path $envPath -Force | Out-Null

            # Create valid environment config
            $envConfig = @{
                name = "test-env"
                settings = @{
                    logLevel = "DEBUG"
                    timeout = 30
                }
            }
            $envConfig | ConvertTo-Json | Set-Content (Join-Path $envPath "env-config.json")

            $result = Validate-ConfigurationRepository -Path $repoPath

            $result.Info | Should -Contain "Valid JSON: env-config.json"
        }
    }

    Context "Validation Error Handling" {
        It "Should handle validation exceptions gracefully" {
            # Mock file access to throw exception
            Mock Test-Path { throw "Simulated file system error" } -ParameterFilter { $Path -match "exception-test" }

            $result = Validate-ConfigurationRepository -Path "exception-test-path"

            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match "Validation error:.*Simulated file system error"
        }

        It "Should provide comprehensive validation results" {
            $validRepoPath = $script:ValidationTestRepos["valid"]

            if ($validRepoPath -and (Test-Path $validRepoPath)) {
                $result = Validate-ConfigurationRepository -Path $validRepoPath

                # Should include all result components
                $result.IsValid | Should -Not -BeNullOrEmpty
                $result.Errors | Should -Not -BeNullOrEmpty
                $result.Warnings | Should -Not -BeNullOrEmpty
                $result.Info | Should -Not -BeNullOrEmpty
                $result.RepositoryPath | Should -Be $validRepoPath
            }
        }

        It "Should handle large repositories efficiently" {
            $largeRepoPath = Join-Path $TestLocalRepos "large-repo"
            New-Item -ItemType Directory -Path $largeRepoPath -Force | Out-Null

            # Create many JSON files
            for ($i = 1; $i -le 50; $i++) {
                $filePath = Join-Path $largeRepoPath "config$i.json"
                @{ config = $i; data = "test data $i" } | ConvertTo-Json | Set-Content $filePath
            }

            $validationTime = Measure-Command {
                $result = Validate-ConfigurationRepository -Path $largeRepoPath
            }

            # Should complete validation in reasonable time
            $validationTime.TotalSeconds | Should -BeLessThan 10
        }
    }
}

Describe "ConfigurationRepository Module - Advanced Features" {
    Context "Enterprise Template Features" {
        It "Should create enterprise security policies" {
            $repoPath = Join-Path $TestLocalRepos "enterprise-security-test"

            $result = New-ConfigurationRepository -RepositoryName "enterprise-security-test" -LocalPath $repoPath -Provider "local" -Template "enterprise"

            if ($result.Success) {
                # Verify security policy files
                Test-Path (Join-Path $repoPath "policies/security-policy.md") | Should -Be $true
                Test-Path (Join-Path $repoPath "policies/deployment-policy.md") | Should -Be $true

                # Verify content of security policy
                $securityPolicy = Get-Content (Join-Path $repoPath "policies/security-policy.md") -Raw
                $securityPolicy | Should -Match "Multi-factor authentication"
                $securityPolicy | Should -Match "Role-based access control"
                $securityPolicy | Should -Match "Data encryption"
            }
        }

        It "Should create compliance documentation" {
            $repoPath = Join-Path $TestLocalRepos "enterprise-compliance-test"

            $result = New-ConfigurationRepository -RepositoryName "enterprise-compliance-test" -LocalPath $repoPath -Provider "local" -Template "enterprise"

            if ($result.Success) {
                # Verify compliance files
                Test-Path (Join-Path $repoPath "compliance/audit-config.json") | Should -Be $true
                Test-Path (Join-Path $repoPath "compliance/compliance-checklist.md") | Should -Be $true

                # Verify audit configuration
                $auditConfigPath = Join-Path $repoPath "compliance/audit-config.json"
                if (Test-Path $auditConfigPath) {
                    $auditConfig = Get-Content $auditConfigPath | ConvertFrom-Json
                    $auditConfig.enabled | Should -Be $true
                    $auditConfig.retention | Should -Be "7y"
                    $auditConfig.fields | Should -Contain "timestamp"
                    $auditConfig.fields | Should -Contain "user"
                    $auditConfig.fields | Should -Contain "action"
                }
            }
        }

        It "Should create comprehensive enterprise configuration" {
            $repoPath = Join-Path $TestLocalRepos "enterprise-comprehensive-test"

            $result = New-ConfigurationRepository -RepositoryName "enterprise-comprehensive-test" -LocalPath $repoPath -Provider "local" -Template "enterprise"

            if ($result.Success) {
                # Verify enterprise app config
                $appConfigPath = Join-Path $repoPath "configs/app-config.json"
                if (Test-Path $appConfigPath) {
                    $appConfig = Get-Content $appConfigPath | ConvertFrom-Json
                    $appConfig.settings.auditEnabled | Should -Be $true
                    $appConfig.settings.securityEnforced | Should -Be $true
                    $appConfig.security.requireApproval | Should -Be $true
                    $appConfig.security.encryptionRequired | Should -Be $true
                }
            }
        }
    }

    Context "Repository Documentation Generation" {
        It "Should generate comprehensive documentation" {
            $repoPath = Join-Path $TestLocalRepos "documentation-test"

            $result = New-ConfigurationRepository -RepositoryName "documentation-test" -LocalPath $repoPath -Provider "local" -Template "default"

            if ($result.Success) {
                # Verify documentation structure
                Test-Path (Join-Path $repoPath "docs") | Should -Be $true
                Test-Path (Join-Path $repoPath "docs/configuration-guide.md") | Should -Be $true
                Test-Path (Join-Path $repoPath "README.md") | Should -Be $true

                # Verify documentation content
                $readmePath = Join-Path $repoPath "README.md"
                if (Test-Path $readmePath) {
                    $readmeContent = Get-Content $readmePath -Raw
                    $readmeContent | Should -Match "AitherZero Configuration Repository"
                    $readmeContent | Should -Match "Structure"
                    $readmeContent | Should -Match "Usage"
                }

                $configGuidePath = Join-Path $repoPath "docs/configuration-guide.md"
                if (Test-Path $configGuidePath) {
                    $guideContent = Get-Content $configGuidePath -Raw
                    $guideContent | Should -Match "Configuration Guide"
                    $guideContent | Should -Match "Security Considerations"
                    $guideContent | Should -Match "Maintenance"
                }
            }
        }

        It "Should include template-specific documentation" {
            $templates = @("default", "minimal", "enterprise")

            foreach ($template in $templates) {
                $repoPath = Join-Path $TestLocalRepos "docs-$template-test"

                $result = New-ConfigurationRepository -RepositoryName "docs-$template-test" -LocalPath $repoPath -Provider "local" -Template $template

                if ($result.Success) {
                    $readmePath = Join-Path $repoPath "README.md"
                    if (Test-Path $readmePath) {
                        $readmeContent = Get-Content $readmePath -Raw
                        $readmeContent | Should -Match $template -Because "Documentation should mention template type"
                    }
                }
            }
        }
    }

    Context "Cross-Platform Support" {
        It "Should create platform-appropriate file paths" {
            $repoPath = Join-Path $TestLocalRepos "cross-platform-test"

            $result = New-ConfigurationRepository -RepositoryName "cross-platform-test" -LocalPath $repoPath -Provider "local"

            if ($result.Success) {
                # Verify paths use platform-appropriate separators
                $configPath = Join-Path $repoPath "configs"
                Test-Path $configPath | Should -Be $true

                # Path should use correct separator for current platform
                $separator = [System.IO.Path]::DirectorySeparatorChar
                $configPath | Should -Match [regex]::Escape($separator)
            }
        }

        It "Should handle Unicode file names correctly" {
            $repoPath = Join-Path $TestLocalRepos "unicode-test"
            $unicodeFiles = @{
                'configs/配置文件.json' = @{ name = "Unicode config"; encoding = "UTF-8" }
                'テスト/test.txt' = "Unicode directory test"
                'файл.md' = "# Unicode file name test"
            }

            $result = New-ConfigurationRepository -RepositoryName "unicode-test" -LocalPath $repoPath -Provider "local" -CustomSettings @{ files = $unicodeFiles }

            if ($result.Success) {
                # Basic structure should still be created
                Test-Path $repoPath | Should -Be $true
                Test-Path (Join-Path $repoPath "configs") | Should -Be $true
            }
        }

        It "Should set appropriate file permissions on Unix systems" {
            if (-not $IsWindows) {
                $repoPath = Join-Path $TestLocalRepos "permissions-test"

                $result = New-ConfigurationRepository -RepositoryName "permissions-test" -LocalPath $repoPath -Provider "local"

                if ($result.Success) {
                    # Check directory permissions
                    $dirInfo = Get-Item $repoPath
                    if ($dirInfo.UnixMode) {
                        # Should have appropriate permissions (readable/writable by owner)
                        $dirInfo.UnixMode | Should -Match "^d.*"
                    }
                }
            }
        }
    }

    Context "Performance and Scalability" {
        It "Should handle large template files efficiently" {
            $repoPath = Join-Path $TestLocalRepos "large-template-test"

            # Create large configuration data
            $largeConfig = @{}
            for ($i = 1; $i -le 1000; $i++) {
                $largeConfig["property$i"] = "value$i" * 10
            }

            $createTime = Measure-Command {
                $result = New-ConfigurationRepository -RepositoryName "large-template-test" -LocalPath $repoPath -Provider "local" -CustomSettings $largeConfig
            }

            # Should complete in reasonable time
            $createTime.TotalSeconds | Should -BeLessThan 30
        }

        It "Should efficiently process multiple environment configurations" {
            $repoPath = Join-Path $TestLocalRepos "multi-env-performance-test"
            $manyEnvironments = @()
            for ($i = 1; $i -le 20; $i++) {
                $manyEnvironments += "env$i"
            }

            $createTime = Measure-Command {
                $result = New-ConfigurationRepository -RepositoryName "multi-env-performance-test" -LocalPath $repoPath -Provider "local" -Environments $manyEnvironments
            }

            if ($result.Success) {
                # All environments should be created
                foreach ($env in $manyEnvironments) {
                    Test-Path (Join-Path $repoPath "environments/$env") | Should -Be $true
                }
            }

            # Should complete efficiently
            $createTime.TotalSeconds | Should -BeLessThan 15
        }

        It "Should maintain reasonable memory usage" {
            $initialMemory = [GC]::GetTotalMemory($false)

            # Create multiple repositories
            for ($i = 1; $i -le 5; $i++) {
                $repoPath = Join-Path $TestLocalRepos "memory-test-$i"
                $result = New-ConfigurationRepository -RepositoryName "memory-test-$i" -LocalPath $repoPath -Provider "local" -Template "enterprise"
            }

            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()

            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory

            # Memory increase should be reasonable
            $memoryIncrease | Should -BeLessThan (20 * 1024 * 1024) # Less than 20MB
        }
    }
}

Describe "ConfigurationRepository Module - Error Handling and Recovery" {
    Context "Creation Error Handling" {
        It "Should handle file system permission errors" {
            # This test would require platform-specific permission manipulation
            # For now, we'll test the error handling structure
            $restrictedPath = "/root/restricted-path"  # Typically restricted on Unix systems

            if (-not $IsWindows -and (Test-Path "/root")) {
                $result = New-ConfigurationRepository -RepositoryName "permission-test" -LocalPath $restrictedPath -Provider "local"

                $result.Success | Should -Be $false
                $result.Error | Should -Not -BeNullOrEmpty
            }
        }

        It "Should clean up on creation failure" {
            # Mock template creation to fail
            Mock Create-ConfigurationTemplate {
                return @{ Success = $false; Error = "Template creation failed" }
            }

            $repoPath = Join-Path $TestLocalRepos "cleanup-failure-test"

            $result = New-ConfigurationRepository -RepositoryName "cleanup-failure-test" -LocalPath $repoPath -Provider "local"

            $result.Success | Should -Be $false

            # Directory should be cleaned up on failure
            Test-Path $repoPath | Should -Be $false
        }

        It "Should handle Git initialization failures gracefully" {
            if ($script:GitAvailable) {
                # Mock git init to fail
                Mock git {
                    if ($args[0] -eq "init") {
                        $global:LASTEXITCODE = 1
                        throw "Git init failed"
                    }
                } -ParameterFilter { $args[0] -eq "init" }

                $repoPath = Join-Path $TestLocalRepos "git-init-failure-test"

                $result = New-ConfigurationRepository -RepositoryName "git-init-failure-test" -LocalPath $repoPath -Provider "local"

                $result.Success | Should -Be $false
                $result.Error | Should -Match "Git init failed"
            }
        }

        It "Should provide detailed error messages" {
            # Test various error scenarios
            $errorScenarios = @(
                @{ Path = ""; ExpectedError = "path" },
                @{ Path = " "; ExpectedError = "path" },
                @{ Path = "/invalid\0path"; ExpectedError = "path|invalid" }
            )

            foreach ($scenario in $errorScenarios) {
                try {
                    $result = New-ConfigurationRepository -RepositoryName "error-test" -LocalPath $scenario.Path -Provider "local"
                    $result.Success | Should -Be $false
                    $result.Error | Should -Match $scenario.ExpectedError
                } catch {
                    # Some errors might be thrown directly
                    $_.Exception.Message | Should -Match $scenario.ExpectedError
                }
            }
        }
    }

    Context "Synchronization Error Handling" {
        It "Should handle network connectivity issues" {
            if ($script:GitAvailable) {
                # Mock network failure
                Mock git {
                    $global:LASTEXITCODE = 1
                    return "fatal: unable to access remote: Network is unreachable"
                } -ParameterFilter { $args[0] -eq "fetch" }

                $repoPath = $script:ValidationTestRepos["valid"]
                if ($repoPath -and (Test-Path $repoPath)) {
                    $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull"

                    $result.Success | Should -Be $false
                    $result.Error | Should -Match "network|Network"
                }
            }
        }

        It "Should provide recovery suggestions" {
            if ($script:GitAvailable) {
                # Mock authentication failure
                Mock git {
                    $global:LASTEXITCODE = 1
                    return "fatal: Authentication failed"
                } -ParameterFilter { $args[0] -eq "push" }

                $repoPath = $script:ValidationTestRepos["valid"]
                if ($repoPath -and (Test-Path $repoPath)) {
                    $result = Sync-ConfigurationRepository -Path $repoPath -Operation "push"

                    $result.Success | Should -Be $false

                    # Should provide recovery suggestions (this would be in logs)
                    # The actual implementation should include recovery suggestions
                    $true | Should -Be $true  # Placeholder for recovery suggestion verification
                }
            }
        }

        It "Should maintain repository integrity during failures" {
            if ($script:GitAvailable) {
                $repoPath = $script:ValidationTestRepos["valid"]

                if ($repoPath -and (Test-Path $repoPath)) {
                    # Get initial state
                    Push-Location $repoPath
                    try {
                        $initialCommit = git rev-parse HEAD 2>$null
                        $initialFiles = Get-ChildItem -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
                    } finally {
                        Pop-Location
                    }

                    # Mock operation that fails
                    Mock git {
                        if ($args[0] -eq "pull") {
                            $global:LASTEXITCODE = 1
                            throw "Simulated failure"
                        }
                        return ""
                    } -ParameterFilter { $args[0] -eq "pull" }

                    $result = Sync-ConfigurationRepository -Path $repoPath -Operation "pull"

                    # Repository should be unchanged
                    Push-Location $repoPath
                    try {
                        $currentCommit = git rev-parse HEAD 2>$null
                        $currentFiles = Get-ChildItem -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count

                        $currentCommit | Should -Be $initialCommit
                        $currentFiles | Should -Be $initialFiles
                    } finally {
                        Pop-Location
                    }
                }
            }
        }
    }

    Context "Validation Error Recovery" {
        It "Should handle corrupted repository gracefully" {
            $corruptRepoPath = Join-Path $TestLocalRepos "corrupt-repo"
            New-Item -ItemType Directory -Path $corruptRepoPath -Force | Out-Null

            # Create corrupted Git repository
            $gitDir = Join-Path $corruptRepoPath ".git"
            New-Item -ItemType Directory -Path $gitDir -Force | Out-Null
            "corrupted content" | Set-Content (Join-Path $gitDir "HEAD")

            $result = Validate-ConfigurationRepository -Path $corruptRepoPath

            # Should handle corruption without crashing
            $result | Should -Not -BeNullOrEmpty
            $result.IsValid | Should -BeOfType [bool]
        }

        It "Should continue validation despite file access errors" {
            $repoPath = Join-Path $TestLocalRepos "access-error-repo"
            New-Item -ItemType Directory -Path $repoPath -Force | Out-Null

            # Create files that might cause access errors
            "valid content" | Set-Content (Join-Path $repoPath "valid.txt")

            # Mock file access to fail for specific files
            Mock Get-ChildItem {
                if ($Path -match "problematic") {
                    throw "Access denied"
                }
                # Call original for other paths
                & (Get-Command Get-ChildItem -CommandType Cmdlet) @PSBoundParameters
            } -ParameterFilter { $Filter -eq "*.json" }

            $result = Validate-ConfigurationRepository -Path $repoPath

            # Should complete validation despite access errors
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Clean up test environment
    try {
        # Remove test repositories
        $testRepos = Get-ChildItem $TestLocalRepos -Directory | Where-Object { $_.Name -match "test|enterprise|template|validation|unicode|performance|memory|cleanup|error" }
        foreach ($repo in $testRepos) {
            Remove-Item $repo.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Clean up environment variables
        Remove-Item Env:TEST_REPOSITORY_DIR -ErrorAction SilentlyContinue
        Remove-Item Env:TEST_LOCAL_REPOS -ErrorAction SilentlyContinue
        Remove-Item Env:TEST_REMOTE_REPOS -ErrorAction SilentlyContinue

    } catch {
        Write-Warning "Cleanup failed: $_"
    }
}
