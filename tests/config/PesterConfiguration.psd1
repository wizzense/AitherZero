@{
    # Enhanced Pester 5.x Configuration for VS Code Integration with Bulletproof support
    Run = @{
        Path = @(
            'tests/unit',
            'tests/integration',
            'tests/pester',
            'tests/unit/modules/CoreApp/NonInteractiveMode.Tests.ps1',
            'tests/unit/modules/CoreApp/BulletproofCoreRunner.Tests.ps1'
        )
        Exit = $false
        PassThru = $true
        Throw = $false
    }

    Filter = @{
        ExcludeTag = @('Slow', 'E2E')  # Include Integration and Bulletproof tests
        Tag = @('Unit', 'Integration', 'Bulletproof', 'CoreApp', 'NonInteractive')
    }

    Output = @{
        Verbosity = 'Detailed'
        CIFormat = 'Auto'
        StackTraceVerbosity = 'Full'
    }

    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = 'tests/results/TestResults.xml'
        TestSuiteName = 'Aitherium Infrastructure Automation - Enhanced'
        OutputEncoding = 'UTF8'
    }

    CodeCoverage = @{
        Enabled = $true  # Re-enabled with bulletproof optimizations
        Path = @(
            'aither-core/core-runner.ps1',
            'aither-core/CoreApp.psm1',
            'aither-core/modules/Logging/*.ps1',
            'aither-core/modules/LabRunner/*.ps1',
            'aither-core/modules/TestingFramework/*.ps1'
        )
        OutputFormat = 'JaCoCo'
        OutputPath = 'tests/results/coverage.xml'
        OutputEncoding = 'UTF8'
        UseBreakpoints = $false
        SingleHitBreakpoints = $true
    }

    Should = @{
        ErrorAction = 'Stop'  # Strict error handling for bulletproof testing
    }

    Debug = @{
        ShowFullErrors = $true
        WriteDebugMessages = $true
        WriteDebugMessagesFrom = @('Bulletproof', 'CoreApp', 'NonInteractive')
        ReturnRawResultObject = $true
        WriteVSCodeMarker = $true
    }

    # Enhanced settings for bulletproof testing
    Custom = @{
        BulletproofMode = $true
        NonInteractiveValidation = $true
        ExitCodeTesting = $true
        LogFileValidation = $true
        PerformanceBenchmarks = $true
    }
}