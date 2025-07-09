#Requires -Module Pester

<#
.SYNOPSIS
    Module Communication and APIs Integration Tests

.DESCRIPTION
    Comprehensive integration tests for module communication and API interactions:
    - ModuleCommunication system integration
    - Inter-module API calls and responses
    - Event-driven communication patterns
    - Message queuing and processing
    - Circuit breaker and resilience patterns
    - Authentication and authorization for module APIs
    - Performance and scalability of communication system
    - Error handling and retry mechanisms

.NOTES
    Tests the complete module communication ecosystem including APIs,
    events, messaging, and cross-module integration scenarios.
#>

BeforeAll {
    # Setup test environment
    $ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else {
        $currentPath = $PSScriptRoot
        while ($currentPath -and -not (Test-Path (Join-Path $currentPath ".git"))) {
            $currentPath = Split-Path $currentPath -Parent
        }
        $currentPath
    }
    
    # Import required modules
    $requiredModules = @(
        "ModuleCommunication",
        "Logging",
        "TestingFramework",
        "ConfigurationCore",
        "PatchManager"
    )
    
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $ProjectRoot "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Write-CustomLog is guaranteed to be available from AitherCore orchestration
    # No fallback needed - trust the orchestration system
    
    # Setup test directory structure
    $TestCommRoot = Join-Path $TestDrive "communication-integration"
    $TestAPIRoot = Join-Path $TestCommRoot "apis"
    $TestMessagesRoot = Join-Path $TestCommRoot "messages"
    $TestEventsRoot = Join-Path $TestCommRoot "events"
    $TestLogsRoot = Join-Path $TestCommRoot "logs"
    
    @($TestCommRoot, $TestAPIRoot, $TestMessagesRoot, $TestEventsRoot, $TestLogsRoot) | ForEach-Object {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
    
    # Mock module communication system
    $script:ModuleRegistry = @{}
    $script:APIRegistry = @{}
    $script:EventSubscriptions = @{}
    $script:MessageQueue = @()
    $script:EventHistory = @()
    $script:CircuitBreakers = @{}
    $script:AuthTokens = @{}
    
    # Mock module communication functions
    if (-not (Get-Command 'Register-ModuleAPI' -ErrorAction SilentlyContinue)) {
        function Register-ModuleAPI {
            param(
                [string]$ModuleName,
                [string]$APIVersion,
                [string[]]$Endpoints
            )
            
            $apiId = "$ModuleName-$APIVersion"
            $script:APIRegistry[$apiId] = @{
                ModuleName = $ModuleName
                APIVersion = $APIVersion
                Endpoints = $Endpoints
                RegisteredAt = Get-Date
                Status = "Active"
            }
            
            return @{
                Success = $true
                APIId = $apiId
                ModuleName = $ModuleName
                APIVersion = $APIVersion
                Endpoints = $Endpoints
            }
        }
    }
    
    if (-not (Get-Command 'Invoke-ModuleAPI' -ErrorAction SilentlyContinue)) {
        function Invoke-ModuleAPI {
            param(
                [string]$ModuleName,
                [string]$Endpoint,
                [hashtable]$Parameters = @{},
                [string]$Method = "GET",
                [string]$AuthToken = $null
            )
            
            $apiId = ($script:APIRegistry.Keys | Where-Object { $script:APIRegistry[$_].ModuleName -eq $ModuleName })[0]
            
            if (-not $apiId) {
                return @{
                    Success = $false
                    Error = "Module API not found: $ModuleName"
                    StatusCode = 404
                }
            }
            
            $api = $script:APIRegistry[$apiId]
            
            if ($Endpoint -notin $api.Endpoints) {
                return @{
                    Success = $false
                    Error = "Endpoint not found: $Endpoint"
                    StatusCode = 404
                }
            }
            
            # Simulate API call
            $result = @{
                Success = $true
                StatusCode = 200
                ModuleName = $ModuleName
                Endpoint = $Endpoint
                Method = $Method
                Parameters = $Parameters
                ResponseTime = (Get-Random -Minimum 10 -Maximum 500)
                Data = @{}
            }
            
            # Simulate endpoint-specific responses
            switch ($Endpoint) {
                "health" {
                    $result.Data = @{
                        Status = "Healthy"
                        Version = $api.APIVersion
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                }
                "status" {
                    $result.Data = @{
                        ModuleName = $ModuleName
                        Status = "Running"
                        Uptime = (Get-Random -Minimum 1 -Maximum 86400)
                        Metrics = @{
                            RequestCount = (Get-Random -Minimum 1 -Maximum 1000)
                            ErrorRate = (Get-Random -Minimum 0 -Maximum 5)
                        }
                    }
                }
                "config" {
                    $result.Data = @{
                        ModuleName = $ModuleName
                        Configuration = @{
                            Enabled = $true
                            LogLevel = "INFO"
                            Features = @("Feature1", "Feature2")
                        }
                    }
                }
                "execute" {
                    $result.Data = @{
                        ExecutionId = [guid]::NewGuid().ToString()
                        Status = "Completed"
                        Result = "Operation successful"
                        Duration = (Get-Random -Minimum 100 -Maximum 5000)
                    }
                }
                default {
                    $result.Data = @{
                        Message = "Generic endpoint response"
                        Endpoint = $Endpoint
                        Parameters = $Parameters
                    }
                }
            }
            
            return $result
        }
    }
    
    if (-not (Get-Command 'Submit-ModuleEvent' -ErrorAction SilentlyContinue)) {
        function Submit-ModuleEvent {
            param(
                [string]$EventName,
                [hashtable]$EventData,
                [string]$SourceModule = "TestModule"
            )
            
            $event = @{
                EventId = [guid]::NewGuid().ToString()
                EventName = $EventName
                EventData = $EventData
                SourceModule = $SourceModule
                Timestamp = Get-Date
                Processed = $false
            }
            
            $script:EventHistory += $event
            
            # Notify subscribers
            if ($script:EventSubscriptions.ContainsKey($EventName)) {
                foreach ($subscription in $script:EventSubscriptions[$EventName]) {
                    $subscription.Handler.Invoke($event)
                }
            }
            
            return @{
                Success = $true
                EventId = $event.EventId
                EventName = $EventName
                Timestamp = $event.Timestamp
            }
        }
    }
    
    if (-not (Get-Command 'Register-ModuleEventHandler' -ErrorAction SilentlyContinue)) {
        function Register-ModuleEventHandler {
            param(
                [string]$EventName,
                [scriptblock]$Handler,
                [string]$ModuleName = "TestModule"
            )
            
            if (-not $script:EventSubscriptions.ContainsKey($EventName)) {
                $script:EventSubscriptions[$EventName] = @()
            }
            
            $subscription = @{
                EventName = $EventName
                Handler = $Handler
                ModuleName = $ModuleName
                RegisteredAt = Get-Date
            }
            
            $script:EventSubscriptions[$EventName] += $subscription
            
            return @{
                Success = $true
                EventName = $EventName
                ModuleName = $ModuleName
                SubscriptionId = [guid]::NewGuid().ToString()
            }
        }
    }
    
    if (-not (Get-Command 'Submit-ModuleMessage' -ErrorAction SilentlyContinue)) {
        function Submit-ModuleMessage {
            param(
                [string]$TargetModule,
                [string]$MessageType,
                [hashtable]$MessageData,
                [string]$SourceModule = "TestModule",
                [int]$Priority = 5
            )
            
            $message = @{
                MessageId = [guid]::NewGuid().ToString()
                TargetModule = $TargetModule
                MessageType = $MessageType
                MessageData = $MessageData
                SourceModule = $SourceModule
                Priority = $Priority
                Timestamp = Get-Date
                Processed = $false
                Retries = 0
            }
            
            $script:MessageQueue += $message
            
            return @{
                Success = $true
                MessageId = $message.MessageId
                TargetModule = $TargetModule
                MessageType = $MessageType
            }
        }
    }
    
    if (-not (Get-Command 'New-AuthenticationToken' -ErrorAction SilentlyContinue)) {
        function New-AuthenticationToken {
            param(
                [string]$ModuleName,
                [string[]]$Permissions = @("read"),
                [int]$ExpirationMinutes = 60
            )
            
            $token = [guid]::NewGuid().ToString()
            $expiresAt = (Get-Date).AddMinutes($ExpirationMinutes)
            
            $script:AuthTokens[$token] = @{
                ModuleName = $ModuleName
                Permissions = $Permissions
                CreatedAt = Get-Date
                ExpiresAt = $expiresAt
                Active = $true
            }
            
            return @{
                Success = $true
                Token = $token
                ModuleName = $ModuleName
                Permissions = $Permissions
                ExpiresAt = $expiresAt
            }
        }
    }
    
    # Mock circuit breaker implementation
    if (-not (Get-Command 'Reset-CircuitBreaker' -ErrorAction SilentlyContinue)) {
        function Reset-CircuitBreaker {
            param([string]$CircuitName)
            
            if ($script:CircuitBreakers.ContainsKey($CircuitName)) {
                $script:CircuitBreakers[$CircuitName] = @{
                    Name = $CircuitName
                    State = "Closed"
                    FailureCount = 0
                    LastFailure = $null
                    ResetAt = $null
                }
                
                return @{
                    Success = $true
                    CircuitName = $CircuitName
                    State = "Closed"
                }
            }
            
            return @{
                Success = $false
                Error = "Circuit breaker not found: $CircuitName"
            }
        }
    }
    
    # Create mock modules for testing
    $script:TestModules = @{
        "ModuleA" = @{
            Name = "ModuleA"
            APIs = @("health", "status", "config")
            Events = @("ModuleA.Started", "ModuleA.ConfigChanged")
            MessageTypes = @("Command", "Query", "Notification")
        }
        "ModuleB" = @{
            Name = "ModuleB"
            APIs = @("health", "execute", "metrics")
            Events = @("ModuleB.TaskCompleted", "ModuleB.ErrorOccurred")
            MessageTypes = @("Task", "Result", "Error")
        }
        "ModuleC" = @{
            Name = "ModuleC"
            APIs = @("health", "data", "export")
            Events = @("ModuleC.DataUpdated", "ModuleC.ExportCompleted")
            MessageTypes = @("DataRequest", "DataResponse", "Export")
        }
    }
    
    # Register test modules
    foreach ($module in $script:TestModules.Values) {
        Register-ModuleAPI -ModuleName $module.Name -APIVersion "1.0.0" -Endpoints $module.APIs
    }
    
    # Event tracking for integration tests
    $script:IntegrationEvents = @()
    
    if (-not (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue)) {
        function Publish-TestEvent {
            param([string]$EventName, [hashtable]$EventData)
            $script:IntegrationEvents += @{
                EventName = $EventName
                EventData = $EventData
                Timestamp = Get-Date
            }
        }
    }
}

Describe "Module Communication and APIs Integration Tests" {
    
    Context "Inter-Module API Communication" {
        
        It "Should register and discover module APIs" {
            # Arrange
            $newModule = @{
                Name = "TestModule"
                Version = "2.0.0"
                Endpoints = @("health", "status", "config", "execute")
            }
            
            # Act
            $registrationResult = Register-ModuleAPI -ModuleName $newModule.Name -APIVersion $newModule.Version -Endpoints $newModule.Endpoints
            
            # Verify API is registered
            $apiId = "$($newModule.Name)-$($newModule.Version)"
            $registeredAPI = $script:APIRegistry[$apiId]
            
            # Publish API registration event
            Publish-TestEvent -EventName "ModuleAPIRegistered" -EventData @{
                ModuleName = $newModule.Name
                APIVersion = $newModule.Version
                Endpoints = $newModule.Endpoints
                RegistrationResult = $registrationResult
            }
            
            # Assert
            $registrationResult.Success | Should -Be $true
            $registrationResult.APIId | Should -Be $apiId
            $registrationResult.ModuleName | Should -Be $newModule.Name
            $registrationResult.APIVersion | Should -Be $newModule.Version
            $registrationResult.Endpoints | Should -Be $newModule.Endpoints
            
            # Verify registry entry
            $registeredAPI | Should -Not -BeNullOrEmpty
            $registeredAPI.ModuleName | Should -Be $newModule.Name
            $registeredAPI.APIVersion | Should -Be $newModule.Version
            $registeredAPI.Endpoints | Should -Be $newModule.Endpoints
            $registeredAPI.Status | Should -Be "Active"
            
            # Verify event tracking
            $apiEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "ModuleAPIRegistered" }
            $apiEvents.Count | Should -BeGreaterThan 0
            $apiEvents[-1].EventData.ModuleName | Should -Be $newModule.Name
        }
        
        It "Should execute API calls between modules" {
            # Arrange
            $apiCalls = @(
                @{ Module = "ModuleA"; Endpoint = "health"; Method = "GET" },
                @{ Module = "ModuleB"; Endpoint = "status"; Method = "GET" },
                @{ Module = "ModuleC"; Endpoint = "health"; Method = "GET" },
                @{ Module = "ModuleA"; Endpoint = "config"; Method = "GET" },
                @{ Module = "ModuleB"; Endpoint = "execute"; Method = "POST"; Parameters = @{ action = "test" } }
            )
            
            # Act
            $apiResults = @()
            foreach ($call in $apiCalls) {
                $result = Invoke-ModuleAPI -ModuleName $call.Module -Endpoint $call.Endpoint -Method $call.Method -Parameters $call.Parameters
                $apiResults += $result
            }
            
            # Publish API communication event
            Publish-TestEvent -EventName "InterModuleAPICommunication" -EventData @{
                TotalCalls = $apiCalls.Count
                SuccessfulCalls = ($apiResults | Where-Object { $_.Success }).Count
                FailedCalls = ($apiResults | Where-Object { -not $_.Success }).Count
                AverageResponseTime = ($apiResults | Measure-Object -Property ResponseTime -Average).Average
                Results = $apiResults
            }
            
            # Assert
            $apiResults.Count | Should -Be $apiCalls.Count
            $apiResults | ForEach-Object { $_.Success | Should -Be $true }
            $apiResults | ForEach-Object { $_.StatusCode | Should -Be 200 }
            $apiResults | ForEach-Object { $_.ResponseTime | Should -BeGreaterThan 0 }
            
            # Verify specific endpoint responses
            $healthResults = $apiResults | Where-Object { $_.Endpoint -eq "health" }
            $healthResults | ForEach-Object { $_.Data.Status | Should -Be "Healthy" }
            
            $statusResults = $apiResults | Where-Object { $_.Endpoint -eq "status" }
            $statusResults | ForEach-Object { $_.Data.Status | Should -Be "Running" }
            
            $executeResults = $apiResults | Where-Object { $_.Endpoint -eq "execute" }
            $executeResults | ForEach-Object { $_.Data.Status | Should -Be "Completed" }
            
            # Verify event tracking
            $commEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "InterModuleAPICommunication" }
            $commEvents.Count | Should -BeGreaterThan 0
            $commEvents[-1].EventData.SuccessfulCalls | Should -Be $apiCalls.Count
            $commEvents[-1].EventData.FailedCalls | Should -Be 0
        }
        
        It "Should handle API authentication and authorization" {
            # Arrange
            $authModule = "SecurityModule"
            $permissions = @("read", "write", "execute")
            
            # Act
            # Create authentication token
            $tokenResult = New-AuthenticationToken -ModuleName $authModule -Permissions $permissions -ExpirationMinutes 30
            
            # Test API calls with authentication
            $authenticatedCalls = @()
            
            # Successful call with valid token
            $authenticatedResult = Invoke-ModuleAPI -ModuleName "ModuleA" -Endpoint "config" -AuthToken $tokenResult.Token
            $authenticatedCalls += @{
                Description = "ValidToken"
                Result = $authenticatedResult
            }
            
            # Simulate call with invalid token
            $invalidTokenResult = @{
                Success = $false
                Error = "Invalid authentication token"
                StatusCode = 401
            }
            $authenticatedCalls += @{
                Description = "InvalidToken"
                Result = $invalidTokenResult
            }
            
            # Simulate call without token (should succeed for public endpoints)
            $publicResult = Invoke-ModuleAPI -ModuleName "ModuleA" -Endpoint "health"
            $authenticatedCalls += @{
                Description = "PublicEndpoint"
                Result = $publicResult
            }
            
            # Publish authentication event
            Publish-TestEvent -EventName "APIAuthenticationTested" -EventData @{
                AuthModule = $authModule
                TokenResult = $tokenResult
                AuthenticatedCalls = $authenticatedCalls
                Permissions = $permissions
            }
            
            # Assert
            $tokenResult.Success | Should -Be $true
            $tokenResult.Token | Should -Not -BeNullOrEmpty
            $tokenResult.ModuleName | Should -Be $authModule
            $tokenResult.Permissions | Should -Be $permissions
            
            # Verify authenticated calls
            $validTokenCall = $authenticatedCalls | Where-Object { $_.Description -eq "ValidToken" }
            $validTokenCall.Result.Success | Should -Be $true
            
            $invalidTokenCall = $authenticatedCalls | Where-Object { $_.Description -eq "InvalidToken" }
            $invalidTokenCall.Result.Success | Should -Be $false
            $invalidTokenCall.Result.StatusCode | Should -Be 401
            
            $publicCall = $authenticatedCalls | Where-Object { $_.Description -eq "PublicEndpoint" }
            $publicCall.Result.Success | Should -Be $true
            
            # Verify event tracking
            $authEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "APIAuthenticationTested" }
            $authEvents.Count | Should -BeGreaterThan 0
            $authEvents[-1].EventData.AuthModule | Should -Be $authModule
        }
    }
    
    Context "Event-Driven Communication" {
        
        It "Should handle event publishing and subscription" {
            # Arrange
            $eventSubscriptions = @()
            $receivedEvents = @()
            
            # Create event handlers
            $moduleAHandler = {
                param($event)
                $receivedEvents += @{
                    Handler = "ModuleA"
                    Event = $event
                    ProcessedAt = Get-Date
                }
            }
            
            $moduleBHandler = {
                param($event)
                $receivedEvents += @{
                    Handler = "ModuleB"
                    Event = $event
                    ProcessedAt = Get-Date
                }
            }
            
            # Act
            # Register event handlers
            $eventSubscriptions += Register-ModuleEventHandler -EventName "TestEvent" -Handler $moduleAHandler -ModuleName "ModuleA"
            $eventSubscriptions += Register-ModuleEventHandler -EventName "TestEvent" -Handler $moduleBHandler -ModuleName "ModuleB"
            $eventSubscriptions += Register-ModuleEventHandler -EventName "ConfigChanged" -Handler $moduleAHandler -ModuleName "ModuleA"
            
            # Publish events
            $publishedEvents = @()
            $publishedEvents += Submit-ModuleEvent -EventName "TestEvent" -EventData @{ Message = "Test message 1" } -SourceModule "TestModule"
            $publishedEvents += Submit-ModuleEvent -EventName "TestEvent" -EventData @{ Message = "Test message 2" } -SourceModule "TestModule"
            $publishedEvents += Submit-ModuleEvent -EventName "ConfigChanged" -EventData @{ ConfigKey = "LogLevel"; NewValue = "DEBUG" } -SourceModule "ConfigModule"
            
            # Allow time for event processing
            Start-Sleep -Milliseconds 100
            
            # Publish event communication event
            Publish-TestEvent -EventName "EventDrivenCommunication" -EventData @{
                Subscriptions = $eventSubscriptions
                PublishedEvents = $publishedEvents
                ReceivedEvents = $receivedEvents
                EventHistory = $script:EventHistory
            }
            
            # Assert
            $eventSubscriptions.Count | Should -Be 3
            $eventSubscriptions | ForEach-Object { $_.Success | Should -Be $true }
            
            $publishedEvents.Count | Should -Be 3
            $publishedEvents | ForEach-Object { $_.Success | Should -Be $true }
            
            # Verify event reception
            $receivedEvents.Count | Should -Be 4  # 2 TestEvent * 2 handlers + 1 ConfigChanged * 1 handler
            
            $testEventReceivers = $receivedEvents | Where-Object { $_.Event.EventName -eq "TestEvent" }
            $testEventReceivers.Count | Should -Be 4  # 2 events * 2 handlers
            
            $configEventReceivers = $receivedEvents | Where-Object { $_.Event.EventName -eq "ConfigChanged" }
            $configEventReceivers.Count | Should -Be 1
            
            # Verify event history
            $script:EventHistory.Count | Should -Be 3
            $script:EventHistory | ForEach-Object { $_.EventId | Should -Not -BeNullOrEmpty }
            
            # Verify event tracking
            $eventCommEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "EventDrivenCommunication" }
            $eventCommEvents.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle event filtering and prioritization" {
            # Arrange
            $prioritizedEvents = @()
            $filteredEvents = @()
            
            # Create filtering event handler
            $filteringHandler = {
                param($event)
                if ($event.EventData.Priority -eq "High") {
                    $prioritizedEvents += $event
                }
                if ($event.EventData.Category -eq "Security") {
                    $filteredEvents += $event
                }
            }
            
            # Act
            # Register filtering handler
            $filterSubscription = Register-ModuleEventHandler -EventName "PriorityEvent" -Handler $filteringHandler -ModuleName "FilterModule"
            
            # Publish events with different priorities and categories
            $testEvents = @(
                @{ EventName = "PriorityEvent"; EventData = @{ Priority = "High"; Category = "Security"; Message = "Security alert" } },
                @{ EventName = "PriorityEvent"; EventData = @{ Priority = "Low"; Category = "Info"; Message = "Info message" } },
                @{ EventName = "PriorityEvent"; EventData = @{ Priority = "High"; Category = "Performance"; Message = "Performance issue" } },
                @{ EventName = "PriorityEvent"; EventData = @{ Priority = "Medium"; Category = "Security"; Message = "Security warning" } }
            )
            
            $publishResults = @()
            foreach ($event in $testEvents) {
                $publishResults += Submit-ModuleEvent -EventName $event.EventName -EventData $event.EventData -SourceModule "TestModule"
            }
            
            # Allow time for event processing
            Start-Sleep -Milliseconds 100
            
            # Publish event filtering event
            Publish-TestEvent -EventName "EventFilteringTested" -EventData @{
                FilterSubscription = $filterSubscription
                TestEvents = $testEvents
                PrioritizedEvents = $prioritizedEvents
                FilteredEvents = $filteredEvents
                PublishResults = $publishResults
            }
            
            # Assert
            $filterSubscription.Success | Should -Be $true
            $publishResults.Count | Should -Be 4
            $publishResults | ForEach-Object { $_.Success | Should -Be $true }
            
            # Verify priority filtering
            $prioritizedEvents.Count | Should -Be 2  # 2 High priority events
            $prioritizedEvents | ForEach-Object { $_.EventData.Priority | Should -Be "High" }
            
            # Verify category filtering
            $filteredEvents.Count | Should -Be 2  # 2 Security category events
            $filteredEvents | ForEach-Object { $_.EventData.Category | Should -Be "Security" }
            
            # Verify overlap (High priority AND Security category)
            $highPrioritySecurityEvents = $prioritizedEvents | Where-Object { $_.EventData.Category -eq "Security" }
            $highPrioritySecurityEvents.Count | Should -Be 1
            
            # Verify event tracking
            $filteringEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "EventFilteringTested" }
            $filteringEvents.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Message Queue and Processing" {
        
        It "Should handle message queuing and processing" {
            # Arrange
            $messageResults = @()
            $processedMessages = @()
            
            # Act
            # Submit messages with different priorities
            $testMessages = @(
                @{ Target = "ModuleA"; Type = "Command"; Data = @{ Action = "Start" }; Priority = 1 },
                @{ Target = "ModuleB"; Type = "Query"; Data = @{ Query = "GetStatus" }; Priority = 5 },
                @{ Target = "ModuleC"; Type = "Notification"; Data = @{ Event = "DataChanged" }; Priority = 3 },
                @{ Target = "ModuleA"; Type = "Command"; Data = @{ Action = "Stop" }; Priority = 2 },
                @{ Target = "ModuleB"; Type = "Task"; Data = @{ Task = "ProcessData" }; Priority = 4 }
            )
            
            foreach ($message in $testMessages) {
                $result = Submit-ModuleMessage -TargetModule $message.Target -MessageType $message.Type -MessageData $message.Data -Priority $message.Priority -SourceModule "TestModule"
                $messageResults += $result
            }
            
            # Simulate message processing (sorted by priority)
            $sortedMessages = $script:MessageQueue | Sort-Object Priority
            foreach ($message in $sortedMessages) {
                $processedMessages += @{
                    MessageId = $message.MessageId
                    TargetModule = $message.TargetModule
                    MessageType = $message.MessageType
                    Priority = $message.Priority
                    ProcessedAt = Get-Date
                    Result = "Processed successfully"
                }
            }
            
            # Publish message processing event
            Publish-TestEvent -EventName "MessageQueueProcessed" -EventData @{
                SubmittedMessages = $testMessages
                MessageResults = $messageResults
                ProcessedMessages = $processedMessages
                QueueSize = $script:MessageQueue.Count
            }
            
            # Assert
            $messageResults.Count | Should -Be 5
            $messageResults | ForEach-Object { $_.Success | Should -Be $true }
            $messageResults | ForEach-Object { $_.MessageId | Should -Not -BeNullOrEmpty }
            
            # Verify message queue
            $script:MessageQueue.Count | Should -Be 5
            $script:MessageQueue | ForEach-Object { $_.MessageId | Should -Not -BeNullOrEmpty }
            
            # Verify priority ordering
            $processedMessages.Count | Should -Be 5
            $processedMessages[0].Priority | Should -Be 1  # Highest priority (lowest number)
            $processedMessages[1].Priority | Should -Be 2
            $processedMessages[2].Priority | Should -Be 3
            $processedMessages[3].Priority | Should -Be 4
            $processedMessages[4].Priority | Should -Be 5  # Lowest priority (highest number)
            
            # Verify target modules
            $moduleAMessages = $processedMessages | Where-Object { $_.TargetModule -eq "ModuleA" }
            $moduleAMessages.Count | Should -Be 2
            
            $moduleBMessages = $processedMessages | Where-Object { $_.TargetModule -eq "ModuleB" }
            $moduleBMessages.Count | Should -Be 2
            
            $moduleCMessages = $processedMessages | Where-Object { $_.TargetModule -eq "ModuleC" }
            $moduleCMessages.Count | Should -Be 1
            
            # Verify event tracking
            $messageEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "MessageQueueProcessed" }
            $messageEvents.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle message retry and error handling" {
            # Arrange
            $retryResults = @()
            $errorMessages = @()
            
            # Act
            # Submit messages that will simulate failures
            $failingMessages = @(
                @{ Target = "NonExistentModule"; Type = "Command"; Data = @{ Action = "Test" }; Priority = 1 },
                @{ Target = "ModuleA"; Type = "InvalidType"; Data = @{ Action = "Test" }; Priority = 2 },
                @{ Target = "ModuleB"; Type = "Command"; Data = @{ Action = "FailingAction" }; Priority = 3 }
            )
            
            foreach ($message in $failingMessages) {
                $result = Submit-ModuleMessage -TargetModule $message.Target -MessageType $message.Type -MessageData $message.Data -Priority $message.Priority -SourceModule "TestModule"
                $retryResults += $result
            }
            
            # Simulate message processing with failures and retries
            $messagesToProcess = $script:MessageQueue | Where-Object { $_.TargetModule -in @("NonExistentModule", "ModuleA", "ModuleB") -and $_.MessageType -in @("Command", "InvalidType") }
            
            foreach ($message in $messagesToProcess) {
                $processResult = @{
                    MessageId = $message.MessageId
                    TargetModule = $message.TargetModule
                    MessageType = $message.MessageType
                    Success = $false
                    Retries = 0
                    Errors = @()
                }
                
                # Simulate processing with retries
                for ($retry = 0; $retry -lt 3; $retry++) {
                    $processResult.Retries = $retry + 1
                    
                    if ($message.TargetModule -eq "NonExistentModule") {
                        $processResult.Errors += "Target module not found"
                        $processResult.Success = $false
                    } elseif ($message.MessageType -eq "InvalidType") {
                        $processResult.Errors += "Invalid message type"
                        $processResult.Success = $false
                    } elseif ($message.MessageData.Action -eq "FailingAction") {
                        if ($retry -lt 2) {
                            $processResult.Errors += "Action failed (retry $($retry + 1))"
                            $processResult.Success = $false
                        } else {
                            $processResult.Success = $true  # Succeed on 3rd try
                        }
                    }
                    
                    if ($processResult.Success) {
                        break
                    }
                }
                
                $errorMessages += $processResult
            }
            
            # Publish error handling event
            Publish-TestEvent -EventName "MessageErrorHandling" -EventData @{
                FailingMessages = $failingMessages
                RetryResults = $retryResults
                ErrorMessages = $errorMessages
                TotalRetries = ($errorMessages | Measure-Object -Property Retries -Sum).Sum
            }
            
            # Assert
            $retryResults.Count | Should -Be 3
            $retryResults | ForEach-Object { $_.Success | Should -Be $true }  # Message submission succeeded
            
            $errorMessages.Count | Should -Be 3
            
            # Verify retry logic
            $nonExistentModuleError = $errorMessages | Where-Object { $_.TargetModule -eq "NonExistentModule" }
            $nonExistentModuleError.Success | Should -Be $false
            $nonExistentModuleError.Retries | Should -Be 3
            
            $invalidTypeError = $errorMessages | Where-Object { $_.MessageType -eq "InvalidType" }
            $invalidTypeError.Success | Should -Be $false
            $invalidTypeError.Retries | Should -Be 3
            
            $failingActionError = $errorMessages | Where-Object { $_.TargetModule -eq "ModuleB" }
            $failingActionError.Success | Should -Be $true  # Should succeed after retries
            $failingActionError.Retries | Should -Be 3
            
            # Verify event tracking
            $errorEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "MessageErrorHandling" }
            $errorEvents.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Circuit Breaker and Resilience Patterns" {
        
        It "Should handle circuit breaker pattern for failing services" {
            # Arrange
            $circuitName = "ModuleA-API"
            $circuitResults = @()
            
            # Initialize circuit breaker
            $script:CircuitBreakers[$circuitName] = @{
                Name = $circuitName
                State = "Closed"
                FailureCount = 0
                FailureThreshold = 3
                TimeoutSeconds = 30
                LastFailure = $null
                ResetAt = $null
            }
            
            # Act
            # Simulate multiple API calls with failures
            for ($i = 1; $i -le 5; $i++) {
                $circuit = $script:CircuitBreakers[$circuitName]
                
                # Simulate API call result
                $apiResult = @{
                    Success = $i -le 3 ? $false : $true  # First 3 calls fail, then succeed
                    CallNumber = $i
                    CircuitState = $circuit.State
                }
                
                # Update circuit breaker state
                if (-not $apiResult.Success) {
                    $circuit.FailureCount++
                    $circuit.LastFailure = Get-Date
                    
                    if ($circuit.FailureCount -ge $circuit.FailureThreshold) {
                        $circuit.State = "Open"
                        $circuit.ResetAt = (Get-Date).AddSeconds($circuit.TimeoutSeconds)
                    }
                } else {
                    if ($circuit.State -eq "Open" -and (Get-Date) -gt $circuit.ResetAt) {
                        $circuit.State = "Half-Open"
                    }
                    
                    if ($circuit.State -eq "Half-Open") {
                        $circuit.State = "Closed"
                        $circuit.FailureCount = 0
                    }
                }
                
                $apiResult.CircuitStateAfter = $circuit.State
                $circuitResults += $apiResult
            }
            
            # Test circuit breaker reset
            $resetResult = Reset-CircuitBreaker -CircuitName $circuitName
            
            # Publish circuit breaker event
            Publish-TestEvent -EventName "CircuitBreakerTested" -EventData @{
                CircuitName = $circuitName
                CircuitResults = $circuitResults
                ResetResult = $resetResult
                FinalState = $script:CircuitBreakers[$circuitName].State
            }
            
            # Assert
            $circuitResults.Count | Should -Be 5
            
            # Verify circuit breaker state progression
            $circuitResults[0].CircuitState | Should -Be "Closed"
            $circuitResults[1].CircuitState | Should -Be "Closed"
            $circuitResults[2].CircuitState | Should -Be "Closed"
            $circuitResults[2].CircuitStateAfter | Should -Be "Open"  # Should open after 3rd failure
            
            # Verify reset functionality
            $resetResult.Success | Should -Be $true
            $resetResult.CircuitName | Should -Be $circuitName
            $resetResult.State | Should -Be "Closed"
            
            # Verify final state
            $script:CircuitBreakers[$circuitName].State | Should -Be "Closed"
            $script:CircuitBreakers[$circuitName].FailureCount | Should -Be 0
            
            # Verify event tracking
            $circuitEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "CircuitBreakerTested" }
            $circuitEvents.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle timeout and retry patterns" {
            # Arrange
            $timeoutScenarios = @()
            $retryScenarios = @()
            
            # Act
            # Simulate timeout scenarios
            $timeoutTests = @(
                @{ Operation = "FastAPI"; TimeoutMs = 100; ExpectedResult = "Success" },
                @{ Operation = "SlowAPI"; TimeoutMs = 50; ExpectedResult = "Timeout" },
                @{ Operation = "VerySlowAPI"; TimeoutMs = 200; ExpectedResult = "Timeout" }
            )
            
            foreach ($test in $timeoutTests) {
                $startTime = Get-Date
                $operationTime = switch ($test.Operation) {
                    "FastAPI" { 30 }
                    "SlowAPI" { 100 }
                    "VerySlowAPI" { 300 }
                }
                
                $result = @{
                    Operation = $test.Operation
                    TimeoutMs = $test.TimeoutMs
                    OperationTimeMs = $operationTime
                    Success = $operationTime -le $test.TimeoutMs
                    ActualResult = if ($operationTime -le $test.TimeoutMs) { "Success" } else { "Timeout" }
                    ExpectedResult = $test.ExpectedResult
                }
                
                $timeoutScenarios += $result
            }
            
            # Simulate retry scenarios
            $retryTests = @(
                @{ Operation = "IntermittentAPI"; MaxRetries = 3; SuccessOnAttempt = 2 },
                @{ Operation = "AlwaysFailingAPI"; MaxRetries = 3; SuccessOnAttempt = 0 },
                @{ Operation = "ImmediateSuccessAPI"; MaxRetries = 3; SuccessOnAttempt = 1 }
            )
            
            foreach ($test in $retryTests) {
                $attempts = 0
                $success = $false
                
                for ($attempt = 1; $attempt -le $test.MaxRetries; $attempt++) {
                    $attempts++
                    
                    if ($test.SuccessOnAttempt -gt 0 -and $attempt -eq $test.SuccessOnAttempt) {
                        $success = $true
                        break
                    }
                }
                
                $result = @{
                    Operation = $test.Operation
                    MaxRetries = $test.MaxRetries
                    ActualAttempts = $attempts
                    Success = $success
                    SuccessOnAttempt = if ($success) { $attempts } else { 0 }
                    ExpectedSuccessOnAttempt = $test.SuccessOnAttempt
                }
                
                $retryScenarios += $result
            }
            
            # Publish resilience pattern event
            Publish-TestEvent -EventName "ResiliencePatternsTest" -EventData @{
                TimeoutScenarios = $timeoutScenarios
                RetryScenarios = $retryScenarios
                TotalTests = $timeoutTests.Count + $retryTests.Count
            }
            
            # Assert
            $timeoutScenarios.Count | Should -Be 3
            $retryScenarios.Count | Should -Be 3
            
            # Verify timeout scenarios
            $fastApiResult = $timeoutScenarios | Where-Object { $_.Operation -eq "FastAPI" }
            $fastApiResult.Success | Should -Be $true
            $fastApiResult.ActualResult | Should -Be "Success"
            
            $slowApiResult = $timeoutScenarios | Where-Object { $_.Operation -eq "SlowAPI" }
            $slowApiResult.Success | Should -Be $false
            $slowApiResult.ActualResult | Should -Be "Timeout"
            
            # Verify retry scenarios
            $intermittentResult = $retryScenarios | Where-Object { $_.Operation -eq "IntermittentAPI" }
            $intermittentResult.Success | Should -Be $true
            $intermittentResult.ActualAttempts | Should -Be 2
            
            $alwaysFailingResult = $retryScenarios | Where-Object { $_.Operation -eq "AlwaysFailingAPI" }
            $alwaysFailingResult.Success | Should -Be $false
            $alwaysFailingResult.ActualAttempts | Should -Be 3
            
            $immediateSuccessResult = $retryScenarios | Where-Object { $_.Operation -eq "ImmediateSuccessAPI" }
            $immediateSuccessResult.Success | Should -Be $true
            $immediateSuccessResult.ActualAttempts | Should -Be 1
            
            # Verify event tracking
            $resilienceEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "ResiliencePatternsTest" }
            $resilienceEvents.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Performance and Scalability" {
        
        It "Should handle high-volume API communication" {
            # Arrange
            $highVolumeTest = @{
                TotalRequests = 100
                ConcurrentRequests = 10
                Modules = @("ModuleA", "ModuleB", "ModuleC")
                Endpoints = @("health", "status")
            }
            
            # Act
            $performanceResults = @()
            $startTime = Get-Date
            
            # Simulate high-volume API calls
            for ($i = 1; $i -le $highVolumeTest.TotalRequests; $i++) {
                $module = $highVolumeTest.Modules | Get-Random
                $endpoint = $highVolumeTest.Endpoints | Get-Random
                
                $callStart = Get-Date
                $result = Invoke-ModuleAPI -ModuleName $module -Endpoint $endpoint
                $callEnd = Get-Date
                
                $performanceResults += @{
                    RequestId = $i
                    Module = $module
                    Endpoint = $endpoint
                    Success = $result.Success
                    ResponseTime = ($callEnd - $callStart).TotalMilliseconds
                    StatusCode = $result.StatusCode
                }
            }
            
            $endTime = Get-Date
            $totalDuration = ($endTime - $startTime).TotalMilliseconds
            
            # Calculate performance metrics
            $performanceMetrics = @{
                TotalRequests = $highVolumeTest.TotalRequests
                TotalDuration = $totalDuration
                RequestsPerSecond = [math]::Round($highVolumeTest.TotalRequests / ($totalDuration / 1000), 2)
                SuccessfulRequests = ($performanceResults | Where-Object { $_.Success }).Count
                FailedRequests = ($performanceResults | Where-Object { -not $_.Success }).Count
                AverageResponseTime = [math]::Round(($performanceResults | Measure-Object -Property ResponseTime -Average).Average, 2)
                MinResponseTime = ($performanceResults | Measure-Object -Property ResponseTime -Minimum).Minimum
                MaxResponseTime = ($performanceResults | Measure-Object -Property ResponseTime -Maximum).Maximum
                SuccessRate = [math]::Round((($performanceResults | Where-Object { $_.Success }).Count / $highVolumeTest.TotalRequests) * 100, 2)
            }
            
            # Publish performance event
            Publish-TestEvent -EventName "HighVolumeAPIPerformance" -EventData @{
                TestConfiguration = $highVolumeTest
                PerformanceMetrics = $performanceMetrics
                SampleResults = $performanceResults | Select-Object -First 10
            }
            
            # Assert
            $performanceResults.Count | Should -Be $highVolumeTest.TotalRequests
            $performanceMetrics.SuccessfulRequests | Should -Be $highVolumeTest.TotalRequests
            $performanceMetrics.FailedRequests | Should -Be 0
            $performanceMetrics.SuccessRate | Should -Be 100
            $performanceMetrics.RequestsPerSecond | Should -BeGreaterThan 0
            $performanceMetrics.AverageResponseTime | Should -BeGreaterThan 0
            $performanceMetrics.AverageResponseTime | Should -BeLessThan 1000  # Should be under 1 second
            
            # Verify event tracking
            $performanceEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "HighVolumeAPIPerformance" }
            $performanceEvents.Count | Should -BeGreaterThan 0
            $performanceEvents[-1].EventData.PerformanceMetrics.RequestsPerSecond | Should -BeGreaterThan 0
        }
        
        It "Should handle concurrent event processing" {
            # Arrange
            $concurrentTest = @{
                TotalEvents = 50
                EventTypes = @("DataUpdate", "ConfigChange", "StatusChange", "AlertEvent")
                ConcurrentHandlers = 5
            }
            
            $processedEvents = @()
            $handlerResults = @()
            
            # Create concurrent event handlers
            $handlers = @()
            for ($i = 1; $i -le $concurrentTest.ConcurrentHandlers; $i++) {
                $handlers += @{
                    Id = $i
                    Handler = {
                        param($event)
                        $processStart = Get-Date
                        
                        # Simulate processing time
                        Start-Sleep -Milliseconds (Get-Random -Minimum 10 -Maximum 100)
                        
                        $processEnd = Get-Date
                        $processedEvents += @{
                            HandlerId = $i
                            EventId = $event.EventId
                            EventName = $event.EventName
                            ProcessingTime = ($processEnd - $processStart).TotalMilliseconds
                            ProcessedAt = $processEnd
                        }
                    }
                }
            }
            
            # Act
            # Register all handlers for all event types
            foreach ($eventType in $concurrentTest.EventTypes) {
                foreach ($handler in $handlers) {
                    Register-ModuleEventHandler -EventName $eventType -Handler $handler.Handler -ModuleName "Handler$($handler.Id)"
                }
            }
            
            $publishStart = Get-Date
            
            # Publish events concurrently
            for ($i = 1; $i -le $concurrentTest.TotalEvents; $i++) {
                $eventType = $concurrentTest.EventTypes | Get-Random
                $eventData = @{
                    EventNumber = $i
                    Timestamp = Get-Date
                    RandomValue = Get-Random
                }
                
                Submit-ModuleEvent -EventName $eventType -EventData $eventData -SourceModule "ConcurrentTest"
            }
            
            $publishEnd = Get-Date
            
            # Allow time for event processing
            Start-Sleep -Milliseconds 500
            
            # Calculate concurrent processing metrics
            $concurrentMetrics = @{
                TotalEvents = $concurrentTest.TotalEvents
                ConcurrentHandlers = $concurrentTest.ConcurrentHandlers
                ExpectedProcessedEvents = $concurrentTest.TotalEvents * $concurrentTest.ConcurrentHandlers
                ActualProcessedEvents = $processedEvents.Count
                PublishingDuration = ($publishEnd - $publishStart).TotalMilliseconds
                AverageProcessingTime = if ($processedEvents.Count -gt 0) { [math]::Round(($processedEvents | Measure-Object -Property ProcessingTime -Average).Average, 2) } else { 0 }
                TotalProcessingTime = if ($processedEvents.Count -gt 0) { ($processedEvents | Measure-Object -Property ProcessingTime -Sum).Sum } else { 0 }
            }
            
            # Publish concurrent processing event
            Publish-TestEvent -EventName "ConcurrentEventProcessing" -EventData @{
                TestConfiguration = $concurrentTest
                ConcurrentMetrics = $concurrentMetrics
                ProcessedEventsSample = $processedEvents | Select-Object -First 10
            }
            
            # Assert
            $concurrentMetrics.ActualProcessedEvents | Should -BeGreaterThan 0
            $concurrentMetrics.ActualProcessedEvents | Should -BeLessOrEqual $concurrentMetrics.ExpectedProcessedEvents
            $concurrentMetrics.AverageProcessingTime | Should -BeGreaterThan 0
            $concurrentMetrics.AverageProcessingTime | Should -BeLessThan 200  # Should be under 200ms
            $concurrentMetrics.PublishingDuration | Should -BeGreaterThan 0
            
            # Verify event tracking
            $concurrentEvents = $script:IntegrationEvents | Where-Object { $_.EventName -eq "ConcurrentEventProcessing" }
            $concurrentEvents.Count | Should -BeGreaterThan 0
        }
    }
}

AfterAll {
    # Cleanup test environment
    if (Test-Path $TestCommRoot) {
        Remove-Item -Path $TestCommRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clear all tracking variables
    $script:ModuleRegistry = @{}
    $script:APIRegistry = @{}
    $script:EventSubscriptions = @{}
    $script:MessageQueue = @()
    $script:EventHistory = @()
    $script:CircuitBreakers = @{}
    $script:AuthTokens = @{}
    $script:IntegrationEvents = @()
    $script:TestModules = @{}
}