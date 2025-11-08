@{
    # Test execution profiles defining which tests to run and how
    
    Quick = @{
        Name = 'Quick Validation'
        Description = 'Fast validation for local development'
        Duration = '5 minutes'
        
        Include = @{
            Unit = @{
                Modules = $true
                Scripts = @('Changed')  # Only modified scripts
                Workflows = $false
            }
            Integration = @{
                Modules = $false
                Playbooks = $false
                Infrastructure = $false
                Workflows = $false
            }
            E2E = $false
            Quality = @{
                PSScriptAnalyzer = @('Critical', 'Error')  # Only critical issues
                AST = $false
                Style = $false
                Documentation = $false
            }
            Performance = $false
        }
        
        Options = @{
            Parallel = $true
            MaxParallel = 4
            StopOnFirstFailure = $false
            GenerateCoverage = $false
            GenerateReport = $true
        }
    }
    
    Standard = @{
        Name = 'Standard Test Suite'
        Description = 'Comprehensive testing for PR validation'
        Duration = '15 minutes'
        
        Include = @{
            Unit = @{
                Modules = $true
                Scripts = $true  # All scripts
                Workflows = $true
            }
            Integration = @{
                Modules = $true
                Playbooks = $true
                Infrastructure = $false  # Too slow for standard
                Workflows = $true
            }
            E2E = $false  # Too slow for standard
            Quality = @{
                PSScriptAnalyzer = @('Critical', 'Error', 'Warning')
                AST = $true
                Style = $true
                Documentation = $true
            }
            Performance = $false
        }
        
        Options = @{
            Parallel = $true
            MaxParallel = 8
            StopOnFirstFailure = $false
            GenerateCoverage = $true
            GenerateReport = $true
        }
    }
    
    Full = @{
        Name = 'Full Test Suite'
        Description = 'Complete validation including E2E and performance'
        Duration = '30 minutes'
        
        Include = @{
            Unit = @{
                Modules = $true
                Scripts = $true
                Workflows = $true
            }
            Integration = @{
                Modules = $true
                Playbooks = $true
                Infrastructure = $true
                Workflows = $true
            }
            E2E = @{
                Bootstrap = $true
                Deployment = $true
                Orchestration = $true
                Release = $true
            }
            Quality = @{
                PSScriptAnalyzer = @('Critical', 'Error', 'Warning', 'Information')
                AST = $true
                Style = $true
                Documentation = $true
            }
            Performance = @{
                Modules = $true
                Scripts = $true
                Workflows = $true
            }
        }
        
        Options = @{
            Parallel = $true
            MaxParallel = 16
            StopOnFirstFailure = $false
            GenerateCoverage = $true
            GenerateReport = $true
        }
    }
    
    CI = @{
        Name = 'CI/CD Pipeline'
        Description = 'Optimized for GitHub Actions parallel execution'
        Duration = '10 minutes'
        
        Include = @{
            Unit = @{
                Modules = $true
                Scripts = $true
                Workflows = $true
            }
            Integration = @{
                Modules = $true
                Playbooks = $true
                Infrastructure = $false  # Not in CI
                Workflows = $true
            }
            E2E = @{
                Bootstrap = $true  # Critical path only
                Deployment = $false
                Orchestration = $false
                Release = $false
            }
            Quality = @{
                PSScriptAnalyzer = @('Critical', 'Error')  # Fail on critical only
                AST = $true
                Style = $false  # Tracked but doesn't fail
                Documentation = $true
            }
            Performance = $false  # Not in CI
        }
        
        Options = @{
            Parallel = $true
            MaxParallel = 32  # GitHub Actions matrix
            StopOnFirstFailure = $false
            GenerateCoverage = $true
            GenerateReport = $true
            FailFast = $false  # Let all tests complete
        }
    }
    
    Developer = @{
        Name = 'Developer Focused'
        Description = 'Tests for active development work'
        Duration = '3 minutes'
        
        Include = @{
            Unit = @{
                Modules = @('Modified')  # Only modules being worked on
                Scripts = @('Modified')  # Only scripts being worked on
                Workflows = $false
            }
            Integration = $false
            E2E = $false
            Quality = @{
                PSScriptAnalyzer = @('Critical', 'Error')
                AST = $false
                Style = $false
                Documentation = $false
            }
            Performance = $false
        }
        
        Options = @{
            Parallel = $false  # Sequential for easier debugging
            MaxParallel = 1
            StopOnFirstFailure = $true  # Stop immediately for debugging
            GenerateCoverage = $false
            GenerateReport = $false
        }
    }
    
    Release = @{
        Name = 'Release Validation'
        Description = 'Full validation before release'
        Duration = '45 minutes'
        
        Include = @{
            Unit = @{
                Modules = $true
                Scripts = $true
                Workflows = $true
            }
            Integration = @{
                Modules = $true
                Playbooks = $true
                Infrastructure = $true
                Workflows = $true
            }
            E2E = @{
                Bootstrap = $true
                Deployment = $true
                Orchestration = $true
                Release = $true
            }
            Quality = @{
                PSScriptAnalyzer = @('Critical', 'Error', 'Warning', 'Information')
                AST = $true
                Style = $true
                Documentation = $true
            }
            Performance = @{
                Modules = $true
                Scripts = $true
                Workflows = $true
                Benchmarks = $true  # Include historical comparisons
            }
        }
        
        Options = @{
            Parallel = $true
            MaxParallel = 16
            StopOnFirstFailure = $false
            GenerateCoverage = $true
            GenerateReport = $true
            GenerateBenchmarks = $true
            ArchiveResults = $true
        }
    }
}
