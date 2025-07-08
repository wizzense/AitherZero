function New-TemplateRepository {
    <#
    .SYNOPSIS
        Creates a new template repository structure.

    .DESCRIPTION
        Creates a new Git repository with the standard structure for infrastructure templates,
        including README, example configurations, and metadata files.

    .PARAMETER Name
        Name of the template repository.

    .PARAMETER Path
        Local path where the repository should be created.

    .PARAMETER Description
        Description of the template repository.

    .PARAMETER Provider
        Target infrastructure provider (Hyper-V, Azure, AWS, VMware).

    .PARAMETER TemplateType
        Type of templates (Lab, Production, Development, Testing).

    .PARAMETER InitializeGit
        Initialize as a Git repository.

    .PARAMETER AddExamples
        Include example templates.

    .EXAMPLE
        New-TemplateRepository -Name "hyperv-lab-templates" -Path "C:\Repos" -Provider "Hyper-V" -TemplateType "Lab" -InitializeGit

    .OUTPUTS
        PSCustomObject with repository creation details
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z0-9-_]+$')]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$Description = "Infrastructure as Code template repository",

        [Parameter()]
        [ValidateSet('Hyper-V', 'Azure', 'AWS', 'VMware', 'Generic')]
        [string]$Provider = 'Generic',

        [Parameter()]
        [ValidateSet('Lab', 'Production', 'Development', 'Testing', 'Mixed')]
        [string]$TemplateType = 'Mixed',

        [Parameter()]
        [switch]$InitializeGit,

        [Parameter()]
        [switch]$AddExamples
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating template repository: $Name"
        $repoPath = Join-Path $Path $Name
    }

    process {
        try {
            # Check if path already exists
            if (Test-Path $repoPath) {
                throw "Repository path already exists: $repoPath"
            }

            if ($PSCmdlet.ShouldProcess($repoPath, "Create template repository")) {
                # Create repository structure
                Write-CustomLog -Level 'INFO' -Message "Creating repository structure at: $repoPath"

                # Create directories
                $directories = @(
                    $repoPath
                    (Join-Path $repoPath "templates")
                    (Join-Path $repoPath "modules")
                    (Join-Path $repoPath "scripts")
                    (Join-Path $repoPath "docs")
                    (Join-Path $repoPath "tests")
                    (Join-Path $repoPath ".github")
                    (Join-Path $repoPath ".github" "workflows")
                )

                foreach ($dir in $directories) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }

                # Create repository metadata
                $metadata = @{
                    name = $Name
                    description = $Description
                    version = "1.0.0"
                    provider = $Provider
                    templateType = $TemplateType
                    created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
                    schema_version = "1.0"
                    compatibility = @{
                        opentofu = ">=1.6.0"
                        terraform = ">=1.5.0"
                        powershell = ">=7.0"
                    }
                }

                $metadataPath = Join-Path $repoPath "repository.json"
                $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath -Encoding UTF8

                # Create README
                $readmeContent = @"
# $Name

$Description

## Overview

This repository contains infrastructure as code templates for **$Provider** targeting **$TemplateType** environments.

## Structure

\`\`\`
$Name/
├── templates/          # Infrastructure templates
├── modules/           # Reusable infrastructure modules
├── scripts/           # Helper scripts
├── docs/              # Documentation
├── tests/             # Template tests
└── repository.json    # Repository metadata
\`\`\`

## Requirements

- OpenTofu >= 1.6.0 or Terraform >= 1.5.0
- PowerShell >= 7.0
- AitherZero OpenTofuProvider module

## Usage

1. Register this repository with AitherZero:
   \`\`\`powershell
   Register-InfrastructureRepository -Name "$Name" -RepositoryUrl "file://$repoPath"
   \`\`\`

2. List available templates:
   \`\`\`powershell
   Get-InfrastructureTemplate -Repository "$Name"
   \`\`\`

3. Deploy a template:
   \`\`\`powershell
   Start-InfrastructureDeployment -Template "template-name" -Repository "$Name"
   \`\`\`

## Templates

$(if ($AddExamples) { "See the `templates/` directory for example templates." } else { "Add your infrastructure templates to the `templates/` directory." })

## Contributing

1. Create feature branch
2. Add/modify templates
3. Update documentation
4. Submit pull request

## License

[Your License Here]

---
*Generated by AitherZero Infrastructure Automation*
"@

                Set-Content -Path (Join-Path $repoPath "README.md") -Value $readmeContent -Encoding UTF8

                # Create .gitignore
                $gitignoreContent = @"
# Terraform/OpenTofu
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.tfvars
!example.tfvars

# AitherZero
.aitherzero/
*.log
.cache/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Secrets
*.pem
*.key
secrets/
credentials/
"@

                Set-Content -Path (Join-Path $repoPath ".gitignore") -Value $gitignoreContent -Encoding UTF8

                # Add example templates if requested
                if ($AddExamples) {
                    Write-CustomLog -Level 'INFO' -Message "Adding example templates"

                    # Create example template directory
                    $examplePath = Join-Path $repoPath "templates" "example-vm"
                    New-Item -ItemType Directory -Path $examplePath -Force | Out-Null

                    # Create template.yaml
                    $templateYaml = @"
name: example-vm
version: 1.0.0
description: Example virtual machine template
provider: $Provider
type: $TemplateType
author: AitherZero
tags:
  - example
  - vm
  - basic

parameters:
  vm_name:
    type: string
    description: Name of the virtual machine
    default: example-vm

  vm_memory:
    type: number
    description: Memory in MB
    default: 4096

  vm_cpus:
    type: number
    description: Number of CPUs
    default: 2

resources:
  - type: virtual_machine
    name: main_vm
    properties:
      name: "{{ vm_name }}"
      memory_mb: "{{ vm_memory }}"
      cpu_count: "{{ vm_cpus }}"
      os_type: windows
      generation: 2

outputs:
  vm_id:
    description: ID of the created VM
    value: "{{ resources.main_vm.id }}"
"@

                    Set-Content -Path (Join-Path $examplePath "template.yaml") -Value $templateYaml -Encoding UTF8

                    # Create main.tf
                    $mainTf = @"
# Example VM Template
# Generated by AitherZero

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "example-vm"
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "vm_cpus" {
  description = "Number of CPUs"
  type        = number
  default     = 2
}

# Provider-specific resources would go here
# This is a placeholder for the actual implementation
"@

                    Set-Content -Path (Join-Path $examplePath "main.tf") -Value $mainTf -Encoding UTF8
                }

                # Initialize Git repository if requested
                if ($InitializeGit) {
                    Write-CustomLog -Level 'INFO' -Message "Initializing Git repository"

                    Push-Location $repoPath
                    try {
                        git init --initial-branch=main 2>&1 | Out-Null
                        git add . 2>&1 | Out-Null
                        git commit -m "Initial commit: Template repository structure" 2>&1 | Out-Null
                        Write-CustomLog -Level 'SUCCESS' -Message "Git repository initialized"
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Failed to initialize Git repository: $_"
                    } finally {
                        Pop-Location
                    }
                }

                # Create result object
                $result = [PSCustomObject]@{
                    Name = $Name
                    Path = $repoPath
                    Provider = $Provider
                    TemplateType = $TemplateType
                    Description = $Description
                    GitInitialized = $InitializeGit
                    ExamplesAdded = $AddExamples
                    CreatedAt = (Get-Date).ToUniversalTime()
                    Structure = @{
                        Directories = $directories.Count
                        Files = (Get-ChildItem -Path $repoPath -File -Recurse).Count
                    }
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Template repository created successfully"
                return $result
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create template repository: $_"
            throw
        }
    }

    end {
        if (Test-Path $repoPath) {
            Write-CustomLog -Level 'INFO' -Message "Template repository available at: $repoPath"
        }
    }
}
