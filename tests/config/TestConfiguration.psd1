# Ensure environment variables are set for admin-friendly module discovery
if (-not $env:PWSH_MODULES_PATH) {
    $env:PWSH_MODULES_PATH = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "core-runner/modules"
}
@{
    # Test Configuration for Aitherium Infrastructure Automation
    # This configuration controls test discovery, execution, and reporting
    
    # Test Discovery Settings
    Discovery = @{
        # PowerShell module discovery
        PowerShell = @{
            ModulesPath = $env:PWSH_MODULES_PATH
            IncludePrivateFunctions = $true
            RequiredModules = @('LabRunner', 'PatchManager', 'Logging')')
            TestPatterns = @('*.Tests.ps1', '*Test*.ps1')
        }
        
        # Python module discovery
        Python = @{
            ModulesPath = "src/python"
            Packages = @('labctl')
            TestPatterns = @('test_*.py', '*_test.py')
            RequirePytest = $false
        }
        
        # Script discovery
        Scripts = @{
            IncludePaths = @('src/pwsh', 'scripts')
            ExcludePatterns = @('*.Tests.ps1', 'test_*', '*backup*', '*temp*')
            MaxScriptsToTest = 50  # Prevent overwhelming test runs
        }
    }
    
    # Test Execution Settings
    Execution = @{
        # Timeout settings (in seconds)
        Timeouts = @{
            ModuleImport = 30
            FunctionTest = 60
            ScriptAnalysis = 120
            PythonTest = 180
        }
        
        # Parallel execution
        Parallel = @{
            Enable = $true
            MaxJobs = 4
            PowerShellTests = $true
            PythonTests = $false  # Python tests run sequentially
        }
        
        # Error handling
        ErrorHandling = @{
            ContinueOnModuleFailure = $true
            ContinueOnTestFailure = $true
            MaxRetries = 2
            RetryDelay = 5  # seconds
        }
    }
    
    # Test Quality Standards
    Quality = @{
        # PowerShell quality requirements
        PowerShell = @{
            RequireHelp = $true
            RequireParameterValidation = $true
            RequireErrorHandling = $true
            RequireModuleManifest = $true
            PSScriptAnalyzer = @{
                Enable = $true
                Severity = @('Error', 'Warning')
                ExcludeRules = @('PSAvoidUsingWriteHost')  # We use Write-Host for user interaction
            }
        }
        
        # Python quality requirements
        Python = @{
            RequireDocstrings = $true
            RequireTypeHints = $false  # Optional for now
            MaxLineLength = 120
            RequireTests = $false  # Optional for now
        }
    }
    
    # Reporting Settings
    Reporting = @{
        # Output formats
        Formats = @{
            Console = @{
                Verbosity = 'Normal'  # Minimal, Normal, Detailed
                ShowProgress = $true
                UseColors = $true
            }
            JUnit = @{
                OutputPath = "tests/results"
                IncludeSystemOut = $true
                IncludeSystemErr = $true
            }
            HTML = @{
                OutputPath = "tests/results"
                IncludeLogs = $true
                Theme = 'Modern'  # Classic, Modern
            }
            JSON = @{
                OutputPath = "tests/results"
                IncludeFullResults = $true
                PrettyPrint = $true
            }
        }
        
        # GitHub integration
        GitHub = @{
            CreateIssuesOnFailure = $false  # Set to $true for CI/CD
            IssueLabels = @('test-failure', 'automated')
            AssignToOwner = $false
        }
    }
    
    # Performance Settings
    Performance = @{
        # Resource limits
        Memory = @{
            MaxUsageMB = 1024
            WarnThresholdMB = 512
        }
        
        # Caching
        Cache = @{
            Enable = $true
            ModuleAnalysis = $true
            TestResults = $false  # Always run fresh tests
            CacheLocation = "tests/.cache"
            TTLHours = 24
        }
    }
    
    # Environment-specific settings
    Environment = @{
        # Required environment variables
        RequiredVars = @(
            'PROJECT_ROOT',
            'PWSH_MODULES_PATH'
        )
        
        # Platform-specific settings
        Windows = @{
            UseWindowsPowerShell = $false  # Use PowerShell 7+ only
            TestHyperV = $false  # Skip Hyper-V tests in CI
        }
        
        Linux = @{
            TestDocker = $true
            RequiredPackages = @('git', 'curl')
        }
        
        macOS = @{
            TestBrew = $false
        }
    }
    
    # CI/CD Integration
    CICD = @{
        # GitHub Actions
        GitHubActions = @{
            UploadArtifacts = $true
            ArtifactRetentionDays = 30
            FailFast = $false
            Matrix = @{
                OS = @('windows-latest', 'ubuntu-latest')
                PowerShellVersion = @('7.3', '7.4')
            }
        }
        
        # Azure DevOps
        AzureDevOps = @{
            PublishTestResults = $true
            PublishCodeCoverage = $false  # Not implemented yet
        }
    }
}

