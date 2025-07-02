#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Write-TestLog'
}

Describe 'TestingFramework.Write-TestLog' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'When Logging module is available' {
        BeforeAll {
            # Mock successful Logging module import
            Mock Get-Module { @{ Name = 'Logging' } } -ModuleName $script:ModuleName
            Mock Write-CustomLog { } -ModuleName $script:ModuleName
            
            # Force re-evaluation of logging state
            InModuleScope $script:ModuleName {
                $script:loggingImported = $true
            }
        }
        
        It 'Should call Write-CustomLog with correct parameters' {
            Write-TestLog -Message "Test message" -Level "INFO"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -eq "Test message" -and
                $Level -eq "INFO"
            }
        }
        
        It 'Should use INFO as default level' {
            Write-TestLog -Message "Default level test"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Level -eq "INFO"
            }
        }
        
        It 'Should pass through different log levels' {
            $levels = @('INFO', 'WARN', 'ERROR', 'SUCCESS')
            
            foreach ($level in $levels) {
                Write-TestLog -Message "Level test" -Level $level
                
                Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                    $Level -eq $level
                }
            }
        }
    }
    
    Context 'When Logging module is NOT available' {
        BeforeAll {
            # Force fallback mode
            InModuleScope $script:ModuleName {
                $script:loggingImported = $false
            }
            
            # Mock Write-Host for fallback logging
            Mock Write-Host { } -ModuleName $script:ModuleName
            Mock Get-Date { [DateTime]::new(2025, 1, 15, 10, 30, 45) } -ModuleName $script:ModuleName
        }
        
        It 'Should use fallback logging with Write-Host' {
            Write-TestLog -Message "Fallback test" -Level "INFO"
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match '\[2025-01-15 10:30:45\]' -and
                $Object -match '\[INFO\]' -and
                $Object -match 'Fallback test'
            }
        }
        
        It 'Should use correct colors for different levels' {
            Write-TestLog -Message "Success" -Level "SUCCESS"
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $ForegroundColor -eq 'Green'
            }
            
            Write-TestLog -Message "Warning" -Level "WARN"
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $ForegroundColor -eq 'Yellow'
            }
            
            Write-TestLog -Message "Error" -Level "ERROR"
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $ForegroundColor -eq 'Red'
            }
            
            Write-TestLog -Message "Info" -Level "INFO"
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $ForegroundColor -eq 'White'
            }
        }
        
        It 'Should format timestamp correctly' {
            Write-TestLog -Message "Timestamp test"
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]'
            }
        }
        
        It 'Should handle empty messages' {
            Write-TestLog -Message ""
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match '\[INFO\] $'
            }
        }
    }
    
    Context 'Parameter Handling' {
        BeforeAll {
            InModuleScope $script:ModuleName {
                $script:loggingImported = $false
            }
            Mock Write-Host { } -ModuleName $script:ModuleName
        }
        
        It 'Should handle very long messages' {
            $longMessage = "A" * 1000
            
            { Write-TestLog -Message $longMessage } | Should -Not -Throw
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match $longMessage
            }
        }
        
        It 'Should handle special characters in messages' {
            $specialMessage = 'Test with $pecial ch@rs & symbols!'
            
            Write-TestLog -Message $specialMessage
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match [regex]::Escape($specialMessage)
            }
        }
        
        It 'Should handle null level (use default)' {
            Write-TestLog -Message "Null level test" -Level $null
            
            Should -Invoke Write-Host -ModuleName $script:ModuleName -ParameterFilter {
                $Object -match '\[INFO\]'
            }
        }
    }
}