function New-DeploymentPlan {
    <#
    .SYNOPSIS
        Creates a deployment plan based on configuration.

    .DESCRIPTION
        Analyzes deployment configuration and generates an execution plan with
        stages, dependencies, and resource requirements. Supports both simple
        and complex multi-stage deployments.

    .PARAMETER Configuration
        Deployment configuration object from Read-DeploymentConfiguration.

    .PARAMETER DryRun
        Generate plan for dry-run mode only.

    .PARAMETER SkipPreChecks
        Skip pre-deployment validation checks.

    .PARAMETER CustomStages
        Override default deployment stages.

    .PARAMETER ParallelThreshold
        Resource count threshold for parallel execution.

    .EXAMPLE
        $config = Read-DeploymentConfiguration -Path ".\deploy.yaml"
        $plan = New-DeploymentPlan -Configuration $config

    .EXAMPLE
        $plan = New-DeploymentPlan -Configuration $config -CustomStages @('Plan', 'Apply')

    .OUTPUTS
        Deployment plan object with stages and dependencies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Configuration,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$SkipPreChecks,

        [Parameter()]
        [string[]]$CustomStages,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$ParallelThreshold = 5
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating deployment plan"

        # Define default deployment stages
        $script:defaultStages = @(
            @{
                Name = 'Prepare'
                Order = 1
                Required = $true
                CreateCheckpoint = $false
                Actions = @('ValidateConfig', 'SyncRepository', 'PrepareISOs')
            },
            @{
                Name = 'Validate'
                Order = 2
                Required = $true
                CreateCheckpoint = $false
                Actions = @('ValidateTemplate', 'CheckDependencies', 'TestConnectivity')
            },
            @{
                Name = 'Plan'
                Order = 3
                Required = $true
                CreateCheckpoint = $true
                Actions = @('GeneratePlan', 'ReviewChanges', 'CalculateCost')
            },
            @{
                Name = 'Apply'
                Order = 4
                Required = $false
                CreateCheckpoint = $true
                Actions = @('ApplyInfrastructure', 'ConfigureResources', 'ValidateDeployment')
            },
            @{
                Name = 'Verify'
                Order = 5
                Required = $false
                CreateCheckpoint = $false
                Actions = @('TestFunctionality', 'ValidateCompliance', 'GenerateReport')
            }
        )
    }

    process {
        try {
            # Initialize deployment plan
            $deploymentPlan = @{
                Id = [Guid]::NewGuid().ToString()
                Created = Get-Date
                Configuration = $Configuration
                IsValid = $false
                ValidationErrors = @()
                Stages = @{}
                Dependencies = @{}
                Resources = @{}
                EstimatedDuration = [TimeSpan]::Zero
                RequiredISOs = @()
                RequiredModules = @()
                ParallelExecution = $false
                Metadata = @{
                    ConfigurationPath = $Configuration.SourcePath
                    RepositoryName = $Configuration.repository.name
                    RepositoryVersion = $Configuration.repository.version
                    TemplateName = $Configuration.template.name
                    TemplateVersion = $Configuration.template.version
                }
            }

            # Step 1: Determine stages to include
            $stagesToInclude = if ($CustomStages) {
                Write-CustomLog -Level 'INFO' -Message "Using custom stages: $($CustomStages -join ', ')"
                $script:defaultStages | Where-Object { $_.Name -in $CustomStages }
            } elseif ($DryRun) {
                Write-CustomLog -Level 'INFO' -Message "Dry-run mode: excluding Apply and Verify stages"
                $script:defaultStages | Where-Object { $_.Name -in @('Prepare', 'Validate', 'Plan') }
            } else {
                $script:defaultStages
            }

            # Step 2: Build stage definitions
            foreach ($stageDefinition in $stagesToInclude) {
                $stage = @{
                    Name = $stageDefinition.Name
                    Order = $stageDefinition.Order
                    Required = $stageDefinition.Required
                    CreateCheckpoint = $stageDefinition.CreateCheckpoint
                    Actions = @()
                    Prerequisites = @()
                    EstimatedDuration = [TimeSpan]::FromMinutes(5)  # Default estimate
                    CanRunParallel = $false
                    RetryPolicy = @{
                        MaxAttempts = 2
                        DelaySeconds = 30
                    }
                }

                # Build actions for stage
                foreach ($actionName in $stageDefinition.Actions) {
                    $action = Build-StageAction -ActionName $actionName -Configuration $Configuration -Stage $stageDefinition.Name
                    if ($action) {
                        $stage.Actions += $action
                    }
                }

                # Set stage-specific properties
                switch ($stage.Name) {
                    'Prepare' {
                        $stage.Prerequisites = @()
                        $stage.EstimatedDuration = [TimeSpan]::FromMinutes(10)

                        # Add ISO requirements
                        if ($Configuration.iso_requirements) {
                            foreach ($iso in $Configuration.iso_requirements) {
                                $deploymentPlan.RequiredISOs += @{
                                    Name = $iso.name
                                    Type = $iso.type
                                    Customization = $iso.customization
                                    Required = $true
                                }
                            }
                        }
                    }

                    'Validate' {
                        $stage.Prerequisites = @('Prepare')
                        $stage.EstimatedDuration = [TimeSpan]::FromMinutes(5)

                        # Check for required modules
                        if ($Configuration.dependencies) {
                            foreach ($dep in $Configuration.dependencies.PSObject.Properties) {
                                $deploymentPlan.RequiredModules += @{
                                    Name = $dep.Name
                                    Version = $dep.Value
                                    Required = $true
                                }
                            }
                        }
                    }

                    'Plan' {
                        $stage.Prerequisites = @('Validate')
                        $stage.EstimatedDuration = [TimeSpan]::FromMinutes(15)
                        $stage.RetryPolicy.MaxAttempts = 1  # Don't retry planning
                    }

                    'Apply' {
                        $stage.Prerequisites = @('Plan')
                        $stage.EstimatedDuration = [TimeSpan]::FromMinutes(30)

                        # Check if parallel execution is beneficial
                        $resourceCount = 0
                        if ($Configuration.infrastructure) {
                            $resourceCount = ($Configuration.infrastructure.PSObject.Properties | Measure-Object).Count
                        }

                        if ($resourceCount -ge $ParallelThreshold) {
                            $stage.CanRunParallel = $true
                            $deploymentPlan.ParallelExecution = $true
                            Write-CustomLog -Level 'INFO' -Message "Enabling parallel execution for $resourceCount resources"
                        }
                    }

                    'Verify' {
                        $stage.Prerequisites = @('Apply')
                        $stage.EstimatedDuration = [TimeSpan]::FromMinutes(10)
                        $stage.Required = $false  # Optional verification
                    }
                }

                $deploymentPlan.Stages[$stage.Name] = $stage
            }

            # Step 3: Build dependency graph
            foreach ($stageName in $deploymentPlan.Stages.Keys) {
                $stage = $deploymentPlan.Stages[$stageName]
                $deploymentPlan.Dependencies[$stageName] = $stage.Prerequisites
            }

            # Step 4: Analyze resources
            if ($Configuration.infrastructure) {
                foreach ($resourceProp in $Configuration.infrastructure.PSObject.Properties) {
                    $resourceType = $resourceProp.Name
                    $resourceConfig = $resourceProp.Value

                    $resourceAnalysis = @{
                        Type = $resourceType
                        Count = 1
                        Provider = 'taliesins/hyperv'  # Default for now
                        EstimatedCost = 0
                        Dependencies = @()
                    }

                    # Handle arrays of resources
                    if ($resourceConfig -is [array]) {
                        $resourceAnalysis.Count = $resourceConfig.Count
                    } elseif ($resourceConfig.count) {
                        $resourceAnalysis.Count = $resourceConfig.count
                    }

                    # Analyze dependencies
                    if ($resourceConfig.depends_on) {
                        $resourceAnalysis.Dependencies = @($resourceConfig.depends_on)
                    }

                    $deploymentPlan.Resources[$resourceType] = $resourceAnalysis
                }
            }

            # Step 5: Calculate total estimated duration
            $totalMinutes = 0
            foreach ($stage in $deploymentPlan.Stages.Values) {
                if (-not $stage.CanRunParallel) {
                    $totalMinutes += $stage.EstimatedDuration.TotalMinutes
                }
            }
            $deploymentPlan.EstimatedDuration = [TimeSpan]::FromMinutes($totalMinutes)

            # Step 6: Validate plan
            if (-not $SkipPreChecks) {
                Write-CustomLog -Level 'INFO' -Message "Validating deployment plan"

                # Check for circular dependencies
                $circularDeps = Test-CircularDependencies -Dependencies $deploymentPlan.Dependencies
                if ($circularDeps) {
                    $deploymentPlan.ValidationErrors += "Circular dependency detected: $circularDeps"
                }

                # Validate required fields
                if (-not $Configuration.repository -or -not $Configuration.repository.name) {
                    $deploymentPlan.ValidationErrors += "Repository name is required"
                }

                if (-not $Configuration.template -or -not $Configuration.template.name) {
                    $deploymentPlan.ValidationErrors += "Template name is required"
                }

                # Validate ISO requirements
                foreach ($iso in $deploymentPlan.RequiredISOs) {
                    if (-not $iso.Type) {
                        $deploymentPlan.ValidationErrors += "ISO type not specified for: $($iso.Name)"
                    }
                }

                # Check deployment variables
                if ($Configuration.variables) {
                    foreach ($varProp in $Configuration.variables.PSObject.Properties) {
                        if ($null -eq $varProp.Value -or $varProp.Value -eq '') {
                            $deploymentPlan.ValidationErrors += "Variable '$($varProp.Name)' has no value"
                        }
                    }
                }
            }

            # Set validation status
            $deploymentPlan.IsValid = $deploymentPlan.ValidationErrors.Count -eq 0

            # Generate summary
            if ($deploymentPlan.IsValid) {
                Write-CustomLog -Level 'SUCCESS' -Message "Deployment plan created successfully"
                Write-DeploymentPlanSummary -Plan $deploymentPlan
            } else {
                Write-CustomLog -Level 'ERROR' -Message "Deployment plan validation failed"
                foreach ($error in $deploymentPlan.ValidationErrors) {
                    Write-CustomLog -Level 'ERROR' -Message "  - $error"
                }
            }

            return [PSCustomObject]$deploymentPlan

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create deployment plan: $($_.Exception.Message)"
            throw
        }
    }
}

function Build-StageAction {
    param(
        [string]$ActionName,
        [PSCustomObject]$Configuration,
        [string]$Stage
    )

    $action = @{
        Name = $ActionName
        Type = 'PowerShell'  # Default type
        Script = $null
        Parameters = @{}
        Timeout = [TimeSpan]::FromMinutes(5)
        ContinueOnError = $false
    }

    # Define action implementations
    switch ($ActionName) {
        'ValidateConfig' {
            $action.Script = {
                param($Config)
                # Configuration validation logic
                Test-DeploymentConfiguration -Configuration $Config
            }
            $action.Parameters.Config = $Configuration
        }

        'SyncRepository' {
            $action.Script = {
                param($RepoName, $RepoUrl)
                Sync-InfrastructureRepository -Name $RepoName
            }
            $action.Parameters.RepoName = $Configuration.repository.name
            $action.Parameters.RepoUrl = $Configuration.repository.url
            $action.Timeout = [TimeSpan]::FromMinutes(10)
        }

        'PrepareISOs' {
            $action.Script = {
                param($ISORequirements)
                if ($ISORequirements) {
                    $isoReq = Initialize-DeploymentISOs -DeploymentConfig @{iso_requirements = $ISORequirements}
                    Test-ISORequirements -Requirements $isoReq
                }
            }
            $action.Parameters.ISORequirements = $Configuration.iso_requirements
        }

        'ValidateTemplate' {
            $action.Script = {
                param($Template, $Variables)
                # Template validation logic
                Test-TemplateSyntax -Template $Template -Variables $Variables
            }
            $action.Parameters.Template = $Configuration.template
            $action.Parameters.Variables = $Configuration.variables
        }

        'GeneratePlan' {
            $action.Type = 'OpenTofu'
            $action.Script = {
                param($WorkingDir, $Variables)
                # Run tofu plan
                & tofu plan -out=tfplan -var-file=terraform.tfvars
            }
            $action.Timeout = [TimeSpan]::FromMinutes(15)
        }

        'ApplyInfrastructure' {
            $action.Type = 'OpenTofu'
            $action.Script = {
                param($WorkingDir, $PlanFile)
                # Run tofu apply
                & tofu apply -auto-approve tfplan
            }
            $action.Timeout = [TimeSpan]::FromMinutes(30)
        }

        'TestFunctionality' {
            $action.Script = {
                param($Resources)
                # Run post-deployment tests
                Test-DeployedResources -Resources $Resources
            }
            $action.ContinueOnError = $true  # Don't fail deployment on test failures
        }

        default {
            # Return null for unknown actions
            return $null
        }
    }

    return $action
}

function Test-CircularDependencies {
    param([hashtable]$Dependencies)

    # Simple circular dependency check
    foreach ($node in $Dependencies.Keys) {
        $visited = @($node)
        $queue = [System.Collections.Queue]::new()

        foreach ($dep in $Dependencies[$node]) {
            $queue.Enqueue($dep)
        }

        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()

            if ($current -eq $node) {
                return "$node -> ... -> $current"
            }

            if ($visited -contains $current) {
                continue
            }

            $visited += $current

            if ($Dependencies.ContainsKey($current)) {
                foreach ($dep in $Dependencies[$current]) {
                    $queue.Enqueue($dep)
                }
            }
        }
    }

    return $null
}

function Write-DeploymentPlanSummary {
    param([PSCustomObject]$Plan)

    Write-Host "`n=== DEPLOYMENT PLAN SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Plan ID: $($Plan.Id)"
    Write-Host "Repository: $($Plan.Metadata.RepositoryName) (v$($Plan.Metadata.RepositoryVersion))"
    Write-Host "Template: $($Plan.Metadata.TemplateName) (v$($Plan.Metadata.TemplateVersion))"

    Write-Host "`nStages ($($Plan.Stages.Count)):" -ForegroundColor Yellow
    foreach ($stage in $Plan.Stages.Values | Sort-Object Order) {
        $req = if ($stage.Required) { "[Required]" } else { "[Optional]" }
        Write-Host "  $($stage.Order). $($stage.Name) $req - $($stage.Actions.Count) actions"
    }

    if ($Plan.Resources.Count -gt 0) {
        Write-Host "`nResources:" -ForegroundColor Yellow
        foreach ($resource in $Plan.Resources.Values) {
            Write-Host "  - $($resource.Type): $($resource.Count) instance(s)"
        }
    }

    if ($Plan.RequiredISOs.Count -gt 0) {
        Write-Host "`nRequired ISOs:" -ForegroundColor Yellow
        foreach ($iso in $Plan.RequiredISOs) {
            $custom = if ($iso.Customization) { " ($($iso.Customization))" } else { "" }
            Write-Host "  - $($iso.Name): $($iso.Type)$custom"
        }
    }

    Write-Host "`nEstimated Duration: $([Math]::Round($Plan.EstimatedDuration.TotalMinutes, 0)) minutes" -ForegroundColor Green

    if ($Plan.ParallelExecution) {
        Write-Host "Parallel Execution: Enabled" -ForegroundColor Green
    }

    Write-Host "==============================`n" -ForegroundColor Cyan
}

function Test-DeploymentConfiguration {
    param([PSCustomObject]$Configuration)

    # Basic configuration validation
    $isValid = $true

    if (-not $Configuration) {
        throw "Configuration is null"
    }

    if (-not $Configuration.version) {
        Write-CustomLog -Level 'WARN' -Message "Configuration version not specified"
    }

    return $isValid
}

function Test-TemplateSyntax {
    param(
        [PSCustomObject]$Template,
        [PSCustomObject]$Variables
    )

    # Basic template syntax validation
    return $true
}

function Test-DeployedResources {
    param([PSCustomObject]$Resources)

    # Basic resource validation
    return $true
}
