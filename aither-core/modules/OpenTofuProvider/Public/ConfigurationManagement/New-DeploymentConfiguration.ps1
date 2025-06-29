function New-DeploymentConfiguration {
    <#
    .SYNOPSIS
        Creates a new deployment configuration from template.
    
    .DESCRIPTION
        Creates a new deployment configuration file from a template with parameter
        substitution and interactive mode support.
    
    .PARAMETER Template
        Template name or path.
    
    .PARAMETER OutputPath
        Where to save the configuration.
    
    .PARAMETER Parameters
        Parameters to populate in template.
    
    .PARAMETER Interactive
        Interactive mode for parameter input.
    
    .PARAMETER Format
        Output format (YAML or JSON).
    
    .PARAMETER Repository
        Repository to use for template lookup.
    
    .EXAMPLE
        New-DeploymentConfiguration -Template "hyperv-lab" -OutputPath ".\my-lab.yaml" -Interactive
    
    .OUTPUTS
        Path to created configuration
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Template,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [hashtable]$Parameters = @{},
        
        [Parameter()]
        [switch]$Interactive,
        
        [Parameter()]
        [ValidateSet('YAML', 'JSON')]
        [string]$Format,
        
        [Parameter()]
        [string]$Repository
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating deployment configuration from template: $Template"
        
        # Determine format from output path if not specified
        if (-not $Format) {
            $Format = switch -Regex ($OutputPath) {
                '\.ya?ml$' { 'YAML' }
                '\.json$' { 'JSON' }
                default { 'YAML' }
            }
        }
        
        # Ensure output path has correct extension
        if ($Format -eq 'YAML' -and $OutputPath -notmatch '\.ya?ml$') {
            $OutputPath += '.yaml'
        } elseif ($Format -eq 'JSON' -and $OutputPath -notmatch '\.json$') {
            $OutputPath += '.json'
        }
    }
    
    process {
        try {
            # Find template
            Write-CustomLog -Level 'DEBUG' -Message "Locating template: $Template"
            
            $templatePath = $null
            $templateMetadata = $null
            
            # Check if template is a direct path
            if (Test-Path $Template) {
                $templatePath = $Template
            } else {
                # Search in repositories
                if ($Repository) {
                    $repo = Get-InfrastructureRepository -Name $Repository
                    if (-not $repo) {
                        throw "Repository not found: $Repository"
                    }
                    
                    # Sync repository if needed
                    if (-not $repo.LocalExists) {
                        Write-CustomLog -Level 'INFO' -Message "Syncing repository: $Repository"
                        Sync-InfrastructureRepository -Name $Repository
                    }
                    
                    # Look for template in repository
                    $possiblePaths = @(
                        (Join-Path $repo.LocalPath "templates" $Template)
                        (Join-Path $repo.LocalPath "templates" $Template "latest")
                        (Join-Path $repo.LocalPath $Template)
                    )
                    
                    $templatePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
                } else {
                    # Search in all registered repositories
                    $repos = Get-InfrastructureRepository -IncludeStatus
                    
                    foreach ($repo in $repos) {
                        if ($repo.LocalExists) {
                            $possiblePaths = @(
                                (Join-Path $repo.LocalPath "templates" $Template)
                                (Join-Path $repo.LocalPath "templates" $Template "latest")
                                (Join-Path $repo.LocalPath $Template)
                            )
                            
                            $templatePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
                            if ($templatePath) {
                                Write-CustomLog -Level 'DEBUG' -Message "Found template in repository: $($repo.Name)"
                                break
                            }
                        }
                    }
                }
                
                # Search in local template directory
                if (-not $templatePath) {
                    $localTemplatePath = (Get-TemplateConfiguration).TemplatePath
                    $possiblePaths = @(
                        (Join-Path $localTemplatePath $Template)
                        (Join-Path $localTemplatePath $Template "latest")
                    )
                    
                    $templatePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
                }
            }
            
            if (-not $templatePath) {
                throw "Template not found: $Template"
            }
            
            Write-CustomLog -Level 'DEBUG' -Message "Using template from: $templatePath"
            
            # Load template metadata
            $metadataFiles = @("template.json", "template.yaml", "template.yml", "metadata.json")
            foreach ($file in $metadataFiles) {
                $metadataPath = Join-Path $templatePath $file
                if (Test-Path $metadataPath) {
                    Write-CustomLog -Level 'DEBUG' -Message "Loading template metadata from: $file"
                    
                    if ($file -match '\.ya?ml$') {
                        $yamlContent = Get-Content $metadataPath -Raw
                        if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) {
                            $templateMetadata = ConvertFrom-Yaml $yamlContent -Ordered
                        } else {
                            $templateMetadata = $yamlContent | ConvertFrom-Json -AsHashtable
                        }
                    } else {
                        $templateMetadata = Get-Content $metadataPath -Raw | ConvertFrom-Json -AsHashtable
                    }
                    break
                }
            }
            
            if (-not $templateMetadata) {
                Write-CustomLog -Level 'WARNING' -Message "No template metadata found, using defaults"
                $templateMetadata = @{
                    name = $Template
                    version = "1.0.0"
                    parameters = @{}
                }
            }
            
            # Prepare configuration structure
            $config = @{
                name = Split-Path $OutputPath -LeafBase
                version = "1.0.0"
                created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
                template = $templateMetadata.name ?? $Template
                template_version = $templateMetadata.version ?? "latest"
                provider = $templateMetadata.provider ?? "Generic"
                description = $templateMetadata.description ?? "Deployment configuration"
                environment = "default"
                tags = @()
                parameters = @{}
                resources = @()
            }
            
            # Add repository reference if found
            if ($Repository) {
                $config.repository = $Repository
            }
            
            # Process template parameters
            if ($templateMetadata.parameters) {
                Write-CustomLog -Level 'INFO' -Message "Processing template parameters"
                
                $templateParams = $templateMetadata.parameters
                
                # Interactive mode
                if ($Interactive) {
                    Write-Host ""
                    Write-Host "Template: $($templateMetadata.name ?? $Template)" -ForegroundColor Cyan
                    Write-Host "Description: $($templateMetadata.description ?? 'No description')" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Please provide values for template parameters:" -ForegroundColor Yellow
                    Write-Host ""
                    
                    foreach ($paramName in $templateParams.Keys) {
                        $param = $templateParams[$paramName]
                        $paramType = $param.type ?? "string"
                        $paramDesc = $param.description ?? "No description"
                        $paramDefault = $param.default
                        
                        Write-Host "$paramName ($paramType): $paramDesc" -ForegroundColor Green
                        
                        if ($paramDefault) {
                            Write-Host "Default: $paramDefault" -ForegroundColor Gray
                        }
                        
                        if ($param.allowed_values) {
                            Write-Host "Allowed values: $($param.allowed_values -join ', ')" -ForegroundColor Gray
                        }
                        
                        $value = Read-Host "Enter value (press Enter for default)"
                        
                        if ([string]::IsNullOrWhiteSpace($value) -and $paramDefault) {
                            $value = $paramDefault
                        }
                        
                        # Type conversion
                        switch ($paramType) {
                            "number" { $value = [int]$value }
                            "boolean" { $value = [bool]$value }
                            "array" { $value = $value -split ',' | ForEach-Object { $_.Trim() } }
                        }
                        
                        $Parameters[$paramName] = $value
                        Write-Host ""
                    }
                }
                
                # Apply parameters
                foreach ($paramName in $templateParams.Keys) {
                    $param = $templateParams[$paramName]
                    
                    if ($Parameters.ContainsKey($paramName)) {
                        $config.parameters[$paramName] = $Parameters[$paramName]
                    } elseif ($param.default) {
                        $config.parameters[$paramName] = $param.default
                    } elseif ($param.required) {
                        throw "Required parameter not provided: $paramName"
                    }
                }
            }
            
            # Copy resources from template if defined
            if ($templateMetadata.resources) {
                $config.resources = $templateMetadata.resources
            }
            
            # Apply parameter substitution in resources
            if ($config.resources -and $config.parameters) {
                $config.resources = Expand-TemplateParameters -Resources $config.resources -Parameters $config.parameters
            }
            
            # Create output directory if needed
            $outputDir = Split-Path $OutputPath -Parent
            if ($outputDir -and -not (Test-Path $outputDir)) {
                New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            }
            
            # Save configuration
            if ($PSCmdlet.ShouldProcess($OutputPath, "Create deployment configuration")) {
                Write-CustomLog -Level 'INFO' -Message "Saving configuration to: $OutputPath"
                
                switch ($Format) {
                    'YAML' {
                        if (Get-Command ConvertTo-Yaml -ErrorAction SilentlyContinue) {
                            $config | ConvertTo-Yaml | Set-Content -Path $OutputPath -Encoding UTF8
                        } else {
                            # Fallback to JSON with .yaml extension
                            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
                            Write-CustomLog -Level 'WARNING' -Message "YAML module not available, saved as JSON format"
                        }
                    }
                    'JSON' {
                        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
                    }
                }
                
                Write-CustomLog -Level 'SUCCESS' -Message "Deployment configuration created successfully"
                
                # Return the path
                Get-Item $OutputPath
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create deployment configuration: $_"
            throw
        }
    }
    
    end {
        if (Test-Path $OutputPath) {
            Write-Host ""
            Write-Host "Configuration created: $OutputPath" -ForegroundColor Green
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "1. Review and customize the configuration" -ForegroundColor Gray
            Write-Host "2. Validate: Read-DeploymentConfiguration -Path '$OutputPath'" -ForegroundColor Gray
            Write-Host "3. Deploy: Start-InfrastructureDeployment -ConfigurationPath '$OutputPath'" -ForegroundColor Gray
        }
    }
}