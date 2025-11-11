@{
    # Code coverage requirements for different component types
    
    # Global settings
    Global = @{
        MinimumCoverage = 75
        TargetCoverage = 85
        FailOnBelowMinimum = $true
        GenerateHtmlReport = $true
        GenerateXmlReport = $true
        ReportPath = 'library/tests/results/coverage'
    }
    
    # Coverage by component type
    Components = @{
        
        # Core modules (aithercore/)
        CoreModules = @{
            MinimumCoverage = 80
            TargetCoverage = 90
            
            Modules = @{
                Configuration = @{ Minimum = 85; Target = 95 }
                Logging = @{ Minimum = 85; Target = 95 }
                Security = @{ Minimum = 80; Target = 90 }
                Infrastructure = @{ Minimum = 75; Target = 85 }
                Orchestration = @{ Minimum = 80; Target = 90 }
                Testing = @{ Minimum = 75; Target = 85 }
                Reporting = @{ Minimum = 70; Target = 80 }
                Documentation = @{ Minimum = 70; Target = 80 }
                Development = @{ Minimum = 75; Target = 85 }
                AIAgents = @{ Minimum = 60; Target = 75 }
                Utilities = @{ Minimum = 80; Target = 90 }
            }
        }
        
        # Automation scripts (library/automation-scripts/)
        AutomationScripts = @{
            MinimumCoverage = 70
            TargetCoverage = 85
            
            Ranges = @{
                '0000-0099' = @{ Minimum = 75; Target = 85; Category = 'Environment Setup' }
                '0100-0199' = @{ Minimum = 65; Target = 80; Category = 'Infrastructure' }
                '0200-0299' = @{ Minimum = 70; Target = 85; Category = 'Development Tools' }
                '0300-0399' = @{ Minimum = 65; Target = 80; Category = 'Deployment' }
                '0400-0499' = @{ Minimum = 80; Target = 90; Category = 'Testing & Quality' }
                '0500-0599' = @{ Minimum = 75; Target = 85; Category = 'Reporting & Analytics' }
                '0700-0799' = @{ Minimum = 70; Target = 85; Category = 'Git & AI Automation' }
                '0800-0899' = @{ Minimum = 70; Target = 80; Category = 'Issue Management' }
                '0900-0999' = @{ Minimum = 75; Target = 85; Category = 'Validation' }
                '9000-9999' = @{ Minimum = 60; Target = 75; Category = 'Maintenance' }
            }
        }
        
        # Orchestration (playbooks, workflows)
        Orchestration = @{
            MinimumCoverage = 80
            TargetCoverage = 90
            
            Components = @{
                OrchestrationEngine = @{ Minimum = 85; Target = 95 }
                Playbooks = @{ Minimum = 75; Target = 85 }
                ScriptUtilities = @{ Minimum = 85; Target = 95 }
            }
        }
        
        # Infrastructure
        Infrastructure = @{
            MinimumCoverage = 60
            TargetCoverage = 75
            Note = 'Lower threshold due to platform-specific code and external dependencies'
            
            Components = @{
                HyperV = @{ Minimum = 55; Target = 70; Note = 'Windows-only' }
                Networking = @{ Minimum = 65; Target = 75 }
                Storage = @{ Minimum = 60; Target = 75 }
                Certificates = @{ Minimum = 70; Target = 80 }
            }
        }
    }
    
    # Coverage exclusions
    Exclusions = @{
        # Files to completely exclude from coverage
        Files = @(
            '*.Tests.ps1',
            'TestHelpers.psm1',
            '*.Example.ps1',
            'Demo-*.ps1',
            '*-Template.ps1'
        )
        
        # Functions to exclude (typically external or mock functions)
        Functions = @(
            'Mock-*',
            'Test-*Mock*'
        )
        
        # Directories to exclude
        Directories = @(
            'tests',
            'examples',
            'demos',
            'archive',
            '.git',
            '.github',
            'docs/archive'
        )
    }
    
    # Code paths that require 100% coverage (critical paths)
    CriticalPaths = @{
        SecurityFunctions = @(
            'Get-SecureCredential',
            'Set-SecureCredential',
            'Protect-Secret',
            'Get-CertificateInfo',
            'New-SelfSignedCertificateAdvanced'
        )
        
        ConfigurationFunctions = @(
            'Get-Configuration',
            'Set-Configuration',
            'Export-Configuration',
            'Import-Configuration'
        )
        
        OrchestrationFunctions = @(
            'Invoke-OrchestrationSequence',
            'Invoke-AitherPlaybook',
            'Invoke-AitherScript'
        )
    }
    
    # Coverage reporting
    Reporting = @{
        # Report formats to generate
        Formats = @('Html', 'Xml', 'Json', 'Console')
        
        # Report verbosity
        Verbosity = 'Normal'  # Minimal, Normal, Detailed
        
        # Show untested files
        ShowUntested = $true
        
        # Show coverage by function
        ShowFunctionCoverage = $true
        
        # Show coverage trend (requires historical data)
        ShowTrend = $true
        
        # Historical comparison
        CompareToBaseline = $true
        BaselinePath = 'library/tests/results/coverage/baseline.xml'
        
        # Fail conditions
        FailConditions = @{
            BelowMinimum = $true
            DecreasedFromBaseline = $false  # Warning only
            UncoveredCriticalPath = $true
        }
    }
    
    # Integration with CI/CD
    CI = @{
        # Publish coverage to external services
        PublishTo = @(
            # 'Codecov',
            # 'Coveralls',
            'GitHubActions'  # Publish as artifacts
        )
        
        # Comment coverage on PRs
        CommentOnPR = $true
        
        # Required coverage increase for new code
        NewCodeMinimum = 80
        
        # Block merge if coverage below threshold
        BlockMerge = $true
    }
}
