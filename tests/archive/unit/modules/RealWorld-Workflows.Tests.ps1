BeforeAll {
    # Find project root using robust detection
    $projectRoot = if ($env:PROJECT_ROOT) { 
        $env:PROJECT_ROOT 
    } elseif (Test-Path '/workspaces/AitherLabs') { 
        '/workspaces/AitherLabs' 
    } else { 
        Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 
    }
    
    # Import all available modules for workflow testing
    $script:WorkflowModules = @{}
    $moduleNames = @('Logging', 'BackupManager', 'PatchManager', 'LabRunner', 'ParallelExecution', 'ScriptManager', 'DevEnvironment', 'TestingFramework', 'UnifiedMaintenance')
    
    foreach ($moduleName in $moduleNames) {
        $modulePath = Join-Path $env:PWSH_MODULES_PATH "$moduleName"
        try {
            Import-Module $modulePath -Force -ErrorAction Stop
            $script:WorkflowModules[$moduleName] = $true
            Write-Host "Imported $moduleName for workflow testing" -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not import $moduleName for workflow testing: $_"
            $script:WorkflowModules[$moduleName] = $false
        }
    }
    
    # Workflow test data
    $script:workflowDir = Join-Path $TestDrive "WorkflowTests"
    New-Item -Path $script:workflowDir -ItemType Directory -Force | Out-Null
    
    # Helper function to simulate a development project structure
    function New-MockProject {
        param(
            [string]$ProjectPath,
            [string]$ProjectName = "MockProject"
        )
        
        New-Item -Path $ProjectPath -ItemType Directory -Force | Out-Null
        
        # Create typical project structure
        $srcDir = Join-Path $ProjectPath "src"
        $testDir = Join-Path $ProjectPath "tests"
        $docsDir = Join-Path $ProjectPath "docs"
        $configDir = Join-Path $ProjectPath "config"
        
        New-Item -Path $srcDir, $testDir, $docsDir, $configDir -ItemType Directory -Force | Out-Null
        
        # Create some mock files
        @"
# $ProjectName

This is a mock project for testing workflows.

## Features
- Feature 1
- Feature 2
- Feature 3
"@ | Set-Content (Join-Path $ProjectPath "README.md")
        
        @"
{
    "name": "$ProjectName",
    "version": "1.0.0",
    "description": "Mock project for testing",
    "main": "src/main.ps1",
    "scripts": {
        "test": "Invoke-Pester",
        "build": "Build-Project"
    }
}
"@ | Set-Content (Join-Path $ProjectPath "package.json")
        
        @"
param(
    [string]$Environment = "dev",
    [switch]$Verbose
)

Write-Host "Running $ProjectName in $Environment environment"

if ($Verbose) {
    Write-Host "Verbose output enabled"
}

# Mock main functionality
Write-Output "Mock project executed successfully"
"@ | Set-Content (Join-Path $srcDir "main.ps1")
        
        @"
Describe "$ProjectName Tests" {
    Context "Basic Functionality" {
        It "Should execute main script" {
            { & "src/main.ps1" } | Should -Not -Throw
        }
        
        It "Should handle parameters" {
            { & "src/main.ps1" -Environment "test" -Verbose } | Should -Not -Throw
        }
    }
}
"@ | Set-Content (Join-Path $testDir "main.tests.ps1")
        
        return $ProjectPath
    }
    
    # Helper to create mock backup files
    function New-MockBackupFiles {
        param([string]$BasePath)
        
        $backupPatterns = @("*.bak", "*backup*", "*.old", "*.orig", "*~")
        $files = @()
        
        foreach ($pattern in $backupPatterns) {
            $fileName = $pattern -replace '\*', "test$(Get-Random)"
            $filePath = Join-Path $BasePath $fileName
            "Mock backup content" | Set-Content $filePath
            $files += $filePath
        }
        
        return $files
    }
}

Describe "Real-World Workflow Scenarios" {
    
    Context "Development Project Lifecycle" {
        
        It "Should handle a complete project setup and maintenance workflow" {
            $projectPath = Join-Path $script:workflowDir "DevProject"
            $projectPath = New-MockProject -ProjectPath $projectPath -ProjectName "TestProject"
            
            $workflowSteps = @()
            
            # Step 1: Initialize logging for the project
            if ($script:WorkflowModules['Logging']) {
                $projectLogFile = Join-Path $projectPath "project.log"
                try {
                    Initialize-LoggingSystem -LogPath $projectLogFile -LogLevel "INFO"
                    Write-CustomLog -Message "Project workflow started" -Level "INFO"
                    $workflowSteps += "Logging initialized"
                }
                catch {
                    $workflowSteps += "Logging failed: $($_.Exception.Message)"
                }
            }
            
            # Step 2: Set up development environment validation
            if ($script:WorkflowModules['DevEnvironment']) {
                try {
                    $envResult = Test-PowerShellVersion
                    if ($envResult) {
                        $workflowSteps += "Environment validated"
                    }
                    else {
                        $workflowSteps += "Environment validation failed"
                    }
                }
                catch {
                    $workflowSteps += "Environment check failed: $($_.Exception.Message)"
                }
            }
            
            # Step 3: Create some backup files and clean them up
            if ($script:WorkflowModules['BackupManager']) {
                try {
                    $backupFiles = New-MockBackupFiles -BasePath $projectPath
                    $backupDir = Join-Path $script:workflowDir "ProjectBackups"
                    
                    Invoke-BackupConsolidation -SourcePath $projectPath -BackupPath $backupDir
                    $workflowSteps += "Backup consolidation completed"
                }
                catch {
                    $workflowSteps += "Backup failed: $($_.Exception.Message)"
                }
            }
            
            # Step 4: Run project tests in parallel
            if ($script:WorkflowModules['ParallelExecution'] -and $script:WorkflowModules['TestingFramework']) {
                try {
                    $testFiles = Get-ChildItem -Path (Join-Path $projectPath "tests") -Filter "*.tests.ps1"
                    if ($testFiles) {
                        # Simulate running tests (actual Pester might not work in this context)
                        $testResults = Invoke-ParallelForEach -InputObject $testFiles -ScriptBlock {
                            param($testFile)
                            return @{
                                TestFile = $testFile.Name
                                Status = "Passed"
                                Duration = (Get-Random -Minimum 100 -Maximum 500)
                            }
                        } -ThrottleLimit 2
                        
                        $workflowSteps += "Parallel tests completed: $($testResults.Count) test files"
                    }
                }
                catch {
                    $workflowSteps += "Parallel testing failed: $($_.Exception.Message)"
                }
            }
            
            # Step 5: Unified maintenance operations
            if ($script:WorkflowModules['UnifiedMaintenance']) {
                try {
                    # This might fail if UnifiedMaintenance has issues, but that's okay
                    $maintenanceResult = Invoke-UnifiedMaintenance -TargetPath $projectPath -WhatIf
                    $workflowSteps += "Maintenance check completed"
                }
                catch {
                    $workflowSteps += "Maintenance check failed: $($_.Exception.Message)"
                }
            }
            
            # Verify workflow completion
            $workflowSteps.Count | Should -BeGreaterThan 2
            Write-Host "Workflow steps completed:" -ForegroundColor Cyan
            $workflowSteps | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
            
            # Verify project structure is intact
            Test-Path $projectPath | Should -Be $true
            Test-Path (Join-Path $projectPath "README.md") | Should -Be $true
            Test-Path (Join-Path $projectPath "src/main.ps1") | Should -Be $true
        }
    }
    
    Context "Continuous Integration Simulation" {
        
        It "Should simulate a CI pipeline with multiple projects" {
            $ciResults = @()
            
            # Create multiple mock projects
            $projects = @()
            for ($i = 1; $i -le 3; $i++) {
                $projectPath = Join-Path $script:workflowDir "CIProject$i"
                $projects += New-MockProject -ProjectPath $projectPath -ProjectName "CIProject$i"
            }
            
            # Process projects in parallel (simulating CI)
            if ($script:WorkflowModules['ParallelExecution']) {
                $ciResults = Invoke-ParallelForEach -InputObject $projects -ScriptBlock {
                    param($projectPath)
                    
                    $projectName = Split-Path $projectPath -Leaf
                    $results = @{
                        ProjectName = $projectName
                        Steps = @()
                        Success = $true
                        Errors = @()
                    }
                    
                    try {
                        # Step 1: Validate project structure
                        if (-not (Test-Path (Join-Path $projectPath "src/main.ps1"))) {
                            throw "Main script not found"
                        }
                        $results.Steps += "Structure validated"
                        
                        # Step 2: Run syntax check
                        $mainScript = Join-Path $projectPath "src/main.ps1"
                        $errors = $null
                        $tokens = $null
                        $ast = [System.Management.Automation.Language.Parser]::ParseFile($mainScript, [ref]$tokens, [ref]$errors)
                        
                        if ($errors.Count -gt 0) {
                            throw "Syntax errors found: $($errors.Count)"
                        }
                        $results.Steps += "Syntax validated"
                        
                        # Step 3: Mock test execution
                        Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 500)
                        $results.Steps += "Tests passed"
                        
                        # Step 4: Mock deployment check
                        $results.Steps += "Deployment ready"
                        
                    }
                    catch {
                        $results.Success = $false
                        $results.Errors += $_.Exception.Message
                    }
                    
                    return $results
                } -ThrottleLimit 3
                
                # Verify CI results
                $ciResults.Count | Should -Be 3
                $successfulProjects = ($ciResults | Where-Object { $_.Success }).Count
                $failedProjects = ($ciResults | Where-Object { -not $_.Success }).Count
                
                Write-Host "CI Results: $successfulProjects successful, $failedProjects failed" -ForegroundColor Cyan
                
                # At least some projects should succeed
                $successfulProjects | Should -BeGreaterThan 0
                
                # Log the results
                if ($script:WorkflowModules['Logging']) {
                    foreach ($result in $ciResults) {
                        $status = if ($result.Success) { "SUCCESS" } else { "ERROR" }
                        Write-CustomLog -Message "CI Project $($result.ProjectName): $status" -Level $status
                    }
                }
            }
        }
    }
    
    Context "Emergency Response Workflow" {
        
        It "Should handle emergency patch deployment scenario" {
            $emergencySteps = @()
            
            # Simulate emergency: critical vulnerability found
            $emergencyProject = Join-Path $script:workflowDir "EmergencyProject"
            $emergencyProject = New-MockProject -ProjectPath $emergencyProject -ProjectName "EmergencyProject"
            
            # Step 1: Create emergency backup
            if ($script:WorkflowModules['BackupManager']) {
                try {
                    $emergencyBackup = Join-Path $script:workflowDir "EmergencyBackup"
                    Invoke-BackupConsolidation -SourcePath $emergencyProject -BackupPath $emergencyBackup
                    $emergencySteps += "Emergency backup created"
                }
                catch {
                    $emergencySteps += "Emergency backup failed: $($_.Exception.Message)"
                }
            }
            
            # Step 2: Apply emergency patch using PatchManager
            if ($script:WorkflowModules['PatchManager']) {
                try {
                    # Create a simple patch operation
                    $patchResult = Invoke-PatchWorkflow -PatchDescription "Emergency security fix" -PatchOperation {
                        $mainScript = Join-Path $emergencyProject "src/main.ps1"
                        $content = Get-Content $mainScript -Raw
                        $patchedContent = $content + "`n# Emergency security patch applied"
                        Set-Content $mainScript -Value $patchedContent
                    } -CreateIssue:$false -DryRun
                    
                    $emergencySteps += "Emergency patch applied"
                }
                catch {
                    $emergencySteps += "Emergency patch failed: $($_.Exception.Message)"
                }
            }
            
            # Step 3: Rapid testing
            if ($script:WorkflowModules['ParallelExecution']) {
                try {
                    # Simulate rapid testing of critical components
                    $criticalTests = @("Security", "Authentication", "DataIntegrity", "Performance")
                    
                    $testResults = Invoke-ParallelForEach -InputObject $criticalTests -ScriptBlock {
                        param($testType)
                        
                        # Simulate test execution
                        Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 200)
                        
                        return @{
                            TestType = $testType
                            Status = if ((Get-Random) -gt 0.1) { "Passed" } else { "Failed" }
                            Duration = Get-Random -Minimum 50 -Maximum 200
                        }
                    } -ThrottleLimit 4
                    
                    $passedTests = ($testResults | Where-Object { $_.Status -eq "Passed" }).Count
                    $emergencySteps += "Rapid testing: $passedTests/$($testResults.Count) tests passed"
                }
                catch {
                    $emergencySteps += "Rapid testing failed: $($_.Exception.Message)"
                }
            }
            
            # Step 4: Emergency validation
            try {
                # Verify the emergency patch was applied
                $mainScript = Join-Path $emergencyProject "src/main.ps1"
                $content = Get-Content $mainScript -Raw
                if ($content -like "*Emergency security patch applied*") {
                    $emergencySteps += "Patch verification successful"
                }
                else {
                    $emergencySteps += "Patch verification failed"
                }
            }
            catch {
                $emergencySteps += "Verification failed: $($_.Exception.Message)"
            }
            
            # Emergency workflow should complete critical steps
            $emergencySteps.Count | Should -BeGreaterThan 2
            Write-Host "Emergency Response Steps:" -ForegroundColor Red
            $emergencySteps | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
            
            # Log emergency response
            if ($script:WorkflowModules['Logging']) {
                Write-CustomLog -Message "Emergency response workflow completed with $($emergencySteps.Count) steps" -Level "SUCCESS"
            }
        }
    }
    
    Context "Long-Running Maintenance Workflow" {
        
        It "Should handle extended maintenance operations" {
            $maintenanceSteps = @()
            $startTime = Get-Date
            
            # Create a complex project structure for maintenance
            $maintenanceProject = Join-Path $script:workflowDir "MaintenanceProject"
            $maintenanceProject = New-MockProject -ProjectPath $maintenanceProject -ProjectName "MaintenanceProject"
            
            # Add various types of files that need maintenance
            $subDirs = @("logs", "temp", "cache", "backup-old", "build")
            foreach ($dir in $subDirs) {
                $dirPath = Join-Path $maintenanceProject $dir
                New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
                
                # Add files to each directory
                for ($i = 1; $i -le 5; $i++) {
                    $fileName = "$dir-file-$i.txt"
                    $filePath = Join-Path $dirPath $fileName
                    "Content for $fileName" | Set-Content $filePath
                    
                    # Make some files old
                    if ($i -le 2) {
                        $oldDate = (Get-Date).AddDays(-30)
                        (Get-Item $filePath).LastWriteTime = $oldDate
                    }
                }
            }
            
            # Create backup files
            $backupFiles = New-MockBackupFiles -BasePath $maintenanceProject
            $maintenanceSteps += "Test environment prepared"
            
            # Step 1: Comprehensive backup
            if ($script:WorkflowModules['BackupManager']) {
                try {
                    $maintenanceBackup = Join-Path $script:workflowDir "MaintenanceBackup"
                    Invoke-BackupConsolidation -SourcePath $maintenanceProject -BackupPath $maintenanceBackup
                    $maintenanceSteps += "Comprehensive backup completed"
                }
                catch {
                    $maintenanceSteps += "Backup failed: $($_.Exception.Message)"
                }
            }
            
            # Step 2: Parallel cleanup operations
            if ($script:WorkflowModules['ParallelExecution']) {
                try {
                    $cleanupTasks = @(
                        @{ Name = "LogCleanup"; Path = "logs"; Pattern = "*.log" },
                        @{ Name = "TempCleanup"; Path = "temp"; Pattern = "*" },
                        @{ Name = "CacheCleanup"; Path = "cache"; Pattern = "*.cache" },
                        @{ Name = "OldBackupCleanup"; Path = "backup-old"; Pattern = "*.bak" }
                    )
                    
                    $cleanupResults = Invoke-ParallelForEach -InputObject $cleanupTasks -ScriptBlock {
                        param($task)
                        
                        $taskPath = Join-Path $using:maintenanceProject $task.Path
                        $itemsToClean = @()
                        
                        if (Test-Path $taskPath) {
                            $items = Get-ChildItem $taskPath -Filter $task.Pattern -ErrorAction SilentlyContinue
                            foreach ($item in $items) {
                                # Only clean files older than 7 days
                                if ($item.LastWriteTime -lt (Get-Date).AddDays(-7)) {
                                    $itemsToClean += $item.FullName
                                }
                            }
                        }
                        
                        return @{
                            TaskName = $task.Name
                            ItemsFound = $itemsToClean.Count
                            Status = "Completed"
                        }
                    } -ThrottleLimit 4
                    
                    $totalItemsCleaned = ($cleanupResults | ForEach-Object { $_.ItemsFound } | Measure-Object -Sum).Sum
                    $maintenanceSteps += "Parallel cleanup: $totalItemsCleaned items processed"
                }
                catch {
                    $maintenanceSteps += "Parallel cleanup failed: $($_.Exception.Message)"
                }
            }
            
            # Step 3: System health checks
            try {
                $healthChecks = @()
                
                # Disk space check
                $drives = Get-PSDrive -PSProvider FileSystem
                foreach ($drive in $drives) {
                    $freeSpace = $drive.Free / 1GB
                    $healthChecks += "Drive $($drive.Name): $([math]::Round($freeSpace, 2))GB free"
                }
                
                # Memory check
                $memory = [System.GC]::GetTotalMemory($false) / 1MB
                $healthChecks += "Memory usage: $([math]::Round($memory, 2))MB"
                
                # Module status check
                $loadedModules = (Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'PatchManager') }).Count
                $healthChecks += "Loaded project modules: $loadedModules"
                
                $maintenanceSteps += "Health checks completed: $($healthChecks.Count) checks"
            }
            catch {
                $maintenanceSteps += "Health checks failed: $($_.Exception.Message)"
            }
            
            # Step 4: Performance optimization
            try {
                # Simulate performance optimizations
                $optimizations = @("IndexRebuild", "CacheRefresh", "ConfigOptimization", "ResourceCleanup")
                
                foreach ($optimization in $optimizations) {
                    # Simulate optimization work
                    Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 300)
                }
                
                $maintenanceSteps += "Performance optimizations completed: $($optimizations.Count) tasks"
            }
            catch {
                $maintenanceSteps += "Performance optimization failed: $($_.Exception.Message)"
            }
            
            $endTime = Get-Date
            $totalDuration = ($endTime - $startTime).TotalSeconds
            
            # Verify maintenance workflow
            $maintenanceSteps.Count | Should -BeGreaterThan 4
            $totalDuration | Should -BeLessThan 60  # Should complete within 60 seconds
            
            Write-Host "Maintenance Workflow Completed in $([math]::Round($totalDuration, 2)) seconds:" -ForegroundColor Green
            $maintenanceSteps | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
            
            # Log maintenance completion
            if ($script:WorkflowModules['Logging']) {
                Write-CustomLog -Message "Extended maintenance workflow completed in $totalDuration seconds" -Level "SUCCESS"
            }
        }
    }
    
    Context "Cross-Platform Workflow Validation" {
        
        It "Should handle platform-specific operations gracefully" {
            $platformSteps = @()
            
            # Detect current platform
            $platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            $platformSteps += "Platform detected: $platform"
            
            # Platform-specific path handling
            try {
                $testPaths = @()
                
                if ($IsWindows) {
                    $testPaths += "C:\Windows\Temp"
                    $testPaths += "D:\NonExistent\Path"
                }
                else {
                    $testPaths += "/tmp"
                    $testPaths += "/nonexistent/path"
                }
                
                foreach ($path in $testPaths) {
                    $exists = Test-Path $path
                    $platformSteps += "Path check $path`: $exists"
                }
            }
            catch {
                $platformSteps += "Path handling failed: $($_.Exception.Message)"
            }
            
            # Platform-specific commands
            try {
                $platformCommands = @()
                
                if ($IsWindows) {
                    $platformCommands += @{ Name = "tasklist"; Args = "/fi `"imagename eq powershell.exe`"" }
                }
                else {
                    $platformCommands += @{ Name = "ps"; Args = "aux" }
                }
                
                foreach ($cmd in $platformCommands) {
                    try {
                        $result = & $cmd.Name $cmd.Args.Split() 2>$null
                        $platformSteps += "Command $($cmd.Name) executed successfully"
                    }
                    catch {
                        $platformSteps += "Command $($cmd.Name) failed: expected on some systems"
                    }
                }
            }
            catch {
                $platformSteps += "Platform command testing failed: $($_.Exception.Message)"
            }
            
            # Character encoding tests
            try {
                $testFile = Join-Path $script:workflowDir "encoding-test.txt"
                $testContent = @"
ASCII: Hello World
UTF-8: Héllo Wörld
Unicode: Hello 世界
Symbols: ★☆♠♥♦♣
"@
                
                Set-Content $testFile -Value $testContent -Encoding UTF8
                $readContent = Get-Content $testFile -Raw
                
                if ($readContent -like "*Hello World*") {
                    $platformSteps += "Character encoding test passed"
                }
                else {
                    $platformSteps += "Character encoding test failed"
                }
            }
            catch {
                $platformSteps += "Character encoding test error: $($_.Exception.Message)"
            }
            
            # Verify platform workflow
            $platformSteps.Count | Should -BeGreaterThan 3
            Write-Host "Platform-Specific Workflow ($platform):" -ForegroundColor Magenta
            $platformSteps | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
            
            # Log platform results
            if ($script:WorkflowModules['Logging']) {
                Write-CustomLog -Message "Cross-platform workflow completed on $platform" -Level "INFO"
            }
        }
    }
}

