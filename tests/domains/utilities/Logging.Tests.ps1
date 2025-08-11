#Requires -Version 7.0

BeforeAll {
    # Import the core module which loads all domains
    $projectRoot = Split-Path -Parent -Path $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    Import-Module (Join-Path $projectRoot "AitherZero.psm1") -Force
}

Describe "Logging Module Tests" {
    BeforeEach {
        # Set test log path
        $script:TestLogPath = Join-Path $TestDrive "logs"
        
        # Create the log directory
        if (-not (Test-Path $script:TestLogPath)) {
            New-Item -Path $script:TestLogPath -ItemType Directory -Force | Out-Null
        }
        
        Set-Variable -Name LogPath -Value $script:TestLogPath -Scope Script -Option AllScope -Force
        
        # Reset log settings
        Set-LogLevel -Level "Information"
        Set-LogTargets -Targets @("Console")
    }
    
    Context "Write-CustomLog" {
        It "Should write log messages at appropriate levels" {
            Mock Write-Host {} -ModuleName Logging
            
            Write-CustomLog -Level "Information" -Message "Test message"
            
            Should -Invoke Write-Host -ModuleName Logging -Times 1
        }
        
        It "Should respect log level filtering" {
            Mock Write-Host {} -ModuleName Logging
            
            Set-LogLevel -Level "Warning"
            
            Write-CustomLog -Level "Debug" -Message "Debug message"
            Write-CustomLog -Level "Information" -Message "Info message"
            Write-CustomLog -Level "Warning" -Message "Warning message"
            Write-CustomLog -Level "Error" -Message "Error message"

            # Only Warning and Error should be logged
            Should -Invoke Write-Host -ModuleName Logging -Times 3 # Including the Set-LogLevel message
        }
        
        It "Should include structured data when provided" {
            Mock Write-Host {
                param($Message)
                $script:LastLogMessage = $Message
            } -ModuleName Logging
            
            Write-CustomLog -Level "Information" -Message "Test" -Data @{ Key = "Value" }
            
            $script:LastLogMessage | Should -Match "Data:"
            $script:LastLogMessage | Should -Match "Key"
            $script:LastLogMessage | Should -Match "Value"
        }
        
        It "Should include source information" {
            Mock Write-Host {
                param($Message)
                $script:LastLogMessage = $Message
            } -ModuleName Logging
            
            Write-CustomLog -Level "Information" -Message "Test" -Source "TestSource"
            
            $script:LastLogMessage | Should -Match "TestSource"
        }
    }
    
    Context "Log Targets" {
        It "Should write to file when File target is enabled" {
            Set-LogTargets -Targets @("File")
            
            Write-CustomLog -Level "Information" -Message "File test message"
            
            $logFile = Get-ChildItem -Path $script:TestLogPath -Filter "*.log" | Select-Object -First 1
            $logFile | Should -Not -BeNullOrEmpty
            
            $content = Get-Content $logFile.FullName -Raw
            $content | Should -Match "File test message"
        }
        
        It "Should write JSON when Json target is enabled" {
            Set-LogTargets -Targets @("Json")
            
            Write-CustomLog -Level "Information" -Message "JSON test message"
            
            $jsonFile = Get-ChildItem -Path $script:TestLogPath -Filter "*.json" | Select-Object -First 1
            $jsonFile | Should -Not -BeNullOrEmpty
            
            $content = Get-Content $jsonFile.FullName -Raw
            $json = $content | ConvertFrom-Json
            $json.Message | Should -Be "JSON test message"
            $json.Level | Should -Be "Information"
        }
        
        It "Should write to multiple targets" {
            Mock Write-Host {} -ModuleName Logging
            Set-LogTargets -Targets @("Console", "File")
            
            Write-CustomLog -Level "Information" -Message "Multi-target test"
            
            Should -Invoke Write-Host -ModuleName Logging -Times 2 # Set-LogTargets + Write-CustomLog
            
            $logFile = Get-ChildItem -Path $script:TestLogPath -Filter "*.log" | Select-Object -First 1
            $logFile | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Performance Tracking" {
        It "Should track performance duration" {
            Mock Write-Host {} -ModuleName Logging
            
            Start-PerformanceTrace -Name "TestOperation" -Description "Testing performance"
            
            Start-Sleep -Milliseconds 100
            
            $duration = Stop-PerformanceTrace -Name "TestOperation"
            
            $duration.TotalMilliseconds | Should -BeGreaterThan 90
            $duration.TotalMilliseconds | Should -BeLessThan 200
        }
        
        It "Should handle missing performance trace gracefully" {
            Mock Write-Host {} -ModuleName Logging
            
            { Stop-PerformanceTrace -Name "NonExistent" } | Should -Not -Throw
        }
    }
    
    Context "Log Rotation" {
        It "Should rotate logs when size limit is reached" {
            Set-LogTargets -Targets @("File")
            Enable-LogRotation -MaxSizeMB 0.001 -MaxFiles 3 # Very small size to trigger rotation

            # Write enough data to trigger rotation
            1..100 | ForEach-Object {
                Write-CustomLog -Level "Information" -Message ("Large message " * 100)
            }
            
            $logFiles = Get-ChildItem -Path $script:TestLogPath -Filter "*.log"
            $logFiles.Count | Should -BeGreaterThan 1
        }
    }
    
    Context "Log Querying" {
        It "Should query logs by time range" {
            Set-LogTargets -Targets @("File")
            
            $startTime = Get-Date
            Write-CustomLog -Level "Information" -Message "Message 1"
            Start-Sleep -Milliseconds 100
            Write-CustomLog -Level "Warning" -Message "Message 2"
            
            $logs = Get-Logs -StartTime $startTime
            
            $logs.Count | Should -Be 2
            $logs[0].Message | Should -Match "Message 1"
            $logs[1].Message | Should -Match "Message 2"
        }
        
        It "Should filter logs by level" {
            Set-LogTargets -Targets @("File")
            
            Write-CustomLog -Level "Information" -Message "Info message"
            Write-CustomLog -Level "Warning" -Message "Warning message"
            Write-CustomLog -Level "Error" -Message "Error message"
            
            $warnings = Get-Logs -Level "WARNING"
            
            $warnings.Count | Should -Be 1
            $warnings[0].Message | Should -Match "Warning message"
        }
        
        It "Should filter logs by pattern" {
            Set-LogTargets -Targets @("File")
            
            Write-CustomLog -Level "Information" -Message "Test pattern ABC"
            Write-CustomLog -Level "Information" -Message "Different message"
            Write-CustomLog -Level "Information" -Message "Another ABC test"
            
            $filtered = Get-Logs -Pattern "ABC"
            
            $filtered.Count | Should -Be 2
        }
    }
    
    Context "Log Cleanup" {
        It "Should clean old log files" {
            # Create old log files
            $oldFile1 = Join-Path $script:TestLogPath "old-log-1.log"
            $oldFile2 = Join-Path $script:TestLogPath "old-log-2.log"
            $recentFile = Join-Path $script:TestLogPath "recent.log"
            
            New-Item -ItemType Directory -Path $script:TestLogPath -Force | Out-Null
            
            Set-Content -Path $oldFile1 -Value "Old log 1"
            Set-Content -Path $oldFile2 -Value "Old log 2"
            Set-Content -Path $recentFile -Value "Recent log"

            # Set old timestamps
            (Get-Item $oldFile1).LastWriteTime = (Get-Date).AddDays(-10)
            (Get-Item $oldFile2).LastWriteTime = (Get-Date).AddDays(-8)
            
            Clear-Logs -DaysToKeep 7 -Confirm:$false
            
            Test-Path $oldFile1 | Should -Be $false
            Test-Path $oldFile2 | Should -Be $false
            Test-Path $recentFile | Should -Be $true
        }
    }
    
    AfterAll {
        # Clean up
        Remove-Module aitherzero -Force -ErrorAction SilentlyContinue
    }
}