#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
}

Describe 'TestingFramework Performance Tests' -Tag 'Performance' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Helper function to measure execution time
        function Measure-ExecutionTime {
            param([scriptblock]$ScriptBlock)
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            & $ScriptBlock
            $stopwatch.Stop()
            return $stopwatch.ElapsedMilliseconds
        }
        
        # Create test module structure for performance testing
        $script:TestRoot = Join-Path $TestDrive 'PerfTestProject'
        $script:ModulesPath = Join-Path $script:TestRoot 'aither-core/modules'
        
        # Create multiple test modules
        1..10 | ForEach-Object {
            $modPath = Join-Path $script:ModulesPath "PerfModule$_"
            New-Item -Path $modPath -ItemType Directory -Force | Out-Null
            
            # Create module with functions
            $moduleContent = @"
function Get-PerfTest$_ {
    return "Performance Test Module $_"
}

function Test-Performance$_ {
    param([int]`$Count = 100)
    1..`$Count | ForEach-Object { `$null = `$_ * 2 }
}

Export-ModuleMember -Function Get-PerfTest$_, Test-Performance$_
"@
            Set-Content -Path "$modPath\PerfModule$_.psm1" -Value $moduleContent
        }
        
        # Set project root
        InModuleScope $script:ModuleName -ArgumentList $script:TestRoot {
            param($root)
            $script:ProjectRoot = $root
        }
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Module Discovery Performance' {
        It 'Should discover modules quickly (< 500ms for 10 modules)' {
            $time = Measure-ExecutionTime {
                $modules = Get-DiscoveredModules
            }
            
            $time | Should -BeLessThan 500
        }
        
        It 'Should scale linearly with module count' {
            # Create additional modules
            11..20 | ForEach-Object {
                $modPath = Join-Path $script:ModulesPath "ExtraModule$_"
                New-Item -Path $modPath -ItemType Directory -Force | Out-Null
                "function Test-Extra$_ { }" | Set-Content "$modPath\ExtraModule$_.psm1"
            }
            
            $time1 = Measure-ExecutionTime { Get-DiscoveredModules }
            
            # Create even more modules
            21..30 | ForEach-Object {
                $modPath = Join-Path $script:ModulesPath "MoreModule$_"
                New-Item -Path $modPath -ItemType Directory -Force | Out-Null
                "function Test-More$_ { }" | Set-Content "$modPath\MoreModule$_.psm1"
            }
            
            $time2 = Measure-ExecutionTime { Get-DiscoveredModules }
            
            # Time should not increase dramatically
            $ratio = $time2 / $time1
            $ratio | Should -BeLessThan 2.0
        }
    }
    
    Context 'Event System Performance' {
        BeforeEach {
            # Clear events
            InModuleScope $script:ModuleName {
                $script:TestEvents = @{}
            }
        }
        
        It 'Should publish events quickly (< 1ms per event)' {
            $eventCount = 1000
            
            $time = Measure-ExecutionTime {
                1..$eventCount | ForEach-Object {
                    Publish-TestEvent -EventType 'PerfTest' -Data @{ Index = $_ }
                }
            }
            
            $avgTimePerEvent = $time / $eventCount
            $avgTimePerEvent | Should -BeLessThan 1
        }
        
        It 'Should retrieve events efficiently' {
            # Publish many events
            1..100 | ForEach-Object {
                Publish-TestEvent -EventType "Type$_" -Data @{ Value = $_ }
            }
            
            1..10 | ForEach-Object {
                Publish-TestEvent -EventType 'CommonType' -Data @{ Value = $_ }
            }
            
            # Measure retrieval time
            $time1 = Measure-ExecutionTime { Get-TestEvents }
            $time2 = Measure-ExecutionTime { Get-TestEvents -EventType 'CommonType' }
            
            # Specific type retrieval should be faster than all
            $time2 | Should -BeLessThan $time1
            
            # Both should be fast
            $time1 | Should -BeLessThan 50
            $time2 | Should -BeLessThan 10
        }
    }
    
    Context 'Test Execution Performance' {
        It 'Should create execution plans quickly' {
            $modules = Get-DiscoveredModules
            
            $time = Measure-ExecutionTime {
                $plan = New-TestExecutionPlan -Modules $modules -TestSuite 'All'
            }
            
            $time | Should -BeLessThan 100
        }
        
        It 'Should handle configuration profiles efficiently' {
            $profiles = @('Development', 'CI', 'Production')
            
            $times = $profiles | ForEach-Object {
                Measure-ExecutionTime { Get-TestConfiguration -Profile $_ }
            }
            
            # All should be fast
            $times | ForEach-Object { $_ | Should -BeLessThan 10 }
        }
    }
    
    Context 'Provider Registration Performance' {
        BeforeEach {
            InModuleScope $script:ModuleName {
                $script:TestProviders = @{}
            }
        }
        
        It 'Should register many providers quickly' {
            $providerCount = 100
            
            $time = Measure-ExecutionTime {
                1..$providerCount | ForEach-Object {
                    Register-TestProvider -ModuleName "Provider$_" -TestTypes @('Unit', 'Integration') -Handler { }
                }
            }
            
            $avgTimePerProvider = $time / $providerCount
            $avgTimePerProvider | Should -BeLessThan 1
        }
        
        It 'Should filter providers efficiently' {
            # Register many providers
            1..50 | ForEach-Object {
                Register-TestProvider -ModuleName "UnitProvider$_" -TestTypes @('Unit') -Handler { }
            }
            
            1..30 | ForEach-Object {
                Register-TestProvider -ModuleName "IntProvider$_" -TestTypes @('Integration') -Handler { }
            }
            
            1..20 | ForEach-Object {
                Register-TestProvider -ModuleName "MultiProvider$_" -TestTypes @('Unit', 'Integration', 'E2E') -Handler { }
            }
            
            # Measure filtering performance
            $time1 = Measure-ExecutionTime { Get-RegisteredTestProviders }
            $time2 = Measure-ExecutionTime { Get-RegisteredTestProviders -TestType 'Unit' }
            $time3 = Measure-ExecutionTime { Get-RegisteredTestProviders -TestType 'E2E' }
            
            # All operations should be fast
            $time1 | Should -BeLessThan 50
            $time2 | Should -BeLessThan 50
            $time3 | Should -BeLessThan 50
        }
    }
    
    Context 'Report Generation Performance' {
        It 'Should generate reports quickly for many results' {
            # Create many test results
            $results = 1..50 | ForEach-Object {
                @{
                    Success = $_ % 2 -eq 0
                    Module = "Module$_"
                    Phase = 'Unit'
                    TestsRun = 10
                    TestsPassed = 8
                    TestsFailed = 2
                    Duration = 1.5
                    Details = @("Detail 1", "Detail 2")
                }
            }
            
            # Mock file operations for speed
            Mock Out-File { } -ModuleName $script:ModuleName
            Mock ConvertTo-Json { '{}' } -ModuleName $script:ModuleName
            
            $time = Measure-ExecutionTime {
                New-TestReport -Results $results -OutputPath $TestDrive -TestSuite 'Performance'
            }
            
            # Should handle 50 modules in under 200ms
            $time | Should -BeLessThan 200
        }
    }
    
    Context 'Memory Usage' {
        It 'Should not leak memory when publishing many events' {
            # Get initial memory
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Publish and clear events multiple times
            1..5 | ForEach-Object {
                1..1000 | ForEach-Object {
                    Publish-TestEvent -EventType 'MemTest' -Data @{ 
                        LargeData = 'X' * 1000 
                    }
                }
                
                # Clear events
                InModuleScope $script:ModuleName {
                    $script:TestEvents = @{}
                }
            }
            
            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            $finalMemory = [GC]::GetTotalMemory($false)
            
            # Memory increase should be minimal (< 10MB)
            $memoryIncrease = ($finalMemory - $initialMemory) / 1MB
            $memoryIncrease | Should -BeLessThan 10
        }
    }
    
    Context 'Concurrent Operations' {
        It 'Should handle concurrent event publishing' -Skip {
            # Skip this test as PowerShell modules aren't thread-safe by default
            # This would require special handling in the actual module
        }
    }
}