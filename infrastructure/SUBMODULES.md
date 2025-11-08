# Infrastructure Submodule System

## Overview

The `infrastructure/` directory is a **stub directory** that serves as a container for infrastructure-as-code repositories managed as **Git submodules**. This design allows you to version-control your infrastructure definitions separately while still integrating them seamlessly with AitherZero.

## Why Submodules?

Using Git submodules for infrastructure provides several benefits:

1. **Separation of Concerns**: Infrastructure code is versioned independently
2. **Reusability**: Share infrastructure templates across multiple projects
3. **Flexibility**: Use different infrastructure repositories for different environments
4. **Version Control**: Pin specific versions of infrastructure templates
5. **Team Collaboration**: Infrastructure teams can work independently

## Default Configuration

By default, AitherZero uses the **Aitherium Infrastructure** repository, which provides:

- Pre-configured templates for mass deployments
- Multi-cloud support (Azure, AWS, GCP, Kubernetes)
- OpenTofu/Terraform configurations
- Container orchestration manifests
- Network and security templates
- Monitoring and observability setups

## Directory Structure

After initialization, the infrastructure directory will contain:

```
infrastructure/
├── SUBMODULES.md           # This file
├── README.md               # Main infrastructure documentation
├── aitherium/              # Default Aitherium infrastructure (submodule)
│   ├── terraform/
│   ├── kubernetes/
│   ├── docker/
│   └── ...
├── custom/                 # Custom infrastructure repo (optional submodule)
└── kubernetes/             # K8s-specific infrastructure (optional submodule)
```

## Configuration

Infrastructure submodules are configured in `config.psd1` under the `Infrastructure.Submodules` section:

```powershell
Infrastructure = @{
    Submodules = @{
        Enabled    = $true
        AutoInit   = $true
        AutoUpdate = $false
        
        # Default repository (Aitherium Infrastructure)
        Default = @{
            Name        = 'aitherium-infrastructure'
            Url         = 'https://github.com/Aitherium/aitherium-infrastructure.git'
            Path        = 'infrastructure/aitherium'
            Branch      = 'main'
            Description = 'Default Aitherium infrastructure templates'
            Enabled     = $true
        }
        
        # Additional repositories
        Repositories = @{
            'custom-infra' = @{
                Url     = 'https://github.com/YourOrg/custom-infra.git'
                Path    = 'infrastructure/custom'
                Branch  = 'main'
                Enabled = $true
            }
        }
    }
}
```

### Local Overrides

For environment-specific configurations, create `config.local.psd1`:

```powershell
@{
    Infrastructure = @{
        Submodules = @{
            # Override default repository for development
            Default = @{
                Url    = 'https://github.com/YourOrg/dev-infrastructure.git'
                Branch = 'develop'
            }
            
            # Add development-specific repositories
            Repositories = @{
                'dev-k8s' = @{
                    Url     = 'https://github.com/YourOrg/dev-k8s.git'
                    Path    = 'infrastructure/dev-k8s'
                    Enabled = $true
                }
            }
        }
    }
}
```

## Automation Commands

AitherZero provides PowerShell cmdlets for managing infrastructure submodules:

### Initialize Submodules

```powershell
# Initialize all enabled submodules from config
Initialize-InfrastructureSubmodule

# Initialize specific submodule
Initialize-InfrastructureSubmodule -Name 'custom-infra'

# Initialize with custom URL
Initialize-InfrastructureSubmodule -Name 'my-infra' -Url 'https://github.com/me/infra.git' -Path 'infrastructure/my-infra'
```

### Update Submodules

```powershell
# Update all submodules to latest commits
Update-InfrastructureSubmodules

# Update specific submodule
Update-InfrastructureSubmodules -Name 'aitherium-infrastructure'

# Update and merge (instead of checkout)
Update-InfrastructureSubmodules -Merge
```

### List Submodules

```powershell
# List all configured submodules
Get-InfrastructureSubmodules

# Show only initialized submodules
Get-InfrastructureSubmodules -Initialized

# Show detailed status
Get-InfrastructureSubmodules -Detailed
```

### Sync Configuration

```powershell
# Sync .gitmodules with config.psd1 configuration
Sync-InfrastructureSubmodules

# Preview changes without applying
Sync-InfrastructureSubmodules -WhatIf

# Force sync (remove unmanaged submodules)
Sync-InfrastructureSubmodules -Force
```

### Remove Submodules

```powershell
# Remove a submodule
Remove-InfrastructureSubmodule -Name 'old-infra'

# Remove and clean working directory
Remove-InfrastructureSubmodule -Name 'old-infra' -Clean
```

## Automation Script

Use the numbered automation script for initialization:

```bash
# Initialize infrastructure submodules
aitherzero 0109

# Or run directly
./automation-scripts/0109_Initialize-InfrastructureSubmodules.ps1
```

This script:
1. Reads submodule configuration from `config.psd1`
2. Initializes enabled submodules
3. Checks out specified branches
4. Validates submodule integrity
5. Reports initialization status

## Manual Submodule Management

While AitherZero cmdlets are recommended, you can also use Git directly:

```bash
# Add a new submodule manually
git submodule add https://github.com/YourOrg/infra.git infrastructure/custom

# Initialize all submodules
git submodule update --init --recursive

# Update submodules to latest
git submodule update --remote

# Remove a submodule manually
git submodule deinit -f infrastructure/custom
git rm -f infrastructure/custom
rm -rf .git/modules/infrastructure/custom
```

## Best Practices

1. **Pin Versions**: Use specific commits or tags in production
2. **Test First**: Always test infrastructure changes in dev/staging
3. **Document Changes**: Update infrastructure documentation when modifying
4. **Review Carefully**: Infrastructure changes can have wide impact
5. **Backup State**: Keep infrastructure state files backed up
6. **Use Branches**: Use branches for different environments (dev, staging, prod)
7. **Automate Testing**: Include infrastructure validation in CI/CD

## Workflow Examples

### Development Workflow

```powershell
# 1. Clone AitherZero
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# 2. Bootstrap (automatically initializes submodules if AutoInit = $true)
./bootstrap.ps1 -Mode New

# 3. Or manually initialize submodules
Initialize-InfrastructureSubmodule

# 4. Make infrastructure changes
cd infrastructure/aitherium
# ... edit terraform files ...
git add .
git commit -m "feat: add new VM template"
git push origin main

# 5. Update AitherZero to reference new commit
cd ../..
git add infrastructure/aitherium
git commit -m "chore: update aitherium infrastructure"
git push
```

### Production Deployment

```powershell
# 1. Check out specific infrastructure version
cd infrastructure/aitherium
git checkout v2.1.0  # Use tagged release
cd ../..

# 2. Commit the version pin
git add infrastructure/aitherium
git commit -m "chore: pin aitherium-infrastructure to v2.1.0"

# 3. Deploy infrastructure
Invoke-InfrastructurePlan -WorkingDirectory './infrastructure/aitherium/terraform'
Invoke-InfrastructureApply -WorkingDirectory './infrastructure/aitherium/terraform' -AutoApprove
```

### Multi-Environment Setup

```powershell
# config.local.psd1 for development
@{
    Infrastructure = @{
        Submodules = @{
            Default = @{
                Branch = 'develop'
            }
            Repositories = @{
                'dev-infra' = @{
                    Url     = 'https://github.com/YourOrg/dev-infrastructure.git'
                    Path    = 'infrastructure/dev'
                    Enabled = $true
                }
            }
        }
    }
}

# Initialize development environment
Initialize-InfrastructureSubmodule
```

## Troubleshooting

### Submodule Not Initializing

```powershell
# Check configuration
Get-InfrastructureSubmodules

# Force re-initialization
Remove-InfrastructureSubmodule -Name 'problem-submodule' -Clean
Initialize-InfrastructureSubmodule -Name 'problem-submodule'
```

### Authentication Issues

```bash
# Use SSH instead of HTTPS
git config --global url."git@github.com:".insteadOf "https://github.com/"

# Or configure credentials
git config --global credential.helper store
```

### Submodule Out of Sync

```powershell
# Sync configuration with actual submodules
Sync-InfrastructureSubmodules

# Or update to latest
Update-InfrastructureSubmodules
```

### Detached HEAD State

```bash
cd infrastructure/aitherium
git checkout main  # or your target branch
git pull origin main
cd ../..
git add infrastructure/aitherium
git commit -m "chore: update submodule to latest main"
```

## Security Considerations

1. **Access Control**: Ensure team members have appropriate access to submodule repositories
2. **Secret Management**: Never commit secrets to infrastructure repos
3. **Branch Protection**: Protect main branches in infrastructure repositories
4. **Code Review**: Require reviews for infrastructure changes
5. **Audit Logging**: Track who makes infrastructure changes and when
6. **Signature Verification**: Consider enabling GPG signature verification for submodule commits

## Migration Guide

### From Monolithic to Submodules

If you have existing infrastructure in the repository:

```bash
# 1. Create new infrastructure repository
cd /tmp
git init my-infrastructure
cp -r /path/to/AitherZero/infrastructure/* my-infrastructure/
cd my-infrastructure
git add .
git commit -m "Initial infrastructure extraction"
git remote add origin https://github.com/YourOrg/my-infrastructure.git
git push -u origin main

# 2. Remove old infrastructure from AitherZero
cd /path/to/AitherZero
git rm -r infrastructure/*  # Careful! Backup first!
git commit -m "chore: prepare for infrastructure submodules"

# 3. Add as submodule
git submodule add https://github.com/YourOrg/my-infrastructure.git infrastructure/my-infra
git commit -m "chore: add infrastructure as submodule"

# 4. Update config.psd1
# Add submodule configuration as shown above

# 5. Verify
Initialize-InfrastructureSubmodule
Get-InfrastructureSubmodules
```

## Additional Resources

- [Git Submodules Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [AitherZero Infrastructure Module](../aithercore/infrastructure/README.md)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [Aitherium Infrastructure Repository](https://github.com/Aitherium/aitherium-infrastructure)

## Support

For issues or questions:

1. Check this documentation
2. Review [Infrastructure module README](../aithercore/infrastructure/README.md)
3. Open an issue on GitHub
4. Contact the AitherZero team

---

**Last Updated**: 2025-11-08  
**Maintainers**: AitherZero Team  
**Version**: 2.0.0
