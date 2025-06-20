# Bulletproof Test Configuration for Aitherium Infrastructure Automation
# Enhanced Pester 5.x Configuration with comprehensive coverage

@{
    # Core test execution settings
    Run = @{
        Path = @(
            'tests/unit/modules/CoreApp',
            'tests/unit/modules/Logging',
            'tests/unit/modules/LabRunner',
            'tests/unit/modules/TestingFramework',
            'tests/unit/modules/ParallelExecution',
            'tests/unit/modules/BackupManager',
            'tests/unit/modules/ScriptManager',
            'tests/unit/modules/DevEnvironment',
            'tests/unit/modules/UnifiedMaintenance',
            'tests/unit/modules/PatchManager',
            'tests/integration',
            'tests/system'
        )
        Exit = $false
        PassThru = $true
        Throw = $false
        Container = New-PesterContainer -Path "tests/unit/modules/CoreApp/NonInteractiveMode.Tests.ps1" -Data @{
            ProjectRoot = $env:PROJECT_ROOT
        }
    }

    # Advanced filtering for targeted testing
    Filter = @{
        ExcludeTag = @()  # Include all tests by default
        Tag = @('Unit', 'Integration', 'CoreApp', 'NonInteractive', 'Bulletproof')
        FullName = @()
        Line = @()
        ExcludeLine = @()
    }

    # Enhanced output settings
    Output = @{
        Verbosity = 'Detailed'
        CIFormat = 'GithubActions'
        StackTraceVerbosity = 'Full'
        RenderMode = 'Plaintext'
    }

    # Comprehensive test results
    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = 'tests/results/BulletproofTestResults.xml'
        TestSuiteName = 'Aitherium Infrastructure Automation - Bulletproof Tests'
        OutputEncoding = 'UTF8'
    }

    # Code coverage settings
    CodeCoverage = @{
        Enabled = $true
        Path = @(
            'core-runner/core_app/core-runner.ps1',
            'core-runner/core_app/CoreApp.psm1',
            'core-runner/modules/Logging/*.ps1',
            'core-runner/modules/LabRunner/*.ps1',
            'core-runner/modules/TestingFramework/*.ps1',
            'core-runner/modules/ParallelExecution/*.ps1'
        )
        OutputFormat = 'JaCoCo'
        OutputPath = 'tests/results/bulletproof-coverage.xml'
        OutputEncoding = 'UTF8'
        UseBreakpoints = $false
        SingleHitBreakpoints = $true
    }

    # Strict validation settings
    Should = @{
        ErrorAction = 'Stop'
        DisableV5Compatibility = $false
    }

    # Enhanced debugging
    Debug = @{
        ShowFullErrors = $true
        WriteDebugMessages = $true
        WriteDebugMessagesFrom = @('CoreApp', 'NonInteractive', 'Bulletproof')
        ReturnRawResultObject = $true
        WriteVSCodeMarker = $true
    }

    # Performance monitoring
    Performance = @{
        Enabled = $true
        SlowTestThreshold = 30000  # 30 seconds
        ReportSlowTests = $true
    }

    # Custom settings for bulletproof testing
    Custom = @{
        BulletproofMode = $true
        LogFileOutput = $true
        ExitCodeValidation = $true
        CrossPlatformTesting = $true
        NonInteractiveValidation = $true
        ErrorHandlingTests = $true
        PerformanceTests = $true
        IntegrationTests = $true
        SystemTests = $true
    }
}
