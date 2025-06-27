# AitherZero Module Reference

Complete reference guide for all 14 AitherZero PowerShell modules.

## Table of Contents

1. [LabRunner](#labrunner)
2. [PatchManager](#patchmanager)
3. [BackupManager](#backupmanager)
4. [DevEnvironment](#devenvironment)
5. [OpenTofuProvider](#opentofuprovider)
6. [ISOManager](#isomanager)
7. [ISOCustomizer](#isocustomizer)
8. [RemoteConnection](#remoteconnection)
9. [SecureCredentials](#securecredentials)
10. [ParallelExecution](#parallelexecution)
11. [TestingFramework](#testingframework)
12. [Logging](#logging)
13. [ScriptManager](#scriptmanager)
14. [MaintenanceOperations](#maintenanceoperations)
15. [RepoSync](#reposync)

---

## LabRunner

**Purpose**: Automated lab environment orchestration and management

### Key Functions

#### `Start-LabEnvironment`
Starts a lab environment with specified configuration
```powershell
Start-LabEnvironment -ConfigPath "./configs/lab-config.json" -Environment "dev"
```

#### `Stop-LabEnvironment`
Gracefully stops a running lab environment
```powershell
Stop-LabEnvironment -LabName "TestLab" -SaveState
```

#### `New-LabConfiguration`
Creates a new lab configuration template
```powershell
New-LabConfiguration -Name "WindowsLab" -Type "HyperV" -VMCount 3
```

#### `Test-LabHealth`
Performs health checks on lab infrastructure
```powershell
Test-LabHealth -LabName "TestLab" -Verbose
```

### Configuration Example
```json
{
  "labName": "DevelopmentLab",
  "platform": "HyperV",
  "vms": [
    {
      "name": "DC01",
      "role": "DomainController",
      "memory": 4096,
      "processors": 2
    }
  ]
}
```

---

## PatchManager

**Purpose**: Git workflow automation with intelligent PR and issue creation

### Key Functions

#### `Invoke-PatchWorkflow`
Creates a patch with automated Git operations
```powershell
Invoke-PatchWorkflow -PatchDescription "Fix authentication bug" -CreatePR -CreateIssue
```

#### `Invoke-PatchRollback`
Rolls back changes with safety checks
```powershell
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup
```

#### `Get-PatchStatus`
Retrieves current patch workflow status
```powershell
Get-PatchStatus -ShowAll
```

#### `New-ConsolidatedPR`
Creates consolidated PR from multiple patches
```powershell
New-ConsolidatedPR -SourceBranches @("patch-1", "patch-2") -Title "Feature Update"
```

### Advanced Usage
```powershell
# Complex patch workflow
Invoke-PatchWorkflow -PatchDescription "Security improvements" -PatchOperation {
    # Make your changes
    Edit-File -Path "./src/auth.ps1" -Changes $securityFixes
    Add-Tests -Module "Authentication"
} -TestCommands @(
    "Invoke-Pester ./tests/auth.tests.ps1"
) -CreatePR -AssignReviewers @("john", "jane")
```

---

## BackupManager

**Purpose**: Enterprise backup, restore, and cleanup operations

### Key Functions

#### `Start-Backup`
Creates a backup with compression and encryption
```powershell
Start-Backup -SourcePath "C:\ImportantData" -DestinationPath "D:\Backups" -Compress -Encrypt
```

#### `Restore-Backup`
Restores data from backup
```powershell
Restore-Backup -BackupPath "D:\Backups\backup-20240101.zip" -TargetPath "C:\Restore"
```

#### `Invoke-BackupCleanup`
Cleans up old backups based on retention policy
```powershell
Invoke-BackupCleanup -RetentionDays 30 -Path "D:\Backups"
```

#### `Get-BackupInventory`
Lists all available backups
```powershell
Get-BackupInventory -Path "D:\Backups" -SortBy Date
```

### Backup Configuration
```powershell
# Scheduled backup example
$backupConfig = @{
    Schedule = "Daily"
    Time = "02:00"
    Sources = @("C:\Data", "C:\Config")
    Destination = "\\BackupServer\Share"
    Compression = $true
    Encryption = $true
    RetentionDays = 90
}
```

---

## DevEnvironment

**Purpose**: Development environment setup and configuration

### Key Functions

#### `Initialize-DevEnvironment`
Sets up complete development environment
```powershell
Initialize-DevEnvironment -Components @("Git", "VSCode", "PowerShell7", "Node")
```

#### `Install-DevTool`
Installs specific development tools
```powershell
Install-DevTool -Name "Docker" -Version "latest"
```

#### `Set-EnvironmentVariable`
Configures environment variables
```powershell
Set-EnvironmentVariable -Name "JAVA_HOME" -Value "C:\Program Files\Java\jdk-17" -Scope "User"
```

#### `Test-DevEnvironment`
Validates development environment setup
```powershell
Test-DevEnvironment -CheckComponents @("Git", "Node", "Python")
```

### Tool Installation Manifest
```json
{
  "tools": {
    "git": {
      "version": "2.40.0",
      "installer": "winget",
      "id": "Git.Git"
    },
    "vscode": {
      "version": "latest",
      "installer": "winget",
      "id": "Microsoft.VisualStudioCode",
      "extensions": ["ms-vscode.powershell", "ms-azuretools.vscode-docker"]
    }
  }
}
```

---

## OpenTofuProvider

**Purpose**: OpenTofu/Terraform infrastructure deployment and management

### Key Functions

#### `Invoke-TofuPlan`
Generates execution plan
```powershell
Invoke-TofuPlan -WorkingDirectory "./infrastructure" -VarFile "./vars/prod.tfvars"
```

#### `Invoke-TofuApply`
Applies infrastructure changes
```powershell
Invoke-TofuApply -WorkingDirectory "./infrastructure" -AutoApprove:$false
```

#### `Get-TofuState`
Retrieves current infrastructure state
```powershell
Get-TofuState -WorkingDirectory "./infrastructure" -OutputFormat "JSON"
```

#### `Test-TofuConfiguration`
Validates configuration files
```powershell
Test-TofuConfiguration -Path "./infrastructure" -CheckSecurity
```

### Example Configuration
```hcl
# Example OpenTofu configuration
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    Environment = var.environment
    ManagedBy   = "AitherZero"
  }
}
```

---

## ISOManager

**Purpose**: ISO file download, validation, and management

### Key Functions

#### `Get-ISOFile`
Downloads ISO files with validation
```powershell
Get-ISOFile -Source "https://example.com/windows.iso" -Destination "C:\ISOs" -ValidateChecksum
```

#### `Mount-ISO`
Mounts ISO file to system
```powershell
Mount-ISO -Path "C:\ISOs\windows.iso" -DriveLetter "E"
```

#### `New-ISOFromFolder`
Creates ISO from directory
```powershell
New-ISOFromFolder -SourcePath "C:\CustomOS" -ISOPath "C:\ISOs\custom.iso" -VolumeLabel "CUSTOM_OS"
```

#### `Test-ISOIntegrity`
Validates ISO file integrity
```powershell
Test-ISOIntegrity -Path "C:\ISOs\windows.iso" -ChecksumFile "C:\ISOs\checksums.txt"
```

---

## ISOCustomizer

**Purpose**: ISO customization for unattended installations

### Key Functions

#### `New-CustomISO`
Creates customized ISO with injected files
```powershell
New-CustomISO -SourceISO "C:\ISOs\windows.iso" -OutputISO "C:\ISOs\custom.iso" -UnattendFile ".\unattend.xml"
```

#### `Add-ISODrivers`
Injects drivers into ISO
```powershell
Add-ISODrivers -ISOPath "C:\ISOs\windows.iso" -DriverPath "C:\Drivers" -Architecture "x64"
```

#### `New-UnattendFile`
Generates unattend.xml for Windows
```powershell
New-UnattendFile -ComputerName "WORKSTATION01" -AdminPassword $secureString -TimeZone "Pacific Standard Time"
```

#### `Add-ISOPackages`
Adds software packages to ISO
```powershell
Add-ISOPackages -ISOPath "C:\ISOs\windows.iso" -PackagePath "C:\Packages" -InstallScript ".\install.ps1"
```

---

## RemoteConnection

**Purpose**: Multi-protocol remote connection management

### Key Functions

#### `New-RemoteSession`
Establishes remote connection
```powershell
New-RemoteSession -ComputerName "server01" -Protocol "SSH" -Credential $cred
```

#### `Invoke-RemoteCommand`
Executes commands on remote systems
```powershell
Invoke-RemoteCommand -Session $session -ScriptBlock { Get-Service } -AsJob
```

#### `Copy-RemoteFile`
Transfers files to/from remote systems
```powershell
Copy-RemoteFile -Session $session -Source "C:\local\file.txt" -Destination "/remote/path/"
```

#### `Test-RemoteConnection`
Tests connectivity to remote systems
```powershell
Test-RemoteConnection -ComputerName "server01" -Protocol @("SSH", "WinRM", "RDP")
```

---

## SecureCredentials

**Purpose**: Enterprise credential management and security

### Key Functions

#### `New-SecureCredential`
Creates and stores secure credentials
```powershell
New-SecureCredential -Name "ServiceAccount" -Username "svc_app" -Description "Application service account"
```

#### `Get-SecureCredential`
Retrieves stored credentials
```powershell
$cred = Get-SecureCredential -Name "ServiceAccount"
```

#### `Update-SecureCredential`
Updates existing credentials
```powershell
Update-SecureCredential -Name "ServiceAccount" -NewPassword $newSecureString -Force
```

#### `Remove-SecureCredential`
Removes stored credentials
```powershell
Remove-SecureCredential -Name "ServiceAccount" -Confirm
```

### Credential Store Configuration
```json
{
  "store": {
    "type": "LocalVault",
    "encryption": "AES256",
    "keyRotationDays": 90,
    "auditLog": true
  }
}
```

---

## ParallelExecution

**Purpose**: High-performance parallel task execution

### Key Functions

#### `Start-ParallelJob`
Executes tasks in parallel
```powershell
Start-ParallelJob -ScriptBlock { param($item) Process-Item $item } -InputObject $items -ThrottleLimit 10
```

#### `Wait-ParallelJob`
Waits for parallel jobs to complete
```powershell
Wait-ParallelJob -Job $jobs -Timeout 300 -ShowProgress
```

#### `Get-ParallelJobResult`
Retrieves results from parallel execution
```powershell
$results = Get-ParallelJobResult -Job $jobs -ErrorAction Continue
```

#### `New-RunspacePool`
Creates custom runspace pool
```powershell
$pool = New-RunspacePool -MinRunspaces 5 -MaxRunspaces 20
```

---

## TestingFramework

**Purpose**: Comprehensive testing with Pester integration

### Key Functions

#### `Invoke-BulletproofValidation`
Runs comprehensive validation tests
```powershell
Invoke-BulletproofValidation -ValidationLevel "Standard" -FailFast
```

#### `New-TestSuite`
Creates new test suite
```powershell
New-TestSuite -Name "Authentication" -Module "SecureCredentials" -TestTypes @("Unit", "Integration")
```

#### `Get-TestCoverage`
Analyzes code coverage
```powershell
Get-TestCoverage -Path "./src" -MinimumCoverage 80
```

#### `Publish-TestResults`
Publishes test results
```powershell
Publish-TestResults -ResultsPath "./TestResults.xml" -Format "NUnit" -UploadTo "AzureDevOps"
```

### Validation Levels
- **Quick** (30 seconds): Syntax, basic validation
- **Standard** (2-5 minutes): Module tests, integration
- **Complete** (10-15 minutes): Full system validation

---

## Logging

**Purpose**: Centralized logging system

### Key Functions

#### `Write-CustomLog`
Writes structured log entries
```powershell
Write-CustomLog -Level "INFO" -Message "Operation completed" -Component "BackupManager"
```

#### `Get-LogEntries`
Queries log entries
```powershell
Get-LogEntries -Level "ERROR" -StartTime (Get-Date).AddHours(-24) -Component "PatchManager"
```

#### `Export-Logs`
Exports logs to various formats
```powershell
Export-Logs -Format "JSON" -Path "./logs/export.json" -Filter { $_.Level -eq "ERROR" }
```

#### `Clear-OldLogs`
Manages log rotation
```powershell
Clear-OldLogs -RetentionDays 30 -ArchivePath "./logs/archive"
```

### Log Levels
- **DEBUG**: Detailed debugging information
- **INFO**: Informational messages
- **WARNING**: Warning messages
- **ERROR**: Error messages
- **CRITICAL**: Critical failures
- **SUCCESS**: Success messages

---

## ScriptManager

**Purpose**: PowerShell script repository management

### Key Functions

#### `Register-Script`
Registers script in repository
```powershell
Register-Script -Path "./scripts/Deploy-App.ps1" -Category "Deployment" -Tags @("Azure", "WebApp")
```

#### `Invoke-ManagedScript`
Executes managed script
```powershell
Invoke-ManagedScript -Name "Deploy-App" -Parameters @{Environment="Production"}
```

#### `Get-ScriptInventory`
Lists available scripts
```powershell
Get-ScriptInventory -Category "Maintenance" -IncludeMetadata
```

#### `Update-ScriptMetadata`
Updates script information
```powershell
Update-ScriptMetadata -Name "Deploy-App" -Version "2.0" -Description "Updated deployment script"
```

---

## MaintenanceOperations

**Purpose**: System maintenance automation

### Key Functions

#### `Start-MaintenanceMode`
Enters maintenance mode
```powershell
Start-MaintenanceMode -Scope "Application" -NotificationMessage "Scheduled maintenance in progress"
```

#### `Invoke-SystemCleanup`
Performs system cleanup
```powershell
Invoke-SystemCleanup -CleanupType @("TempFiles", "Logs", "Cache") -FreeSpaceTarget 20GB
```

#### `Update-SystemComponents`
Updates system components
```powershell
Update-SystemComponents -Components @("PowerShell", "Git", "OpenTofu") -AutoRestart:$false
```

#### `Get-MaintenanceReport`
Generates maintenance report
```powershell
Get-MaintenanceReport -Period "LastMonth" -Format "HTML" -SendEmail $true
```

---

## RepoSync

**Purpose**: Repository synchronization across fork chains

### Key Functions

#### `Sync-Repository`
Synchronizes repository with upstream
```powershell
Sync-Repository -UpstreamUrl "https://github.com/original/repo.git" -Branch "main"
```

#### `Update-ForkChain`
Updates entire fork chain
```powershell
Update-ForkChain -Chain @("AitherZero", "AitherLabs", "Aitherium") -SyncBranches @("main", "develop")
```

#### `Resolve-SyncConflicts`
Handles merge conflicts
```powershell
Resolve-SyncConflicts -Strategy "PreferUpstream" -AutoCommit:$false
```

#### `Get-SyncStatus`
Checks synchronization status
```powershell
Get-SyncStatus -ShowDiff -IncludeAllBranches
```

---

## Common Parameters

Most functions support these common parameters:

- `-WhatIf`: Shows what would happen without making changes
- `-Confirm`: Prompts for confirmation before making changes
- `-Verbose`: Provides detailed output
- `-Debug`: Shows debug information
- `-ErrorAction`: Controls error handling behavior

## Error Handling

All modules implement consistent error handling:

```powershell
try {
    # Module operation
} catch {
    Write-CustomLog -Level "ERROR" -Message $_.Exception.Message
    throw
}
```

## Best Practices

1. **Always use parameter validation**
2. **Implement proper error handling**
3. **Use Write-CustomLog for all output**
4. **Follow naming conventions**
5. **Include help documentation**
6. **Write unit tests for new functions**

---

For more detailed information, refer to individual module documentation in `/aither-core/modules/[ModuleName]/`