# Aitherium Organization Setup Playbook
# Complete zero-to-deployment setup for an AitherZero organization owner
#
# This playbook orchestrates the full setup process including:
# - Environment and development tools
# - Certificate Authority and PKI infrastructure
# - License generation and management system
# - Secure credential management
# - GitHub integration for license distribution
#
# Usage:
#   Start-AitherZero -Mode Orchestrate -Playbook aitherium-org-setup
#   OR
#   Invoke-OrchestrationSequence -PlaybookPath "./orchestration/playbooks/aitherium-org-setup.psd1"

@{
    # Playbook metadata
    Name = 'aitherium-org-setup'
    Description = 'Complete setup for AitherZero organization owner (Aitherium)'
    Version = '1.0.0'
    Author = 'AitherZero Team'
    Tags = @('Setup', 'Organization', 'Infrastructure', 'Licensing', 'CA', 'PKI')
    
    # Playbook configuration
    Configuration = @{
        # Organization name
        OrganizationName = 'aitherium'
        
        # Whether to continue on non-critical errors
        ContinueOnError = $false
        
        # Parallel execution where possible
        MaxParallelJobs = 4
        
        # Timeout for entire playbook (minutes)
        TimeoutMinutes = 60
    }
    
    # Variables available to all scripts
    Variables = @{
        OrgName = 'aitherium'
        GitHubOwner = 'aitherium'
        LicenseRepo = 'licenses'
        SetupMode = 'Full'
        InstallProfile = 'Developer'  # Minimal, Standard, Developer, Full
    }
    
    # Execution stages
    Stages = @(
        @{
            Name = 'Environment-Setup'
            Description = 'Bootstrap PowerShell 7 and basic environment'
            ContinueOnError = $false
            Scripts = @(
                @{
                    Path = '0000_Bootstrap-PowerShell7.ps1'
                    Parameters = @{}
                    Optional = $false
                }
            )
        }
        
        @{
            Name = 'Development-Tools'
            Description = 'Install core development tools'
            ContinueOnError = $false
            Parallel = $true
            Scripts = @(
                @{
                    Path = '0207_Install-Git.ps1'
                    Parameters = @{}
                    Optional = $false
                }
                @{
                    Path = '0201_Install-Node.ps1'
                    Parameters = @{}
                    Optional = $true
                }
                @{
                    Path = '0210_Install-VSCode.ps1'
                    Parameters = @{}
                    Optional = $true
                }
            )
        }
        
        @{
            Name = 'Infrastructure-Setup'
            Description = 'Set up infrastructure components'
            ContinueOnError = $false
            Scripts = @(
                @{
                    Path = '0100_Configure-System.ps1'
                    Parameters = @{}
                    Optional = $false
                    Condition = { $IsWindows }
                }
                @{
                    Path = '0104_Install-CertificateAuthority.ps1'
                    Parameters = @{
                        CAName = "Aitherium Root CA"
                        ValidityYears = 10
                    }
                    Optional = $false
                    Condition = { $IsWindows }
                    Description = 'Install and configure Certificate Authority for PKI'
                }
            )
        }
        
        @{
            Name = 'License-Infrastructure'
            Description = 'Set up license generation and management system'
            ContinueOnError = $false
            Scripts = @(
                @{
                    Path = '0803_Setup-LicenseInfrastructure.ps1'
                    Parameters = @{
                        OrganizationName = '$Variables:OrgName'
                        GitHubOwner = '$Variables:GitHubOwner'
                        GitHubRepo = '$Variables:LicenseRepo'
                        SetupCA = $true
                        GenerateMasterKeys = $true
                    }
                    Optional = $false
                    Description = 'Configure license infrastructure with CA integration and master keys'
                }
            )
        }
        
        @{
            Name = 'GitHub-Integration'
            Description = 'Configure GitHub for secure credential and license storage'
            ContinueOnError = $false
            Scripts = @(
                @{
                    Path = 'Invoke-Expression'
                    Parameters = @{
                        Command = @'
# Configure GitHub credentials for organization
Write-Host "GitHub Integration Setup" -ForegroundColor Cyan
Write-Host "Please provide a GitHub Personal Access Token with 'repo' scope"
Write-Host "Create token at: https://github.com/settings/tokens/new"
Write-Host ""

$token = Read-Host -Prompt "GitHub Token" -AsSecureString
$tokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token)
)

Set-AitherCredentialGitHub -Token $tokenPlain
Write-Host "✓ GitHub credentials configured" -ForegroundColor Green
'@
                    }
                    Optional = $false
                    Description = 'Configure GitHub credentials for license distribution'
                }
            )
        }
        
        @{
            Name = 'License-Generation'
            Description = 'Generate initial licenses for organization'
            ContinueOnError = $true
            Scripts = @(
                @{
                    Path = '0800_Manage-License.ps1'
                    Parameters = @{
                        Action = 'Create'
                        LicenseId = 'AITHERIUM-MASTER-001'
                        LicensedTo = 'Aitherium Organization'
                        ExpirationDays = 3650  # 10 years
                        GenerateKey = $true
                        GenerateSigningKey = $true
                        OutputPath = '~/.aitherzero/licenses/AITHERIUM-MASTER-001.json'
                    }
                    Optional = $true
                    Description = 'Generate master organization license'
                }
            )
        }
        
        @{
            Name = 'Validation'
            Description = 'Validate setup and configuration'
            ContinueOnError = $false
            Scripts = @(
                @{
                    Path = 'Invoke-Expression'
                    Parameters = @{
                        Command = @'
# Validation checks
Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Aitherium Organization Setup Validation       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$checks = @()

# Check PowerShell version
$checks += @{
    Name = "PowerShell 7+"
    Status = $PSVersionTable.PSVersion.Major -ge 7
}

# Check Git
$checks += @{
    Name = "Git installed"
    Status = (Get-Command git -ErrorAction SilentlyContinue) -ne $null
}

# Check license infrastructure
$licenseDir = [System.IO.Path]::GetFullPath("~/.aitherzero/licenses")
$checks += @{
    Name = "License storage created"
    Status = Test-Path $licenseDir
}

# Check GitHub credentials
try {
    Get-AitherCredentialGitHub -ErrorAction Stop | Out-Null
    $checks += @{
        Name = "GitHub credentials"
        Status = $true
    }
} catch {
    $checks += @{
        Name = "GitHub credentials"
        Status = $false
    }
}

# Display results
foreach ($check in $checks) {
    $icon = if ($check.Status) { "✓" } else { "✗" }
    $color = if ($check.Status) { "Green" } else { "Red" }
    Write-Host "  $icon $($check.Name)" -ForegroundColor $color
}

$allPassed = ($checks | Where-Object { -not $_.Status }).Count -eq 0
if ($allPassed) {
    Write-Host "`n✓ All validation checks passed!" -ForegroundColor Green
} else {
    Write-Host "`n⚠ Some checks failed - review above" -ForegroundColor Yellow
}
'@
                    }
                    Optional = $false
                    Description = 'Validate organization setup'
                }
            )
        }
        
        @{
            Name = 'Summary'
            Description = 'Display setup summary and next steps'
            ContinueOnError = $true
            Scripts = @(
                @{
                    Path = 'Invoke-Expression'
                    Parameters = @{
                        Command = @'
Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Aitherium Organization Setup Complete!                    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Organization Infrastructure Ready:" -ForegroundColor Green
Write-Host "  • Certificate Authority configured (Windows)" -ForegroundColor White
Write-Host "  • Master signing and encryption keys generated" -ForegroundColor White
Write-Host "  • License storage configured" -ForegroundColor White
Write-Host "  • GitHub integration enabled" -ForegroundColor White

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Deploy master license to GitHub:" -ForegroundColor White
Write-Host "   ./automation-scripts/0804_Deploy-LicenseToGitHub.ps1 \" -ForegroundColor Gray
Write-Host "       -LicensePath ~/.aitherzero/licenses/AITHERIUM-MASTER-001.json" -ForegroundColor Gray

Write-Host "`n2. Generate client licenses:" -ForegroundColor White
Write-Host "   ./automation-scripts/0800_Manage-License.ps1 -Action Create \" -ForegroundColor Gray
Write-Host "       -LicenseId 'CLIENT-001' -LicensedTo 'Customer Name' \" -ForegroundColor Gray
Write-Host "       -GenerateSigningKey" -ForegroundColor Gray

Write-Host "`n3. Set up infrastructure deployment:" -ForegroundColor White
Write-Host "   # Install OpenTofu for infrastructure as code" -ForegroundColor Gray
Write-Host "   ./automation-scripts/02XX_Install-OpenTofu.ps1" -ForegroundColor Gray

Write-Host "`n4. Configure source code obfuscation:" -ForegroundColor White
Write-Host "   # Edit .obfuscate-patterns to specify files to protect" -ForegroundColor Gray
Write-Host "   git config core.hooksPath .githooks" -ForegroundColor Gray

Write-Host "`nDocumentation: docs/LICENSING-OBFUSCATION-SYSTEM.md" -ForegroundColor Cyan
Write-Host ""
'@
                    }
                    Optional = $false
                }
            )
        }
    )
    
    # Post-execution hooks
    OnComplete = @{
        Success = @{
            Message = 'Aitherium organization setup completed successfully!'
            LogPath = '~/.aitherzero/logs/org-setup-$(Get-Date -Format "yyyyMMdd-HHmmss").log'
        }
        Failure = @{
            Message = 'Organization setup failed - check logs for details'
            LogPath = '~/.aitherzero/logs/org-setup-$(Get-Date -Format "yyyyMMdd-HHmmss")-FAILED.log'
        }
    }
}
