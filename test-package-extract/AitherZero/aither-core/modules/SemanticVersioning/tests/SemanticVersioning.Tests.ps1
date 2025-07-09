#Requires -Version 7.0

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot ".." "SemanticVersioning.psm1"
    Import-Module $modulePath -Force -ErrorAction Stop

    # Setup test environment
    $script:TestPath = Join-Path ([System.IO.Path]::GetTempPath()) "SemanticVersioningTests"
    $script:TestRepoPath = Join-Path $script:TestPath "test-repo"

    # Create test directories
    if (Test-Path $script:TestPath) {
        Remove-Item $script:TestPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:TestPath -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TestRepoPath -Force | Out-Null

    # Initialize a test git repository
    Push-Location $script:TestRepoPath
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Create initial commit
    "# Test Repository" | Set-Content "README.md"
    git add README.md
    git commit -m "Initial commit" --quiet

    # Create some test commits with conventional commit messages
    "1.0.0" | Set-Content "VERSION"
    git add VERSION
    git commit -m "feat: initial version" --quiet
    git tag -a "v1.0.0" -m "Release 1.0.0" --quiet

    "Feature content" | Set-Content "feature.txt"
    git add feature.txt
    git commit -m "feat(api): add new API endpoint" --quiet

    "Bug fix content" | Set-Content "bugfix.txt"
    git add bugfix.txt
    git commit -m "fix(core): resolve memory leak issue" --quiet

    "Documentation" | Set-Content "docs.md"
    git add docs.md
    git commit -m "docs: update API documentation" --quiet

    Pop-Location
}

Describe "SemanticVersioning Module Tests" {
    Context "Module Loading and Initialization" {
        It "Should import module successfully" {
            Get-Module SemanticVersioning | Should -Not -BeNullOrEmpty
        }

        It "Should have valid manifest" {
            $manifestPath = Join-Path $PSScriptRoot ".." "SemanticVersioning.psd1"
            Test-Path $manifestPath | Should -Be $true

            { Test-ModuleManifest $manifestPath } | Should -Not -Throw
        }

        It "Should export expected functions" {
            $expectedFunctions = @(
                'Get-NextSemanticVersion',
                'ConvertFrom-ConventionalCommits',
                'Get-CommitTypeImpact',
                'New-VersionTag',
                'Get-VersionHistory',
                'Update-ProjectVersion',
                'Get-ReleaseNotes',
                'Test-SemanticVersion',
                'Compare-SemanticVersions',
                'Get-VersionBump'
            )

            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Test-SemanticVersion Function Tests" {
        It "Should validate correct semantic versions" {
            $validVersions = @(
                "1.0.0",
                "0.0.1",
                "10.20.30",
                "1.2.3-alpha",
                "1.2.3-alpha.1",
                "1.2.3-alpha.beta",
                "1.2.3-alpha.1.beta",
                "1.2.3+build",
                "1.2.3+build.1",
                "1.2.3-alpha+build",
                "1.2.3-alpha.1+build.2.3"
            )

            foreach ($version in $validVersions) {
                Test-SemanticVersion -Version $version | Should -Be $true -Because "$version should be a valid semantic version"
            }
        }

        It "Should reject invalid semantic versions" {
            $invalidVersions = @(
                "1",
                "1.2",
                "1.2.3.4",
                "01.2.3",
                "1.02.3",
                "1.2.03",
                "1.2.3-",
                "1.2.3+",
                "1.2.3-+build",
                "1.2.3-alpha..beta",
                "",
                "v1.2.3",
                "1.2.3-α"
            )

            foreach ($version in $invalidVersions) {
                Test-SemanticVersion -Version $version | Should -Be $false -Because "$version should be an invalid semantic version"
            }
        }
    }

    Context "Compare-SemanticVersions Function Tests" {
        It "Should compare major versions correctly" {
            Compare-SemanticVersions -Version1 "1.0.0" -Version2 "2.0.0" | Should -BeLessThan 0
            Compare-SemanticVersions -Version1 "2.0.0" -Version2 "1.0.0" | Should -BeGreaterThan 0
            Compare-SemanticVersions -Version1 "1.0.0" -Version2 "1.0.0" | Should -Be 0
        }

        It "Should compare minor versions correctly" {
            Compare-SemanticVersions -Version1 "1.1.0" -Version2 "1.2.0" | Should -BeLessThan 0
            Compare-SemanticVersions -Version1 "1.2.0" -Version2 "1.1.0" | Should -BeGreaterThan 0
        }

        It "Should compare patch versions correctly" {
            Compare-SemanticVersions -Version1 "1.0.1" -Version2 "1.0.2" | Should -BeLessThan 0
            Compare-SemanticVersions -Version1 "1.0.2" -Version2 "1.0.1" | Should -BeGreaterThan 0
        }

        It "Should handle pre-release versions correctly" {
            Compare-SemanticVersions -Version1 "1.0.0-alpha" -Version2 "1.0.0" | Should -BeLessThan 0
            Compare-SemanticVersions -Version1 "1.0.0" -Version2 "1.0.0-alpha" | Should -BeGreaterThan 0
            Compare-SemanticVersions -Version1 "1.0.0-alpha" -Version2 "1.0.0-beta" | Should -BeLessThan 0
        }

        It "Should throw on invalid versions" {
            { Compare-SemanticVersions -Version1 "invalid" -Version2 "1.0.0" } | Should -Throw
            { Compare-SemanticVersions -Version1 "1.0.0" -Version2 "invalid" } | Should -Throw
        }
    }

    Context "Get-VersionBump Function Tests" {
        It "Should detect major version bumps" {
            Get-VersionBump -FromVersion "1.0.0" -ToVersion "2.0.0" | Should -Be "Major"
            Get-VersionBump -FromVersion "0.5.3" -ToVersion "1.0.0" | Should -Be "Major"
        }

        It "Should detect minor version bumps" {
            Get-VersionBump -FromVersion "1.0.0" -ToVersion "1.1.0" | Should -Be "Minor"
            Get-VersionBump -FromVersion "2.3.0" -ToVersion "2.4.0" | Should -Be "Minor"
        }

        It "Should detect patch version bumps" {
            Get-VersionBump -FromVersion "1.0.0" -ToVersion "1.0.1" | Should -Be "Patch"
            Get-VersionBump -FromVersion "2.3.4" -ToVersion "2.3.5" | Should -Be "Patch"
        }

        It "Should detect no version bump" {
            Get-VersionBump -FromVersion "1.0.0" -ToVersion "1.0.0" | Should -Be "None"
        }

        It "Should throw on invalid versions" {
            { Get-VersionBump -FromVersion "invalid" -ToVersion "1.0.0" } | Should -Throw
            { Get-VersionBump -FromVersion "1.0.0" -ToVersion "invalid" } | Should -Throw
        }
    }

    Context "ConvertFrom-ConventionalCommits Function Tests" {
        It "Should parse valid conventional commits" {
            $commits = @(
                "feat: add new feature",
                "fix(api): resolve bug in endpoint",
                "docs: update documentation",
                "feat!: breaking change feature",
                "fix(core): memory leak BREAKING CHANGE: API changed"
            )

            $result = ConvertFrom-ConventionalCommits -Commits $commits

            $result.Count | Should -Be 5
            $result[0].Type | Should -Be "feat"
            $result[0].IsConventional | Should -Be $true
            $result[1].Scope | Should -Be "api"
            $result[3].IsBreaking | Should -Be $true
            $result[4].IsBreaking | Should -Be $true
        }

        It "Should handle non-conventional commits when requested" {
            $commits = @(
                "feat: conventional commit",
                "Random commit message",
                "Another non-conventional message"
            )

            $result = ConvertFrom-ConventionalCommits -Commits $commits -IncludeNonConventional

            $result.Count | Should -Be 3
            $result[0].IsConventional | Should -Be $true
            $result[1].IsConventional | Should -Be $false
            $result[2].IsConventional | Should -Be $false
        }

        It "Should skip non-conventional commits by default" {
            $commits = @(
                "feat: conventional commit",
                "Random commit message"
            )

            $result = ConvertFrom-ConventionalCommits -Commits $commits

            $result.Count | Should -Be 1
            $result[0].IsConventional | Should -Be $true
        }

        It "Should handle commit objects with hash and message" {
            $commits = @(
                @{ Hash = "abc123"; Message = "feat: test feature" }
                @{ Hash = "def456"; Message = "fix: test fix" }
            )

            $result = ConvertFrom-ConventionalCommits -Commits $commits

            $result.Count | Should -Be 2
            $result[0].Hash | Should -Be "abc123"
            $result[1].Hash | Should -Be "def456"
        }
    }

    Context "Get-CommitTypeImpact Function Tests" {
        It "Should return correct impact for known commit types" {
            Get-CommitTypeImpact -CommitType "feat" | Should -Be "Minor"
            Get-CommitTypeImpact -CommitType "fix" | Should -Be "Patch"
            Get-CommitTypeImpact -CommitType "docs" | Should -Be "Patch"
            Get-CommitTypeImpact -CommitType "breaking" | Should -Be "Major"
        }

        It "Should return Patch for unknown commit types" {
            Get-CommitTypeImpact -CommitType "unknown" | Should -Be "Patch"
            Get-CommitTypeImpact -CommitType "custom" | Should -Be "Patch"
        }

        It "Should be case insensitive" {
            Get-CommitTypeImpact -CommitType "FEAT" | Should -Be "Minor"
            Get-CommitTypeImpact -CommitType "Fix" | Should -Be "Patch"
        }
    }

    Context "Get-NextSemanticVersion Function Tests" {
        BeforeEach {
            Push-Location $script:TestRepoPath
        }

        AfterEach {
            Pop-Location
        }

        It "Should calculate next version based on commits" {
            $result = Get-NextSemanticVersion -CurrentVersion "1.0.0"

            $result | Should -Not -BeNullOrEmpty
            $result.CurrentVersion | Should -Be "1.0.0"
            $result.NextVersion | Should -Not -BeNullOrEmpty
            $result.VersionBump | Should -BeIn @("Major", "Minor", "Patch", "None")
        }

        It "Should force specific version type when requested" {
            $result = Get-NextSemanticVersion -CurrentVersion "1.0.0" -ForceVersionType "Major"

            $result.VersionBump | Should -Be "Major"
            $result.NextVersion | Should -Be "2.0.0"
        }

        It "Should add pre-release label when specified" {
            $result = Get-NextSemanticVersion -CurrentVersion "1.0.0" -ForceVersionType "Minor" -PreReleaseLabel "alpha"

            $result.PreRelease | Should -Be "alpha"
            $result.NextVersion | Should -Match "1.1.0-alpha"
            $result.IsPreRelease | Should -Be $true
        }

        It "Should add build metadata when specified" {
            $result = Get-NextSemanticVersion -CurrentVersion "1.0.0" -ForceVersionType "Patch" -BuildMetadata "build.123"

            $result.BuildMetadata | Should -Be "build.123"
            $result.NextVersion | Should -Be "1.0.1+build.123"
        }

        It "Should analyze commits correctly" {
            $result = Get-NextSemanticVersion -CurrentVersion "1.0.0" -AnalyzeCommits

            $result.Analysis | Should -Not -BeNullOrEmpty
            $result.CommitsSinceLastRelease | Should -BeGreaterOrEqual 0
            $result.ReleaseNotes | Should -Not -BeNullOrEmpty
        }

        It "Should skip commit analysis when requested" {
            $result = Get-NextSemanticVersion -CurrentVersion "1.0.0" -AnalyzeCommits:$false -ForceVersionType "Patch"

            $result.CommitsSinceLastRelease | Should -Be 0
            $result.VersionBump | Should -Be "Patch"
        }

        It "Should throw on invalid current version" {
            { Get-NextSemanticVersion -CurrentVersion "invalid" } | Should -Throw
        }
    }

    Context "Update-ProjectVersion Function Tests" {
        BeforeEach {
            Push-Location $script:TestRepoPath

            # Create test version files
            "1.0.0" | Set-Content "VERSION"
            @{
                ModuleVersion = '1.0.0'
                Author = 'Test'
            } | ConvertTo-Json | Set-Content "test.psd1"
            @{
                version = "1.0.0"
                name = "test-package"
            } | ConvertTo-Json | Set-Content "package.json"
        }

        AfterEach {
            Pop-Location
        }

        It "Should update VERSION file" {
            $result = Update-ProjectVersion -Version "2.0.0" -UpdateFiles @("VERSION")

            $result | Should -Contain "VERSION"
            Get-Content "VERSION" | Should -Be "2.0.0"
        }

        It "Should update PowerShell manifest file" {
            # Create a proper PowerShell manifest
            "ModuleVersion = '1.0.0'" | Set-Content "test.psd1"

            $result = Update-ProjectVersion -Version "2.0.0" -UpdateFiles @("test.psd1")

            $content = Get-Content "test.psd1" -Raw
            $content | Should -Match "ModuleVersion = '2.0.0'"
        }

        It "Should update JSON package file" {
            $result = Update-ProjectVersion -Version "2.0.0" -UpdateFiles @("package.json")

            $content = Get-Content "package.json" | ConvertFrom-Json
            $content.version | Should -Be "2.0.0"
        }

        It "Should handle non-existent files gracefully" {
            $result = Update-ProjectVersion -Version "2.0.0" -UpdateFiles @("nonexistent.txt")

            $result | Should -Not -Contain "nonexistent.txt"
        }

        It "Should auto-detect version files when none specified" {
            { Update-ProjectVersion -Version "2.0.0" } | Should -Not -Throw
        }

        It "Should throw on invalid version" {
            { Update-ProjectVersion -Version "invalid" } | Should -Throw
        }
    }

    Context "New-VersionTag Function Tests" {
        BeforeEach {
            Push-Location $script:TestRepoPath
        }

        AfterEach {
            Pop-Location
        }

        It "Should create version tag successfully" {
            $result = New-VersionTag -Version "2.0.0" -Message "Release 2.0.0"

            $result | Should -Not -BeNullOrEmpty
            $result.TagName | Should -Be "v2.0.0"
            $result.Version | Should -Be "2.0.0"
            $result.Pushed | Should -Be $false

            # Verify tag exists
            $tags = git tag -l "v2.0.0"
            $tags | Should -Contain "v2.0.0"
        }

        It "Should create tag with default message when none provided" {
            $result = New-VersionTag -Version "2.1.0"

            $result.Message | Should -Match "Release version 2.1.0"
        }

        It "Should include release notes in tag message" {
            $releaseNotes = "- Added new feature`n- Fixed bug"
            $result = New-VersionTag -Version "2.2.0" -ReleaseNotes $releaseNotes

            $result.Message | Should -Match "Added new feature"
        }

        It "Should handle tag creation without push" {
            $result = New-VersionTag -Version "2.3.0" -Push:$false

            $result.Pushed | Should -Be $false
        }

        It "Should throw on invalid version" {
            { New-VersionTag -Version "invalid" } | Should -Throw
        }
    }

    Context "Get-VersionHistory Function Tests" {
        BeforeEach {
            Push-Location $script:TestRepoPath
        }

        AfterEach {
            Pop-Location
        }

        It "Should retrieve version history from git tags" {
            $result = Get-VersionHistory -Count 10

            $result | Should -Not -BeNullOrEmpty
            $result[0].Version | Should -Not -BeNullOrEmpty
            $result[0].Tag | Should -Not -BeNullOrEmpty
            $result[0].Major | Should -BeOfType [int]
            $result[0].Minor | Should -BeOfType [int]
            $result[0].Patch | Should -BeOfType [int]
        }

        It "Should limit results to specified count" {
            $result = Get-VersionHistory -Count 1

            $result.Count | Should -BeLessOrEqual 1
        }

        It "Should exclude pre-release versions by default" {
            # Create a pre-release tag
            git tag -a "v1.1.0-alpha" -m "Pre-release" --quiet

            $result = Get-VersionHistory -IncludePreRelease:$false

            $preReleases = $result | Where-Object IsPreRelease
            $preReleases.Count | Should -Be 0
        }

        It "Should include pre-release versions when requested" {
            # Create a pre-release tag
            git tag -a "v1.2.0-beta" -m "Beta release" --quiet

            $result = Get-VersionHistory -IncludePreRelease

            $preReleases = $result | Where-Object IsPreRelease
            $preReleases.Count | Should -BeGreaterThan 0
        }
    }

    Context "Get-ReleaseNotes Function Tests" {
        BeforeEach {
            Push-Location $script:TestRepoPath
        }

        AfterEach {
            Pop-Location
        }

        It "Should generate markdown release notes" {
            $notes = Get-ReleaseNotes -FromVersion "v1.0.0" -ToVersion "HEAD" -Format "Markdown"

            $notes | Should -Not -BeNullOrEmpty
            $notes | Should -Match "# Release"
        }

        It "Should generate text release notes" {
            $notes = Get-ReleaseNotes -FromVersion "v1.0.0" -ToVersion "HEAD" -Format "Text"

            $notes | Should -Not -BeNullOrEmpty
            $notes | Should -Not -Match "##"  # Should not contain markdown headers
        }

        It "Should generate JSON release notes" {
            $notes = Get-ReleaseNotes -FromVersion "v1.0.0" -ToVersion "HEAD" -Format "JSON"

            $notes | Should -Not -BeNullOrEmpty
            { $notes | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should categorize commits by type" {
            $notes = Get-ReleaseNotes -FromVersion "v1.0.0" -ToVersion "HEAD" -Format "Markdown"

            # Should contain sections for different commit types
            $notes | Should -Match "(Features|Bug Fixes|Other Changes)"
        }
    }

    Context "Error Handling and Edge Cases" {
        It "Should handle git repository not available" {
            Push-Location $script:TestPath  # Not a git repo

            { Get-NextSemanticVersion -CurrentVersion "1.0.0" } | Should -Not -Throw

            Pop-Location
        }

        It "Should handle empty commit history" {
            Push-Location $script:TestRepoPath

            # Test with a version that doesn't exist
            $result = Get-NextSemanticVersion -CurrentVersion "1.0.0" -FromCommit "nonexistent"
            $result | Should -Not -BeNullOrEmpty

            Pop-Location
        }

        It "Should handle malformed conventional commits gracefully" {
            $commits = @(
                "feat:",  # Missing description
                "feat() add feature",  # Missing colon
                ": no type"  # Missing type
            )

            $result = ConvertFrom-ConventionalCommits -Commits $commits
            # Should not crash, might return empty or minimal results
            $result | Should -Not -BeNullOrEmpty -Or $result.Count -eq 0
        }

        It "Should handle version comparison edge cases" {
            # Test with very large version numbers
            { Compare-SemanticVersions -Version1 "999.999.999" -Version2 "1000.0.0" } | Should -Not -Throw

            # Test with zero versions
            Compare-SemanticVersions -Version1 "0.0.0" -Version2 "0.0.1" | Should -BeLessThan 0
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            $platform | Should -BeIn @("Windows", "Linux", "macOS")

            # Test basic functionality on current platform
            Test-SemanticVersion -Version "1.0.0" | Should -Be $true
        }

        It "Should handle path operations cross-platform" {
            Push-Location $script:TestRepoPath

            $result = Get-NextSemanticVersion -CurrentVersion "1.0.0"
            $result | Should -Not -BeNullOrEmpty

            Pop-Location
        }

        It "Should work with PowerShell 7+ features" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7

            # Test that functions work with PowerShell 7+ syntax
            $result = Test-SemanticVersion -Version "1.0.0"
            $result | Should -BeOfType [bool]
        }
    }

    Context "Performance and Resource Management" {
        It "Should handle large version histories efficiently" {
            # Create many tags quickly
            Push-Location $script:TestRepoPath

            1..10 | ForEach-Object {
                git tag -a "v1.0.$_" -m "Version 1.0.$_" --quiet
            }

            $startTime = Get-Date
            $result = Get-VersionHistory -Count 20
            $duration = (Get-Date) - $startTime

            $duration.TotalSeconds | Should -BeLessThan 5
            $result | Should -Not -BeNullOrEmpty

            Pop-Location
        }

        It "Should process many commits efficiently" {
            $commits = 1..100 | ForEach-Object {
                "feat: feature number $_"
            }

            $startTime = Get-Date
            $result = ConvertFrom-ConventionalCommits -Commits $commits
            $duration = (Get-Date) - $startTime

            $duration.TotalSeconds | Should -BeLessThan 2
            $result.Count | Should -Be 100
        }

        It "Should handle concurrent operations" {
            # Test that multiple version operations don't interfere
            $job1 = Start-Job -ScriptBlock {
                param($ModulePath)
                Import-Module $ModulePath -Force
                Test-SemanticVersion -Version "1.0.0"
            } -ArgumentList $modulePath

            $job2 = Start-Job -ScriptBlock {
                param($ModulePath)
                Import-Module $ModulePath -Force
                Compare-SemanticVersions -Version1 "1.0.0" -Version2 "2.0.0"
            } -ArgumentList $modulePath

            $result1 = Receive-Job $job1 -Wait
            $result2 = Receive-Job $job2 -Wait

            Remove-Job $job1, $job2

            $result1 | Should -Be $true
            $result2 | Should -BeLessThan 0
        }
    }

    Context "Integration Tests" {
        BeforeEach {
            Push-Location $script:TestRepoPath
        }

        AfterEach {
            Pop-Location
        }

        It "Should perform end-to-end version workflow" {
            # 1. Get next version
            $nextVersion = Get-NextSemanticVersion -CurrentVersion "1.0.0" -ForceVersionType "Minor"

            # 2. Update project files
            "1.0.0" | Set-Content "VERSION"
            $updatedFiles = Update-ProjectVersion -Version $nextVersion.NextVersion -UpdateFiles @("VERSION")

            # 3. Create version tag
            $tag = New-VersionTag -Version $nextVersion.NextVersion -Message "Release $($nextVersion.NextVersion)"

            # 4. Verify results
            $nextVersion.NextVersion | Should -Be "1.1.0"
            $updatedFiles | Should -Contain "VERSION"
            Get-Content "VERSION" | Should -Be "1.1.0"
            $tag.TagName | Should -Be "v1.1.0"

            # 5. Verify tag exists in git
            $tags = git tag -l "v1.1.0"
            $tags | Should -Contain "v1.1.0"
        }

        It "Should generate comprehensive release notes workflow" {
            # Create some more commits for testing
            "New feature" | Set-Content "newfeature.txt"
            git add newfeature.txt
            git commit -m "feat(ui): add new dashboard component" --quiet

            "Bug fix" | Set-Content "bugfix2.txt"
            git add bugfix2.txt
            git commit -m "fix(api): handle null response properly" --quiet

            # Generate release notes
            $notes = Get-ReleaseNotes -FromVersion "v1.0.0" -ToVersion "HEAD" -Format "Markdown"

            $notes | Should -Match "Features"
            $notes | Should -Match "Bug Fixes"
            $notes | Should -Match "dashboard component"
            $notes | Should -Match "null response"
        }
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $script:TestPath) {
        Push-Location $script:TestPath
        Remove-Item $script:TestPath -Recurse -Force -ErrorAction SilentlyContinue
        Pop-Location
    }

    # Remove the module
    Remove-Module SemanticVersioning -Force -ErrorAction SilentlyContinue
}
