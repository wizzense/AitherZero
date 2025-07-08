#Requires -Modules Pester

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot ".." "ModuleCommunication.psm1"
    Import-Module $ModulePath -Force
    
    # Import required modules
    $LoggingPath = Join-Path $PSScriptRoot ".." ".." "Logging" "Logging.psm1"
    if (Test-Path $LoggingPath) {
        Import-Module $LoggingPath -Force
    } else {
        # Mock Write-CustomLog if Logging module not available
        function Write-CustomLog {
            param($Level, $Message)
            Write-Host "[$Level] $Message"
        }
    }
}

Describe "ModuleCommunication Module Tests" {
    
    Context "Module Loading" {
        It "Should load without errors" {
            Get-Module ModuleCommunication | Should -Not -BeNullOrEmpty
        }
        
        It "Should export all expected functions" {
            $ExportedFunctions = (Get-Module ModuleCommunication).ExportedFunctions.Keys
            $ExpectedFunctions = @(
                'Submit-ModuleMessage', 'Register-ModuleMessageHandler', 'Unsubscribe-ModuleMessage',
                'Get-MessageSubscriptions', 'Clear-MessageQueue', 'New-MessageChannel',
                'Remove-MessageChannel', 'Get-MessageChannels', 'Test-MessageChannel',
                'Register-ModuleAPI', 'Unregister-ModuleAPI', 'Invoke-ModuleAPI',
                'Get-ModuleAPIs', 'Test-ModuleAPI', 'Add-APIMiddleware',
                'Remove-APIMiddleware', 'Get-APIMiddleware', 'Submit-ModuleEvent',
                'Register-ModuleEventHandler', 'Unsubscribe-ModuleEvent', 'Get-ModuleEvents',
                'Clear-EventHistory', 'Get-CommunicationMetrics', 'Reset-CommunicationMetrics',
                'Enable-MessageTracing', 'Disable-MessageTracing', 'Test-ModuleCommunication',
                'Get-CommunicationStatus', 'Start-MessageProcessor', 'Stop-MessageProcessor'
            )
            
            foreach ($Function in $ExpectedFunctions) {
                $ExportedFunctions | Should -Contain $Function
            }
        }
        
        It "Should have backward compatibility aliases" {
            $ExportedAliases = (Get-Module ModuleCommunication).ExportedAliases.Keys
            @('Publish-ModuleMessage', 'Subscribe-ModuleMessage', 'Publish-ModuleEvent', 'Subscribe-ModuleEvent') | ForEach-Object {
                $ExportedAliases | Should -Contain $_
            }
        }
    }
    
    Context "Message Bus Operations" {
        BeforeEach {
            # Clean up any existing test channels
            $TestChannels = @('TestChannel', 'TestChannel2', 'IntegrationTest')
            foreach ($Channel in $TestChannels) {
                try {
                    Remove-MessageChannel -Name $Channel -Force -ErrorAction SilentlyContinue
                } catch { }
            }
        }
        
        AfterEach {
            # Clean up test channels
            $TestChannels = @('TestChannel', 'TestChannel2', 'IntegrationTest')
            foreach ($Channel in $TestChannels) {
                try {
                    Remove-MessageChannel -Name $Channel -Force -ErrorAction SilentlyContinue
                } catch { }
            }
        }
        
        It "Should create a new message channel" {
            $Channel = New-MessageChannel -Name "TestChannel" -Description "Test channel"
            $Channel | Should -Not -BeNullOrEmpty
            $Channel.Name | Should -Be "TestChannel"
            $Channel.Description | Should -Be "Test channel"
        }
        
        It "Should get message channels" {
            New-MessageChannel -Name "TestChannel" -Description "Test channel"
            $Channels = Get-MessageChannels
            $Channels | Where-Object { $_.Name -eq "TestChannel" } | Should -Not -BeNullOrEmpty
        }
        
        It "Should test message channel connectivity" {
            New-MessageChannel -Name "TestChannel" -Description "Test channel"
            $TestResult = Test-MessageChannel -Name "TestChannel" -Timeout 10
            $TestResult | Should -Not -BeNullOrEmpty
            $TestResult.Channel | Should -Be "TestChannel"
        }
        
        It "Should remove a message channel" {
            New-MessageChannel -Name "TestChannel" -Description "Test channel"
            $Result = Remove-MessageChannel -Name "TestChannel" -Force
            $Result.Success | Should -Be $true
        }
        
        It "Should register and unregister message handlers" {
            New-MessageChannel -Name "TestChannel" -Description "Test channel"
            
            $Subscription = Register-ModuleMessageHandler -Channel "TestChannel" -MessageType "Test" -Handler {
                param($Message)
                # Test handler
            }
            
            $Subscription | Should -Not -BeNullOrEmpty
            $Subscription.SubscriptionId | Should -Not -BeNullOrEmpty
            
            $Result = Unsubscribe-ModuleMessage -SubscriptionId $Subscription.SubscriptionId
            $Result.Success | Should -Be $true
        }
        
        It "Should send and receive messages" {
            New-MessageChannel -Name "TestChannel" -Description "Test channel"
            
            $ReceivedMessage = $null
            $Subscription = Register-ModuleMessageHandler -Channel "TestChannel" -MessageType "Test" -Handler {
                param($Message)
                $script:ReceivedMessage = $Message
            }
            
            $MessageId = Submit-ModuleMessage -Channel "TestChannel" -MessageType "Test" -Data @{Content = "Hello World"}
            $MessageId | Should -Not -BeNullOrEmpty
            
            # Wait for message delivery
            $Timeout = (Get-Date).AddSeconds(5)
            while ((Get-Date) -lt $Timeout -and -not $script:ReceivedMessage) {
                Start-Sleep -Milliseconds 100
            }
            
            $script:ReceivedMessage | Should -Not -BeNullOrEmpty
            $script:ReceivedMessage.Data.Content | Should -Be "Hello World"
            
            Unsubscribe-ModuleMessage -SubscriptionId $Subscription.SubscriptionId
        }
        
        It "Should get message subscriptions" {
            New-MessageChannel -Name "TestChannel" -Description "Test channel"
            
            $Subscription = Register-ModuleMessageHandler -Channel "TestChannel" -MessageType "Test" -Handler {
                param($Message)
                # Test handler
            }
            
            $Subscriptions = Get-MessageSubscriptions -Channel "TestChannel"
            $Subscriptions | Should -Not -BeNullOrEmpty
            $Subscriptions | Where-Object { $_.Id -eq $Subscription.SubscriptionId } | Should -Not -BeNullOrEmpty
            
            Unsubscribe-ModuleMessage -SubscriptionId $Subscription.SubscriptionId
        }
        
        It "Should clear message queue" {
            $Result = Clear-MessageQueue -Force
            $Result | Should -Not -BeNullOrEmpty
            $Result.Success | Should -Be $true
        }
    }
    
    Context "API Registry Operations" {
        BeforeEach {
            # Clean up any existing test APIs
            try {
                Unregister-ModuleAPI -ModuleName "TestModule" -APIName "TestAPI" -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        AfterEach {
            # Clean up test APIs
            try {
                Unregister-ModuleAPI -ModuleName "TestModule" -APIName "TestAPI" -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        It "Should register a module API" {
            $API = Register-ModuleAPI -ModuleName "TestModule" -APIName "TestAPI" -Handler {
                param($TestParam)
                return @{Success = $true; Echo = $TestParam}
            } -Parameters @{
                TestParam = @{Type = "string"; Required = $true; Description = "Test parameter"}
            }
            
            $API | Should -Not -BeNullOrEmpty
            $API.ModuleName | Should -Be "TestModule"
            $API.APIName | Should -Be "TestAPI"
        }
        
        It "Should get module APIs" {
            Register-ModuleAPI -ModuleName "TestModule" -APIName "TestAPI" -Handler {
                param($TestParam)
                return @{Success = $true; Echo = $TestParam}
            } -Parameters @{
                TestParam = @{Type = "string"; Required = $true}
            }
            
            $APIs = Get-ModuleAPIs -ModuleName "TestModule"
            $APIs | Should -Not -BeNullOrEmpty
            $APIs | Where-Object { $_.APIName -eq "TestAPI" } | Should -Not -BeNullOrEmpty
        }
        
        It "Should invoke a module API" {
            Register-ModuleAPI -ModuleName "TestModule" -APIName "TestAPI" -Handler {
                param($TestParam)
                return @{Success = $true; Echo = $TestParam}
            } -Parameters @{
                TestParam = @{Type = "string"; Required = $true}
            }
            
            $Result = Invoke-ModuleAPI -Module "TestModule" -Operation "TestAPI" -Parameters @{TestParam = "Hello"}
            $Result | Should -Not -BeNullOrEmpty
            $Result.Success | Should -Be $true
            $Result.Echo | Should -Be "Hello"
        }
        
        It "Should test a module API" {
            Register-ModuleAPI -ModuleName "TestModule" -APIName "TestAPI" -Handler {
                param($TestParam)
                return @{Success = $true; Echo = $TestParam}
            } -Parameters @{
                TestParam = @{Type = "string"; Required = $true}
            }
            
            $TestResult = Test-ModuleAPI -ModuleName "TestModule" -APIName "TestAPI" -TestParameters @{TestParam = "Test"}
            $TestResult | Should -Not -BeNullOrEmpty
            $TestResult.Success | Should -Be $true
        }
        
        It "Should unregister a module API" {
            Register-ModuleAPI -ModuleName "TestModule" -APIName "TestAPI" -Handler {
                param($TestParam)
                return @{Success = $true; Echo = $TestParam}
            } -Parameters @{
                TestParam = @{Type = "string"; Required = $true}
            }
            
            $Result = Unregister-ModuleAPI -ModuleName "TestModule" -APIName "TestAPI" -Force
            $Result.Success | Should -Be $true
        }
    }
    
    Context "Event System Operations" {
        BeforeEach {
            # Clean up any existing event subscriptions
            try {
                Clear-EventHistory -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        It "Should send and receive events" {
            $ReceivedEvent = $null
            $Subscription = Register-ModuleEventHandler -EventName "TestEvent" -Handler {
                param($Event)
                $script:ReceivedEvent = $Event
            }
            
            $EventId = Submit-ModuleEvent -EventName "TestEvent" -EventData @{Message = "Test Event"}
            $EventId | Should -Not -BeNullOrEmpty
            
            # Wait for event delivery
            $Timeout = (Get-Date).AddSeconds(5)
            while ((Get-Date) -lt $Timeout -and -not $script:ReceivedEvent) {
                Start-Sleep -Milliseconds 100
            }
            
            $script:ReceivedEvent | Should -Not -BeNullOrEmpty
            $script:ReceivedEvent.Data.Message | Should -Be "Test Event"
            
            Unsubscribe-ModuleEvent -SubscriptionId $Subscription.SubscriptionId
        }
        
        It "Should get module events from history" {
            Submit-ModuleEvent -EventName "TestEvent" -EventData @{Message = "Test Event"}
            
            $Events = Get-ModuleEvents -EventName "TestEvent"
            $Events | Should -Not -BeNullOrEmpty
            $Events | Where-Object { $_.Name -eq "TestEvent" } | Should -Not -BeNullOrEmpty
        }
        
        It "Should unsubscribe from events" {
            $Subscription = Register-ModuleEventHandler -EventName "TestEvent" -Handler {
                param($Event)
                # Test handler
            }
            
            $Result = Unsubscribe-ModuleEvent -SubscriptionId $Subscription.SubscriptionId
            $Result.Success | Should -Be $true
        }
        
        It "Should clear event history" {
            Submit-ModuleEvent -EventName "TestEvent" -EventData @{Message = "Test Event"}
            
            $Result = Clear-EventHistory -Force
            $Result.Success | Should -Be $true
            $Result.ClearedCount | Should -BeGreaterThan 0
        }
    }
    
    Context "Middleware Operations" {
        BeforeEach {
            # Clean up any existing test middleware
            try {
                Remove-APIMiddleware -Name "TestMiddleware" -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        AfterEach {
            # Clean up test middleware
            try {
                Remove-APIMiddleware -Name "TestMiddleware" -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        
        It "Should add API middleware" {
            $Middleware = Add-APIMiddleware -Name "TestMiddleware" -Handler {
                param($Context, $Next)
                $Context.Metadata.MiddlewareExecuted = $true
                return & $Next $Context
            }
            
            $Middleware | Should -Not -BeNullOrEmpty
            $Middleware.Name | Should -Be "TestMiddleware"
        }
        
        It "Should get API middleware" {
            Add-APIMiddleware -Name "TestMiddleware" -Handler {
                param($Context, $Next)
                return & $Next $Context
            }
            
            $Middleware = Get-APIMiddleware -Name "TestMiddleware"
            $Middleware | Should -Not -BeNullOrEmpty
            $Middleware.Name | Should -Be "TestMiddleware"
        }
        
        It "Should remove API middleware" {
            Add-APIMiddleware -Name "TestMiddleware" -Handler {
                param($Context, $Next)
                return & $Next $Context
            }
            
            $Result = Remove-APIMiddleware -Name "TestMiddleware" -Force
            $Result.Success | Should -Be $true
        }
    }
    
    Context "Performance and Monitoring" {
        It "Should get communication metrics" {
            $Metrics = Get-CommunicationMetrics
            $Metrics | Should -Not -BeNullOrEmpty
            $Metrics.MessageBus | Should -Not -BeNullOrEmpty
            $Metrics.API | Should -Not -BeNullOrEmpty
        }
        
        It "Should reset communication metrics" {
            $Result = Reset-CommunicationMetrics -Force
            $Result.Success | Should -Be $true
        }
        
        It "Should get communication status" {
            $Status = Get-CommunicationStatus
            $Status | Should -Not -BeNullOrEmpty
            $Status.OverallHealth | Should -BeIn @('Healthy', 'Warning', 'Unhealthy')
        }
        
        It "Should enable and disable message tracing" {
            $EnableResult = Enable-MessageTracing -Level "Basic"
            $EnableResult.Success | Should -Be $true
            
            $DisableResult = Disable-MessageTracing
            $DisableResult.Success | Should -Be $true
        }
    }
    
    Context "Message Processor Operations" {
        It "Should start and stop message processor" {
            # Stop if running
            try { Stop-MessageProcessor -Force } catch { }
            
            $StartResult = Start-MessageProcessor
            $StartResult.Success | Should -Be $true
            
            $StopResult = Stop-MessageProcessor -Timeout 5
            $StopResult.Success | Should -Be $true
        }
    }
    
    Context "Integration Tests" {
        It "Should run basic communication tests" {
            $TestResult = Test-ModuleCommunication -TestType Basic
            $TestResult | Should -Not -BeNullOrEmpty
            $TestResult.PassRate | Should -BeGreaterThan 0
        }
        
        It "Should handle end-to-end message flow" {
            # Create channel
            New-MessageChannel -Name "IntegrationTest" -Description "Integration test channel"
            
            # Register API that publishes events
            Register-ModuleAPI -ModuleName "IntegrationTest" -APIName "ProcessData" -Handler {
                param($Data)
                
                # Send event about processing
                Submit-ModuleEvent -EventName "DataProcessing" -EventData @{
                    Data = $Data
                    ProcessedAt = Get-Date
                }
                
                return @{Success = $true; ProcessedData = $Data.ToUpper()}
            } -Parameters @{
                Data = @{Type = "string"; Required = $true}
            }
            
            # Register event handler
            $EventReceived = $false
            $Subscription = Register-ModuleEventHandler -EventName "DataProcessing" -Handler {
                param($Event)
                $script:EventReceived = $true
            }
            
            # Call API
            $Result = Invoke-ModuleAPI -Module "IntegrationTest" -Operation "ProcessData" -Parameters @{Data = "hello"}
            
            # Wait for event
            $Timeout = (Get-Date).AddSeconds(5)
            while ((Get-Date) -lt $Timeout -and -not $script:EventReceived) {
                Start-Sleep -Milliseconds 100
            }
            
            # Verify results
            $Result.Success | Should -Be $true
            $Result.ProcessedData | Should -Be "HELLO"
            $script:EventReceived | Should -Be $true
            
            # Cleanup
            Unsubscribe-ModuleEvent -SubscriptionId $Subscription.SubscriptionId
            Unregister-ModuleAPI -ModuleName "IntegrationTest" -APIName "ProcessData" -Force
            Remove-MessageChannel -Name "IntegrationTest" -Force
        }
    }
    
    Context "Error Handling" {
        It "Should handle non-existent API calls gracefully" {
            { Invoke-ModuleAPI -Module "NonExistent" -Operation "NonExistent" -Parameters @{} } | Should -Throw
        }
        
        It "Should handle invalid channel operations gracefully" {
            { Test-MessageChannel -Name "NonExistentChannel" } | Should -Not -Throw
        }
        
        It "Should handle parameter validation errors" {
            Register-ModuleAPI -ModuleName "ValidationTest" -APIName "TestAPI" -Handler {
                param($RequiredParam)
                return @{Success = $true}
            } -Parameters @{
                RequiredParam = @{Type = "string"; Required = $true}
            }
            
            { Invoke-ModuleAPI -Module "ValidationTest" -Operation "TestAPI" -Parameters @{} } | Should -Throw
            
            Unregister-ModuleAPI -ModuleName "ValidationTest" -APIName "TestAPI" -Force
        }
    }
}

AfterAll {
    # Clean up any remaining test resources
    $TestChannels = @('TestChannel', 'TestChannel2', 'IntegrationTest')
    foreach ($Channel in $TestChannels) {
        try {
            Remove-MessageChannel -Name $Channel -Force -ErrorAction SilentlyContinue
        } catch { }
    }
    
    $TestAPIs = @(
        @{Module = "TestModule"; API = "TestAPI"},
        @{Module = "IntegrationTest"; API = "ProcessData"},
        @{Module = "ValidationTest"; API = "TestAPI"}
    )
    foreach ($API in $TestAPIs) {
        try {
            Unregister-ModuleAPI -ModuleName $API.Module -APIName $API.API -Force -ErrorAction SilentlyContinue
        } catch { }
    }
    
    try {
        Remove-APIMiddleware -Name "TestMiddleware" -Force -ErrorAction SilentlyContinue
    } catch { }
}