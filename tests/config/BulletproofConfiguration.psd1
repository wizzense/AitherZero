# Bulletproof Test Configuration for Aitherium Infrastructure Automation
# Enhanced Pester 5.x Configuration with comprehensive coverage

@{
    # Core test execution settings
    Run = @{
        Path = @(
            'tests/Unit',
            'tests/Integration',
            'tests/Critical',
            'tests/Performance'
        )
        Exit = $false
        PassThru = $true
        Throw = $false
        Container = $null  # Will be set dynamically based on discovered tests
    }

    # Advanced filtering for targeted testing
    Filter = @{
        ExcludeTag = @()  # Include all tests by default
        Tag = @()  # No tag filtering by default
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
            'aither-core/core-runner.ps1',
            'aither-core/CoreApp.psm1',
            'aither-core/modules/Logging/*.ps1',
            'aither-core/modules/LabRunner/*.ps1',
            'aither-core/modules/TestingFramework/*.ps1',
            'aither-core/modules/ParallelExecution/*.ps1'
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