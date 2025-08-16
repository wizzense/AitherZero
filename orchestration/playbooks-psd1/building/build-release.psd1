@{
    Name = 'build-release'
    Description = 'Build production release with all validations'
    Version = '1.0.0'
    Author = 'AitherZero Build System'
    
    Stages = @(
        @{
            Name = 'PreBuild'
            Description = 'Pre-build validation'
            Sequence = @('0402', '0404', '0407')  # Tests, linting, syntax
            ContinueOnError = $false
        }
        @{
            Name = 'Build'
            Description = 'Build release artifacts'
            Sequence = @('9100')  # Build-Release script
            ContinueOnError = $false
        }
        @{
            Name = 'PostBuild'
            Description = 'Post-build validation'
            Sequence = @('0523', '9105')  # Security scan, test packages
            ContinueOnError = $false
        }
        @{
            Name = 'Package'
            Description = 'Create release package'
            Sequence = @('9102')  # Create GitHub release
            ContinueOnError = $false
        }
    )
    
    Variables = @{
        Configuration = 'Release'
        SignPackages = $true
        RunTests = $true
        GenerateChangelog = $true
    }
    
    Requirements = @{
        MinPowerShellVersion = '7.0'
        RequiredModules = @('Pester', 'PSScriptAnalyzer')
        CheckGitStatus = $true
    }
}