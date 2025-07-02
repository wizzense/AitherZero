#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Publish-TestEvent'
}

Describe 'TestingFramework.Publish-TestEvent' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Get-Date { [DateTime]::new(2025, 1, 15, 10, 30, 45) } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Clear TestEvents before each test
        InModuleScope $script:ModuleName {
            $script:TestEvents = @{}
        }
    }
    
    Context 'Parameter Validation' {
        It 'Should require EventType parameter' {
            { Publish-TestEvent } | Should -Throw
        }
        
        It 'Should accept EventType without Data' {
            { Publish-TestEvent -EventType 'TestStarted' } | Should -Not -Throw
        }
        
        It 'Should accept EventType with Data' {
            { Publish-TestEvent -EventType 'TestCompleted' -Data @{ Module = 'Test' } } | Should -Not -Throw
        }
    }
    
    Context 'Event Publishing' {
        It 'Should create new event type entry if it does not exist' {
            Publish-TestEvent -EventType 'NewEventType'
            
            $events = InModuleScope $script:ModuleName {
                $script:TestEvents
            }
            
            $events.ContainsKey('NewEventType') | Should -Be $true
            $events['NewEventType'] | Should -HaveCount 1
        }
        
        It 'Should append to existing event type' {
            Publish-TestEvent -EventType 'TestEvent'
            Publish-TestEvent -EventType 'TestEvent'
            
            $events = InModuleScope $script:ModuleName {
                $script:TestEvents
            }
            
            $events['TestEvent'] | Should -HaveCount 2
        }
        
        It 'Should store event with correct structure' {
            $testData = @{ Module = 'TestModule'; Success = $true }
            
            Publish-TestEvent -EventType 'ModuleTest' -Data $testData
            
            $events = InModuleScope $script:ModuleName {
                $script:TestEvents['ModuleTest']
            }
            
            $event = $events[0]
            $event.EventType | Should -Be 'ModuleTest'
            $event.Timestamp | Should -Be ([DateTime]::new(2025, 1, 15, 10, 30, 45))
            $event.Data | Should -BeOfType [hashtable]
            $event.Data.Module | Should -Be 'TestModule'
            $event.Data.Success | Should -Be $true
        }
        
        It 'Should use empty hashtable when Data not provided' {
            Publish-TestEvent -EventType 'EmptyDataEvent'
            
            $events = InModuleScope $script:ModuleName {
                $script:TestEvents['EmptyDataEvent']
            }
            
            $event = $events[0]
            $event.Data | Should -BeOfType [hashtable]
            $event.Data.Count | Should -Be 0
        }
    }
    
    Context 'Multiple Event Types' {
        It 'Should maintain separate arrays for different event types' {
            Publish-TestEvent -EventType 'Type1' -Data @{ Value = 1 }
            Publish-TestEvent -EventType 'Type2' -Data @{ Value = 2 }
            Publish-TestEvent -EventType 'Type1' -Data @{ Value = 3 }
            
            $events = InModuleScope $script:ModuleName {
                $script:TestEvents
            }
            
            $events.Keys.Count | Should -Be 2
            $events['Type1'] | Should -HaveCount 2
            $events['Type2'] | Should -HaveCount 1
            $events['Type1'][0].Data.Value | Should -Be 1
            $events['Type1'][1].Data.Value | Should -Be 3
            $events['Type2'][0].Data.Value | Should -Be 2
        }
    }
    
    Context 'Logging' {
        It 'Should log event publication' {
            Publish-TestEvent -EventType 'TestEvent'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Published event: TestEvent' -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should include emoji in log message' {
            Publish-TestEvent -EventType 'TestEvent'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match '📡'
            }
        }
    }
    
    Context 'Data Handling' {
        It 'Should handle complex nested data structures' {
            $complexData = @{
                Module = 'TestModule'
                Results = @(
                    @{ Test = 'Test1'; Passed = $true },
                    @{ Test = 'Test2'; Passed = $false }
                )
                Metadata = @{
                    Duration = 5.5
                    Platform = 'Windows'
                }
            }
            
            { Publish-TestEvent -EventType 'ComplexEvent' -Data $complexData } | Should -Not -Throw
            
            $events = InModuleScope $script:ModuleName {
                $script:TestEvents['ComplexEvent']
            }
            
            $event = $events[0]
            $event.Data.Results | Should -HaveCount 2
            $event.Data.Metadata.Duration | Should -Be 5.5
        }
        
        It 'Should not modify original data hashtable' {
            $originalData = @{ Value = 'Original' }
            
            Publish-TestEvent -EventType 'DataTest' -Data $originalData
            
            # Modify stored data
            $events = InModuleScope $script:ModuleName {
                $script:TestEvents['DataTest'][0].Data.Value = 'Modified'
                $script:TestEvents['DataTest']
            }
            
            # Original should remain unchanged
            $originalData.Value | Should -Be 'Original'
        }
    }
    
    Context 'Event Order' {
        It 'Should preserve order of published events' {
            1..5 | ForEach-Object {
                Publish-TestEvent -EventType 'OrderTest' -Data @{ Index = $_ }
            }
            
            $events = InModuleScope $script:ModuleName {
                $script:TestEvents['OrderTest']
            }
            
            $events | Should -HaveCount 5
            for ($i = 0; $i -lt 5; $i++) {
                $events[$i].Data.Index | Should -Be ($i + 1)
            }
        }
    }
}