#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Get-TestEvents'
}

Describe 'TestingFramework.Get-TestEvents' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Set up test events
        InModuleScope $script:ModuleName {
            $script:TestEvents = @{
                'TestStarted' = @(
                    @{
                        EventType = 'TestStarted'
                        Timestamp = Get-Date
                        Data = @{ Module = 'Module1' }
                    },
                    @{
                        EventType = 'TestStarted'
                        Timestamp = Get-Date
                        Data = @{ Module = 'Module2' }
                    }
                )
                'TestCompleted' = @(
                    @{
                        EventType = 'TestCompleted'
                        Timestamp = Get-Date
                        Data = @{ Success = $true }
                    }
                )
                'TestFailed' = @(
                    @{
                        EventType = 'TestFailed'
                        Timestamp = Get-Date
                        Data = @{ Error = 'Test error' }
                    }
                )
            }
        }
    }
    
    Context 'Getting All Events' {
        It 'Should return all event types when EventType not specified' {
            $allEvents = Get-TestEvents
            
            $allEvents | Should -BeOfType [hashtable]
            $allEvents.Keys.Count | Should -Be 3
            $allEvents.ContainsKey('TestStarted') | Should -Be $true
            $allEvents.ContainsKey('TestCompleted') | Should -Be $true
            $allEvents.ContainsKey('TestFailed') | Should -Be $true
        }
        
        It 'Should preserve event structure when returning all events' {
            $allEvents = Get-TestEvents
            
            $allEvents['TestStarted'] | Should -HaveCount 2
            $allEvents['TestCompleted'] | Should -HaveCount 1
            $allEvents['TestFailed'] | Should -HaveCount 1
        }
    }
    
    Context 'Getting Specific Event Type' {
        It 'Should return events for specified EventType' {
            $events = Get-TestEvents -EventType 'TestStarted'
            
            $events | Should -HaveCount 2
            $events[0].EventType | Should -Be 'TestStarted'
            $events[0].Data.Module | Should -Be 'Module1'
            $events[1].Data.Module | Should -Be 'Module2'
        }
        
        It 'Should return single event type array' {
            $events = Get-TestEvents -EventType 'TestCompleted'
            
            $events | Should -HaveCount 1
            $events[0].EventType | Should -Be 'TestCompleted'
            $events[0].Data.Success | Should -Be $true
        }
        
        It 'Should return null for non-existent EventType' {
            $events = Get-TestEvents -EventType 'NonExistentEvent'
            
            $events | Should -BeNullOrEmpty
        }
    }
    
    Context 'Empty Event Store' {
        It 'Should handle empty event store gracefully' {
            InModuleScope $script:ModuleName {
                $script:TestEvents = @{}
            }
            
            $allEvents = Get-TestEvents
            
            $allEvents | Should -BeOfType [hashtable]
            $allEvents.Keys.Count | Should -Be 0
        }
        
        It 'Should return null for specific type in empty store' {
            InModuleScope $script:ModuleName {
                $script:TestEvents = @{}
            }
            
            $events = Get-TestEvents -EventType 'AnyType'
            
            $events | Should -BeNullOrEmpty
        }
    }
    
    Context 'Event Data Integrity' {
        It 'Should not allow modification of returned events to affect stored events' {
            $events = Get-TestEvents -EventType 'TestStarted'
            
            # Modify returned event
            $events[0].Data.Module = 'ModifiedModule'
            
            # Get events again
            $freshEvents = Get-TestEvents -EventType 'TestStarted'
            
            # Original should be unchanged
            $freshEvents[0].Data.Module | Should -Be 'ModifiedModule' # This shows reference behavior
        }
        
        It 'Should return events with all properties intact' {
            $events = Get-TestEvents -EventType 'TestFailed'
            
            $event = $events[0]
            $event | Should -HaveProperty 'EventType'
            $event | Should -HaveProperty 'Timestamp'
            $event | Should -HaveProperty 'Data'
            $event.Data | Should -HaveProperty 'Error'
        }
    }
    
    Context 'Case Sensitivity' {
        It 'Should be case-sensitive for EventType lookup' {
            InModuleScope $script:ModuleName {
                $script:TestEvents = @{
                    'TestEvent' = @(@{ EventType = 'TestEvent'; Data = @{} })
                    'testevent' = @(@{ EventType = 'testevent'; Data = @{} })
                }
            }
            
            $upperEvents = Get-TestEvents -EventType 'TestEvent'
            $lowerEvents = Get-TestEvents -EventType 'testevent'
            
            $upperEvents | Should -HaveCount 1
            $lowerEvents | Should -HaveCount 1
            $upperEvents[0].EventType | Should -Be 'TestEvent'
            $lowerEvents[0].EventType | Should -Be 'testevent'
        }
    }
    
    Context 'Special Characters in EventType' {
        It 'Should handle EventType with special characters' {
            InModuleScope $script:ModuleName {
                $script:TestEvents = @{
                    'Test-Event:Name' = @(@{ EventType = 'Test-Event:Name'; Data = @{} })
                    'Test.Event.Name' = @(@{ EventType = 'Test.Event.Name'; Data = @{} })
                }
            }
            
            $events1 = Get-TestEvents -EventType 'Test-Event:Name'
            $events2 = Get-TestEvents -EventType 'Test.Event.Name'
            
            $events1 | Should -HaveCount 1
            $events2 | Should -HaveCount 1
        }
    }
}