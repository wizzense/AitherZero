function Register-InfrastructureProvider {
    <#
    .SYNOPSIS
        Registers an infrastructure provider for use with deployments.

    .DESCRIPTION
        Registers and configures an infrastructure provider, validating its
        requirements and storing configuration for future use. Supports both
        built-in and custom providers.

    .PARAMETER Name
        Name of the provider to register.

    .PARAMETER Configuration
        Provider-specific configuration settings.

    .PARAMETER Credential
        Credentials for provider authentication if required.

    .PARAMETER SkipValidation
        Skip provider validation during registration.

    .PARAMETER Force
        Force re-registration of an already registered provider.

    .PARAMETER PassThru
        Return the registered provider object.

    .EXAMPLE
        Register-InfrastructureProvider -Name "Hyper-V"

    .EXAMPLE
        $azureConfig = @{
            SubscriptionId = "12345-67890"
            ResourceGroup = "MyRG"
            Location = "eastus"
        }
        Register-InfrastructureProvider -Name "Azure" -Configuration $azureConfig -Credential $cred

    .OUTPUTS
        Registered provider object if PassThru is specified
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [hashtable]$Configuration = @{},
        
        [Parameter()]
        [PSCredential]$Credential,
        
        [Parameter()]
        [switch]$SkipValidation,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$PassThru
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Registering infrastructure provider: $Name"
        
        # Initialize provider registry
        if (-not $script:infrastructureProviders) {
            $script:infrastructureProviders = @{}
        }
        
        # Get state file path
        $script:providerStatePath = Join-Path $env:PROJECT_ROOT "configs" "registered-providers.json"
    }
    
    process {
        try {
            # Check if already registered
            if ($script:infrastructureProviders.ContainsKey($Name) -and -not $Force) {
                throw "Provider '$Name' is already registered. Use -Force to re-register."
            }
            
            # Get provider definition
            Write-CustomLog -Level 'INFO' -Message "Loading provider definition for: $Name"
            $providerDef = Get-ProviderDefinition -ProviderName $Name
            
            if (-not $providerDef) {
                throw "Provider '$Name' not found. Use Get-InfrastructureProvider -ListAvailable to see available providers."
            }
            
            # Validate requirements
            if (-not $SkipValidation) {
                Write-CustomLog -Level 'INFO' -Message "Validating provider requirements"
                
                # Check OS requirements
                if ($providerDef.Requirements.OperatingSystem -ne 'Any') {
                    $currentOS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'MacOS' }
                    if ($providerDef.Requirements.OperatingSystem -ne $currentOS) {
                        throw "Provider '$Name' requires $($providerDef.Requirements.OperatingSystem) but current OS is $currentOS"
                    }
                }
                
                # Check PowerShell version
                if ($providerDef.Requirements.PowerShellVersion) {
                    $requiredVersion = [Version]$providerDef.Requirements.PowerShellVersion
                    if ($PSVersionTable.PSVersion -lt $requiredVersion) {
                        throw "Provider '$Name' requires PowerShell $requiredVersion or higher"
                    }
                }
                
                # Check required modules
                if ($providerDef.Requirements.RequiredModules) {
                    foreach ($module in $providerDef.Requirements.RequiredModules) {
                        if (-not (Get-Module -Name $module -ListAvailable)) {
                            Write-CustomLog -Level 'WARN' -Message "Required module '$module' not found"
                            
                            if ($PSCmdlet.ShouldProcess($module, "Install required module")) {
                                try {
                                    Install-Module -Name $module -Force -AllowClobber
                                    Write-CustomLog -Level 'SUCCESS' -Message "Installed module: $module"
                                } catch {
                                    throw "Failed to install required module '$module': $_"
                                }
                            } else {
                                throw "Required module '$module' is not installed"
                            }
                        }
                    }
                }
                
                # Check Windows features (if applicable)
                if ($IsWindows -and $providerDef.Requirements.RequiredFeatures) {
                    foreach ($feature in $providerDef.Requirements.RequiredFeatures) {
                        $featureState = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
                        if (-not $featureState -or $featureState.State -ne 'Enabled') {
                            throw "Required Windows feature '$feature' is not enabled"
                        }
                    }
                }
            }
            
            # Load provider adapter if available
            $adapterPath = Join-Path $PSScriptRoot "../../Private/Providers" "${Name}Adapter.ps1"
            if (Test-Path $adapterPath) {
                Write-CustomLog -Level 'INFO' -Message "Loading provider adapter"
                . $adapterPath
                
                # Initialize provider methods
                Initialize-ProviderMethods -Provider $providerDef
            }
            
            # Merge configurations
            $mergedConfig = $providerDef.Configuration.Clone()
            foreach ($key in $Configuration.Keys) {
                $mergedConfig[$key] = $Configuration[$key]
            }
            
            # Validate configuration
            if ($providerDef.Methods.ValidateConfiguration -and -not $SkipValidation) {
                Write-CustomLog -Level 'INFO' -Message "Validating provider configuration"
                $validationResult = & $providerDef.Methods.ValidateConfiguration -Configuration $mergedConfig
                
                if (-not $validationResult.IsValid) {
                    throw "Provider configuration validation failed: $($validationResult.Errors -join '; ')"
                }
            }
            
            # Store credentials if provided
            if ($Credential) {
                if ($providerDef.Configuration.RequiresAuthentication) {
                    Write-CustomLog -Level 'INFO' -Message "Storing provider credentials"
                    $credentialName = "InfraProvider_${Name}"
                    
                    # Use SecureCredentials module if available
                    if (Get-Command Set-SecureCredential -ErrorAction SilentlyContinue) {
                        Set-SecureCredential -Name $credentialName -Credential $Credential
                        $mergedConfig['CredentialName'] = $credentialName
                    } else {
                        Write-CustomLog -Level 'WARN' -Message "SecureCredentials module not available, credentials will not be persisted"
                    }
                } else {
                    Write-CustomLog -Level 'WARN' -Message "Provider '$Name' does not require authentication, ignoring credentials"
                }
            }
            
            # Create registration object
            $registration = @{
                Name = $Name
                DisplayName = $providerDef.DisplayName
                Version = $providerDef.Version
                RegisteredAt = Get-Date
                Configuration = $mergedConfig
                Status = 'Registered'
            }
            
            # Register provider
            if ($PSCmdlet.ShouldProcess($Name, "Register infrastructure provider")) {
                $script:infrastructureProviders[$Name] = $registration
                
                # Save to persistent storage
                Save-RegisteredProviders
                
                Write-CustomLog -Level 'SUCCESS' -Message "Successfully registered provider: $Name"
                
                # Initialize provider if it has an initialize method
                if ($providerDef.Methods.Initialize) {
                    Write-CustomLog -Level 'INFO' -Message "Initializing provider"
                    try {
                        & $providerDef.Methods.Initialize -Configuration $mergedConfig
                        Write-CustomLog -Level 'SUCCESS' -Message "Provider initialized successfully"
                    } catch {
                        Write-CustomLog -Level 'WARN' -Message "Provider initialization failed: $_"
                    }
                }
                
                # Return provider if requested
                if ($PassThru) {
                    $result = Get-InfrastructureProvider -Name $Name
                    return $result
                }
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to register provider '$Name': $($_.Exception.Message)"
            throw
        }
    }
}

function Save-RegisteredProviders {
    try {
        # Ensure config directory exists
        $configDir = Split-Path $script:providerStatePath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        # Convert to array for JSON serialization
        $providerArray = @()
        foreach ($provider in $script:infrastructureProviders.Values) {
            $providerArray += $provider
        }
        
        # Save to file
        $providerArray | ConvertTo-Json -Depth 10 | Set-Content -Path $script:providerStatePath
        
        Write-CustomLog -Level 'DEBUG' -Message "Saved registered providers to: $script:providerStatePath"
    } catch {
        Write-CustomLog -Level 'WARN' -Message "Failed to save registered providers: $_"
    }
}

function Initialize-ProviderMethods {
    param([PSCustomObject]$Provider)
    
    # Map adapter functions to provider methods
    $methodMappings = @{
        Initialize = "Initialize-${($Provider.Name)}Provider"
        ValidateConfiguration = "Test-${($Provider.Name)}Configuration"
        TranslateResource = "ConvertTo-${($Provider.Name)}Resource"
        TestReadiness = "Test-${($Provider.Name)}Readiness"
        GetResourceTypes = "Get-${($Provider.Name)}ResourceTypes"
        ValidateCredentials = "Test-${($Provider.Name)}Credentials"
    }
    
    foreach ($method in $methodMappings.GetEnumerator()) {
        if (Get-Command $method.Value -ErrorAction SilentlyContinue) {
            $Provider.Methods[$method.Key] = (Get-Command $method.Value).ScriptBlock
            Write-CustomLog -Level 'DEBUG' -Message "Loaded provider method: $($method.Key)"
        }
    }
}