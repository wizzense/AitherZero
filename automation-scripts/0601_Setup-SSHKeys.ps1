#Requires -Version 7.0

<#
.SYNOPSIS
    Setup SSH keys for remote connections
.DESCRIPTION
    Creates SSH key pairs for secure remote connections to infrastructure hosts.
    Part of AitherZero Infrastructure Automation Platform.
.PARAMETER KeyName
    Name for the SSH key pair (default: aitherzero-default)
.PARAMETER KeyType
    Type of SSH key to generate (ed25519, rsa, ecdsa)
.PARAMETER Force
    Overwrite existing key if it exists
.PARAMETER Configuration
    Configuration object containing settings
.EXAMPLE
    ./0601_Setup-SSHKeys.ps1 -KeyName "prod-deploy" -KeyType "ed25519"
.NOTES
    Copyright © 2025 Aitherium Corporation
    Script Range: 0600-0699 (Security and Credentials)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$KeyName = "aitherzero-default",
    
    [ValidateSet('ed25519', 'rsa', 'ecdsa')]
    [string]$KeyType = "ed25519",
    
    [switch]$Force,
    
    [hashtable]$Configuration = @{}
)

# Import required functions
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Write-CustomLog {
        param([string]$Level = 'Information', [string]$Message, [string]$Source = 'Script', [hashtable]$Data = @{})
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] [$Source] $Message"
    }
}

# Get configuration values
$config = if ($Configuration.Count -gt 0) { $Configuration } else { @{} }
$sshConfig = if ($config.Security -and $config.Security.SSH) { $config.Security.SSH } else { @{} }

# Default values from configuration or fallback
$defaultKeyType = if ($sshConfig.DefaultKeyType) { $sshConfig.DefaultKeyType } else { $KeyType }
$keyComment = "$env:USERNAME@$(hostname) - AitherZero $(Get-Date -Format 'yyyy-MM-dd')"

try {
    Write-CustomLog -Message "Starting SSH key setup" -Data @{
        KeyName = $KeyName
        KeyType = $defaultKeyType
        Force = $Force.IsPresent
    }
    
    # Check if Security module is available
    if (-not (Get-Command New-SSHKeyPair -ErrorAction SilentlyContinue)) {
        Write-CustomLog -Level Warning -Message "Security module not loaded, attempting to import"
        
        $securityModulePath = Join-Path $PSScriptRoot "../domains/security/Security.psm1"
        if (Test-Path $securityModulePath) {
            Import-Module $securityModulePath -Force
        } else {
            throw "Security module not found. Please ensure AitherZero is properly initialized."
        }
    }
    
    # Check SSH availability
    if (-not (Test-SSHAvailability)) {
        throw "SSH client tools are not available on this system. Please install OpenSSH client."
    }
    
    # Check if key already exists
    $existingKey = Get-SSHKey -KeyName $KeyName
    if ($existingKey -and -not $Force) {
        Write-CustomLog -Level Warning -Message "SSH key '$KeyName' already exists. Use -Force to overwrite or choose a different name."
        
        Write-Host ""
        Write-Host "Existing key details:" -ForegroundColor Cyan
        Write-Host "  Name: $($existingKey.KeyName)" -ForegroundColor White
        Write-Host "  Type: $($existingKey.KeyType)" -ForegroundColor White
        Write-Host "  Fingerprint: $($existingKey.Fingerprint)" -ForegroundColor White
        Write-Host "  Comment: $($existingKey.Comment)" -ForegroundColor White
        Write-Host ""
        
        return @{
            Success = $false
            Message = "Key already exists"
            ExistingKey = $existingKey
        }
    }
    
    # Generate new SSH key pair
    Write-CustomLog -Message "Generating SSH key pair" -Data @{
        KeyName = $KeyName
        KeyType = $defaultKeyType
        Comment = $keyComment
    }
    
    $keyResult = New-SSHKeyPair -KeyName $KeyName -KeyType $defaultKeyType -Comment $keyComment -Force:$Force
    
    if ($keyResult) {
        Write-CustomLog -Message "SSH key pair generated successfully" -Data @{
            KeyName = $keyResult.KeyName
            KeyType = $keyResult.KeyType
            PrivateKeyPath = $keyResult.PrivateKeyPath
            PublicKeyPath = $keyResult.PublicKeyPath
        }
        
        # Display key information
        Write-Host ""
        Write-Host "SSH Key Generated Successfully!" -ForegroundColor Green
        Write-Host "================================" -ForegroundColor Green
        Write-Host "Key Name: $($keyResult.KeyName)" -ForegroundColor White
        Write-Host "Key Type: $($keyResult.KeyType)" -ForegroundColor White
        Write-Host "Private Key: $($keyResult.PrivateKeyPath)" -ForegroundColor Yellow
        Write-Host "Public Key: $($keyResult.PublicKeyPath)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Public Key Content (for remote servers):" -ForegroundColor Cyan
        Write-Host $keyResult.PublicKey -ForegroundColor Gray
        Write-Host ""
        
        # Show next steps
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Copy the public key to your remote servers:" -ForegroundColor White
        Write-Host "   ssh-copy-id -i $($keyResult.PublicKeyPath) user@remote-server" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Or manually append to ~/.ssh/authorized_keys on remote servers" -ForegroundColor White
        Write-Host ""
        Write-Host "3. Create connection profiles using New-ConnectionProfile" -ForegroundColor White
        Write-Host ""
        
        return @{
            Success = $true
            Message = "SSH key pair generated successfully"
            Key = $keyResult
        }
    } else {
        throw "Failed to generate SSH key pair"
    }
}
catch {
    Write-CustomLog -Level Error -Message "SSH key setup failed: $_"
    
    Write-Host ""
    Write-Host "SSH Key Setup Failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    
    return @{
        Success = $false
        Message = "SSH key setup failed: $_"
        Error = $_
    }
}