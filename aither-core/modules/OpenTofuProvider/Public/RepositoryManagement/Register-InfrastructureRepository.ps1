function Register-InfrastructureRepository {
    <#
    .SYNOPSIS
        Registers a remote infrastructure repository for use with deployments.
    
    .DESCRIPTION
        Registers and optionally clones a remote Git repository containing OpenTofu/Terraform
        infrastructure code. Supports authentication, caching, and offline capabilities.
    
    .PARAMETER RepositoryUrl
        The Git URL of the infrastructure repository (HTTPS or SSH).
    
    .PARAMETER Name
        A friendly name for the repository reference.
    
    .PARAMETER Branch
        The branch to track (default: main).
    
    .PARAMETER CacheTTL
        Cache time-to-live in seconds (default: 86400 - 24 hours).
    
    .PARAMETER CredentialName
        Name of stored credential for private repositories.
    
    .PARAMETER AutoSync
        Automatically sync on registration.
    
    .PARAMETER Tags
        Tags for categorizing repositories.
    
    .EXAMPLE
        Register-InfrastructureRepository -RepositoryUrl "https://github.com/org/hyperv-templates" -Name "hyperv-prod" -Branch "main" -AutoSync
    
    .OUTPUTS
        PSCustomObject with repository details
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialName', Justification = 'CredentialName is an identifier string, not sensitive credential data')]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^(https?://|git@).*')]
        [string]$RepositoryUrl,
        
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z0-9-_]+$')]
        [string]$Name,
        
        [Parameter()]
        [string]$Branch = "main",
        
        [Parameter()]
        [ValidateRange(300, 604800)]
        [int]$CacheTTL = 86400,
        
        [Parameter()]
        [string]$CredentialName,
        
        [Parameter()]
        [switch]$AutoSync,
        
        [Parameter()]
        [string[]]$Tags
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Registering infrastructure repository: $Name"
        $repoConfig = Get-RepositoryConfiguration
        $repoPath = Join-Path $repoConfig.BasePath $Name
    }
    
    process {
        try {
            # Check if repository already registered
            if ($repoConfig.Repositories.ContainsKey($Name)) {
                if ($PSCmdlet.ShouldProcess($Name, "Update existing repository registration")) {
                    Write-CustomLog -Level 'WARNING' -Message "Repository '$Name' already registered, updating configuration"
                } else {
                    return
                }
            }
            
            # Validate repository URL accessibility
            $isAccessible = Test-RepositoryAccess -Url $RepositoryUrl -CredentialName $CredentialName
            if (-not $isAccessible) {
                throw "Unable to access repository at $RepositoryUrl"
            }
            
            # Create repository entry
            $repoEntry = @{
                Name = $Name
                Url = $RepositoryUrl
                Branch = $Branch
                CacheTTL = $CacheTTL
                LocalPath = $repoPath
                Tags = $Tags
                RegisteredAt = (Get-Date).ToUniversalTime()
                LastSync = $null
                Status = 'Registered'
            }
            
            if ($CredentialName) {
                $repoEntry.CredentialName = $CredentialName
            }
            
            # Clone repository if AutoSync
            if ($AutoSync) {
                if ($PSCmdlet.ShouldProcess($Name, "Clone repository")) {
                    Write-CustomLog -Level 'INFO' -Message "Cloning repository to: $repoPath"
                    
                    # Ensure parent directory exists
                    $parentPath = Split-Path $repoPath -Parent
                    if (-not (Test-Path $parentPath)) {
                        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
                    }
                    
                    # Clone repository
                    $cloneResult = Invoke-GitClone -Url $RepositoryUrl -Path $repoPath -Branch $Branch -CredentialName $CredentialName
                    
                    if ($cloneResult.Success) {
                        $repoEntry.LastSync = (Get-Date).ToUniversalTime()
                        $repoEntry.Status = 'Synced'
                        Write-CustomLog -Level 'SUCCESS' -Message "Repository cloned successfully"
                    } else {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to clone repository: $($cloneResult.Error)"
                        $repoEntry.Status = 'CloneFailed'
                    }
                }
            }
            
            # Save repository configuration
            $repoConfig.Repositories[$Name] = $repoEntry
            Save-RepositoryConfiguration -Configuration $repoConfig
            
            # Validate repository structure if cloned
            if ($repoEntry.Status -eq 'Synced') {
                $validationResult = Test-RepositoryStructure -Path $repoPath
                if ($validationResult.IsValid) {
                    Write-CustomLog -Level 'INFO' -Message "Repository structure validated successfully"
                    $repoEntry.Metadata = $validationResult.Metadata
                } else {
                    Write-CustomLog -Level 'WARNING' -Message "Repository structure validation warnings: $($validationResult.Warnings -join ', ')"
                }
            }
            
            # Return repository object
            [PSCustomObject]@{
                Name = $repoEntry.Name
                Url = $repoEntry.Url
                Branch = $repoEntry.Branch
                LocalPath = $repoEntry.LocalPath
                Status = $repoEntry.Status
                LastSync = $repoEntry.LastSync
                CacheTTL = $repoEntry.CacheTTL
                Tags = $repoEntry.Tags
                RegisteredAt = $repoEntry.RegisteredAt
                Metadata = $repoEntry.Metadata
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to register repository: $_"
            throw
        }
    }
    
    end {
        if ($repoEntry.Status -eq 'Synced') {
            Write-CustomLog -Level 'SUCCESS' -Message "Repository '$Name' registered and synced successfully"
        } else {
            Write-CustomLog -Level 'SUCCESS' -Message "Repository '$Name' registered successfully (not synced)"
        }
    }
}