function Export-LabTemplate {
    <#
    .SYNOPSIS
    Exports lab infrastructure configuration as reusable templates.

    .DESCRIPTION
    Creates reusable infrastructure templates from existing configurations:
    - Extracts variable definitions
    - Creates modular configuration structures
    - Generates documentation
    - Packages templates for distribution

    .PARAMETER SourcePath
    Path to the source infrastructure configuration.

    .PARAMETER TemplateName
    Name for the exported template.

    .PARAMETER OutputPath
    Directory where the template will be exported.

    .PARAMETER IncludeDocumentation
    Include comprehensive documentation in the template.

    .EXAMPLE
    Export-LabTemplate -SourcePath "./infrastructure" -TemplateName "HyperV-Lab-Template" -OutputPath "./templates"

    .EXAMPLE
    Export-LabTemplate -SourcePath "./infrastructure" -TemplateName "Secure-Lab" -IncludeDocumentation
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplateName,

        [Parameter()]
        [string]$OutputPath = "./templates",

        [Parameter()]
        [switch]$IncludeDocumentation
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Exporting lab template '$TemplateName' from: $SourcePath"
    }

    process {
        try {
            # Create output directory
            $templateDir = Join-Path $OutputPath $TemplateName
            if ($PSCmdlet.ShouldProcess($templateDir, "Create template directory")) {
                if (Test-Path $templateDir) {
                    Remove-Item $templateDir -Recurse -Force
                }
                New-Item -Path $templateDir -ItemType Directory -Force | Out-Null
                Write-CustomLog -Level 'INFO' -Message "Created template directory: $templateDir"
            }

            # Analyze source configuration
            Write-CustomLog -Level 'INFO' -Message "Analyzing source configuration..."
            $configAnalysis = Get-InfrastructureConfigAnalysis -Path $SourcePath

            # Extract and generalize configuration
            $templateConfig = New-TemplateConfiguration -SourceAnalysis $configAnalysis -TemplateName $TemplateName

            # Create main template files
            if ($PSCmdlet.ShouldProcess($templateDir, "Create template files")) {
                # Main configuration
                $mainTfPath = Join-Path $templateDir "main.tf"
                Set-Content -Path $mainTfPath -Value $templateConfig.MainConfig
                Write-CustomLog -Level 'INFO' -Message "Created main.tf template"

                # Variables configuration
                $variablesTfPath = Join-Path $templateDir "variables.tf"
                Set-Content -Path $variablesTfPath -Value $templateConfig.VariablesConfig
                Write-CustomLog -Level 'INFO' -Message "Created variables.tf template"

                # Outputs configuration
                $outputsTfPath = Join-Path $templateDir "outputs.tf"
                Set-Content -Path $outputsTfPath -Value $templateConfig.OutputsConfig
                Write-CustomLog -Level 'INFO' -Message "Created outputs.tf template"

                # Provider configuration
                $providersTfPath = Join-Path $templateDir "providers.tf"
                Set-Content -Path $providersTfPath -Value $templateConfig.ProvidersConfig
                Write-CustomLog -Level 'INFO' -Message "Created providers.tf template"

                # Example configuration file
                $examplePath = Join-Path $templateDir "example.tfvars"
                Set-Content -Path $examplePath -Value $templateConfig.ExampleConfig
                Write-CustomLog -Level 'INFO' -Message "Created example.tfvars"
            }

            # Create documentation
            if ($IncludeDocumentation) {
                Write-CustomLog -Level 'INFO' -Message "Generating template documentation..."
                $documentation = New-TemplateDocumentation -TemplateConfig $templateConfig -TemplateName $TemplateName

                if ($PSCmdlet.ShouldProcess($templateDir, "Create documentation")) {
                    $readmePath = Join-Path $templateDir "README.md"
                    Set-Content -Path $readmePath -Value $documentation
                    Write-CustomLog -Level 'INFO' -Message "Created README.md documentation"
                }
            }

            # Create template metadata
            $metadata = @{
                TemplateName = $TemplateName
                Version = "1.0.0"
                CreatedDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                SourcePath = $SourcePath
                Author = $env:USERNAME
                Description = "Lab infrastructure template generated from $SourcePath"
                RequiredProviders = $templateConfig.RequiredProviders
                Variables = $templateConfig.Variables.Keys
                Outputs = $templateConfig.Outputs.Keys
            }

            if ($PSCmdlet.ShouldProcess($templateDir, "Create template metadata")) {
                $metadataPath = Join-Path $templateDir "template.json"
                $metadata | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataPath
                Write-CustomLog -Level 'INFO' -Message "Created template.json metadata"
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Lab template '$TemplateName' exported successfully to: $templateDir"

            return @{
                Success = $true
                TemplateName = $TemplateName
                TemplatePath = $templateDir
                Files = @(
                    "main.tf",
                    "variables.tf",
                    "outputs.tf",
                    "providers.tf",
                    "example.tfvars",
                    "template.json"
                ) + $(if ($IncludeDocumentation) { @("README.md") } else { @() })
                Metadata = $metadata
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Template export failed: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Lab template export completed"
    }
}
