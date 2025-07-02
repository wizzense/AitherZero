#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/Logging'
    $script:ModuleName = 'Logging'
    $script:FunctionName = 'Invoke-LogRotation'
}

Describe 'Logging.Invoke-LogRotation' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Store original configuration
        $script:OriginalConfig = InModuleScope $script:ModuleName {
            $script:LoggingConfig.Clone()
        }
    }
    
    AfterAll {
        # Restore original configuration
        InModuleScope $script:ModuleName {
            $script:LoggingConfig = $using:OriginalConfig
        }
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Set up test log configuration
        $script:TestLogDir = Join-Path $TestDrive 'logs'
        $script:TestLogPath = Join-Path $script:TestLogDir 'test.log'
        
        New-Item -Path $script:TestLogDir -ItemType Directory -Force | Out-Null
        
        InModuleScope $script:ModuleName -ArgumentList $script:TestLogPath {
            param($logPath)
            $script:LoggingConfig.LogFilePath = $logPath
            $script:LoggingConfig.MaxLogFiles = 3
        }
        
        # Mock Write-Host to suppress error output
        Mock Write-Host { } -ModuleName $script:ModuleName
    }
    
    Context 'Normal Operation' {
        It 'Should rotate current log file to .1' {
            # Create current log file
            "Current log content" | Set-Content $script:TestLogPath
            
            # Invoke rotation
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            # Check files
            Test-Path $script:TestLogPath | Should -Be $false
            Test-Path "$script:TestLogPath.1" | Should -Be $true
            Get-Content "$script:TestLogPath.1" | Should -Be "Current log content"
        }
        
        It 'Should cascade existing numbered logs' {
            # Create multiple log files
            "Current" | Set-Content $script:TestLogPath
            "Old 1" | Set-Content "$script:TestLogPath.1"
            "Old 2" | Set-Content "$script:TestLogPath.2"
            
            # Invoke rotation
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            # Check cascade
            Test-Path $script:TestLogPath | Should -Be $false
            Get-Content "$script:TestLogPath.1" | Should -Be "Current"
            Get-Content "$script:TestLogPath.2" | Should -Be "Old 1"
            Get-Content "$script:TestLogPath.3" | Should -Be "Old 2"
        }
        
        It 'Should delete logs beyond MaxLogFiles' {
            # Set max files to 2
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.MaxLogFiles = 2
            }
            
            # Create multiple log files
            "Current" | Set-Content $script:TestLogPath
            "Old 1" | Set-Content "$script:TestLogPath.1"
            "Old 2" | Set-Content "$script:TestLogPath.2"
            "Old 3" | Set-Content "$script:TestLogPath.3"
            
            # Invoke rotation
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            # Check that old files beyond limit are deleted
            Test-Path "$script:TestLogPath.1" | Should -Be $true
            Test-Path "$script:TestLogPath.2" | Should -Be $true
            Test-Path "$script:TestLogPath.3" | Should -Be $false
        }
        
        It 'Should handle non-existent current log file' {
            # Ensure no current log exists
            Remove-Item $script:TestLogPath -ErrorAction SilentlyContinue
            
            # Should not throw
            { InModuleScope $script:ModuleName { Invoke-LogRotation } } | Should -Not -Throw
        }
        
        It 'Should handle gaps in numbered sequence' {
            # Create files with gaps
            "Current" | Set-Content $script:TestLogPath
            "Old 2" | Set-Content "$script:TestLogPath.2"
            # Note: .1 is missing
            
            # Invoke rotation
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            # Should still work correctly
            Get-Content "$script:TestLogPath.1" | Should -Be "Current"
            Test-Path "$script:TestLogPath.2" | Should -Be $true
        }
    }
    
    Context 'Different File Extensions' {
        It 'Should handle .txt extension' {
            $txtPath = Join-Path $script:TestLogDir 'test.txt'
            InModuleScope $script:ModuleName -ArgumentList $txtPath {
                param($path)
                $script:LoggingConfig.LogFilePath = $path
            }
            
            "Text log" | Set-Content $txtPath
            
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            Test-Path "$txtPath.1" | Should -Be $true
            Get-Content "$txtPath.1" | Should -Be "Text log"
        }
        
        It 'Should handle files without extension' {
            $noExtPath = Join-Path $script:TestLogDir 'logfile'
            InModuleScope $script:ModuleName -ArgumentList $noExtPath {
                param($path)
                $script:LoggingConfig.LogFilePath = $path
            }
            
            "No ext log" | Set-Content $noExtPath
            
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            Test-Path "$noExtPath.1" | Should -Be $true
            Get-Content "$noExtPath.1" | Should -Be "No ext log"
        }
        
        It 'Should handle multiple dots in filename' {
            $multiDotPath = Join-Path $script:TestLogDir 'app.service.log'
            InModuleScope $script:ModuleName -ArgumentList $multiDotPath {
                param($path)
                $script:LoggingConfig.LogFilePath = $path
            }
            
            "Multi dot log" | Set-Content $multiDotPath
            
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            Test-Path "$multiDotPath.1" | Should -Be $true
            Get-Content "$multiDotPath.1" | Should -Be "Multi dot log"
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle Move-Item failures gracefully' {
            Mock Move-Item { throw "Access denied" } -ModuleName $script:ModuleName
            
            "Content" | Set-Content $script:TestLogPath
            
            # Should not throw
            { InModuleScope $script:ModuleName { Invoke-LogRotation } } | Should -Not -Throw
        }
        
        It 'Should handle Remove-Item failures gracefully' {
            Mock Remove-Item { throw "File in use" } -ModuleName $script:ModuleName
            
            # Create files beyond limit
            1..5 | ForEach-Object {
                "Old $_" | Set-Content "$script:TestLogPath.$_"
            }
            
            # Should not throw
            { InModuleScope $script:ModuleName { Invoke-LogRotation } } | Should -Not -Throw
        }
        
        It 'Should log errors to console' {
            Mock Move-Item { throw "Test error" } -ModuleName $script:ModuleName
            Mock Write-Host { } -ModuleName $script:ModuleName
            
            "Content" | Set-Content $script:TestLogPath
            
            InModuleScope $script:ModuleName { Invoke-LogRotation }
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match "\[LOG ERROR\]" -and $Object -match "Failed to rotate logs"
            }
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle MaxLogFiles = 0' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.MaxLogFiles = 0
            }
            
            "Current" | Set-Content $script:TestLogPath
            
            # Should still rotate current to .1
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            Test-Path "$script:TestLogPath.1" | Should -Be $true
        }
        
        It 'Should handle very large MaxLogFiles' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.MaxLogFiles = 1000
            }
            
            # Create a few files
            1..5 | ForEach-Object {
                "Old $_" | Set-Content "$script:TestLogPath.$_"
            }
            
            # Should not delete any
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            1..5 | ForEach-Object {
                Test-Path "$script:TestLogPath.$_" | Should -Be $true
            }
        }
        
        It 'Should handle special characters in log path' {
            $specialPath = Join-Path $script:TestLogDir 'log [special] & test!.log'
            InModuleScope $script:ModuleName -ArgumentList $specialPath {
                param($path)
                $script:LoggingConfig.LogFilePath = $path
            }
            
            "Special log" | Set-Content $specialPath
            
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            Test-Path "$specialPath.1" | Should -Be $true
        }
        
        It 'Should clean up files with numbers beyond MaxLogFiles' {
            InModuleScope $script:ModuleName {
                $script:LoggingConfig.MaxLogFiles = 3
            }
            
            # Create files with high numbers
            "Old 10" | Set-Content "$script:TestLogPath.10"
            "Old 99" | Set-Content "$script:TestLogPath.99"
            "Old 999" | Set-Content "$script:TestLogPath.999"
            
            InModuleScope $script:ModuleName {
                Invoke-LogRotation
            }
            
            # All should be deleted as they exceed MaxLogFiles
            Test-Path "$script:TestLogPath.10" | Should -Be $false
            Test-Path "$script:TestLogPath.99" | Should -Be $false
            Test-Path "$script:TestLogPath.999" | Should -Be $false
        }
    }
}