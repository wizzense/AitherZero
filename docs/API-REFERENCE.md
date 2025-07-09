# AitherZero Domain API Reference

This document provides comprehensive API reference for all 196 functions across the 6 AitherZero domains.

## API Overview

### Domain Summary
| Domain | Functions | Primary Purpose |
|--------|-----------|------------------|
| [Infrastructure](#infrastructure-domain-api) | 57 | Infrastructure deployment and monitoring |
| [Security](#security-domain-api) | 41 | Security automation and credential management |
| [Configuration](#configuration-domain-api) | 36 | Configuration management and environment switching |
| [Utilities](#utilities-domain-api) | 24 | Utility services and maintenance |
| [Experience](#experience-domain-api) | 22 | User experience and setup automation |
| [Automation](#automation-domain-api) | 16 | Script management and workflow orchestration |

**Total: 196 functions**

## Common Patterns

### Function Naming Conventions
- **Get-**: Retrieve information or data
- **Set-**: Configure or update settings
- **New-**: Create new resources or objects
- **Start-**: Begin processes or operations
- **Stop-**: End processes or operations
- **Test-**: Validate or check conditions
- **Invoke-**: Execute operations or commands
- **Enable-**: Turn on features or capabilities
- **Disable-**: Turn off features or capabilities

### Common Parameters
- **-Force**: Override confirmations and force operations
- **-WhatIf**: Preview operations without executing
- **-Verbose**: Enable detailed output
- **-Path**: Specify file or directory paths
- **-Name**: Specify resource names
- **-Configuration**: Specify configuration objects

### Return Value Patterns
- **Success Objects**: `@{ Success = $true; Result = $data }`
- **Error Objects**: `@{ Success = $false; Error = $errorMessage }`
- **Status Objects**: `@{ Status = "Running"; Details = $info }`
- **Collection Objects**: Arrays of objects with consistent structure

## Infrastructure Domain API

### LabRunner Functions (17 functions)

#### `Get-Platform`
**Purpose**: Get comprehensive platform information
**Parameters**: None
**Returns**: Platform information object
**Example**:
```powershell
$platform = Get-Platform
Write-Host "Platform: $($platform.OS)"
```

#### `Get-CrossPlatformTempPath`
**Purpose**: Get cross-platform temporary path
**Parameters**: None
**Returns**: String path to temporary directory
**Example**:
```powershell
$tempPath = Get-CrossPlatformTempPath
New-Item -ItemType Directory -Path $tempPath -Force
```

#### `Invoke-CrossPlatformCommand`
**Purpose**: Execute commands across different platforms
**Parameters**: 
- `Command` (string): Command to execute
- `Arguments` (array): Command arguments
**Returns**: Command execution result
**Example**:
```powershell
$result = Invoke-CrossPlatformCommand -Command "ls" -Arguments @("-la")
```

#### `Write-ProgressLog`
**Purpose**: Write progress information with logging
**Parameters**:
- `Message` (string): Progress message
- `Activity` (string): Activity description
- `PercentComplete` (int): Completion percentage
**Returns**: None
**Example**:
```powershell
Write-ProgressLog -Message "Processing files" -Activity "File Processing" -PercentComplete 50
```

#### `Resolve-ProjectPath`
**Purpose**: Resolve project-relative paths
**Parameters**:
- `Path` (string): Relative path to resolve
**Returns**: Absolute path string
**Example**:
```powershell
$fullPath = Resolve-ProjectPath -Path "configs/app-config.json"
```

#### `Invoke-LabStep`
**Purpose**: Execute individual lab automation steps
**Parameters**:
- `StepName` (string): Name of the step
- `StepScript` (scriptblock): Script to execute
- `Parameters` (hashtable): Step parameters
**Returns**: Step execution result
**Example**:
```powershell
$result = Invoke-LabStep -StepName "Install Tools" -StepScript { Install-RequiredTools } -Parameters @{ Force = $true }
```

#### `Invoke-LabDownload`
**Purpose**: Download resources for lab automation
**Parameters**:
- `Url` (string): URL to download from
- `Destination` (string): Download destination
- `Force` (switch): Force download
**Returns**: Download result
**Example**:
```powershell
$result = Invoke-LabDownload -Url "https://example.com/file.zip" -Destination "./downloads/" -Force
```

#### `Read-LoggedInput`
**Purpose**: Read user input with logging
**Parameters**:
- `Prompt` (string): Input prompt
- `Secure` (switch): Secure input
**Returns**: User input
**Example**:
```powershell
$input = Read-LoggedInput -Prompt "Enter your name"
$secureInput = Read-LoggedInput -Prompt "Enter password" -Secure
```

#### `Invoke-LabWebRequest`
**Purpose**: Make web requests with lab-specific handling
**Parameters**:
- `Uri` (string): Request URI
- `Method` (string): HTTP method
- `Headers` (hashtable): Request headers
**Returns**: Web response
**Example**:
```powershell
$response = Invoke-LabWebRequest -Uri "https://api.example.com/data" -Method "GET"
```

#### `Invoke-LabNpm`
**Purpose**: Execute npm commands in lab environment
**Parameters**:
- `Command` (string): npm command
- `Arguments` (array): Command arguments
- `WorkingDirectory` (string): Working directory
**Returns**: npm execution result
**Example**:
```powershell
$result = Invoke-LabNpm -Command "install" -Arguments @("express") -WorkingDirectory "./app"
```

#### `Get-LabConfig`
**Purpose**: Get lab configuration
**Parameters**:
- `LabName` (string): Lab name
- `ConfigType` (string): Configuration type
**Returns**: Lab configuration object
**Example**:
```powershell
$config = Get-LabConfig -LabName "WebLab" -ConfigType "Development"
```

#### `Start-LabAutomation`
**Purpose**: Start lab automation workflows
**Parameters**:
- `Config` (object): Lab configuration
- `Steps` (array): Automation steps
- `Parallel` (switch): Parallel execution
**Returns**: Automation result
**Example**:
```powershell
$result = Start-LabAutomation -Config $labConfig -Steps @("Setup", "Deploy", "Test") -Parallel
```

#### `Test-ParallelRunnerSupport`
**Purpose**: Test if parallel execution is supported
**Parameters**: None
**Returns**: Boolean indicating support
**Example**:
```powershell
$supportsParallel = Test-ParallelRunnerSupport
if ($supportsParallel) {
    Write-Host "Parallel execution is supported"
}
```

#### `Get-LabStatus`
**Purpose**: Get current lab status
**Parameters**:
- `LabName` (string): Lab name
**Returns**: Lab status object
**Example**:
```powershell
$status = Get-LabStatus -LabName "WebLab"
Write-Host "Lab Status: $($status.Status)"
```

#### `Start-EnhancedLabDeployment`
**Purpose**: Start enhanced lab deployment with monitoring
**Parameters**:
- `DeploymentConfig` (object): Deployment configuration
- `MonitoringEnabled` (switch): Enable monitoring
**Returns**: Deployment result
**Example**:
```powershell
$result = Start-EnhancedLabDeployment -DeploymentConfig $config -MonitoringEnabled
```

#### `Test-LabDeploymentHealth`
**Purpose**: Test lab deployment health
**Parameters**:
- `LabName` (string): Lab name
- `HealthChecks` (array): Health check list
**Returns**: Health check results
**Example**:
```powershell
$health = Test-LabDeploymentHealth -LabName "WebLab" -HealthChecks @("Database", "WebServer", "API")
```

#### `Write-EnhancedDeploymentSummary`
**Purpose**: Write enhanced deployment summary
**Parameters**:
- `DeploymentResult` (object): Deployment result
- `OutputPath` (string): Summary output path
**Returns**: None
**Example**:
```powershell
Write-EnhancedDeploymentSummary -DeploymentResult $result -OutputPath "./deployment-summary.json"
```

### OpenTofu Provider Functions (11 functions)

#### `ConvertFrom-Yaml`
**Purpose**: Convert YAML to PowerShell objects
**Parameters**:
- `YamlContent` (string): YAML content
**Returns**: PowerShell object
**Example**:
```powershell
$yamlContent = Get-Content "./config.yaml" -Raw
$config = ConvertFrom-Yaml -YamlContent $yamlContent
```

#### `ConvertTo-Yaml`
**Purpose**: Convert PowerShell objects to YAML
**Parameters**:
- `InputObject` (object): Object to convert
**Returns**: YAML string
**Example**:
```powershell
$config = @{ Name = "Test"; Value = 123 }
$yaml = ConvertTo-Yaml -InputObject $config
```

#### `Test-OpenTofuInstallation`
**Purpose**: Test OpenTofu installation and configuration
**Parameters**: None
**Returns**: Installation status object
**Example**:
```powershell
$installStatus = Test-OpenTofuInstallation
if ($installStatus.Installed) {
    Write-Host "OpenTofu version: $($installStatus.Version)"
}
```

#### `Install-OpenTofuSecure`
**Purpose**: Install OpenTofu with security validation
**Parameters**:
- `Version` (string): OpenTofu version
- `InstallPath` (string): Installation path
- `Force` (switch): Force installation
**Returns**: Installation result
**Example**:
```powershell
$result = Install-OpenTofuSecure -Version "1.6.0" -InstallPath "./tools" -Force
```

#### `New-TaliesinsProviderConfig`
**Purpose**: Create Taliesins provider configuration
**Parameters**:
- `ProviderConfig` (hashtable): Provider configuration
**Returns**: Provider configuration object
**Example**:
```powershell
$config = New-TaliesinsProviderConfig -ProviderConfig @{
    endpoint = "https://api.example.com"
    token = "secret-token"
}
```

#### `Test-TaliesinsProviderInstallation`
**Purpose**: Test Taliesins provider installation
**Parameters**: None
**Returns**: Provider installation status
**Example**:
```powershell
$providerStatus = Test-TaliesinsProviderInstallation
Write-Host "Provider Status: $($providerStatus.Status)"
```

#### `Invoke-OpenTofuCommand`
**Purpose**: Execute OpenTofu commands
**Parameters**:
- `Command` (string): OpenTofu command
- `Arguments` (array): Command arguments
- `WorkingDirectory` (string): Working directory
**Returns**: Command execution result
**Example**:
```powershell
$result = Invoke-OpenTofuCommand -Command "plan" -Arguments @("-var-file=vars.tfvars") -WorkingDirectory "./infrastructure"
```

#### `Initialize-OpenTofuProvider`
**Purpose**: Initialize OpenTofu provider
**Parameters**:
- `ProviderConfig` (object): Provider configuration
- `BackendConfig` (object): Backend configuration
**Returns**: Initialization result
**Example**:
```powershell
$result = Initialize-OpenTofuProvider -ProviderConfig $providerConfig -BackendConfig $backendConfig
```

#### `Start-InfrastructureDeployment`
**Purpose**: Start infrastructure deployment
**Parameters**:
- `ConfigPath` (string): Configuration file path
- `Variables` (hashtable): Deployment variables
- `Plan` (switch): Plan-only mode
**Returns**: Deployment result
**Example**:
```powershell
$result = Start-InfrastructureDeployment -ConfigPath "./main.tf" -Variables @{ environment = "dev" } -Plan
```

#### `New-LabInfrastructure`
**Purpose**: Create lab infrastructure
**Parameters**:
- `LabConfig` (object): Lab configuration
- `InfrastructureType` (string): Infrastructure type
**Returns**: Infrastructure creation result
**Example**:
```powershell
$result = New-LabInfrastructure -LabConfig $labConfig -InfrastructureType "VM"
```

#### `Get-DeploymentStatus`
**Purpose**: Get deployment status
**Parameters**:
- `DeploymentId` (string): Deployment ID
**Returns**: Deployment status object
**Example**:
```powershell
$status = Get-DeploymentStatus -DeploymentId "deploy-12345"
Write-Host "Deployment Status: $($status.Status)"
```

### System Monitoring Functions (19 functions)

#### `Get-CpuUsageLinux`
**Purpose**: Get CPU usage on Linux systems
**Parameters**: None
**Returns**: CPU usage percentage
**Example**:
```powershell
$cpuUsage = Get-CpuUsageLinux
Write-Host "CPU Usage: $cpuUsage%"
```

#### `Get-MemoryInfo`
**Purpose**: Get memory information
**Parameters**: None
**Returns**: Memory information object
**Example**:
```powershell
$memory = Get-MemoryInfo
Write-Host "Total Memory: $($memory.TotalGB) GB"
Write-Host "Available Memory: $($memory.AvailableGB) GB"
```

#### `Get-DiskInfo`
**Purpose**: Get disk information
**Parameters**: None
**Returns**: Disk information array
**Example**:
```powershell
$disks = Get-DiskInfo
foreach ($disk in $disks) {
    Write-Host "Drive $($disk.Drive): $($disk.UsedPercentage)% used"
}
```

#### `Get-NetworkInfo`
**Purpose**: Get network information
**Parameters**: None
**Returns**: Network information object
**Example**:
```powershell
$network = Get-NetworkInfo
Write-Host "Network Interfaces: $($network.Interfaces.Count)"
```

#### `Get-CriticalServiceStatus`
**Purpose**: Get critical service status
**Parameters**: None
**Returns**: Service status array
**Example**:
```powershell
$services = Get-CriticalServiceStatus
$failedServices = $services | Where-Object { $_.Status -ne "Running" }
```

#### `Get-AlertStatus`
**Purpose**: Get alert status
**Parameters**: None
**Returns**: Alert status object
**Example**:
```powershell
$alertStatus = Get-AlertStatus
Write-Host "Active Alerts: $($alertStatus.ActiveAlerts.Count)"
```

#### `Get-CurrentAlerts`
**Purpose**: Get current system alerts
**Parameters**: None
**Returns**: Current alerts array
**Example**:
```powershell
$alerts = Get-CurrentAlerts
foreach ($alert in $alerts) {
    Write-Host "Alert: $($alert.Message) - Severity: $($alert.Severity)"
}
```

#### `Get-OverallHealthStatus`
**Purpose**: Get overall system health status
**Parameters**: None
**Returns**: Health status object
**Example**:
```powershell
$health = Get-OverallHealthStatus
Write-Host "Overall Health: $($health.Status)"
Write-Host "Health Score: $($health.Score)/100"
```

#### `Get-SystemUptime`
**Purpose**: Get system uptime
**Parameters**: None
**Returns**: Uptime information object
**Example**:
```powershell
$uptime = Get-SystemUptime
Write-Host "System Uptime: $($uptime.Days) days, $($uptime.Hours) hours"
```

#### `Convert-SizeToGB`
**Purpose**: Convert size values to GB
**Parameters**:
- `Size` (long): Size in bytes
**Returns**: Size in GB
**Example**:
```powershell
$sizeInGB = Convert-SizeToGB -Size 1073741824
Write-Host "Size: $sizeInGB GB"
```

#### `Show-ConsoleDashboard`
**Purpose**: Show console-based system dashboard
**Parameters**: None
**Returns**: None
**Example**:
```powershell
Show-ConsoleDashboard
```

#### `Get-SystemDashboard`
**Purpose**: Get system dashboard data
**Parameters**: None
**Returns**: Dashboard data object
**Example**:
```powershell
$dashboard = Get-SystemDashboard
Write-Host "CPU: $($dashboard.CPU.Usage)%"
Write-Host "Memory: $($dashboard.Memory.UsedPercentage)%"
```

#### `Get-SystemPerformance`
**Purpose**: Get system performance metrics
**Parameters**: None
**Returns**: Performance metrics object
**Example**:
```powershell
$performance = Get-SystemPerformance
Write-Host "Response Time: $($performance.ResponseTime)ms"
```

#### `Get-SystemAlerts`
**Purpose**: Get system alerts
**Parameters**: None
**Returns**: System alerts array
**Example**:
```powershell
$alerts = Get-SystemAlerts
$criticalAlerts = $alerts | Where-Object { $_.Severity -eq "Critical" }
```

#### `Start-SystemMonitoring`
**Purpose**: Start system monitoring
**Parameters**:
- `MonitoringConfig` (object): Monitoring configuration
**Returns**: Monitoring session object
**Example**:
```powershell
$session = Start-SystemMonitoring -MonitoringConfig $config
```

#### `Stop-SystemMonitoring`
**Purpose**: Stop system monitoring
**Parameters**:
- `SessionId` (string): Monitoring session ID
**Returns**: Stop result
**Example**:
```powershell
$result = Stop-SystemMonitoring -SessionId $session.Id
```

#### `Invoke-HealthCheck`
**Purpose**: Perform system health check
**Parameters**:
- `CheckType` (string): Type of health check
**Returns**: Health check results
**Example**:
```powershell
$healthCheck = Invoke-HealthCheck -CheckType "Full"
Write-Host "Health Check Score: $($healthCheck.Score)"
```

#### `Set-PerformanceBaseline`
**Purpose**: Set performance baseline
**Parameters**:
- `BaselineConfig` (object): Baseline configuration
**Returns**: Baseline setting result
**Example**:
```powershell
$result = Set-PerformanceBaseline -BaselineConfig $baselineConfig
```

#### `Get-ServiceStatus`
**Purpose**: Get service status
**Parameters**:
- `ServiceName` (string): Service name
**Returns**: Service status object
**Example**:
```powershell
$status = Get-ServiceStatus -ServiceName "AitherService"
Write-Host "Service Status: $($status.Status)"
```

### ISO Manager Functions (10 functions)

#### `Get-WindowsISOUrl`
**Purpose**: Get Windows ISO download URLs
**Parameters**:
- `Version` (string): Windows version
- `Architecture` (string): System architecture
**Returns**: ISO URL information
**Example**:
```powershell
$isoUrl = Get-WindowsISOUrl -Version "Server2022" -Architecture "x64"
Write-Host "Download URL: $($isoUrl.Url)"
```

#### `Get-LinuxISOUrl`
**Purpose**: Get Linux ISO download URLs
**Parameters**:
- `Distribution` (string): Linux distribution
- `Version` (string): Distribution version
**Returns**: ISO URL information
**Example**:
```powershell
$isoUrl = Get-LinuxISOUrl -Distribution "Ubuntu" -Version "22.04"
Write-Host "Download URL: $($isoUrl.Url)"
```

#### `Test-AdminPrivileges`
**Purpose**: Test if running with admin privileges
**Parameters**: None
**Returns**: Boolean indicating admin status
**Example**:
```powershell
$isAdmin = Test-AdminPrivileges
if (-not $isAdmin) {
    Write-Warning "Admin privileges required"
}
```

#### `Test-ISOIntegrity`
**Purpose**: Test ISO file integrity
**Parameters**:
- `ISOPath` (string): Path to ISO file
- `ExpectedHash` (string): Expected hash value
**Returns**: Integrity test result
**Example**:
```powershell
$integrityResult = Test-ISOIntegrity -ISOPath "./windows.iso" -ExpectedHash "ABC123..."
Write-Host "Integrity Check: $($integrityResult.IsValid)"
```

#### `Invoke-ModernHttpDownload`
**Purpose**: Modern HTTP download with progress
**Parameters**:
- `Url` (string): Download URL
- `OutputPath` (string): Output file path
- `ShowProgress` (switch): Show progress
**Returns**: Download result
**Example**:
```powershell
$result = Invoke-ModernHttpDownload -Url "https://example.com/file.iso" -OutputPath "./file.iso" -ShowProgress
```

#### `Invoke-BitsDownload`
**Purpose**: Download using BITS transfer
**Parameters**:
- `Url` (string): Download URL
- `OutputPath` (string): Output file path
**Returns**: BITS download result
**Example**:
```powershell
$result = Invoke-BitsDownload -Url "https://example.com/file.iso" -OutputPath "./file.iso"
```

#### `Invoke-WebRequestDownload`
**Purpose**: Download using web request
**Parameters**:
- `Url` (string): Download URL
- `OutputPath` (string): Output file path
**Returns**: Web request download result
**Example**:
```powershell
$result = Invoke-WebRequestDownload -Url "https://example.com/file.iso" -OutputPath "./file.iso"
```

#### `Get-BootstrapTemplate`
**Purpose**: Get bootstrap template for ISO customization
**Parameters**:
- `TemplateType` (string): Template type
- `OSType` (string): Operating system type
**Returns**: Bootstrap template
**Example**:
```powershell
$template = Get-BootstrapTemplate -TemplateType "Unattended" -OSType "Windows"
```

#### `Apply-OfflineRegistryChanges`
**Purpose**: Apply registry changes to offline image
**Parameters**:
- `ImagePath` (string): Path to mounted image
- `RegistryChanges` (array): Registry changes to apply
**Returns**: Registry application result
**Example**:
```powershell
$result = Apply-OfflineRegistryChanges -ImagePath "./mounted" -RegistryChanges $registryChanges
```

#### `Find-DuplicateISOs`
**Purpose**: Find duplicate ISO files
**Parameters**:
- `SearchPath` (string): Path to search
**Returns**: Duplicate ISO information
**Example**:
```powershell
$duplicates = Find-DuplicateISOs -SearchPath "./isos"
foreach ($duplicate in $duplicates) {
    Write-Host "Duplicate found: $($duplicate.Path)"
}
```

#### `Compress-ISOFile`
**Purpose**: Compress ISO file
**Parameters**:
- `ISOPath` (string): Path to ISO file
- `OutputPath` (string): Output compressed file path
**Returns**: Compression result
**Example**:
```powershell
$result = Compress-ISOFile -ISOPath "./windows.iso" -OutputPath "./windows.iso.gz"
```

#### `Get-ISODownload`
**Purpose**: Download ISO files
**Parameters**:
- `Url` (string): Download URL
- `OutputPath` (string): Output directory
- `Validate` (switch): Validate download
**Returns**: Download result
**Example**:
```powershell
$result = Get-ISODownload -Url $isoUrl.Url -OutputPath "./downloads" -Validate
```

#### `Get-ISOMetadata`
**Purpose**: Get ISO file metadata
**Parameters**:
- `ISOPath` (string): Path to ISO file
**Returns**: ISO metadata object
**Example**:
```powershell
$metadata = Get-ISOMetadata -ISOPath "./windows.iso"
Write-Host "ISO Label: $($metadata.Label)"
Write-Host "ISO Size: $($metadata.Size) bytes"
```

#### `New-CustomISO`
**Purpose**: Create custom ISO file
**Parameters**:
- `SourcePath` (string): Source directory path
- `OutputPath` (string): Output ISO path
- `Label` (string): ISO label
**Returns**: ISO creation result
**Example**:
```powershell
$result = New-CustomISO -SourcePath "./source" -OutputPath "./custom.iso" -Label "CustomOS"
```

#### `Get-ISOInventory`
**Purpose**: Get ISO inventory
**Parameters**:
- `InventoryPath` (string): Inventory path
**Returns**: ISO inventory object
**Example**:
```powershell
$inventory = Get-ISOInventory -InventoryPath "./isos"
Write-Host "Total ISOs: $($inventory.Count)"
```

#### `New-AutounattendFile`
**Purpose**: Create autounattend.xml file
**Parameters**:
- `Configuration` (object): Autounattend configuration
- `OutputPath` (string): Output file path
**Returns**: Autounattend creation result
**Example**:
```powershell
$result = New-AutounattendFile -Configuration $config -OutputPath "./autounattend.xml"
```

#### `Optimize-ISOStorage`
**Purpose**: Optimize ISO storage
**Parameters**:
- `StoragePath` (string): Storage path
- `OptimizationLevel` (string): Optimization level
**Returns**: Optimization result
**Example**:
```powershell
$result = Optimize-ISOStorage -StoragePath "./isos" -OptimizationLevel "Aggressive"
```

## Security Domain API

### Secure Credential Management Functions (10 functions)

#### `Initialize-SecureCredentialStore`
**Purpose**: Initialize secure credential storage
**Parameters**:
- `StorePath` (string): Credential store path
- `EncryptionKey` (string): Encryption key
**Returns**: Initialization result
**Example**:
```powershell
$result = Initialize-SecureCredentialStore -StorePath "./credentials" -EncryptionKey $key
```

#### `New-SecureCredential`
**Purpose**: Create new secure credential
**Parameters**:
- `Name` (string): Credential name
- `Username` (string): Username
- `Password` (securestring): Password
- `Description` (string): Credential description
**Returns**: Credential creation result
**Example**:
```powershell
$securePassword = ConvertTo-SecureString "password" -AsPlainText -Force
$result = New-SecureCredential -Name "DatabaseCred" -Username "admin" -Password $securePassword -Description "Database access"
```

#### `Get-SecureCredential`
**Purpose**: Retrieve secure credential
**Parameters**:
- `Name` (string): Credential name
**Returns**: Credential object
**Example**:
```powershell
$credential = Get-SecureCredential -Name "DatabaseCred"
Write-Host "Username: $($credential.Username)"
```

#### `Get-AllSecureCredentials`
**Purpose**: List all stored credentials
**Parameters**: None
**Returns**: Array of credential objects
**Example**:
```powershell
$credentials = Get-AllSecureCredentials
foreach ($cred in $credentials) {
    Write-Host "Credential: $($cred.Name)"
}
```

#### `Update-SecureCredential`
**Purpose**: Update existing credential
**Parameters**:
- `Name` (string): Credential name
- `Username` (string): New username
- `Password` (securestring): New password
**Returns**: Update result
**Example**:
```powershell
$newPassword = ConvertTo-SecureString "newpassword" -AsPlainText -Force
$result = Update-SecureCredential -Name "DatabaseCred" -Username "newadmin" -Password $newPassword
```

#### `Remove-SecureCredential`
**Purpose**: Remove credential from store
**Parameters**:
- `Name` (string): Credential name
- `Force` (switch): Force removal
**Returns**: Removal result
**Example**:
```powershell
$result = Remove-SecureCredential -Name "DatabaseCred" -Force
```

#### `Backup-SecureCredentialStore`
**Purpose**: Create credential store backup
**Parameters**:
- `BackupPath` (string): Backup destination
**Returns**: Backup result
**Example**:
```powershell
$result = Backup-SecureCredentialStore -BackupPath "./backup-credentials"
```

#### `Test-SecureCredentialCompliance`
**Purpose**: Test credential compliance
**Parameters**:
- `ComplianceRules` (object): Compliance rules
**Returns**: Compliance test result
**Example**:
```powershell
$compliance = Test-SecureCredentialCompliance -ComplianceRules $rules
Write-Host "Compliance Status: $($compliance.Status)"
```

#### `Export-SecureCredential`
**Purpose**: Export credential securely
**Parameters**:
- `Name` (string): Credential name
- `ExportPath` (string): Export destination
- `Format` (string): Export format
**Returns**: Export result
**Example**:
```powershell
$result = Export-SecureCredential -Name "DatabaseCred" -ExportPath "./export.json" -Format "JSON"
```

#### `Import-SecureCredential`
**Purpose**: Import credential from external source
**Parameters**:
- `ImportPath` (string): Import source
- `Format` (string): Import format
**Returns**: Import result
**Example**:
```powershell
$result = Import-SecureCredential -ImportPath "./import.json" -Format "JSON"
```

### Security Automation Functions (31 functions)

#### `Get-ADSecurityAssessment`
**Purpose**: Perform Active Directory security assessment
**Parameters**:
- `DomainName` (string): Domain name
- `AssessmentType` (string): Assessment type
**Returns**: Security assessment result
**Example**:
```powershell
$assessment = Get-ADSecurityAssessment -DomainName "company.local" -AssessmentType "Comprehensive"
Write-Host "Security Score: $($assessment.Score)"
```

#### `Set-ADPasswordPolicy`
**Purpose**: Configure AD password policy
**Parameters**:
- `PolicyConfig` (object): Password policy configuration
**Returns**: Policy configuration result
**Example**:
```powershell
$policy = @{
    MinimumPasswordLength = 12
    PasswordComplexityEnabled = $true
    MaxPasswordAge = 90
}
$result = Set-ADPasswordPolicy -PolicyConfig $policy
```

#### `Get-ADDelegationRisks`
**Purpose**: Identify AD delegation risks
**Parameters**:
- `DomainName` (string): Domain name
**Returns**: Delegation risk assessment
**Example**:
```powershell
$risks = Get-ADDelegationRisks -DomainName "company.local"
foreach ($risk in $risks) {
    Write-Host "Risk: $($risk.Description) - Level: $($risk.Level)"
}
```

#### `Enable-ADSmartCardLogon`
**Purpose**: Enable smart card authentication
**Parameters**:
- `UserAccount` (string): User account
- `CertificateTemplate` (string): Certificate template
**Returns**: Smart card enablement result
**Example**:
```powershell
$result = Enable-ADSmartCardLogon -UserAccount "admin" -CertificateTemplate "SmartCardLogon"
```

#### `Install-EnterpriseCA`
**Purpose**: Install enterprise certificate authority
**Parameters**:
- `CAName` (string): CA name
- `CAType` (string): CA type
- `Configuration` (object): CA configuration
**Returns**: CA installation result
**Example**:
```powershell
$result = Install-EnterpriseCA -CAName "CompanyCA" -CAType "EnterpriseRootCA" -Configuration $caConfig
```

#### `New-CertificateTemplate`
**Purpose**: Create certificate template
**Parameters**:
- `TemplateName` (string): Template name
- `Purpose` (string): Certificate purpose
- `Configuration` (object): Template configuration
**Returns**: Template creation result
**Example**:
```powershell
$result = New-CertificateTemplate -TemplateName "WebServer" -Purpose "ServerAuthentication" -Configuration $templateConfig
```

#### `Enable-CertificateAutoEnrollment`
**Purpose**: Enable certificate auto-enrollment
**Parameters**:
- `TemplateName` (string): Template name
- `UserGroup` (string): User group
**Returns**: Auto-enrollment result
**Example**:
```powershell
$result = Enable-CertificateAutoEnrollment -TemplateName "WebServer" -UserGroup "WebAdmins"
```

#### `Invoke-CertificateLifecycleManagement`
**Purpose**: Manage certificate lifecycle
**Parameters**:
- `Operation` (string): Lifecycle operation
- `CertificateId` (string): Certificate ID
**Returns**: Lifecycle management result
**Example**:
```powershell
$result = Invoke-CertificateLifecycleManagement -Operation "Renew" -CertificateId "cert-12345"
```

#### `Enable-CredentialGuard`
**Purpose**: Enable Windows Credential Guard
**Parameters**:
- `Force` (switch): Force enable
**Returns**: Credential Guard enablement result
**Example**:
```powershell
$result = Enable-CredentialGuard -Force
```

#### `Enable-AdvancedAuditPolicy`
**Purpose**: Enable advanced audit policy
**Parameters**:
- `AuditLevel` (string): Audit level
- `AuditCategories` (array): Audit categories
**Returns**: Audit policy result
**Example**:
```powershell
$result = Enable-AdvancedAuditPolicy -AuditLevel "Enhanced" -AuditCategories @("Logon", "ObjectAccess")
```

#### `Set-AppLockerPolicy`
**Purpose**: Configure AppLocker policy
**Parameters**:
- `PolicyLevel` (string): Policy level
- `PolicyRules` (array): Policy rules
**Returns**: AppLocker configuration result
**Example**:
```powershell
$result = Set-AppLockerPolicy -PolicyLevel "Enforce" -PolicyRules $policyRules
```

#### `Set-WindowsFirewallProfile`
**Purpose**: Configure Windows Firewall profile
**Parameters**:
- `Profile` (string): Firewall profile
- `Configuration` (object): Firewall configuration
**Returns**: Firewall configuration result
**Example**:
```powershell
$result = Set-WindowsFirewallProfile -Profile "Domain" -Configuration $firewallConfig
```

#### `Enable-ExploitProtection`
**Purpose**: Enable Windows Exploit Protection
**Parameters**:
- `ProtectionLevel` (string): Protection level
**Returns**: Exploit protection result
**Example**:
```powershell
$result = Enable-ExploitProtection -ProtectionLevel "Maximum"
```

#### `Set-IPsecPolicy`
**Purpose**: Configure IPsec policy
**Parameters**:
- `PolicyName` (string): Policy name
- `PolicyConfig` (object): IPsec policy configuration
**Returns**: IPsec policy result
**Example**:
```powershell
$result = Set-IPsecPolicy -PolicyName "SecureTraffic" -PolicyConfig $ipsecConfig
```

#### `Set-SMBSecurity`
**Purpose**: Configure SMB security settings
**Parameters**:
- `SecurityLevel` (string): Security level
- `Settings` (object): SMB security settings
**Returns**: SMB security result
**Example**:
```powershell
$result = Set-SMBSecurity -SecurityLevel "High" -Settings $smbSettings
```

#### `Disable-WeakProtocols`
**Purpose**: Disable weak network protocols
**Parameters**:
- `Protocols` (array): Protocols to disable
**Returns**: Protocol disabling result
**Example**:
```powershell
$result = Disable-WeakProtocols -Protocols @("SSLv3", "TLSv1.0", "TLSv1.1")
```

#### `Enable-DNSSECValidation`
**Purpose**: Enable DNSSEC validation
**Parameters**:
- `ValidationLevel` (string): Validation level
**Returns**: DNSSEC validation result
**Example**:
```powershell
$result = Enable-DNSSECValidation -ValidationLevel "Strict"
```

#### `Set-DNSSinkhole`
**Purpose**: Configure DNS sinkhole
**Parameters**:
- `SinkholeConfig` (object): Sinkhole configuration
**Returns**: DNS sinkhole result
**Example**:
```powershell
$result = Set-DNSSinkhole -SinkholeConfig $sinkholeConfig
```

#### `Set-WinRMSecurity`
**Purpose**: Configure WinRM security
**Parameters**:
- `SecurityConfig` (object): WinRM security configuration
**Returns**: WinRM security result
**Example**:
```powershell
$result = Set-WinRMSecurity -SecurityConfig $winrmConfig
```

#### `Enable-PowerShellRemotingSSL`
**Purpose**: Enable PowerShell remoting over SSL
**Parameters**:
- `CertificateThumbprint` (string): SSL certificate thumbprint
**Returns**: SSL remoting result
**Example**:
```powershell
$result = Enable-PowerShellRemotingSSL -CertificateThumbprint "ABC123..."
```

#### `New-JEASessionConfiguration`
**Purpose**: Create JEA session configuration
**Parameters**:
- `ConfigurationName` (string): Configuration name
- `SessionType` (string): Session type
- `RoleCapabilities` (array): Role capabilities
**Returns**: JEA configuration result
**Example**:
```powershell
$result = New-JEASessionConfiguration -ConfigurationName "WebAdminJEA" -SessionType "RestrictedRemoteServer" -RoleCapabilities @("WebAdminRole")
```

#### `New-JEAEndpoint`
**Purpose**: Create JEA endpoint
**Parameters**:
- `EndpointName` (string): Endpoint name
- `Configuration` (object): Endpoint configuration
**Returns**: JEA endpoint result
**Example**:
```powershell
$result = New-JEAEndpoint -EndpointName "WebAdmin" -Configuration $jeaConfig
```

#### `Enable-JustInTimeAccess`
**Purpose**: Enable just-in-time access
**Parameters**:
- `AccessConfig` (object): Access configuration
**Returns**: JIT access result
**Example**:
```powershell
$result = Enable-JustInTimeAccess -AccessConfig $jitConfig
```

#### `Get-PrivilegedAccountActivity`
**Purpose**: Monitor privileged account activity
**Parameters**:
- `AccountName` (string): Account name
- `TimeRange` (object): Time range
**Returns**: Account activity data
**Example**:
```powershell
$activity = Get-PrivilegedAccountActivity -AccountName "admin" -TimeRange $timeRange
Write-Host "Login Count: $($activity.LoginCount)"
```

#### `Set-PrivilegedAccountPolicy`
**Purpose**: Set privileged account policy
**Parameters**:
- `PolicyConfig` (object): Policy configuration
**Returns**: Policy setting result
**Example**:
```powershell
$result = Set-PrivilegedAccountPolicy -PolicyConfig $policyConfig
```

#### `Get-SystemSecurityInventory`
**Purpose**: Get system security inventory
**Parameters**: None
**Returns**: Security inventory object
**Example**:
```powershell
$inventory = Get-SystemSecurityInventory
Write-Host "Security Controls: $($inventory.ControlCount)"
```

#### `Get-InsecureServices`
**Purpose**: Identify insecure services
**Parameters**: None
**Returns**: Insecure services array
**Example**:
```powershell
$insecureServices = Get-InsecureServices
foreach ($service in $insecureServices) {
    Write-Host "Insecure Service: $($service.Name) - Risk: $($service.Risk)"
}
```

#### `Set-SystemHardening`
**Purpose**: Apply system hardening
**Parameters**:
- `HardeningLevel` (string): Hardening level
- `HardeningConfig` (object): Hardening configuration
**Returns**: Hardening result
**Example**:
```powershell
$result = Set-SystemHardening -HardeningLevel "Maximum" -HardeningConfig $hardeningConfig
```

#### `Set-WindowsFeatureSecurity`
**Purpose**: Configure Windows feature security
**Parameters**:
- `FeatureName` (string): Feature name
- `SecurityConfig` (object): Security configuration
**Returns**: Feature security result
**Example**:
```powershell
$result = Set-WindowsFeatureSecurity -FeatureName "IIS" -SecurityConfig $securityConfig
```

#### `Search-SecurityEvents`
**Purpose**: Search security event logs
**Parameters**:
- `EventId` (int): Event ID
- `TimeRange` (object): Time range
- `MaxEvents` (int): Maximum events
**Returns**: Security events array
**Example**:
```powershell
$events = Search-SecurityEvents -EventId 4624 -TimeRange $timeRange -MaxEvents 100
```

#### `Test-SecurityConfiguration`
**Purpose**: Test security configuration
**Parameters**:
- `ConfigurationName` (string): Configuration name
**Returns**: Security test result
**Example**:
```powershell
$testResult = Test-SecurityConfiguration -ConfigurationName "BaselineSecurity"
Write-Host "Security Score: $($testResult.Score)"
```

#### `Get-SecuritySummary`
**Purpose**: Generate security summary
**Parameters**: None
**Returns**: Security summary object
**Example**:
```powershell
$summary = Get-SecuritySummary
Write-Host "Overall Security Rating: $($summary.Rating)"
```

## Configuration Domain API

### Security and Validation Functions (4 functions)

#### `Test-ConfigurationSecurity`
**Purpose**: Test configuration for security issues
**Parameters**:
- `Configuration` (hashtable): Configuration to test
**Returns**: Security test result
**Example**:
```powershell
$securityResult = Test-ConfigurationSecurity -Configuration $config
Write-Host "Security Issues: $($securityResult.Issues.Count)"
```

#### `Get-ConfigurationHash`
**Purpose**: Generate configuration hash
**Parameters**:
- `Configuration` (hashtable): Configuration to hash
**Returns**: Configuration hash
**Example**:
```powershell
$hash = Get-ConfigurationHash -Configuration $config
Write-Host "Configuration Hash: $hash"
```

#### `Validate-Configuration`
**Purpose**: Validate configuration structure
**Parameters**:
- `Configuration` (hashtable): Configuration to validate
- `Schema` (object): Validation schema
**Returns**: Validation result
**Example**:
```powershell
$validationResult = Validate-Configuration -Configuration $config -Schema $schema
Write-Host "Is Valid: $($validationResult.IsValid)"
```

#### `Test-ConfigurationSchema`
**Purpose**: Test configuration against schema
**Parameters**:
- `Configuration` (hashtable): Configuration to test
- `Schema` (object): Schema to test against
**Returns**: Schema test result
**Example**:
```powershell
$schemaResult = Test-ConfigurationSchema -Configuration $config -Schema $schema
Write-Host "Schema Valid: $($schemaResult.IsValid)"
```

### Core Configuration Management Functions (11 functions)

#### `Initialize-ConfigurationStorePath`
**Purpose**: Initialize configuration storage path
**Parameters**:
- `StorePath` (string): Storage path
**Returns**: Initialization result
**Example**:
```powershell
$result = Initialize-ConfigurationStorePath -StorePath "./config-store"
```

#### `Save-ConfigurationStore`
**Purpose**: Save configuration store
**Parameters**:
- `Store` (object): Configuration store
- `Path` (string): Save path
**Returns**: Save result
**Example**:
```powershell
$result = Save-ConfigurationStore -Store $configStore -Path "./config-store.json"
```

#### `Import-ExistingConfiguration`
**Purpose**: Import existing configuration
**Parameters**:
- `ConfigPath` (string): Configuration file path
**Returns**: Import result
**Example**:
```powershell
$result = Import-ExistingConfiguration -ConfigPath "./existing-config.json"
```

#### `Invoke-BackupCleanup`
**Purpose**: Clean up old configuration backups
**Parameters**:
- `BackupPath` (string): Backup directory path
- `RetentionDays` (int): Retention period in days
**Returns**: Cleanup result
**Example**:
```powershell
$result = Invoke-BackupCleanup -BackupPath "./backups" -RetentionDays 30
```

#### `Initialize-ConfigurationCore`
**Purpose**: Initialize core configuration system
**Parameters**:
- `CoreConfig` (object): Core configuration
**Returns**: Initialization result
**Example**:
```powershell
$result = Initialize-ConfigurationCore -CoreConfig $coreConfig
```

#### `Initialize-DefaultSchemas`
**Purpose**: Initialize default configuration schemas
**Parameters**: None
**Returns**: Schema initialization result
**Example**:
```powershell
$result = Initialize-DefaultSchemas
```

#### `Get-ConfigurationStore`
**Purpose**: Get configuration store
**Parameters**:
- `StoreName` (string): Store name
**Returns**: Configuration store object
**Example**:
```powershell
$store = Get-ConfigurationStore -StoreName "AppConfig"
```

#### `Set-ConfigurationStore`
**Purpose**: Set configuration store
**Parameters**:
- `StoreName` (string): Store name
- `Store` (object): Configuration store
**Returns**: Store setting result
**Example**:
```powershell
$result = Set-ConfigurationStore -StoreName "AppConfig" -Store $configStore
```

#### `Get-ModuleConfiguration`
**Purpose**: Get module-specific configuration
**Parameters**:
- `ModuleName` (string): Module name
**Returns**: Module configuration
**Example**:
```powershell
$moduleConfig = Get-ModuleConfiguration -ModuleName "WebModule"
```

#### `Set-ModuleConfiguration`
**Purpose**: Set module configuration
**Parameters**:
- `ModuleName` (string): Module name
- `Configuration` (object): Module configuration
**Returns**: Configuration setting result
**Example**:
```powershell
$result = Set-ModuleConfiguration -ModuleName "WebModule" -Configuration $moduleConfig
```

#### `Register-ModuleConfiguration`
**Purpose**: Register module configuration
**Parameters**:
- `ModuleName` (string): Module name
- `ConfigurationSchema` (object): Configuration schema
**Returns**: Registration result
**Example**:
```powershell
$result = Register-ModuleConfiguration -ModuleName "WebModule" -ConfigurationSchema $schema
```

### Configuration Carousel Functions (12 functions)

#### `Initialize-ConfigurationCarousel`
**Purpose**: Initialize configuration carousel system
**Parameters**:
- `CarouselConfig` (object): Carousel configuration
**Returns**: Initialization result
**Example**:
```powershell
$result = Initialize-ConfigurationCarousel -CarouselConfig $carouselConfig
```

#### `Get-ConfigurationRegistry`
**Purpose**: Get configuration registry
**Parameters**: None
**Returns**: Configuration registry
**Example**:
```powershell
$registry = Get-ConfigurationRegistry
```

#### `Set-ConfigurationRegistry`
**Purpose**: Set configuration registry
**Parameters**:
- `Registry` (object): Configuration registry
**Returns**: Registry setting result
**Example**:
```powershell
$result = Set-ConfigurationRegistry -Registry $registry
```

#### `Switch-ConfigurationSet`
**Purpose**: Switch between configuration sets
**Parameters**:
- `ConfigurationName` (string): Configuration name
- `Environment` (string): Environment name
**Returns**: Switch result
**Example**:
```powershell
$result = Switch-ConfigurationSet -ConfigurationName "AppConfig" -Environment "Production"
```

#### `Get-AvailableConfigurations`
**Purpose**: Get available configurations
**Parameters**: None
**Returns**: Available configurations array
**Example**:
```powershell
$configurations = Get-AvailableConfigurations
foreach ($config in $configurations) {
    Write-Host "Configuration: $($config.Name)"
}
```

#### `Add-ConfigurationRepository`
**Purpose**: Add configuration repository
**Parameters**:
- `Name` (string): Repository name
- `Source` (string): Repository source
- `Type` (string): Repository type
**Returns**: Repository addition result
**Example**:
```powershell
$result = Add-ConfigurationRepository -Name "TeamConfig" -Source "https://github.com/team/config.git" -Type "Git"
```

#### `Get-CurrentConfiguration`
**Purpose**: Get current configuration
**Parameters**: None
**Returns**: Current configuration object
**Example**:
```powershell
$currentConfig = Get-CurrentConfiguration
Write-Host "Current Environment: $($currentConfig.Environment)"
```

#### `Backup-CurrentConfiguration`
**Purpose**: Backup current configuration
**Parameters**:
- `Reason` (string): Backup reason
**Returns**: Backup result
**Example**:
```powershell
$result = Backup-CurrentConfiguration -Reason "Before major update"
```

#### `Validate-ConfigurationSet`
**Purpose**: Validate configuration set
**Parameters**:
- `ConfigurationName` (string): Configuration name
**Returns**: Validation result
**Example**:
```powershell
$validationResult = Validate-ConfigurationSet -ConfigurationName "AppConfig"
Write-Host "Is Valid: $($validationResult.IsValid)"
```

#### `Test-ConfigurationAccessible`
**Purpose**: Test configuration accessibility
**Parameters**:
- `ConfigurationName` (string): Configuration name
**Returns**: Accessibility test result
**Example**:
```powershell
$accessResult = Test-ConfigurationAccessible -ConfigurationName "AppConfig"
Write-Host "Is Accessible: $($accessResult.IsAccessible)"
```

#### `Apply-ConfigurationSet`
**Purpose**: Apply configuration set
**Parameters**:
- `ConfigurationName` (string): Configuration name
- `Environment` (string): Environment name
**Returns**: Application result
**Example**:
```powershell
$result = Apply-ConfigurationSet -ConfigurationName "AppConfig" -Environment "Production"
```

#### `New-ConfigurationFromTemplate`
**Purpose**: Create configuration from template
**Parameters**:
- `TemplateName` (string): Template name
- `ConfigurationName` (string): New configuration name
- `Parameters` (hashtable): Template parameters
**Returns**: Configuration creation result
**Example**:
```powershell
$result = New-ConfigurationFromTemplate -TemplateName "WebApp" -ConfigurationName "MyWebApp" -Parameters @{ Port = 8080 }
```

### Event System Functions (4 functions)

#### `Publish-ConfigurationEvent`
**Purpose**: Publish configuration event
**Parameters**:
- `EventName` (string): Event name
- `EventData` (object): Event data
**Returns**: Event publishing result
**Example**:
```powershell
$result = Publish-ConfigurationEvent -EventName "ConfigurationChanged" -EventData @{ ConfigName = "AppConfig"; Change = "Updated" }
```

#### `Subscribe-ConfigurationEvent`
**Purpose**: Subscribe to configuration events
**Parameters**:
- `EventName` (string): Event name
- `Action` (scriptblock): Event action
**Returns**: Subscription result
**Example**:
```powershell
$result = Subscribe-ConfigurationEvent -EventName "ConfigurationChanged" -Action { Write-Host "Config changed!" }
```

#### `Unsubscribe-ConfigurationEvent`
**Purpose**: Unsubscribe from configuration events
**Parameters**:
- `EventName` (string): Event name
- `SubscriptionId` (string): Subscription ID
**Returns**: Unsubscription result
**Example**:
```powershell
$result = Unsubscribe-ConfigurationEvent -EventName "ConfigurationChanged" -SubscriptionId $subscriptionId
```

#### `Get-ConfigurationEventHistory`
**Purpose**: Get configuration event history
**Parameters**:
- `EventName` (string): Event name (optional)
- `MaxEvents` (int): Maximum events to return
**Returns**: Event history array
**Example**:
```powershell
$history = Get-ConfigurationEventHistory -EventName "ConfigurationChanged" -MaxEvents 50
```

### Environment Management Functions (5 functions)

#### `New-ConfigurationEnvironment`
**Purpose**: Create new configuration environment
**Parameters**:
- `EnvironmentName` (string): Environment name
- `Configuration` (object): Environment configuration
**Returns**: Environment creation result
**Example**:
```powershell
$result = New-ConfigurationEnvironment -EnvironmentName "Staging" -Configuration $stagingConfig
```

#### `Get-ConfigurationEnvironment`
**Purpose**: Get configuration environment
**Parameters**:
- `EnvironmentName` (string): Environment name
**Returns**: Environment configuration
**Example**:
```powershell
$environment = Get-ConfigurationEnvironment -EnvironmentName "Production"
```

#### `Set-ConfigurationEnvironment`
**Purpose**: Set configuration environment
**Parameters**:
- `EnvironmentName` (string): Environment name
- `Configuration` (object): Environment configuration
**Returns**: Environment setting result
**Example**:
```powershell
$result = Set-ConfigurationEnvironment -EnvironmentName "Production" -Configuration $prodConfig
```

#### `Backup-Configuration`
**Purpose**: Backup configuration
**Parameters**:
- `ConfigurationName` (string): Configuration name
- `BackupPath` (string): Backup path
**Returns**: Backup result
**Example**:
```powershell
$result = Backup-Configuration -ConfigurationName "AppConfig" -BackupPath "./backups"
```

#### `Restore-Configuration`
**Purpose**: Restore configuration from backup
**Parameters**:
- `ConfigurationName` (string): Configuration name
- `BackupPath` (string): Backup path
**Returns**: Restore result
**Example**:
```powershell
$result = Restore-Configuration -ConfigurationName "AppConfig" -BackupPath "./backups/backup-20231201.json"
```

## Experience Domain API

### Setup Automation Functions (11 functions)

#### `Start-IntelligentSetup`
**Purpose**: Start intelligent setup process
**Parameters**:
- `Profile` (string): Installation profile
- `MinimalSetup` (switch): Minimal setup mode
- `SkipOptional` (switch): Skip optional components
**Returns**: Setup result
**Example**:
```powershell
$result = Start-IntelligentSetup -Profile "developer" -SkipOptional
```

#### `Get-PlatformInfo`
**Purpose**: Get platform information
**Parameters**: None
**Returns**: Platform information object
**Example**:
```powershell
$platformInfo = Get-PlatformInfo
Write-Host "OS: $($platformInfo.OS)"
Write-Host "Architecture: $($platformInfo.Architecture)"
```

#### `Show-WelcomeMessage`
**Purpose**: Show welcome message
**Parameters**:
- `Message` (string): Custom message
**Returns**: None
**Example**:
```powershell
Show-WelcomeMessage -Message "Welcome to AitherZero Setup!"
```

#### `Show-SetupBanner`
**Purpose**: Show setup banner
**Parameters**:
- `Title` (string): Banner title
- `Version` (string): Version information
**Returns**: None
**Example**:
```powershell
Show-SetupBanner -Title "AitherZero Setup" -Version "1.0.0"
```

#### `Get-InstallationProfile`
**Purpose**: Get installation profile
**Parameters**:
- `ProfileName` (string): Profile name
**Returns**: Installation profile object
**Example**:
```powershell
$profile = Get-InstallationProfile -ProfileName "developer"
Write-Host "Profile Description: $($profile.Description)"
```

#### `Show-EnhancedInstallationProfile`
**Purpose**: Show enhanced installation profile
**Parameters**:
- `Profile` (object): Installation profile
**Returns**: None
**Example**:
```powershell
Show-EnhancedInstallationProfile -Profile $profile
```

#### `Get-SetupSteps`
**Purpose**: Get setup steps
**Parameters**:
- `Profile` (object): Installation profile
**Returns**: Setup steps array
**Example**:
```powershell
$steps = Get-SetupSteps -Profile $profile
foreach ($step in $steps) {
    Write-Host "Step: $($step.Name)"
}
```

#### `Show-EnhancedProgress`
**Purpose**: Show enhanced progress
**Parameters**:
- `Activity` (string): Activity description
- `PercentComplete` (int): Completion percentage
- `ShowETA` (switch): Show estimated time
**Returns**: None
**Example**:
```powershell
Show-EnhancedProgress -Activity "Installing components" -PercentComplete 75 -ShowETA
```

#### `Show-SetupPrompt`
**Purpose**: Show setup prompt
**Parameters**:
- `Prompt` (string): Prompt message
- `Options` (array): Available options
**Returns**: User selection
**Example**:
```powershell
$selection = Show-SetupPrompt -Prompt "Select installation type:" -Options @("Full", "Minimal", "Custom")
```

#### `Show-SetupSummary`
**Purpose**: Show setup summary
**Parameters**:
- `SetupResult` (object): Setup result
**Returns**: None
**Example**:
```powershell
Show-SetupSummary -SetupResult $setupResult
```

#### `Invoke-ErrorRecovery`
**Purpose**: Handle setup errors with recovery
**Parameters**:
- `Error` (object): Error object
- `Context` (string): Error context
**Returns**: Recovery result
**Example**:
```powershell
try {
    # Setup operation
} catch {
    $recovery = Invoke-ErrorRecovery -Error $_ -Context "ComponentInstallation"
}
```

### Interactive Experience Functions (11 functions)

#### `Start-InteractiveMode`
**Purpose**: Start interactive mode
**Parameters**:
- `Mode` (string): Interactive mode type
**Returns**: Interactive session result
**Example**:
```powershell
$result = Start-InteractiveMode -Mode "Setup"
```

#### `Get-StartupMode`
**Purpose**: Get startup mode
**Parameters**: None
**Returns**: Startup mode string
**Example**:
```powershell
$mode = Get-StartupMode
Write-Host "Startup Mode: $mode"
```

#### `Show-Banner`
**Purpose**: Show application banner
**Parameters**:
- `Title` (string): Banner title
- `Subtitle` (string): Banner subtitle
**Returns**: None
**Example**:
```powershell
Show-Banner -Title "AitherZero" -Subtitle "Infrastructure Automation Platform"
```

#### `Initialize-TerminalUI`
**Purpose**: Initialize terminal UI
**Parameters**: None
**Returns**: UI initialization result
**Example**:
```powershell
$result = Initialize-TerminalUI
```

#### `Reset-TerminalUI`
**Purpose**: Reset terminal UI
**Parameters**: None
**Returns**: UI reset result
**Example**:
```powershell
$result = Reset-TerminalUI
```

#### `Test-EnhancedUICapability`
**Purpose**: Test enhanced UI capabilities
**Parameters**: None
**Returns**: UI capability result
**Example**:
```powershell
$capabilities = Test-EnhancedUICapability
Write-Host "Enhanced UI Supported: $($capabilities.Enhanced)"
```

#### `Show-ContextMenu`
**Purpose**: Show context menu
**Parameters**:
- `MenuItems` (array): Menu items
- `Title` (string): Menu title
**Returns**: Selected menu item
**Example**:
```powershell
$selection = Show-ContextMenu -MenuItems @("Setup", "Configure", "Exit") -Title "Main Menu"
```

#### `Edit-Configuration`
**Purpose**: Edit configuration interactively
**Parameters**:
- `ConfigPath` (string): Configuration file path
**Returns**: Edit result
**Example**:
```powershell
$result = Edit-Configuration -ConfigPath "./app-config.json"
```

#### `Review-Configuration`
**Purpose**: Review configuration
**Parameters**:
- `Configuration` (object): Configuration to review
**Returns**: Review result
**Example**:
```powershell
$result = Review-Configuration -Configuration $config
```

#### `Generate-QuickStartGuide`
**Purpose**: Generate quick start guide
**Parameters**:
- `SetupState` (object): Setup state
- `OutputPath` (string): Output path
**Returns**: Guide generation result
**Example**:
```powershell
$result = Generate-QuickStartGuide -SetupState $setupState -OutputPath "./quick-start.md"
```

#### `Find-ProjectRoot`
**Purpose**: Find project root directory
**Parameters**: None
**Returns**: Project root path
**Example**:
```powershell
$projectRoot = Find-ProjectRoot
Write-Host "Project Root: $projectRoot"
```

## Automation Domain API

### Script Repository Management Functions (5 functions)

#### `Initialize-ScriptRepository`
**Purpose**: Initialize script repository
**Parameters**: None
**Returns**: Repository initialization result
**Example**:
```powershell
$result = Initialize-ScriptRepository
```

#### `Initialize-ScriptTemplates`
**Purpose**: Initialize script templates
**Parameters**: None
**Returns**: Template initialization result
**Example**:
```powershell
$result = Initialize-ScriptTemplates
```

#### `Get-ScriptRepository`
**Purpose**: Get script repository information
**Parameters**:
- `Path` (string): Repository path
- `IncludeStatistics` (switch): Include statistics
**Returns**: Repository information
**Example**:
```powershell
$repo = Get-ScriptRepository -Path "./scripts" -IncludeStatistics
Write-Host "Total Scripts: $($repo.TotalScripts)"
```

#### `Backup-ScriptRepository`
**Purpose**: Backup script repository
**Parameters**: None
**Returns**: Backup result
**Example**:
```powershell
$result = Backup-ScriptRepository
```

#### `Get-ScriptMetrics`
**Purpose**: Get script repository metrics
**Parameters**: None
**Returns**: Script metrics object
**Example**:
```powershell
$metrics = Get-ScriptMetrics
Write-Host "Execution Success Rate: $($metrics.Execution.SuccessRate)%"
```

### Script Registration and Management Functions (5 functions)

#### `Register-OneOffScript`
**Purpose**: Register script for execution
**Parameters**:
- `ScriptPath` (string): Script file path
- `Name` (string): Script name
- `Description` (string): Script description
- `Parameters` (hashtable): Default parameters
- `Force` (switch): Force registration
**Returns**: Registration result
**Example**:
```powershell
$result = Register-OneOffScript -ScriptPath "./scripts/deploy.ps1" -Name "Deploy" -Description "Deployment script" -Force
```

#### `Get-RegisteredScripts`
**Purpose**: Get registered scripts
**Parameters**:
- `Name` (string): Specific script name
- `IncludeInvalid` (switch): Include invalid scripts
**Returns**: Registered scripts array
**Example**:
```powershell
$scripts = Get-RegisteredScripts -IncludeInvalid
foreach ($script in $scripts) {
    Write-Host "Script: $($script.Name) - Valid: $($script.IsValid)"
}
```

#### `Remove-ScriptFromRegistry`
**Purpose**: Remove script from registry
**Parameters**:
- `Name` (string): Script name
- `DeleteFile` (switch): Delete script file
**Returns**: Removal result
**Example**:
```powershell
$result = Remove-ScriptFromRegistry -Name "Deploy" -DeleteFile
```

#### `Test-ModernScript`
**Purpose**: Test script for modern practices
**Parameters**:
- `ScriptPath` (string): Script file path
**Returns**: Validation result
**Example**:
```powershell
$isModern = Test-ModernScript -ScriptPath "./scripts/deploy.ps1"
Write-Host "Is Modern: $isModern"
```

#### `Test-OneOffScript`
**Purpose**: Test script compliance
**Parameters**:
- `ScriptPath` (string): Script file path
- `Detailed` (switch): Detailed results
**Returns**: Compliance test result
**Example**:
```powershell
$result = Test-OneOffScript -ScriptPath "./scripts/deploy.ps1" -Detailed
Write-Host "Compliance Score: $($result.Score)/$($result.MaxScore)"
```

### Script Execution Functions (3 functions)

#### `Invoke-OneOffScript`
**Purpose**: Execute registered script
**Parameters**:
- `ScriptPath` (string): Script path
- `Name` (string): Script name
- `Parameters` (hashtable): Script parameters
- `Force` (switch): Force execution
- `Timeout` (int): Timeout seconds
**Returns**: Execution result
**Example**:
```powershell
$result = Invoke-OneOffScript -Name "Deploy" -Parameters @{ Environment = "Production" } -Force
```

#### `Start-ScriptExecution`
**Purpose**: Start advanced script execution
**Parameters**:
- `ScriptName` (string): Script name
- `Parameters` (hashtable): Script parameters
- `Background` (switch): Background execution
- `Priority` (string): Execution priority
- `MaxRetries` (int): Maximum retries
**Returns**: Execution result
**Example**:
```powershell
$result = Start-ScriptExecution -ScriptName "Deploy" -Parameters @{ Env = "prod" } -Background -Priority "High" -MaxRetries 3
```

#### `Get-ScriptExecutionHistory`
**Purpose**: Get script execution history
**Parameters**:
- `ScriptName` (string): Script name
- `Last` (int): Number of recent executions
- `SuccessOnly` (switch): Success only
**Returns**: Execution history array
**Example**:
```powershell
$history = Get-ScriptExecutionHistory -ScriptName "Deploy" -Last 10 -SuccessOnly
```

### Script Template Functions (3 functions)

#### `Get-ScriptTemplate`
**Purpose**: Get script templates
**Parameters**:
- `TemplateName` (string): Template name
- `ListOnly` (switch): List names only
**Returns**: Template information
**Example**:
```powershell
$templates = Get-ScriptTemplate -ListOnly
$template = Get-ScriptTemplate -TemplateName "Basic"
```

#### `New-ScriptFromTemplate`
**Purpose**: Create script from template
**Parameters**:
- `TemplateName` (string): Template name
- `ScriptName` (string): New script name
- `OutputPath` (string): Output path
- `Parameters` (hashtable): Template parameters
**Returns**: Script creation result
**Example**:
```powershell
$result = New-ScriptFromTemplate -TemplateName "Basic" -ScriptName "NewScript" -OutputPath "./scripts" -Parameters @{ Author = "John" }
```

## Utilities Domain API

### Semantic Versioning Functions (8 functions)

#### `Get-NextSemanticVersion`
**Purpose**: Get next semantic version
**Parameters**:
- `CurrentVersion` (string): Current version
- `VersionType` (string): Version increment type
**Returns**: Next version string
**Example**:
```powershell
$nextVersion = Get-NextSemanticVersion -CurrentVersion "1.0.0" -VersionType "minor"
Write-Host "Next Version: $nextVersion"
```

#### `ConvertFrom-ConventionalCommits`
**Purpose**: Convert conventional commits to version
**Parameters**:
- `Commits` (array): Commit messages
**Returns**: Version increment type
**Example**:
```powershell
$commits = @("feat: add new feature", "fix: bug fix")
$incrementType = ConvertFrom-ConventionalCommits -Commits $commits
```

#### `Test-SemanticVersion`
**Purpose**: Test semantic version format
**Parameters**:
- `Version` (string): Version to test
**Returns**: Validation result
**Example**:
```powershell
$isValid = Test-SemanticVersion -Version "1.0.0"
Write-Host "Valid Version: $isValid"
```

#### `Compare-SemanticVersions`
**Purpose**: Compare semantic versions
**Parameters**:
- `Version1` (string): First version
- `Version2` (string): Second version
**Returns**: Comparison result
**Example**:
```powershell
$comparison = Compare-SemanticVersions -Version1 "1.0.0" -Version2 "2.0.0"
Write-Host "Comparison: $comparison"
```

#### `Parse-SemanticVersion`
**Purpose**: Parse semantic version
**Parameters**:
- `Version` (string): Version to parse
**Returns**: Parsed version object
**Example**:
```powershell
$parsed = Parse-SemanticVersion -Version "1.2.3-beta+build"
Write-Host "Major: $($parsed.Major), Minor: $($parsed.Minor), Patch: $($parsed.Patch)"
```

#### `Get-CurrentVersion`
**Purpose**: Get current version
**Parameters**: None
**Returns**: Current version string
**Example**:
```powershell
$currentVersion = Get-CurrentVersion
Write-Host "Current Version: $currentVersion"
```

#### `Get-CommitRange`
**Purpose**: Get commit range
**Parameters**:
- `From` (string): Starting commit/tag
- `To` (string): Ending commit/tag
**Returns**: Commit range array
**Example**:
```powershell
$commits = Get-CommitRange -From "v1.0.0" -To "HEAD"
```

#### `Calculate-NextVersion`
**Purpose**: Calculate next version
**Parameters**:
- `Commits` (array): Commit messages
- `CurrentVersion` (string): Current version
**Returns**: Next version string
**Example**:
```powershell
$nextVersion = Calculate-NextVersion -Commits $commits -CurrentVersion "1.0.0"
```

### License Management Functions (3 functions)

#### `Get-LicenseStatus`
**Purpose**: Get license status
**Parameters**: None
**Returns**: License status object
**Example**:
```powershell
$license = Get-LicenseStatus
Write-Host "License Type: $($license.Type)"
Write-Host "Expires: $($license.Expiration)"
```

#### `Test-FeatureAccess`
**Purpose**: Test feature access
**Parameters**:
- `FeatureName` (string): Feature name
**Returns**: Access result
**Example**:
```powershell
$hasAccess = Test-FeatureAccess -FeatureName "AdvancedReporting"
Write-Host "Has Access: $hasAccess"
```

#### `Get-AvailableFeatures`
**Purpose**: Get available features
**Parameters**: None
**Returns**: Available features array
**Example**:
```powershell
$features = Get-AvailableFeatures
foreach ($feature in $features) {
    Write-Host "Feature: $($feature.Name) - Available: $($feature.Available)"
}
```

### Repository Synchronization Functions (2 functions)

#### `Sync-ToAitherLab`
**Purpose**: Sync to AitherLab
**Parameters**:
- `Force` (switch): Force synchronization
**Returns**: Sync result
**Example**:
```powershell
$result = Sync-ToAitherLab -Force
```

#### `Get-RepoSyncStatus`
**Purpose**: Get repository sync status
**Parameters**: None
**Returns**: Sync status object
**Example**:
```powershell
$status = Get-RepoSyncStatus
Write-Host "Last Sync: $($status.LastSync)"
```

### Maintenance Functions (3 functions)

#### `Invoke-UnifiedMaintenance`
**Purpose**: Invoke unified maintenance
**Parameters**:
- `Operations` (array): Maintenance operations
**Returns**: Maintenance result
**Example**:
```powershell
$result = Invoke-UnifiedMaintenance -Operations @("cleanup", "update", "optimize")
```

#### `Get-UtilityServiceStatus`
**Purpose**: Get utility service status
**Parameters**: None
**Returns**: Service status object
**Example**:
```powershell
$status = Get-UtilityServiceStatus
Write-Host "Service Status: $($status.Status)"
```

#### `Test-UtilityIntegration`
**Purpose**: Test utility integration
**Parameters**: None
**Returns**: Integration test result
**Example**:
```powershell
$result = Test-UtilityIntegration
Write-Host "Integration Test: $($result.Status)"
```

### PowerShell Script Analyzer Functions (1 function)

#### `Get-AnalysisStatus`
**Purpose**: Get script analysis status
**Parameters**: None
**Returns**: Analysis status object
**Example**:
```powershell
$status = Get-AnalysisStatus
Write-Host "Analysis Status: $($status.Status)"
```

## Error Handling Patterns

### Common Error Types
- **ValidationError**: Parameter validation failures
- **ConfigurationError**: Configuration-related errors
- **SecurityError**: Security validation failures
- **NetworkError**: Network connectivity issues
- **FileSystemError**: File system access issues
- **AuthenticationError**: Authentication failures
- **AuthorizationError**: Authorization failures
- **TimeoutError**: Operation timeout errors

### Error Response Format
All functions return consistent error objects:
```powershell
@{
    Success = $false
    Error = @{
        Type = "ValidationError"
        Message = "Parameter validation failed"
        Details = @{
            Parameter = "ConfigPath"
            Value = $null
            Reason = "Parameter cannot be null"
        }
    }
}
```

### Error Handling Best Practices
1. Always check function return values
2. Use try-catch blocks for error handling
3. Log errors for debugging
4. Provide meaningful error messages
5. Handle specific error types appropriately

## Platform Compatibility

### Windows Compatibility
- **Full Support**: All 196 functions
- **Admin Required**: Security functions, some system functions
- **PowerShell**: 7.0+ required

### Linux Compatibility
- **Full Support**: 156 functions (80%)
- **Limited Support**: Windows-specific security functions
- **PowerShell**: 7.0+ required

### macOS Compatibility
- **Full Support**: 147 functions (75%)
- **Limited Support**: Windows-specific and some Linux-specific functions
- **PowerShell**: 7.0+ required

### Cross-Platform Functions
Functions that work on all platforms:
- All Configuration domain functions
- All Experience domain functions
- All Automation domain functions
- Most Utilities domain functions
- Core Infrastructure functions
- Basic Security functions

## Performance Considerations

### Function Performance Tiers
- **Tier 1 (< 100ms)**: Utility functions, validation functions
- **Tier 2 (< 1 second)**: Configuration functions, most security functions
- **Tier 3 (< 10 seconds)**: System monitoring, some infrastructure functions
- **Tier 4 (> 10 seconds)**: Deployment functions, complex automation

### Optimization Tips
1. Use caching for repeated operations
2. Implement parallel processing where possible
3. Use appropriate timeout values
4. Monitor resource usage
5. Optimize database queries and file operations

## API Versioning

### Version Strategy
- **Major Version**: Breaking changes to function signatures
- **Minor Version**: New functions or non-breaking enhancements
- **Patch Version**: Bug fixes and security updates

### Compatibility Promise
- **Backward Compatibility**: Function signatures remain stable within major versions
- **Deprecation Policy**: 2 major versions notice for deprecated functions
- **Migration Support**: Migration tools provided for breaking changes

## Support and Resources

### Documentation
- **Function Help**: Use `Get-Help <FunctionName>` for detailed help
- **Examples**: Each function includes usage examples
- **Best Practices**: Domain-specific best practices documentation

### Community
- **GitHub Issues**: Report bugs and request features
- **Discussions**: Community discussions and Q&A
- **Contributions**: Contributing guidelines and code standards

### Professional Support
- **Enterprise Support**: Available for enterprise customers
- **Training**: Training programs and certification
- **Consulting**: Professional services and consulting

---

This API reference provides comprehensive documentation for all 196 functions across the 6 AitherZero domains. For the most up-to-date information, please refer to the inline help documentation using `Get-Help <FunctionName>` or visit the official documentation repository.