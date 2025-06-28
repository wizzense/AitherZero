# DevEnvironment Module

**Version:** 1.0.0  
**Description:** Development environment setup and management for Aitherium Infrastructure Automation

## Overview

Development environment setup and management for Aitherium Infrastructure Automation

## Functions

### Get-DevEnvironmentStatus

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [switch]$IncludeMetrics
    )
```

#### Parameters

- **IncludeMetrics** [SwitchParameter]


### Initialize-DevelopmentEnvironment

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [switch]$Force,
        [switch]$SkipModuleImportFixes
    )
```

#### Parameters

- **Force** [SwitchParameter]

- **SkipModuleImportFixes** [SwitchParameter]


### Write-Step

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($StepName)
```

#### Parameters

- **StepName** [Object]


### Install-RequiredPowerShellModules

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([switch]$Force)
```

#### Parameters

- **Force** [SwitchParameter]


### Setup-TestingFramework

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Configure-VSCodeIntegration

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Show-DevEnvironmentSummary

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($ValidationResults)
```

#### Parameters

- **ValidationResults** [Object]


### Initialize-DevEnvironment

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [string]$ConfigurationPath,
        [switch]$Force
    )
```

#### Parameters

- **ConfigurationPath** [String]

- **Force** [SwitchParameter]


### Install-ClaudeCodeDependencies

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [switch]$SkipWSL,
        
        [Parameter()]
        [string]$WSLUsername,
        
        [Parameter()]
        [SecureString]$WSLPassword,
        
        [Parameter()]
        [string]$NodeVersion = 'lts',
        
        [Parameter()]
        [switch]$Force
    )
```

#### Parameters

- **SkipWSL** [SwitchParameter]

- **WSLUsername** [String]

- **WSLPassword** [SecureString]

- **NodeVersion** [String] *(Default: 'lts')*

- **Force** [SwitchParameter]


### Install-WindowsClaudeCodeDependencies

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [switch]$SkipWSL,
        [string]$WSLUsername,
        [SecureString]$WSLPassword,
        [string]$NodeVersion,
        [switch]$Force
    )
```

#### Parameters

- **SkipWSL** [SwitchParameter]

- **WSLUsername** [String]

- **WSLPassword** [SecureString]

- **NodeVersion** [String]

- **Force** [SwitchParameter]


### Install-LinuxClaudeCodeDependencies

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [string]$NodeVersion,
        [switch]$Force
    )
```

#### Parameters

- **NodeVersion** [String]

- **Force** [SwitchParameter]


### Install-WSLUbuntu

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [string]$Username,
        [SecureString]$Password,
        [switch]$Force
    )
```

#### Parameters

- **Username** [String]

- **Password** [SecureString]

- **Force** [SwitchParameter]


### Configure-WSLUser

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [string]$Username,
        [SecureString]$Password
    )
```

#### Parameters

- **Username** [String]

- **Password** [SecureString]


### Test-WSLAvailability

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Install-NodeJSInWSL

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [string]$NodeVersion,
        [switch]$Force
        
    )
```

#### Parameters

- **NodeVersion** [String]

- **Force** [SwitchParameter]


### Install-NodeJSLinux

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [string]$NodeVersion,
        [switch]$Force
        
    )
```

#### Parameters

- **NodeVersion** [String]

- **Force** [SwitchParameter]


### Install-ClaudeCodeInWSL

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [switch]$Force
        
    )
```

#### Parameters

- **Force** [SwitchParameter]


### Install-ClaudeCodeLinux

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [switch]$Force
        
    )
```

#### Parameters

- **Force** [SwitchParameter]


### Install-ClaudeRequirementsSystem

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [string]$ProjectRoot,
        
        [Parameter()]
        [string]$ClaudeCommandsPath,
        
        [Parameter()]
        [switch]$Force
    )
```

#### Parameters

- **ProjectRoot** [String]

- **ClaudeCommandsPath** [String]

- **Force** [SwitchParameter]


### Test-ClaudeRequirementsSystem

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [string]$ProjectRoot
    )
```

#### Parameters

- **ProjectRoot** [String]


### Install-GeminiCLIDependencies

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [switch]$SkipWSL,
        
        [Parameter()]
        [string]$WSLUsername,
        
        [Parameter()]
        [SecureString]$WSLPassword,
        
        [Parameter()]
        [string]$NodeVersion = 'lts',
        
        [Parameter()]
        [switch]$SkipNodeInstall,
        
        [Parameter()]
        [switch]$Force
    )
```

#### Parameters

- **SkipWSL** [SwitchParameter]

- **WSLUsername** [String]

- **WSLPassword** [SecureString]

- **NodeVersion** [String] *(Default: 'lts')*

- **SkipNodeInstall** [SwitchParameter]

- **Force** [SwitchParameter]


### Install-WindowsGeminiCLIDependencies

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [switch]$SkipWSL,
        [string]$WSLUsername,
        [SecureString]$WSLPassword,
        [string]$NodeVersion = 'lts',
        [switch]$SkipNodeInstall,
        [switch]$Force
    )
```

#### Parameters

- **SkipWSL** [SwitchParameter]

- **WSLUsername** [String]

- **WSLPassword** [SecureString]

- **NodeVersion** [String] *(Default: 'lts')*

- **SkipNodeInstall** [SwitchParameter]

- **Force** [SwitchParameter]


### Install-LinuxGeminiCLIDependencies

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [string]$NodeVersion = 'lts',
        [switch]$SkipNodeInstall,
        [switch]$Force
    )
```

#### Parameters

- **NodeVersion** [String] *(Default: 'lts')*

- **SkipNodeInstall** [SwitchParameter]

- **Force** [SwitchParameter]


### Install-MacOSGeminiCLIDependencies

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [string]$NodeVersion = 'lts',
        [switch]$SkipNodeInstall,
        [switch]$Force
    )
```

#### Parameters

- **NodeVersion** [String] *(Default: 'lts')*

- **SkipNodeInstall** [SwitchParameter]

- **Force** [SwitchParameter]


### Install-WSLUbuntu

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [string]$WSLUsername,
        [SecureString]$WSLPassword,
        [switch]$Force
    )
```

#### Parameters

- **WSLUsername** [String]

- **WSLPassword** [SecureString]

- **Force** [SwitchParameter]


### Install-PreCommitHook

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [switch]$Force
    )
```

#### Parameters

- **Force** [SwitchParameter]


### Remove-PreCommitHook

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Test-PreCommitHook

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Get-PreCommitHookContent

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Test-DevelopmentSetup

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Resolve-ModuleImportIssues

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [switch]$WhatIf,
        [switch]$Force
    )
```

#### Parameters

- **WhatIf** [SwitchParameter]

- **Force** [SwitchParameter]


### Set-ProjectEnvironmentVariables

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Install-ProjectModulesToStandardLocations

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [switch]$Force,
        [switch]$WhatIf
    )
```

#### Parameters

- **Force** [SwitchParameter]

- **WhatIf** [SwitchParameter]


### Fix-MalformedImportStatements

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([switch]$WhatIf)
```

#### Parameters

- **WhatIf** [SwitchParameter]


### Standardize-ImportPaths

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([switch]$WhatIf)
```

#### Parameters

- **WhatIf** [SwitchParameter]


### Remove-HardcodedPaths

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([switch]$WhatIf)
```

#### Parameters

- **WhatIf** [SwitchParameter]


### Test-ModuleImports

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Show-ImportIssuesSummary

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param()
```

### Fix-PowerShellSyntaxErrors

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param([switch]$WhatIf)
```

#### Parameters

- **WhatIf** [SwitchParameter]


### Test-ClaudeRequirementsSystem

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [Parameter()]
        [string]$ProjectRoot,
        
        [Parameter()]
        [switch]$Detailed
    )
```

#### Parameters

- **ProjectRoot** [String]

- **Detailed** [SwitchParameter]


### Test-DevelopmentSetup

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param(
        [switch]$Detailed
    )
```

#### Parameters

- **Detailed** [SwitchParameter]


### Add-ValidationResult

**Synopsis:** 

**Description:**


#### Syntax
```powershell
param($Test, $Status, $Message)
```

#### Parameters

- **Test** [Object]

- **Status** [Object]

- **Message** [Object]


