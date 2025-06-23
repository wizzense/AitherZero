function New-LabInfrastructure {
    <#
    .SYNOPSIS
    Creates new lab infrastructure using OpenTofu with Taliesins provider.
    
    .DESCRIPTION
    Deploys lab infrastructure by:
    - Validating configuration
    - Planning infrastructure changes
    - Applying infrastructure with security validation
    - Performing post-deployment verification
    
    .PARAMETER ConfigPath
    Path to the lab configuration file.
    
    .PARAMETER PlanOnly
    Only generate and show the plan without applying changes.
    
    .PARAMETER AutoApprove
    Automatically approve the plan and apply changes.
    
    .PARAMETER Force
    Force deployment even if validation warnings exist.
    
    .EXAMPLE
    New-LabInfrastructure -ConfigPath "lab_config.yaml" -PlanOnly
    
    .EXAMPLE
    New-LabInfrastructure -ConfigPath "lab_config.yaml" -AutoApprove
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,
        
        [Parameter()]
        [switch]$PlanOnly,
        
        [Parameter()]
        [switch]$AutoApprove,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting lab infrastructure deployment from: $ConfigPath"
    }
    
    process {
        try {
            # Validate prerequisites
            Write-CustomLog -Level 'INFO' -Message "Validating prerequisites..."
            $prerequisites = Test-LabInfrastructurePrerequisites -ConfigPath $ConfigPath
            
            if (-not $prerequisites.Valid) {
                if (-not $Force) {
                    throw "Prerequisites validation failed: $($prerequisites.Issues -join '; ')"
                } else {
                    Write-CustomLog -Level 'WARN' -Message "Prerequisites validation failed but continuing due to -Force: $($prerequisites.Issues -join '; ')"
                }
            }
            
            # Initialize OpenTofu if not already done
            Write-CustomLog -Level 'INFO' -Message "Checking OpenTofu initialization..."
            $initCheck = Test-OpenTofuInitialization
            if (-not $initCheck.IsInitialized) {
                Write-CustomLog -Level 'INFO' -Message "Initializing OpenTofu..."
                $initResult = Initialize-OpenTofuProvider -ConfigPath $ConfigPath
                if (-not $initResult.Success) {
                    throw "OpenTofu initialization failed: $($initResult.Error)"
                }
            }
            
            # Generate and validate plan
            Write-CustomLog -Level 'INFO' -Message "Generating infrastructure plan..."
            $planResult = Invoke-OpenTofuCommand -Command "plan -out=tfplan"
            
            if (-not $planResult.Success) {
                throw "Infrastructure planning failed: $($planResult.Error)"
            }
            
            Write-CustomLog -Level 'INFO' -Message "Infrastructure plan generated successfully"
            
            # Display plan output
            if ($planResult.Output) {
                Write-Host "`nInfrastructure Plan:" -ForegroundColor Cyan
                Write-Host $planResult.Output -ForegroundColor White
            }
            
            # If plan only, return here
            if ($PlanOnly) {
                Write-CustomLog -Level 'SUCCESS' -Message "Plan-only mode: Infrastructure plan generated and displayed"
                return @{
                    Success = $true
                    PlanGenerated = $true
                    Applied = $false
                    PlanOutput = $planResult.Output
                }
            }
            
            # Confirm deployment if not auto-approved
            if (-not $AutoApprove) {
                $confirmation = Read-Host "`nDo you want to apply this infrastructure plan? (yes/no)"
                if ($confirmation -ne 'yes') {
                    Write-CustomLog -Level 'INFO' -Message "Infrastructure deployment cancelled by user"
                    return @{
                        Success = $true
                        PlanGenerated = $true
                        Applied = $false
                        Cancelled = $true
                    }
                }
            }
            
            # Apply infrastructure
            if ($PSCmdlet.ShouldProcess("Lab Infrastructure", "Apply OpenTofu plan")) {
                Write-CustomLog -Level 'INFO' -Message "Applying infrastructure changes..."
                $applyResult = Invoke-OpenTofuCommand -Command "apply tfplan"
                
                if (-not $applyResult.Success) {
                    throw "Infrastructure deployment failed: $($applyResult.Error)"
                }
                
                Write-CustomLog -Level 'SUCCESS' -Message "Infrastructure deployed successfully"
                
                # Post-deployment verification
                Write-CustomLog -Level 'INFO' -Message "Performing post-deployment verification..."
                $verification = Test-LabInfrastructureDeployment -ConfigPath $ConfigPath
                
                return @{
                    Success = $true
                    PlanGenerated = $true
                    Applied = $true
                    PlanOutput = $planResult.Output
                    ApplyOutput = $applyResult.Output
                    Verification = $verification
                }
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Lab infrastructure deployment failed: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'INFO' -Message "Lab infrastructure deployment process completed"
    }
}
