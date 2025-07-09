function Read-DeploymentConfiguration {
    <#
    .SYNOPSIS
        Reads and validates deployment configuration.

    .DESCRIPTION
        Reads deployment configuration from YAML or JSON files, validates against
        schema, expands variables, and merges multiple configurations.

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

    begin {
        Write-CustomLog -Level 'INFO' -Message "Reading deployment configuration from: $Path"

        # Load required assemblies for YAML if needed
        if ($Path -match '\.ya?ml$') {
            try {
                Add-Type -Path (Join-Path $PSScriptRoot "../../lib/YamlDotNet.dll") -ErrorAction SilentlyContinue
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "YamlDotNet not found, using PowerShell-Yaml module"
                if (-not (Get-Module -Name powershell-yaml -ListAvailable)) {
                    throw "YAML support requires either YamlDotNet.dll or powershell-yaml module"
                }
                Import-Module powershell-yaml -ErrorAction Stop
            }
        }
    }

    process {
        try {
            # Read base configuration
            Write-CustomLog -Level 'DEBUG' -Message "Loading configuration file"

            $config = switch -Regex ($Path) {
                '\.ya?ml$' {
                    $yamlContent = Get-Content $Path -Raw
                    if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) {
                        ConvertFrom-Yaml $yamlContent -Ordered
                    } else {
                        # Fallback to basic YAML parsing
                        $yamlContent | ConvertFrom-Json
                    }
                }
                '\.json$' {
                    Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
                }
                default {
                    throw "Unsupported configuration format. Use .yaml, .yml, or .json"
                }
            }

            # Ensure configuration is a hashtable for manipulation
            if ($config -isnot [hashtable]) {
                $config = ConvertTo-HashtableFromPSObject $config
            }

            # Add metadata
            $config['_metadata'] = @{
                source = $Path
                loaded = (Get-Date).ToUniversalTime()
                format = if ($Path -match '\.ya?ml$') { 'YAML' } else { 'JSON' }
            }

            # Merge additional configurations
            if ($Merge) {
                Write-CustomLog -Level 'INFO' -Message "Merging $($Merge.Count) additional configurations"

                foreach ($mergePath in $Merge) {
                    if (Test-Path $mergePath) {
                        Write-CustomLog -Level 'DEBUG' -Message "Merging: $mergePath"

                        # Recursively read merge configuration
                        $mergeConfig = Read-DeploymentConfiguration -Path $mergePath

                        # Deep merge configurations
                        $config = Merge-DeploymentConfigurations -Base $config -Override $mergeConfig
                    } else {
                        Write-CustomLog -Level 'WARNING' -Message "Merge file not found: $mergePath"
                    }
                }
            }

            # Expand variables if requested
            if ($ExpandVariables) {
                Write-CustomLog -Level 'DEBUG' -Message "Expanding variables in configuration"
                $config = Expand-ConfigurationVariables -Configuration $config
            }

            # Validate against schema if provided
            if ($Schema) {
                Write-CustomLog -Level 'INFO' -Message "Validating configuration against schema: $Schema"

                if (-not (Test-Path $Schema)) {
                    throw "Schema file not found: $Schema"
                }

                $validationResult = Test-ConfigurationSchema -Configuration $config -SchemaPath $Schema

                if (-not $validationResult.IsValid) {
                    $errors = $validationResult.Errors -join "`n"
                    throw "Configuration validation failed:`n$errors"
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Configuration validated successfully"
            }

            # Validate required fields
            $requiredFields = @('name', 'version', 'provider')
            $missingFields = $requiredFields | Where-Object { -not $config.ContainsKey($_) }

            if ($missingFields) {
                throw "Missing required configuration fields: $($missingFields -join ', ')"
            }

            # Add default values for optional fields
            $defaults = @{
                description = "Deployment configuration"
                environment = "default"
                tags = @()
                parameters = @{}
                resources = @()
            }

            foreach ($key in $defaults.Keys) {
                if (-not $config.ContainsKey($key)) {
                    $config[$key] = $defaults[$key]
                }
            }

            # Validate provider
            $validProviders = @('Hyper-V', 'Azure', 'AWS', 'VMware', 'Generic')
            if ($config.provider -notin $validProviders) {
                throw "Invalid provider: $($config.provider). Valid providers: $($validProviders -join ', ')"
            }

            # Process template references
            if ($config.ContainsKey('template')) {
                Write-CustomLog -Level 'DEBUG' -Message "Processing template reference: $($config.template)"

                # Resolve template path
                $templateInfo = Resolve-TemplatePath -Template $config.template -BasePath (Split-Path $Path -Parent)

                if ($templateInfo) {
                    $config['_template'] = $templateInfo
                } else {
                    Write-CustomLog -Level 'WARNING' -Message "Template not found: $($config.template)"
                }
            }

            # Process repository references
            if ($config.ContainsKey('repository')) {
                Write-CustomLog -Level 'DEBUG' -Message "Processing repository reference: $($config.repository)"

                # Check if repository is registered
                $repo = Get-InfrastructureRepository -Name $config.repository

                if ($repo) {
                    $config['_repository'] = $repo
                } else {
                    Write-CustomLog -Level 'WARNING' -Message "Repository not registered: $($config.repository)"
                }
            }

            # Convert to PSCustomObject for consistent output
            $configObject = [PSCustomObject]$config

            # Add helper methods
            $configObject | Add-Member -MemberType ScriptMethod -Name ToJson -Value {
                $this | ConvertTo-Json -Depth 10
            }

            $configObject | Add-Member -MemberType ScriptMethod -Name ToYaml -Value {
                if (Get-Command ConvertTo-Yaml -ErrorAction SilentlyContinue) {
                    $this | ConvertTo-Yaml
                } else {
                    $this | ConvertTo-Json -Depth 10
                }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Configuration loaded successfully"
            return $configObject

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to read deployment configuration: $_"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'DEBUG' -Message "Configuration processing completed"
    }
}
