#Requires -Version 7.0

<#
.SYNOPSIS
    Manage SSH connection profiles for remote hosts
.DESCRIPTION
    Create, list, and manage SSH connection profiles for infrastructure hosts.
    Part of AitherZero Infrastructure Automation Platform.
.PARAMETER Action
    Action to perform (create, list, remove, test)
.PARAMETER ProfileName
    Name of the connection profile
.PARAMETER Hostname
    Target hostname or IP address
.PARAMETER Username
    SSH username for the connection
.PARAMETER Port
    SSH port (default: 22)
.PARAMETER SSHKeyName
    Name of SSH key to use for authentication
.PARAMETER Description
    Optional description for the profile
.PARAMETER Configuration
    Configuration object containing settings
.EXAMPLE
    ./0602_Manage-ConnectionProfiles.ps1 -Action create -ProfileName "web-server-01" -Hostname "192.168.1.10" -Username "admin" -SSHKeyName "aitherzero-default"
.EXAMPLE
    ./0602_Manage-ConnectionProfiles.ps1 -Action list
.EXAMPLE
    ./0602_Manage-ConnectionProfiles.ps1 -Action test -ProfileName "web-server-01"
.NOTES
    Copyright © 2025 Aitherium Corporation
    Script Range: 0600-0699 (Security and Credentials)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('create', 'list', 'remove', 'test')]
    [string]$Action = 'list',
    
    [string]$ProfileName,
    
    [string]$Hostname,
    
    [string]$Username,
    
    [int]$Port = 22,
    
    [string]$SSHKeyName,
    
    [string]$Description = '',
    
    [hashtable]$Configuration = @{}
)

# Import required functions
function Write-ScriptLog {
    param([string]$Level = 'Information', [string]$Message, [string]$Source = 'Script', [hashtable]$Data = @{})
    
    if (Get-Command Write-ScriptLog -ErrorAction SilentlyContinue) {
        Write-ScriptLog -Level $Level -Message $Message -Source $Source -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] [$Source] $Message"
    }
}

# Get configuration values
$config = if ($Configuration.Count -gt 0) { $Configuration } else { @{} }

try {
    Write-ScriptLog -Message "Starting connection profile management" -Data @{
        Action = $Action
        ProfileName = $ProfileName
    }
    
    # Check if Security module is available
    if (-not (Get-Command New-ConnectionProfile -ErrorAction SilentlyContinue)) {
        Write-ScriptLog -Level Warning -Message "Security module not loaded, attempting to import"
        
        $securityModulePath = Join-Path $PSScriptRoot "../domains/security/Security.psm1"
        if (Test-Path $securityModulePath) {
            Import-Module $securityModulePath -Force
        } else {
            throw "Security module not found. Please ensure AitherZero is properly initialized."
        }
    }
    
    switch ($Action) {
        'create' {
            if (-not $ProfileName -or -not $Hostname) {
                throw "ProfileName and Hostname are required for creating profiles"
            }
            
            Write-ScriptLog -Message "Creating connection profile" -Data @{
                ProfileName = $ProfileName
                Hostname = $Hostname
                Username = $Username
                Port = $Port
                SSHKeyName = $SSHKeyName
            }
            
            $profileParams = @{
                ProfileName = $ProfileName
                Hostname = $Hostname
                Port = $Port
                Description = if ($Description) { $Description } else { "Created on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" }
            }
            
            if ($Username) { $profileParams.Username = $Username }
            if ($SSHKeyName) { $profileParams.SSHKeyName = $SSHKeyName }
            
            $profile = New-ConnectionProfile @profileParams
            
            if ($profile) {
                Write-Host ""
                Write-Host "Connection Profile Created Successfully!" -ForegroundColor Green
                Write-Host "=======================================" -ForegroundColor Green
                Write-Host "Profile Name: $($profile.ProfileName)" -ForegroundColor White
                Write-Host "Hostname: $($profile.Hostname)" -ForegroundColor White
                Write-Host "Username: $($profile.Username)" -ForegroundColor White
                Write-Host "Port: $($profile.Port)" -ForegroundColor White
                Write-Host "SSH Key: $($profile.SSHKeyName)" -ForegroundColor White
                Write-Host "Description: $($profile.Description)" -ForegroundColor White
                Write-Host ""
                
                return @{
                    Success = $true
                    Message = "Profile created successfully"
                    Profile = $profile
                }
            }
        }
        
        'list' {
            Write-ScriptLog -Message "Listing connection profiles"
            
            $profiles = Get-ConnectionProfile -ListAll
            
            if ($profiles -and $profiles.Count -gt 0) {
                Write-Host ""
                Write-Host "Connection Profiles:" -ForegroundColor Cyan
                Write-Host "===================" -ForegroundColor Cyan
                Write-Host ""
                
                foreach ($profile in $profiles) {
                    Write-Host "Profile: $($profile.ProfileName)" -ForegroundColor Yellow
                    Write-Host "  Hostname: $($profile.Hostname)" -ForegroundColor White
                    Write-Host "  Username: $($profile.Username)" -ForegroundColor White
                    Write-Host "  Port: $($profile.Port)" -ForegroundColor White
                    Write-Host "  SSH Key: $($profile.SSHKeyName)" -ForegroundColor White
                    Write-Host "  Description: $($profile.Description)" -ForegroundColor Gray
                    if ($profile.LastUsed) {
                        Write-Host "  Last Used: $($profile.LastUsed)" -ForegroundColor Gray
                    }
                    Write-Host ""
                }
                
                Write-Host "Total profiles: $($profiles.Count)" -ForegroundColor Cyan
                Write-Host ""
                
                return @{
                    Success = $true
                    Message = "Listed $($profiles.Count) profiles"
                    Profiles = $profiles
                }
            } else {
                Write-Host ""
                Write-Host "No connection profiles found." -ForegroundColor Yellow
                Write-Host "Use the 'create' action to add profiles." -ForegroundColor Gray
                Write-Host ""
                
                return @{
                    Success = $true
                    Message = "No profiles found"
                    Profiles = @()
                }
            }
        }
        
        'remove' {
            if (-not $ProfileName) {
                throw "ProfileName is required for removing profiles"
            }
            
            Write-ScriptLog -Message "Removing connection profile" -Data @{ ProfileName = $ProfileName }
            
            $result = Remove-ConnectionProfile -ProfileName $ProfileName -Confirm:$false
            
            if ($result) {
                Write-Host ""
                Write-Host "Connection Profile Removed Successfully!" -ForegroundColor Green
                Write-Host "Profile '$ProfileName' has been deleted." -ForegroundColor White
                Write-Host ""
                
                return @{
                    Success = $true
                    Message = "Profile removed successfully"
                    ProfileName = $ProfileName
                }
            } else {
                Write-Host ""
                Write-Host "Profile '$ProfileName' not found." -ForegroundColor Yellow
                Write-Host ""
                
                return @{
                    Success = $false
                    Message = "Profile not found"
                    ProfileName = $ProfileName
                }
            }
        }
        
        'test' {
            if (-not $ProfileName) {
                throw "ProfileName is required for testing connections"
            }
            
            Write-ScriptLog -Message "Testing connection profile" -Data @{ ProfileName = $ProfileName }
            
            # Get profile details first
            $profile = Get-ConnectionProfile -ProfileName $ProfileName
            if (-not $profile) {
                throw "Profile '$ProfileName' not found"
            }
            
            Write-Host ""
            Write-Host "Testing Connection Profile: $ProfileName" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host "Hostname: $($profile.Hostname)" -ForegroundColor White
            Write-Host "Username: $($profile.Username)" -ForegroundColor White
            Write-Host "Port: $($profile.Port)" -ForegroundColor White
            Write-Host ""
            Write-Host "Testing connection..." -ForegroundColor Yellow
            
            $testResult = Test-SSHConnection -ProfileName $ProfileName -TimeoutSeconds 10
            
            if ($testResult) {
                Write-Host "✓ Connection successful!" -ForegroundColor Green
                Write-Host ""
                
                return @{
                    Success = $true
                    Message = "Connection test successful"
                    Profile = $profile
                }
            } else {
                Write-Host "✗ Connection failed!" -ForegroundColor Red
                Write-Host "Check hostname, credentials, and network connectivity." -ForegroundColor Gray
                Write-Host ""
                
                return @{
                    Success = $false
                    Message = "Connection test failed"
                    Profile = $profile
                }
            }
        }
    }
}
catch {
    Write-ScriptLog -Level Error -Message "Connection profile management failed: $_"
    
    Write-Host ""
    Write-Host "Connection Profile Management Failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    
    return @{
        Success = $false
        Message = "Operation failed: $_"
        Error = $_
    }
}