function New-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        Create a new configuration environment
    .DESCRIPTION
        Creates a new configuration environment with optional settings and module configurations
    .PARAMETER Name
        Name of the new environment
    .PARAMETER Description
        Description of the environment
    .PARAMETER CopyFrom
        Copy settings from an existing environment
    .PARAMETER Settings
        Initial settings for the environment
    .PARAMETER SetAsCurrent
        Set the new environment as the current active environment
    .EXAMPLE
        New-ConfigurationEnvironment -Name "staging" -Description "Staging environment"
    .EXAMPLE
        New-ConfigurationEnvironment -Name "production" -Description "Production environment" -CopyFrom "staging"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [string]$Description = "",
        
        [Parameter()]
        [string]$CopyFrom,
        
        [Parameter()]
        [hashtable]$Settings = @{},
        
        [Parameter()]
        [switch]$SetAsCurrent
    )
    
    try {
        # Validate environment doesn't already exist
        if ($script:ConfigurationStore.Environments.ContainsKey($Name)) {
            throw "Environment '$Name' already exists"
        }
        
        # Validate source environment if copying
        if ($CopyFrom) {
            if (-not $script:ConfigurationStore.Environments.ContainsKey($CopyFrom)) {
                throw "Source environment '$CopyFrom' not found"
            }
        }
        
        # Validate environment name
        if ($Name -match '[^\w\-]') {
            throw "Environment name can only contain letters, numbers, and hyphens"
        }
        
        if ($PSCmdlet.ShouldProcess($Name, "Create new environment")) {
            # Create environment structure
            $environment = @{
                Name = $Name
                Description = $Description
                Settings = @{}
                Created = Get-Date
                CreatedBy = $env:USERNAME
            }
            
            # Copy settings from source environment if specified
            if ($CopyFrom) {
                Write-CustomLog -Level 'INFO' -Message "Copying settings from environment '$CopyFrom'"
                $sourceSettings = $script:ConfigurationStore.Environments[$CopyFrom].Settings
                foreach ($key in $sourceSettings.Keys) {
                    $environment.Settings[$key] = $sourceSettings[$key].Clone()
                }
            }
            
            # Add any provided settings
            foreach ($key in $Settings.Keys) {
                $environment.Settings[$key] = $Settings[$key]
            }
            
            # Add environment to store
            $script:ConfigurationStore.Environments[$Name] = $environment
            
            # Set as current if requested
            if ($SetAsCurrent) {
                $script:ConfigurationStore.CurrentEnvironment = $Name
                Write-CustomLog -Level 'INFO' -Message "Set '$Name' as current environment"
            }
            
            # Save configuration
            Save-ConfigurationStore
            
            Write-CustomLog -Level 'SUCCESS' -Message "Created new environment: $Name"
            
            # Publish event
            if (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue) {
                Publish-TestEvent -EventName 'EnvironmentCreated' -EventData @{
                    EnvironmentName = $Name
                    Description = $Description
                    CopiedFrom = $CopyFrom
                    SetAsCurrent = $SetAsCurrent.IsPresent
                    Timestamp = Get-Date
                }
            }
            
            return $environment
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create configuration environment: $_"
        throw
    }
}