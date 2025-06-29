# API Interface Specifications

**Version:** 1.0.0  
**Module:** OpenTofuProvider Extension  
**Focus:** Infrastructure Abstraction Layer APIs

## Core API Categories

### 1. Repository Management APIs

#### Register-InfrastructureRepository
```powershell
<#
.SYNOPSIS
    Registers a remote infrastructure repository for use with deployments.

.DESCRIPTION
    Registers and optionally clones a remote Git repository containing OpenTofu/Terraform
    infrastructure code. Supports authentication, caching, and offline capabilities.

.PARAMETER RepositoryUrl
    The Git URL of the infrastructure repository (HTTPS or SSH).

.PARAMETER Name
    A friendly name for the repository reference.

.PARAMETER Branch
    The branch to track (default: main).

.PARAMETER CacheTTL
    Cache time-to-live in seconds (default: 86400 - 24 hours).

.PARAMETER CredentialName
    Name of stored credential for private repositories.

.PARAMETER AutoSync
    Automatically sync on registration.

.PARAMETER Tags
    Tags for categorizing repositories.

.EXAMPLE
    Register-InfrastructureRepository -RepositoryUrl "https://github.com/org/hyperv-templates" -Name "hyperv-prod" -Branch "main" -AutoSync

.OUTPUTS
    PSCustomObject with repository details
#>
function Register-InfrastructureRepository {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^(https?|git@).*\.git$')]
        [string]$RepositoryUrl,
        
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z0-9-_]+$')]
        [string]$Name,
        
        [Parameter()]
        [string]$Branch = "main",
        
        [Parameter()]
        [ValidateRange(300, 604800)]
        [int]$CacheTTL = 86400,
        
        [Parameter()]
        [string]$CredentialName,
        
        [Parameter()]
        [switch]$AutoSync,
        
        [Parameter()]
        [string[]]$Tags
    )
    # Implementation
}
```

#### Sync-InfrastructureRepository
```powershell
<#
.SYNOPSIS
    Synchronizes a registered infrastructure repository.

.DESCRIPTION
    Pulls latest changes from remote repository, validates infrastructure code,
    and updates local cache. Supports offline mode fallback.

.PARAMETER Name
    The repository name to sync.

.PARAMETER Force
    Force sync even if cache is still valid.

.PARAMETER ValidateOnly
    Only validate without pulling changes.

.PARAMETER Offline
    Use cached version without attempting remote sync.

.EXAMPLE
    Sync-InfrastructureRepository -Name "hyperv-prod" -Force

.OUTPUTS
    PSCustomObject with sync status and details
#>
function Sync-InfrastructureRepository {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Name,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$ValidateOnly,
        
        [Parameter()]
        [switch]$Offline
    )
    # Implementation
}
```

#### Get-InfrastructureRepository
```powershell
<#
.SYNOPSIS
    Gets registered infrastructure repositories.

.PARAMETER Name
    Filter by repository name (supports wildcards).

.PARAMETER Tag
    Filter by tags.

.PARAMETER IncludeStatus
    Include sync status and cache information.

.EXAMPLE
    Get-InfrastructureRepository -Tag "production" -IncludeStatus

.OUTPUTS
    Array of repository objects
#>
function Get-InfrastructureRepository {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name = "*",
        
        [Parameter()]
        [string[]]$Tag,
        
        [Parameter()]
        [switch]$IncludeStatus
    )
    # Implementation
}
```

### 2. Template Management APIs

#### Get-InfrastructureTemplate
```powershell
<#
.SYNOPSIS
    Gets available infrastructure templates from repositories.

.DESCRIPTION
    Searches registered repositories for infrastructure templates,
    including version information and dependencies.

.PARAMETER TemplateName
    Name of the template to find.

.PARAMETER Repository
    Limit search to specific repository.

.PARAMETER Version
    Specific version or version constraint (e.g., ">=2.0.0").

.PARAMETER IncludeDependencies
    Include dependency information.

.EXAMPLE
    Get-InfrastructureTemplate -TemplateName "hyperv-cluster" -Version "~3.0.0"

.OUTPUTS
    Template objects with metadata
#>
function Get-InfrastructureTemplate {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TemplateName,
        
        [Parameter()]
        [string]$Repository,
        
        [Parameter()]
        [string]$Version,
        
        [Parameter()]
        [switch]$IncludeDependencies
    )
    # Implementation
}
```

#### Test-TemplateDependencies
```powershell
<#
.SYNOPSIS
    Tests template dependencies for compatibility.

.PARAMETER Template
    Template object or path to test.

.PARAMETER ResolveConflicts
    Attempt to resolve version conflicts automatically.

.PARAMETER IncludeOptional
    Include optional dependencies in check.

.EXAMPLE
    $template = Get-InfrastructureTemplate -TemplateName "lab-complete"
    Test-TemplateDependencies -Template $template

.OUTPUTS
    Dependency validation results
#>
function Test-TemplateDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Template,
        
        [Parameter()]
        [switch]$ResolveConflicts,
        
        [Parameter()]
        [switch]$IncludeOptional
    )
    # Implementation
}
```

### 3. ISO Management APIs

#### Initialize-DeploymentISOs
```powershell
<#
.SYNOPSIS
    Initializes ISO requirements for deployment.

.DESCRIPTION
    Analyzes deployment configuration to determine ISO requirements,
    checks existing inventory, and prepares for deployment.

.PARAMETER DeploymentConfig
    Path to deployment configuration or config object.

.PARAMETER ISORepository
    Path to ISO repository (default: from config).

.PARAMETER UpdateCheck
    Check for newer ISO versions.

.PARAMETER Interactive
    Prompt for ISO selection when multiple options exist.

.EXAMPLE
    Initialize-DeploymentISOs -DeploymentConfig ".\deploy-config.yaml" -UpdateCheck

.OUTPUTS
    ISO preparation status object
#>
function Initialize-DeploymentISOs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$DeploymentConfig,
        
        [Parameter()]
        [string]$ISORepository,
        
        [Parameter()]
        [switch]$UpdateCheck,
        
        [Parameter()]
        [switch]$Interactive
    )
    # Implementation
}
```

#### Update-DeploymentISOs
```powershell
<#
.SYNOPSIS
    Updates ISOs based on deployment requirements.

.PARAMETER ISORequirements
    ISO requirements object from Initialize-DeploymentISOs.

.PARAMETER AutoApprove
    Automatically approve updates without prompting.

.PARAMETER CustomizationProfile
    Apply customization profile during update.

.PARAMETER MaxParallel
    Maximum parallel ISO operations.

.EXAMPLE
    $isoReq = Initialize-DeploymentISOs -DeploymentConfig $config
    Update-DeploymentISOs -ISORequirements $isoReq -AutoApprove

.OUTPUTS
    Update results with ISO paths
#>
function Update-DeploymentISOs {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$ISORequirements,
        
        [Parameter()]
        [switch]$AutoApprove,
        
        [Parameter()]
        [string]$CustomizationProfile,
        
        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$MaxParallel = 3
    )
    # Implementation
}
```

### 4. Deployment Orchestration APIs

#### Start-InfrastructureDeployment
```powershell
<#
.SYNOPSIS
    Starts an infrastructure deployment using abstraction layer.

.DESCRIPTION
    Main entry point for infrastructure deployment. Orchestrates repository sync,
    template resolution, ISO preparation, and OpenTofu execution.

.PARAMETER ConfigurationPath
    Path to deployment configuration file.

.PARAMETER Repository
    Override repository from configuration.

.PARAMETER DryRun
    Perform planning only without applying changes.

.PARAMETER Stage
    Run specific deployment stage only.

.PARAMETER Checkpoint
    Resume from specific checkpoint.

.PARAMETER MaxRetries
    Maximum retry attempts for failed operations.

.EXAMPLE
    Start-InfrastructureDeployment -ConfigurationPath ".\lab-deployment.yaml" -DryRun

.OUTPUTS
    Deployment result object with detailed status
#>
function Start-InfrastructureDeployment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$ConfigurationPath,
        
        [Parameter()]
        [string]$Repository,
        
        [Parameter()]
        [switch]$DryRun,
        
        [Parameter()]
        [ValidateSet('Prepare', 'Validate', 'Plan', 'Apply', 'Verify')]
        [string]$Stage,
        
        [Parameter()]
        [string]$Checkpoint,
        
        [Parameter()]
        [ValidateRange(0, 5)]
        [int]$MaxRetries = 2
    )
    # Implementation
}
```

#### Get-DeploymentStatus
```powershell
<#
.SYNOPSIS
    Gets current deployment status and progress.

.PARAMETER DeploymentId
    Deployment ID to query.

.PARAMETER Detailed
    Include detailed stage information.

.PARAMETER Follow
    Continuously follow deployment progress.

.PARAMETER Last
    Get last N deployments.

.EXAMPLE
    Get-DeploymentStatus -DeploymentId $deployment.Id -Follow

.OUTPUTS
    Deployment status information
#>
function Get-DeploymentStatus {
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$DeploymentId,
        
        [Parameter(ParameterSetName = 'Last')]
        [int]$Last = 1,
        
        [Parameter()]
        [switch]$Detailed,
        
        [Parameter()]
        [switch]$Follow
    )
    # Implementation
}
```

### 5. Configuration Management APIs

#### Read-DeploymentConfiguration
```powershell
<#
.SYNOPSIS
    Reads and validates deployment configuration.

.PARAMETER Path
    Path to configuration file (YAML/JSON).

.PARAMETER Schema
    Path to validation schema.

.PARAMETER ExpandVariables
    Expand environment variables and references.

.PARAMETER Merge
    Additional configurations to merge.

.EXAMPLE
    $config = Read-DeploymentConfiguration -Path ".\deploy.yaml" -ExpandVariables

.OUTPUTS
    Validated configuration object
#>
function Read-DeploymentConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$Path,
        
        [Parameter()]
        [string]$Schema,
        
        [Parameter()]
        [switch]$ExpandVariables,
        
        [Parameter()]
        [string[]]$Merge
    )
    # Implementation
}
```

#### New-DeploymentConfiguration
```powershell
<#
.SYNOPSIS
    Creates a new deployment configuration from template.

.PARAMETER Template
    Template name or path.

.PARAMETER OutputPath
    Where to save the configuration.

.PARAMETER Parameters
    Parameters to populate in template.

.PARAMETER Interactive
    Interactive mode for parameter input.

.EXAMPLE
    New-DeploymentConfiguration -Template "hyperv-lab" -OutputPath ".\my-lab.yaml" -Interactive

.OUTPUTS
    Path to created configuration
#>
function New-DeploymentConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Template,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [hashtable]$Parameters,
        
        [Parameter()]
        [switch]$Interactive
    )
    # Implementation
}
```

## Helper APIs

### Validation Functions

```powershell
# Validate template syntax
Test-TemplateValid

# Validate repository accessibility  
Test-RepositoryAccess

# Validate ISO availability
Test-ISOAvailable

# Validate Hyper-V prerequisites
Test-HyperVPrerequisites
```

### Utility Functions

```powershell
# Convert between configuration formats
ConvertTo-DeploymentConfiguration

# Export deployment as template
Export-DeploymentAsTemplate

# Generate deployment report
New-DeploymentReport

# Clean up deployment artifacts
Clear-DeploymentArtifacts
```

## Error Handling

All APIs follow consistent error handling:

```powershell
try {
    # API operation
} catch [RepositoryNotFoundException] {
    # Specific error handling
} catch [TemplateValidationException] {
    # Template errors
} catch [DeploymentException] {
    # Deployment errors
} catch {
    # Generic error handling
}
```

## Return Objects

### Standard Success Object
```powershell
@{
    Success = $true
    Result = $data
    Message = "Operation completed"
    Duration = $timespan
    Warnings = @()
}
```

### Standard Error Object
```powershell
@{
    Success = $false
    Error = $errorDetails
    Message = "Operation failed"
    ErrorCode = "ERR_CODE"
    Remediation = "Suggested fix"
}
```

## Events and Callbacks

APIs support event handlers for long-running operations:

```powershell
$deployment = Start-InfrastructureDeployment -ConfigurationPath $config
$deployment.OnProgress = { param($stage, $percent) 
    Write-Host "Stage: $stage - $percent% complete"
}
$deployment.OnStageComplete = { param($stage, $result)
    Write-Log "Stage $stage completed: $($result.Success)"
}
```

---

*These API interfaces provide a comprehensive abstraction layer for OpenTofu infrastructure deployment with focus on usability and automation.*