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
            'aither-core/*.ps1',
            'aither-core/*.psm1',
            'aither-core/modules/*/*.ps1',
            'aither-core/modules/*/*.psm1',
            'aither-core/shared/*.ps1'
        )
        ExcludeTests = $true
        RecursePaths = $true
        CoveragePercentTarget = 80  # Target 80% minimum coverage
        OutputFormat = 'JaCoCo'  # Primary format for CI/CD
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
        # Code coverage thresholds
        CoverageThresholds = @{
            Functions = 80  # 80% function coverage required
            Lines = 75      # 75% line coverage required
            Commands = 70   # 70% command coverage required
        }
        # Additional coverage formats for reporting
        AdditionalCoverageFormats = @('CoverageGutters', 'Cobertura')
    }
}