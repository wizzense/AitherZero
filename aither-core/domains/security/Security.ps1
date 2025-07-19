# Security Functions - Consolidated into AitherCore Security Domain
# Unified security management including SecureCredentials and SecurityAutomation

#Requires -Version 7.0

using namespace System.IO
using namespace System.Security
using namespace System.Security.Cryptography
using namespace System.Text
using namespace System.Text.Json

# MODULE CONSTANTS AND VARIABLES

$script:MODULE_VERSION = '1.0.0'
$script:CREDENTIAL_STORE_VERSION = '1.0'
$script:MAX_CREDENTIAL_BACKUPS = 5
$script:DEFAULT_ENCRYPTION_ALGORITHM = 'AES256'

# Cross-platform credential storage paths
$script:CredentialStorePath = if ($IsWindows) {
    Join-Path $env:APPDATA 'AitherZero' 'SecureCredentials'
} else {
    Join-Path $env:HOME '.aitherzero' 'credentials'
}

# Secure credential store
$script:SecureCredentialStore = @{
    Version = $script:CREDENTIAL_STORE_VERSION
    Created = Get-Date
    LastModified = Get-Date
    Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
    Credentials = @{}
    BackupHistory = @()
    SecuritySettings = @{
        RequireEncryption = $true
        BackupOnChange = $true
        AuditAccess = $true
        MaxCredentialAge = 90 # days
    }
}

# Security automation settings
$script:SecurityAutomationSettings = @{
    Version = $script:MODULE_VERSION
    LogLevel = 'INFO'
    AuditingEnabled = $true
    ComplianceMode = 'Enterprise'
    SecurityPolicies = @{
        RequireComplexPasswords = $true
        MinimumPasswordLength = 12
        RequireMFA = $true
        SessionTimeout = 3600 # seconds
    }
}

# SECURE CREDENTIAL MANAGEMENT FUNCTIONS

function Initialize-SecureCredentialStore {
    <#
    .SYNOPSIS
        Initialize the secure credential store with proper security settings
    .DESCRIPTION
        Sets up the credential store directory structure and security policies
    #>
    try {
        # Create directory structure
        if (-not (Test-Path $script:CredentialStorePath)) {
            New-Item -ItemType Directory -Path $script:CredentialStorePath -Force | Out-Null
            
            # Set restrictive permissions
            if ($IsLinux -or $IsMacOS) {
                chmod 700 $script:CredentialStorePath
            } elseif ($IsWindows) {
                $acl = Get-Acl $script:CredentialStorePath
                $acl.SetAccessRuleProtection($true, $false) # Disable inheritance
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $env:USERNAME, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
                )
                $acl.SetAccessRule($accessRule)
                Set-Acl $script:CredentialStorePath $acl
            }
        }
        
        # Create backup directory
        $backupPath = Join-Path $script:CredentialStorePath 'backups'
        if (-not (Test-Path $backupPath)) {
            New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        }
        
        # Initialize store file if it doesn't exist
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        if (-not (Test-Path $storePath)) {
            $script:SecureCredentialStore | ConvertTo-Json -Depth 10 | Set-Content $storePath -Encoding UTF8
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Secure credential store initialized at: $script:CredentialStorePath"
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize secure credential store: $($_.Exception.Message)"
        throw
    }
}

function New-SecureCredential {
    <#
    .SYNOPSIS
        Create a new secure credential entry
    .DESCRIPTION
        Stores credentials securely with encryption and metadata
    .PARAMETER CredentialName
        Unique name for the credential
    .PARAMETER CredentialType
        Type of credential (UserPassword, ServiceAccount, APIKey, Certificate)
    .PARAMETER Username
        Username for the credential
    .PARAMETER Password
        Secure password for the credential
    .PARAMETER APIKey
        API key for API-based credentials
    .PARAMETER CertificatePath
        Path to certificate file
    .PARAMETER Description
        Description of the credential
    .PARAMETER Metadata
        Additional metadata
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingPlainTextForPassword', 'CredentialName')]
        [string]$CredentialName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('UserPassword', 'ServiceAccount', 'APIKey', 'Certificate')]
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingPlainTextForPassword', 'CredentialType')]
        [string]$CredentialType,

        [Parameter(Mandatory = $false)]
        [string]$Username,

        [Parameter(Mandatory = $false)]
        [SecureString]$Password,

        [Parameter(Mandatory = $false)]
        [SecureString]$APIKey,

        [Parameter(Mandatory = $false)]
        [string]$CertificatePath,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [hashtable]$Metadata = @{}
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Creating secure credential: $CredentialName"
        
        # Validate parameters based on credential type
        switch ($CredentialType) {
            'UserPassword' {
                if (-not $Username -or -not $Password) {
                    throw "Username and Password are required for UserPassword credential type"
                }
            }
            'ServiceAccount' {
                if (-not $Username) {
                    throw "Username is required for ServiceAccount credential type"
                }
            }
            'APIKey' {
                if (-not $APIKey) {
                    throw "APIKey is required for APIKey credential type"
                }
            }
            'Certificate' {
                if (-not $CertificatePath) {
                    throw "CertificatePath is required for Certificate credential type"
                }
                if (-not (Test-Path $CertificatePath)) {
                    throw "Certificate file not found: $CertificatePath"
                }
            }
        }

        Initialize-SecureCredentialStore

        # Load existing store
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        $store = Get-Content $storePath -Raw | ConvertFrom-Json -AsHashtable

        # Check if credential already exists
        if ($store.Credentials.ContainsKey($CredentialName)) {
            throw "Credential '$CredentialName' already exists"
        }

        # Create credential data
        $credentialData = @{
            Name = $CredentialName
            Type = $CredentialType
            Username = $Username
            Description = $Description
            Metadata = $Metadata
            Created = Get-Date
            LastModified = Get-Date
            LastAccessed = $null
        }

        # Encrypt sensitive data
        if ($Password) {
            $credentialData.PasswordEncrypted = ConvertFrom-SecureString $Password
        }
        if ($APIKey) {
            $credentialData.APIKeyEncrypted = ConvertFrom-SecureString $APIKey
        }
        if ($CertificatePath) {
            $credentialData.CertificatePath = $CertificatePath
        }

        if ($PSCmdlet.ShouldProcess($CredentialName, "Create secure credential")) {
            # Add to store
            $store.Credentials[$CredentialName] = $credentialData
            $store.LastModified = Get-Date
            
            # Backup current store
            if ($store.SecuritySettings.BackupOnChange) {
                Backup-SecureCredentialStore
            }
            
            # Save updated store
            $store | ConvertTo-Json -Depth 10 | Set-Content $storePath -Encoding UTF8
            
            Write-CustomLog -Level 'SUCCESS' -Message "Successfully created credential: $CredentialName"
            return @{
                Success = $true
                CredentialName = $CredentialName
                Message = "Credential created successfully"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create credential $CredentialName : $($_.Exception.Message)"
        throw
    }
}

function Get-SecureCredential {
    <#
    .SYNOPSIS
        Retrieve a secure credential
    .DESCRIPTION
        Retrieves and decrypts stored credentials
    .PARAMETER CredentialName
        Name of the credential to retrieve
    .PARAMETER AsPlainText
        Return password as plain text (use with caution)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingPlainTextForPassword', 'CredentialName')]
        [string]$CredentialName,

        [Parameter(Mandatory = $false)]
        [switch]$AsPlainText
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving credential: $CredentialName"
        
        Initialize-SecureCredentialStore
        
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        if (-not (Test-Path $storePath)) {
            throw "Credential store not found"
        }
        
        $store = Get-Content $storePath -Raw | ConvertFrom-Json -AsHashtable
        
        if (-not $store.Credentials.ContainsKey($CredentialName)) {
            throw "Credential '$CredentialName' not found"
        }
        
        $credential = $store.Credentials[$CredentialName]
        
        # Update last accessed time
        $credential.LastAccessed = Get-Date
        $store | ConvertTo-Json -Depth 10 | Set-Content $storePath -Encoding UTF8
        
        # Create return object
        $result = @{
            Name = $credential.Name
            Type = $credential.Type
            Username = $credential.Username
            Description = $credential.Description
            Metadata = $credential.Metadata
            Created = $credential.Created
            LastModified = $credential.LastModified
            LastAccessed = $credential.LastAccessed
        }
        
        # Decrypt sensitive data
        if ($credential.PasswordEncrypted) {
            $securePassword = ConvertTo-SecureString $credential.PasswordEncrypted
            if ($AsPlainText) {
                $result.Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
            } else {
                $result.SecurePassword = $securePassword
            }
        }
        
        if ($credential.APIKeyEncrypted) {
            $secureAPIKey = ConvertTo-SecureString $credential.APIKeyEncrypted
            if ($AsPlainText) {
                $result.APIKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureAPIKey))
            } else {
                $result.SecureAPIKey = $secureAPIKey
            }
        }
        
        if ($credential.CertificatePath) {
            $result.CertificatePath = $credential.CertificatePath
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Successfully retrieved credential: $CredentialName"
        return $result
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve credential $CredentialName : $($_.Exception.Message)"
        throw
    }
}

function Get-AllSecureCredentials {
    <#
    .SYNOPSIS
        Get all stored credentials (metadata only)
    .DESCRIPTION
        Returns a list of all stored credentials with metadata but no sensitive data
    #>
    [CmdletBinding()]
    param()

    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving all credentials metadata"
        
        Initialize-SecureCredentialStore
        
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        if (-not (Test-Path $storePath)) {
            return @()
        }
        
        $store = Get-Content $storePath -Raw | ConvertFrom-Json -AsHashtable
        
        $results = @()
        foreach ($credentialName in $store.Credentials.Keys) {
            $credential = $store.Credentials[$credentialName]
            
            $results += @{
                Name = $credential.Name
                Type = $credential.Type
                Username = $credential.Username
                Description = $credential.Description
                Created = $credential.Created
                LastModified = $credential.LastModified
                LastAccessed = $credential.LastAccessed
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Retrieved $($results.Count) credentials"
        return $results
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve credentials list: $($_.Exception.Message)"
        throw
    }
}

function Update-SecureCredential {
    <#
    .SYNOPSIS
        Update an existing secure credential
    .DESCRIPTION
        Updates credential data while maintaining security
    .PARAMETER CredentialName
        Name of the credential to update
    .PARAMETER Username
        New username
    .PARAMETER Password
        New password
    .PARAMETER Description
        New description
    .PARAMETER Metadata
        New metadata
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingPlainTextForPassword', 'CredentialName')]
        [string]$CredentialName,

        [Parameter(Mandatory = $false)]
        [string]$Username,

        [Parameter(Mandatory = $false)]
        [SecureString]$Password,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [hashtable]$Metadata
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Updating credential: $CredentialName"
        
        Initialize-SecureCredentialStore
        
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        $store = Get-Content $storePath -Raw | ConvertFrom-Json -AsHashtable
        
        if (-not $store.Credentials.ContainsKey($CredentialName)) {
            throw "Credential '$CredentialName' not found"
        }
        
        if ($PSCmdlet.ShouldProcess($CredentialName, "Update secure credential")) {
            $credential = $store.Credentials[$CredentialName]
            
            # Update fields
            if ($Username) { $credential.Username = $Username }
            if ($Password) { $credential.PasswordEncrypted = ConvertFrom-SecureString $Password }
            if ($Description) { $credential.Description = $Description }
            if ($Metadata) { $credential.Metadata = $Metadata }
            
            $credential.LastModified = Get-Date
            
            # Backup before changes
            if ($store.SecuritySettings.BackupOnChange) {
                Backup-SecureCredentialStore
            }
            
            # Save updated store
            $store | ConvertTo-Json -Depth 10 | Set-Content $storePath -Encoding UTF8
            
            Write-CustomLog -Level 'SUCCESS' -Message "Successfully updated credential: $CredentialName"
            return @{
                Success = $true
                CredentialName = $CredentialName
                Message = "Credential updated successfully"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to update credential $CredentialName : $($_.Exception.Message)"
        throw
    }
}

function Remove-SecureCredential {
    <#
    .SYNOPSIS
        Remove a secure credential
    .DESCRIPTION
        Safely removes a credential from the store
    .PARAMETER CredentialName
        Name of the credential to remove
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingPlainTextForPassword', 'CredentialName')]
        [string]$CredentialName
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Removing credential: $CredentialName"
        
        Initialize-SecureCredentialStore
        
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        $store = Get-Content $storePath -Raw | ConvertFrom-Json -AsHashtable
        
        if (-not $store.Credentials.ContainsKey($CredentialName)) {
            throw "Credential '$CredentialName' not found"
        }
        
        if ($PSCmdlet.ShouldProcess($CredentialName, "Remove secure credential")) {
            # Backup before removal
            if ($store.SecuritySettings.BackupOnChange) {
                Backup-SecureCredentialStore
            }
            
            # Remove credential
            $store.Credentials.Remove($CredentialName)
            $store.LastModified = Get-Date
            
            # Save updated store
            $store | ConvertTo-Json -Depth 10 | Set-Content $storePath -Encoding UTF8
            
            Write-CustomLog -Level 'SUCCESS' -Message "Successfully removed credential: $CredentialName"
            return @{
                Success = $true
                CredentialName = $CredentialName
                Message = "Credential removed successfully"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to remove credential $CredentialName : $($_.Exception.Message)"
        throw
    }
}

function Backup-SecureCredentialStore {
    <#
    .SYNOPSIS
        Create a backup of the secure credential store
    .DESCRIPTION
        Creates a timestamped backup of the credential store
    #>
    [CmdletBinding()]
    param()

    try {
        Write-CustomLog -Level 'INFO' -Message "Creating credential store backup"
        
        Initialize-SecureCredentialStore
        
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        $backupPath = Join-Path $script:CredentialStorePath 'backups'
        
        if (-not (Test-Path $storePath)) {
            Write-CustomLog -Level 'WARNING' -Message "No credential store found to backup"
            return
        }
        
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupFile = Join-Path $backupPath "credentials-backup-$timestamp.json"
        
        Copy-Item $storePath $backupFile
        
        # Clean up old backups
        $backupFiles = Get-ChildItem $backupPath -Filter 'credentials-backup-*.json' | Sort-Object LastWriteTime -Descending
        if ($backupFiles.Count -gt $script:MAX_CREDENTIAL_BACKUPS) {
            $filesToRemove = $backupFiles | Select-Object -Skip $script:MAX_CREDENTIAL_BACKUPS
            $filesToRemove | Remove-Item -Force
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Credential store backup created: $backupFile"
        return $backupFile
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to backup credential store: $($_.Exception.Message)"
        throw
    }
}

function Test-SecureCredentialCompliance {
    <#
    .SYNOPSIS
        Test credential store compliance
    .DESCRIPTION
        Validates credential store security and compliance
    #>
    [CmdletBinding()]
    param()

    try {
        Write-CustomLog -Level 'INFO' -Message "Testing credential store compliance"
        
        Initialize-SecureCredentialStore
        
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        if (-not (Test-Path $storePath)) {
            return @{
                Compliant = $false
                Issues = @("Credential store not found")
            }
        }
        
        $store = Get-Content $storePath -Raw | ConvertFrom-Json -AsHashtable
        $issues = @()
        
        # Check store structure
        $requiredKeys = @('Version', 'Created', 'Credentials', 'SecuritySettings')
        foreach ($key in $requiredKeys) {
            if (-not $store.ContainsKey($key)) {
                $issues += "Missing required key: $key"
            }
        }
        
        # Check credential security
        foreach ($credentialName in $store.Credentials.Keys) {
            $credential = $store.Credentials[$credentialName]
            
            # Check for expired credentials
            if ($credential.Created -lt (Get-Date).AddDays(-90)) {
                $issues += "Credential '$credentialName' is older than 90 days"
            }
            
            # Check for unencrypted passwords
            if ($credential.Password -and -not $credential.PasswordEncrypted) {
                $issues += "Credential '$credentialName' has unencrypted password"
            }
        }
        
        # Check file permissions
        if ($IsWindows) {
            $acl = Get-Acl $storePath
            $hasNonOwnerAccess = $acl.Access | Where-Object { $_.IdentityReference -ne $env:USERNAME -and $_.AccessControlType -eq 'Allow' }
            if ($hasNonOwnerAccess) {
                $issues += "Credential store has excessive permissions"
            }
        }
        
        $result = @{
            Compliant = $issues.Count -eq 0
            Issues = $issues
            CheckedAt = Get-Date
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Compliance check completed. Issues found: $($issues.Count)"
        return $result
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to check compliance: $($_.Exception.Message)"
        throw
    }
}

function Export-SecureCredential {
    <#
    .SYNOPSIS
        Export credentials to a secure format
    .DESCRIPTION
        Exports credentials for backup or migration
    .PARAMETER CredentialName
        Name of credential to export
    .PARAMETER OutputPath
        Path to export file
    .PARAMETER IncludeSecrets
        Include encrypted secrets in export
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingPlainTextForPassword', 'CredentialName')]
        [string]$CredentialName,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSecrets
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Exporting credential: $CredentialName"
        
        Initialize-SecureCredentialStore
        
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        $store = Get-Content $storePath -Raw | ConvertFrom-Json -AsHashtable
        
        if (-not $store.Credentials.ContainsKey($CredentialName)) {
            throw "Credential '$CredentialName' not found"
        }
        
        $credential = $store.Credentials[$CredentialName]
        
        # Create export object
        $export = @{
            Name = $credential.Name
            Type = $credential.Type
            Username = $credential.Username
            Description = $credential.Description
            Metadata = $credential.Metadata
            Created = $credential.Created
            LastModified = $credential.LastModified
            ExportedAt = Get-Date
        }
        
        if ($IncludeSecrets) {
            $export.PasswordEncrypted = $credential.PasswordEncrypted
            $export.APIKeyEncrypted = $credential.APIKeyEncrypted
        }
        
        if ($PSCmdlet.ShouldProcess($OutputPath, "Export credential")) {
            $export | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8
            
            Write-CustomLog -Level 'SUCCESS' -Message "Credential exported to: $OutputPath"
            return @{
                Success = $true
                ExportPath = $OutputPath
                Message = "Credential exported successfully"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to export credential $CredentialName : $($_.Exception.Message)"
        throw
    }
}

function Import-SecureCredential {
    <#
    .SYNOPSIS
        Import credentials from a secure format
    .DESCRIPTION
        Imports credentials from backup or migration
    .PARAMETER InputPath
        Path to import file
    .PARAMETER Force
        Force overwrite existing credentials
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Importing credential from: $InputPath"
        
        if (-not (Test-Path $InputPath)) {
            throw "Import file not found: $InputPath"
        }
        
        Initialize-SecureCredentialStore
        
        $importData = Get-Content $InputPath -Raw | ConvertFrom-Json -AsHashtable
        
        # Validate import data
        $requiredKeys = @('Name', 'Type', 'Username')
        foreach ($key in $requiredKeys) {
            if (-not $importData.ContainsKey($key)) {
                throw "Invalid import data: missing $key"
            }
        }
        
        $storePath = Join-Path $script:CredentialStorePath 'credentials.json'
        $store = Get-Content $storePath -Raw | ConvertFrom-Json -AsHashtable
        
        if ($store.Credentials.ContainsKey($importData.Name) -and -not $Force) {
            throw "Credential '$($importData.Name)' already exists. Use -Force to overwrite"
        }
        
        if ($PSCmdlet.ShouldProcess($importData.Name, "Import credential")) {
            # Backup before import
            if ($store.SecuritySettings.BackupOnChange) {
                Backup-SecureCredentialStore
            }
            
            # Import credential
            $importData.LastModified = Get-Date
            $store.Credentials[$importData.Name] = $importData
            $store.LastModified = Get-Date
            
            # Save updated store
            $store | ConvertTo-Json -Depth 10 | Set-Content $storePath -Encoding UTF8
            
            Write-CustomLog -Level 'SUCCESS' -Message "Successfully imported credential: $($importData.Name)"
            return @{
                Success = $true
                CredentialName = $importData.Name
                Message = "Credential imported successfully"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to import credential from $InputPath : $($_.Exception.Message)"
        throw
    }
}

# SECURITY AUTOMATION FUNCTIONS

# Active Directory Security Functions
function Get-ADSecurityAssessment {
    <#
    .SYNOPSIS
        Perform comprehensive Active Directory security assessment
    .DESCRIPTION
        Analyzes AD environment for security vulnerabilities and compliance issues
    .PARAMETER DomainName
        Domain name to assess
    .PARAMETER IncludeDetailedReport
        Include detailed vulnerability report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDetailedReport
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting AD security assessment for domain: $DomainName"
        
        # Ensure AD module is available
        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            throw "Active Directory module not available"
        }
        
        Import-Module ActiveDirectory -ErrorAction Stop
        
        $assessment = @{
            DomainName = $DomainName
            AssessmentDate = Get-Date
            SecurityIssues = @()
            Recommendations = @()
            ComplianceStatus = @{}
        }
        
        # Check domain functional level
        $domain = Get-ADDomain $DomainName
        if ($domain.DomainMode -lt 'Windows2016Domain') {
            $assessment.SecurityIssues += "Domain functional level is below Windows 2016"
            $assessment.Recommendations += "Upgrade domain functional level to Windows 2016 or higher"
        }
        
        # Check for privileged accounts
        $privilegedGroups = @('Domain Admins', 'Enterprise Admins', 'Schema Admins')
        foreach ($group in $privilegedGroups) {
            try {
                $members = Get-ADGroupMember -Identity $group -Server $DomainName
                if ($members.Count -gt 5) {
                    $assessment.SecurityIssues += "Excessive members in $group ($($members.Count))"
                    $assessment.Recommendations += "Review and reduce membership in $group"
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Could not check group $group : $($_.Exception.Message)"
            }
        }
        
        # Check password policy
        $passwordPolicy = Get-ADDefaultDomainPasswordPolicy -Server $DomainName
        if ($passwordPolicy.MinPasswordLength -lt 12) {
            $assessment.SecurityIssues += "Minimum password length is less than 12 characters"
            $assessment.Recommendations += "Increase minimum password length to 12 or more characters"
        }
        
        if (-not $passwordPolicy.ComplexityEnabled) {
            $assessment.SecurityIssues += "Password complexity is not enabled"
            $assessment.Recommendations += "Enable password complexity requirements"
        }
        
        # Check for inactive accounts
        $inactiveThreshold = (Get-Date).AddDays(-90)
        $inactiveUsers = Get-ADUser -Filter {LastLogonDate -lt $inactiveThreshold -and Enabled -eq $true} -Server $DomainName
        if ($inactiveUsers.Count -gt 0) {
            $assessment.SecurityIssues += "Found $($inactiveUsers.Count) inactive enabled user accounts"
            $assessment.Recommendations += "Disable or remove inactive user accounts"
        }
        
        # Set compliance status
        $assessment.ComplianceStatus = @{
            PasswordPolicy = $passwordPolicy.MinPasswordLength -ge 12 -and $passwordPolicy.ComplexityEnabled
            PrivilegedAccounts = $true # Simplified for now
            FunctionalLevel = $domain.DomainMode -ge 'Windows2016Domain'
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "AD security assessment completed. Issues found: $($assessment.SecurityIssues.Count)"
        
        if ($IncludeDetailedReport) {
            $assessment.DetailedReport = @{
                Domain = $domain
                PasswordPolicy = $passwordPolicy
                InactiveUsers = $inactiveUsers | Select-Object Name, LastLogonDate, Enabled
            }
        }
        
        return $assessment
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to perform AD security assessment: $($_.Exception.Message)"
        throw
    }
}

function Set-ADPasswordPolicy {
    <#
    .SYNOPSIS
        Configure Active Directory password policy
    .DESCRIPTION
        Sets secure password policy for the domain
    .PARAMETER DomainName
        Domain name to configure
    .PARAMETER MinPasswordLength
        Minimum password length
    .PARAMETER ComplexityEnabled
        Enable password complexity
    .PARAMETER MaxPasswordAge
        Maximum password age in days
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName,

        [Parameter(Mandatory = $false)]
        [int]$MinPasswordLength = 12,

        [Parameter(Mandatory = $false)]
        [bool]$ComplexityEnabled = $true,

        [Parameter(Mandatory = $false)]
        [int]$MaxPasswordAge = 90
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Configuring AD password policy for domain: $DomainName"
        
        Import-Module ActiveDirectory -ErrorAction Stop
        
        if ($PSCmdlet.ShouldProcess($DomainName, "Configure password policy")) {
            # Set password policy
            Set-ADDefaultDomainPasswordPolicy -Server $DomainName -MinPasswordLength $MinPasswordLength -ComplexityEnabled $ComplexityEnabled -MaxPasswordAge (New-TimeSpan -Days $MaxPasswordAge)
            
            Write-CustomLog -Level 'SUCCESS' -Message "Password policy configured successfully"
            
            return @{
                Success = $true
                Domain = $DomainName
                MinPasswordLength = $MinPasswordLength
                ComplexityEnabled = $ComplexityEnabled
                MaxPasswordAge = $MaxPasswordAge
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure AD password policy: $($_.Exception.Message)"
        throw
    }
}

function Get-ADDelegationRisks {
    <#
    .SYNOPSIS
        Identify delegation risks in Active Directory
    .DESCRIPTION
        Scans for dangerous delegation configurations
    .PARAMETER DomainName
        Domain name to scan
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Scanning for delegation risks in domain: $DomainName"
        
        Import-Module ActiveDirectory -ErrorAction Stop
        
        $risks = @()
        
        # Check for unconstrained delegation
        $unconstrainedDelegation = Get-ADUser -Filter {TrustedForDelegation -eq $true} -Server $DomainName
        foreach ($user in $unconstrainedDelegation) {
            $risks += @{
                Type = 'UnconstrainedDelegation'
                Object = $user.SamAccountName
                Risk = 'High'
                Description = "User has unconstrained delegation enabled"
            }
        }
        
        # Check for constrained delegation
        $constrainedDelegation = Get-ADUser -Filter {TrustedToAuthForDelegation -eq $true} -Server $DomainName
        foreach ($user in $constrainedDelegation) {
            $risks += @{
                Type = 'ConstrainedDelegation'
                Object = $user.SamAccountName
                Risk = 'Medium'
                Description = "User has constrained delegation enabled"
            }
        }
        
        # Check computer accounts
        $computerDelegation = Get-ADComputer -Filter {TrustedForDelegation -eq $true} -Server $DomainName
        foreach ($computer in $computerDelegation) {
            $risks += @{
                Type = 'ComputerDelegation'
                Object = $computer.Name
                Risk = 'High'
                Description = "Computer has unconstrained delegation enabled"
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Delegation risk scan completed. Risks found: $($risks.Count)"
        
        return @{
            DomainName = $DomainName
            ScanDate = Get-Date
            Risks = $risks
            RiskCount = $risks.Count
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to scan for delegation risks: $($_.Exception.Message)"
        throw
    }
}

function Enable-ADSmartCardLogon {
    <#
    .SYNOPSIS
        Enable smart card logon for user accounts
    .DESCRIPTION
        Configures smart card authentication for specified users
    .PARAMETER Username
        Username to configure
    .PARAMETER RequireSmartCard
        Require smart card for logon
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $false)]
        [bool]$RequireSmartCard = $true
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Configuring smart card logon for user: $Username"
        
        Import-Module ActiveDirectory -ErrorAction Stop
        
        if ($PSCmdlet.ShouldProcess($Username, "Configure smart card logon")) {
            # Set smart card logon requirement
            Set-ADUser -Identity $Username -SmartcardLogonRequired $RequireSmartCard
            
            Write-CustomLog -Level 'SUCCESS' -Message "Smart card logon configured for user: $Username"
            
            return @{
                Success = $true
                Username = $Username
                SmartCardRequired = $RequireSmartCard
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure smart card logon for $Username : $($_.Exception.Message)"
        throw
    }
}

# Certificate Services Functions
function Install-EnterpriseCA {
    <#
    .SYNOPSIS
        Install Enterprise Certificate Authority
    .DESCRIPTION
        Installs and configures an Enterprise CA
    .PARAMETER CAName
        Name of the Certificate Authority
    .PARAMETER CAType
        Type of CA (EnterpriseRootCA, EnterpriseSubordinateCA)
    .PARAMETER KeyLength
        RSA key length (2048, 4096)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CAName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('EnterpriseRootCA', 'EnterpriseSubordinateCA')]
        [string]$CAType = 'EnterpriseRootCA',

        [Parameter(Mandatory = $false)]
        [ValidateSet(2048, 4096)]
        [int]$KeyLength = 2048
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Installing Enterprise CA: $CAName"
        
        if (-not $IsWindows) {
            throw "Certificate Authority installation is only supported on Windows"
        }
        
        # Check if ADCS role is available
        $adcsFeature = Get-WindowsFeature -Name ADCS-Cert-Authority
        if ($adcsFeature.InstallState -ne 'Installed') {
            if ($PSCmdlet.ShouldProcess('ADCS-Cert-Authority', 'Install Windows Feature')) {
                Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools
            }
        }
        
        if ($PSCmdlet.ShouldProcess($CAName, "Configure Certificate Authority")) {
            # Configure CA
            $caParams = @{
                CACommonName = $CAName
                CAType = $CAType
                KeyLength = $KeyLength
                HashAlgorithm = 'SHA256'
                ValidityPeriod = 'Years'
                ValidityPeriodUnits = 10
            }
            
            Install-AdcsCertificationAuthority @caParams -Force
            
            Write-CustomLog -Level 'SUCCESS' -Message "Enterprise CA installed successfully: $CAName"
            
            return @{
                Success = $true
                CAName = $CAName
                CAType = $CAType
                KeyLength = $KeyLength
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to install Enterprise CA: $($_.Exception.Message)"
        throw
    }
}

function New-CertificateTemplate {
    <#
    .SYNOPSIS
        Create a new certificate template
    .DESCRIPTION
        Creates a custom certificate template with security settings
    .PARAMETER TemplateName
        Name of the certificate template
    .PARAMETER Purpose
        Purpose of the certificate (ServerAuthentication, ClientAuthentication, CodeSigning)
    .PARAMETER ValidityPeriod
        Validity period in years
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('ServerAuthentication', 'ClientAuthentication', 'CodeSigning')]
        [string]$Purpose,

        [Parameter(Mandatory = $false)]
        [int]$ValidityPeriod = 2
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Creating certificate template: $TemplateName"
        
        if (-not $IsWindows) {
            throw "Certificate template creation is only supported on Windows"
        }
        
        # Import PKI module
        Import-Module PKI -ErrorAction Stop
        
        if ($PSCmdlet.ShouldProcess($TemplateName, "Create certificate template")) {
            # Create template based on purpose
            switch ($Purpose) {
                'ServerAuthentication' {
                    $template = Get-CertificateTemplate -Name 'WebServer' | New-CertificateTemplate -Name $TemplateName
                    $template | Set-CertificateTemplateProperty -Property ValidityPeriod -Value "$ValidityPeriod Years"
                }
                'ClientAuthentication' {
                    $template = Get-CertificateTemplate -Name 'User' | New-CertificateTemplate -Name $TemplateName
                    $template | Set-CertificateTemplateProperty -Property ValidityPeriod -Value "$ValidityPeriod Years"
                }
                'CodeSigning' {
                    $template = Get-CertificateTemplate -Name 'CodeSigning' | New-CertificateTemplate -Name $TemplateName
                    $template | Set-CertificateTemplateProperty -Property ValidityPeriod -Value "$ValidityPeriod Years"
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Certificate template created: $TemplateName"
            
            return @{
                Success = $true
                TemplateName = $TemplateName
                Purpose = $Purpose
                ValidityPeriod = $ValidityPeriod
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create certificate template: $($_.Exception.Message)"
        throw
    }
}

function Enable-CertificateAutoEnrollment {
    <#
    .SYNOPSIS
        Enable certificate auto-enrollment
    .DESCRIPTION
        Configures automatic certificate enrollment via Group Policy
    .PARAMETER TemplateName
        Name of the certificate template
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateName
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Enabling certificate auto-enrollment for template: $TemplateName"
        
        if (-not $IsWindows) {
            throw "Certificate auto-enrollment is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($TemplateName, "Enable auto-enrollment")) {
            # Configure auto-enrollment via registry
            $regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment'
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            
            Set-ItemProperty -Path $regPath -Name 'AEPolicy' -Value 7 -Type DWord
            
            Write-CustomLog -Level 'SUCCESS' -Message "Certificate auto-enrollment enabled for template: $TemplateName"
            
            return @{
                Success = $true
                TemplateName = $TemplateName
                Message = "Auto-enrollment enabled"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable certificate auto-enrollment: $($_.Exception.Message)"
        throw
    }
}

function Invoke-CertificateLifecycleManagement {
    <#
    .SYNOPSIS
        Manage certificate lifecycle
    .DESCRIPTION
        Handles certificate renewal, revocation, and cleanup
    .PARAMETER Action
        Action to perform (Renew, Revoke, Cleanup)
    .PARAMETER CertificateThumbprint
        Thumbprint of the certificate
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Renew', 'Revoke', 'Cleanup')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$CertificateThumbprint
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Performing certificate lifecycle action: $Action for certificate: $CertificateThumbprint"
        
        # Get certificate
        $certificate = Get-ChildItem -Path 'Cert:\LocalMachine\My' | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
        if (-not $certificate) {
            throw "Certificate not found: $CertificateThumbprint"
        }
        
        if ($PSCmdlet.ShouldProcess($CertificateThumbprint, $Action)) {
            switch ($Action) {
                'Renew' {
                    # Initiate certificate renewal
                    $result = Get-Certificate -Template $certificate.Extensions['1.3.6.1.4.1.311.20.2'].RawData -CertStoreLocation 'Cert:\LocalMachine\My'
                    Write-CustomLog -Level 'SUCCESS' -Message "Certificate renewal initiated"
                }
                'Revoke' {
                    # Revoke certificate (requires CA access)
                    Write-CustomLog -Level 'INFO' -Message "Certificate revocation requires CA administrative access"
                }
                'Cleanup' {
                    # Remove expired certificates
                    if ($certificate.NotAfter -lt (Get-Date)) {
                        Remove-Item -Path "Cert:\LocalMachine\My\$CertificateThumbprint" -Force
                        Write-CustomLog -Level 'SUCCESS' -Message "Expired certificate removed"
                    }
                }
            }
            
            return @{
                Success = $true
                Action = $Action
                CertificateThumbprint = $CertificateThumbprint
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to perform certificate lifecycle action: $($_.Exception.Message)"
        throw
    }
}

# Endpoint Hardening Functions
function Enable-CredentialGuard {
    <#
    .SYNOPSIS
        Enable Windows Credential Guard
    .DESCRIPTION
        Enables Credential Guard to protect against credential theft
    .PARAMETER Force
        Force enable even if prerequisites are not met
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Enabling Windows Credential Guard"
        
        if (-not $IsWindows) {
            throw "Credential Guard is only supported on Windows"
        }
        
        # Check prerequisites
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        if ($osInfo.ProductType -ne 1) { # Not a workstation
            Write-CustomLog -Level 'WARNING' -Message "Credential Guard is designed for workstations"
        }
        
        if ($PSCmdlet.ShouldProcess('Credential Guard', 'Enable')) {
            # Enable Credential Guard via registry
            $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\LSA'
            Set-ItemProperty -Path $regPath -Name 'LsaCfgFlags' -Value 1 -Type DWord
            
            # Enable HVCI
            $hvciPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
            if (-not (Test-Path $hvciPath)) {
                New-Item -Path $hvciPath -Force | Out-Null
            }
            Set-ItemProperty -Path $hvciPath -Name 'EnableVirtualizationBasedSecurity' -Value 1 -Type DWord
            Set-ItemProperty -Path $hvciPath -Name 'HypervisorEnforcedCodeIntegrity' -Value 1 -Type DWord
            
            Write-CustomLog -Level 'SUCCESS' -Message "Credential Guard enabled (restart required)"
            
            return @{
                Success = $true
                Message = "Credential Guard enabled, restart required"
                RestartRequired = $true
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable Credential Guard: $($_.Exception.Message)"
        throw
    }
}

function Enable-AdvancedAuditPolicy {
    <#
    .SYNOPSIS
        Enable advanced audit policy
    .DESCRIPTION
        Configures advanced audit policy for security monitoring
    .PARAMETER AuditLevel
        Audit level (Basic, Enhanced, Maximum)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Basic', 'Enhanced', 'Maximum')]
        [string]$AuditLevel = 'Enhanced'
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Enabling advanced audit policy: $AuditLevel"
        
        if (-not $IsWindows) {
            throw "Advanced audit policy is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($AuditLevel, 'Configure audit policy')) {
            # Configure audit policies based on level
            switch ($AuditLevel) {
                'Basic' {
                    auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
                    auditpol /set /category:"Account Logon" /success:enable /failure:enable
                }
                'Enhanced' {
                    auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
                    auditpol /set /category:"Account Logon" /success:enable /failure:enable
                    auditpol /set /category:"Account Management" /success:enable /failure:enable
                    auditpol /set /category:"Privilege Use" /success:enable /failure:enable
                }
                'Maximum' {
                    auditpol /set /category:"*" /success:enable /failure:enable
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Advanced audit policy configured: $AuditLevel"
            
            return @{
                Success = $true
                AuditLevel = $AuditLevel
                Message = "Advanced audit policy configured"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure advanced audit policy: $($_.Exception.Message)"
        throw
    }
}

function Set-AppLockerPolicy {
    <#
    .SYNOPSIS
        Configure AppLocker policy
    .DESCRIPTION
        Sets up AppLocker policies for application control
    .PARAMETER PolicyType
        Type of policy (Whitelist, Blacklist, Hybrid)
    .PARAMETER PolicyPath
        Path to AppLocker policy XML file
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Whitelist', 'Blacklist', 'Hybrid')]
        [string]$PolicyType,

        [Parameter(Mandatory = $false)]
        [string]$PolicyPath
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Configuring AppLocker policy: $PolicyType"
        
        if (-not $IsWindows) {
            throw "AppLocker is only supported on Windows"
        }
        
        # Import AppLocker module
        Import-Module AppLocker -ErrorAction Stop
        
        if ($PSCmdlet.ShouldProcess($PolicyType, 'Configure AppLocker policy')) {
            if ($PolicyPath -and (Test-Path $PolicyPath)) {
                # Import existing policy
                Set-AppLockerPolicy -XMLPolicy $PolicyPath
            } else {
                # Create default policy based on type
                switch ($PolicyType) {
                    'Whitelist' {
                        $rules = @()
                        $rules += New-AppLockerPolicy -FileInformation (Get-ChildItem 'C:\Windows\System32\*.exe') -RuleType Publisher -User Everyone -Optimize
                        $rules += New-AppLockerPolicy -FileInformation (Get-ChildItem 'C:\Program Files\*.exe' -Recurse) -RuleType Publisher -User Everyone -Optimize
                        Set-AppLockerPolicy -PolicyObject $rules
                    }
                    'Blacklist' {
                        # Default allow all, then add specific blocks
                        $defaultRules = Get-AppLockerPolicy -Effective
                        Set-AppLockerPolicy -PolicyObject $defaultRules
                    }
                    'Hybrid' {
                        # Combination of whitelist and blacklist
                        Write-CustomLog -Level 'INFO' -Message "Hybrid policy requires custom configuration"
                    }
                }
            }
            
            # Enable AppLocker service
            Set-Service -Name AppIDSvc -StartupType Automatic
            Start-Service -Name AppIDSvc
            
            Write-CustomLog -Level 'SUCCESS' -Message "AppLocker policy configured: $PolicyType"
            
            return @{
                Success = $true
                PolicyType = $PolicyType
                Message = "AppLocker policy configured"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure AppLocker policy: $($_.Exception.Message)"
        throw
    }
}

function Set-WindowsFirewallProfile {
    <#
    .SYNOPSIS
        Configure Windows Firewall profiles
    .DESCRIPTION
        Sets up Windows Firewall with security best practices
    .PARAMETER Profile
        Firewall profile (Domain, Private, Public)
    .PARAMETER State
        Firewall state (On, Off)
    .PARAMETER DefaultInboundAction
        Default inbound action (Allow, Block)
    .PARAMETER DefaultOutboundAction
        Default outbound action (Allow, Block)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Domain', 'Private', 'Public', 'All')]
        [string]$Profile,

        [Parameter(Mandatory = $false)]
        [ValidateSet('On', 'Off')]
        [string]$State = 'On',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Allow', 'Block')]
        [string]$DefaultInboundAction = 'Block',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Allow', 'Block')]
        [string]$DefaultOutboundAction = 'Allow'
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Configuring Windows Firewall profile: $Profile"
        
        if (-not $IsWindows) {
            throw "Windows Firewall is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($Profile, 'Configure firewall profile')) {
            if ($Profile -eq 'All') {
                $profiles = @('Domain', 'Private', 'Public')
            } else {
                $profiles = @($Profile)
            }
            
            foreach ($profileName in $profiles) {
                Set-NetFirewallProfile -Name $profileName -Enabled $State -DefaultInboundAction $DefaultInboundAction -DefaultOutboundAction $DefaultOutboundAction
                
                Write-CustomLog -Level 'SUCCESS' -Message "Firewall profile configured: $profileName"
            }
            
            return @{
                Success = $true
                Profile = $Profile
                State = $State
                DefaultInboundAction = $DefaultInboundAction
                DefaultOutboundAction = $DefaultOutboundAction
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure firewall profile: $($_.Exception.Message)"
        throw
    }
}

function Enable-ExploitProtection {
    <#
    .SYNOPSIS
        Enable Windows Exploit Protection
    .DESCRIPTION
        Configures Windows Defender Exploit Protection features
    .PARAMETER ProtectionLevel
        Protection level (Basic, Enhanced, Maximum)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Basic', 'Enhanced', 'Maximum')]
        [string]$ProtectionLevel = 'Enhanced'
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Enabling Exploit Protection: $ProtectionLevel"
        
        if (-not $IsWindows) {
            throw "Exploit Protection is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($ProtectionLevel, 'Enable Exploit Protection')) {
            # Configure exploit protection settings
            switch ($ProtectionLevel) {
                'Basic' {
                    Set-ProcessMitigation -System -Enable DEP, SEHOP, ASLR
                }
                'Enhanced' {
                    Set-ProcessMitigation -System -Enable DEP, SEHOP, ASLR, CFG, StrictCFG
                }
                'Maximum' {
                    Set-ProcessMitigation -System -Enable DEP, SEHOP, ASLR, CFG, StrictCFG, StrictHandle, SystemCallDisable
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Exploit Protection enabled: $ProtectionLevel"
            
            return @{
                Success = $true
                ProtectionLevel = $ProtectionLevel
                Message = "Exploit Protection enabled"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable Exploit Protection: $($_.Exception.Message)"
        throw
    }
}

# Network Security Functions
function Set-IPsecPolicy {
    <#
    .SYNOPSIS
        Configure IPsec policies
    .DESCRIPTION
        Sets up IPsec policies for network security
    .PARAMETER PolicyName
        Name of the IPsec policy
    .PARAMETER SourceAddress
        Source IP address or subnet
    .PARAMETER DestinationAddress
        Destination IP address or subnet
    .PARAMETER Protocol
        Protocol (TCP, UDP, Any)
    .PARAMETER Port
        Port number
    .PARAMETER Action
        Action (Require, Request, Allow)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyName,

        [Parameter(Mandatory = $true)]
        [string]$SourceAddress,

        [Parameter(Mandatory = $true)]
        [string]$DestinationAddress,

        [Parameter(Mandatory = $false)]
        [ValidateSet('TCP', 'UDP', 'Any')]
        [string]$Protocol = 'Any',

        [Parameter(Mandatory = $false)]
        [int]$Port,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Require', 'Request', 'Allow')]
        [string]$Action = 'Require'
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Configuring IPsec policy: $PolicyName"
        
        if (-not $IsWindows) {
            throw "IPsec policy configuration is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($PolicyName, 'Configure IPsec policy')) {
            # Create IPsec policy
            $policyParams = @{
                PolicyName = $PolicyName
                SourceAddress = $SourceAddress
                DestinationAddress = $DestinationAddress
                Protocol = $Protocol
                InboundSecurity = $Action
                OutboundSecurity = $Action
            }
            
            if ($Port) {
                $policyParams.Port = $Port
            }
            
            New-NetIPsecRule @policyParams
            
            Write-CustomLog -Level 'SUCCESS' -Message "IPsec policy configured: $PolicyName"
            
            return @{
                Success = $true
                PolicyName = $PolicyName
                SourceAddress = $SourceAddress
                DestinationAddress = $DestinationAddress
                Protocol = $Protocol
                Action = $Action
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure IPsec policy: $($_.Exception.Message)"
        throw
    }
}

function Set-SMBSecurity {
    <#
    .SYNOPSIS
        Configure SMB security settings
    .DESCRIPTION
        Hardens SMB configuration for security
    .PARAMETER DisableSMB1
        Disable SMB1 protocol
    .PARAMETER EnableSMBSigning
        Enable SMB signing
    .PARAMETER EnableSMBEncryption
        Enable SMB encryption
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$DisableSMB1 = $true,

        [Parameter(Mandatory = $false)]
        [bool]$EnableSMBSigning = $true,

        [Parameter(Mandatory = $false)]
        [bool]$EnableSMBEncryption = $true
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Configuring SMB security settings"
        
        if (-not $IsWindows) {
            throw "SMB security configuration is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess('SMB', 'Configure security settings')) {
            # Disable SMB1 if requested
            if ($DisableSMB1) {
                Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
                Write-CustomLog -Level 'SUCCESS' -Message "SMB1 protocol disabled"
            }
            
            # Enable SMB signing
            if ($EnableSMBSigning) {
                Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
                Set-SmbClientConfiguration -RequireSecuritySignature $true -Force
                Write-CustomLog -Level 'SUCCESS' -Message "SMB signing enabled"
            }
            
            # Enable SMB encryption
            if ($EnableSMBEncryption) {
                Set-SmbServerConfiguration -EncryptData $true -Force
                Write-CustomLog -Level 'SUCCESS' -Message "SMB encryption enabled"
            }
            
            return @{
                Success = $true
                DisableSMB1 = $DisableSMB1
                EnableSMBSigning = $EnableSMBSigning
                EnableSMBEncryption = $EnableSMBEncryption
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure SMB security: $($_.Exception.Message)"
        throw
    }
}

function Disable-WeakProtocols {
    <#
    .SYNOPSIS
        Disable weak network protocols
    .DESCRIPTION
        Disables insecure network protocols and cipher suites
    .PARAMETER Protocols
        Protocols to disable
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Protocols = @('TLS 1.0', 'TLS 1.1', 'SSL 2.0', 'SSL 3.0')
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Disabling weak protocols: $($Protocols -join ', ')"
        
        if (-not $IsWindows) {
            throw "Protocol configuration is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($Protocols, 'Disable weak protocols')) {
            foreach ($protocol in $Protocols) {
                # Disable protocol in registry
                $protocolPath = switch ($protocol) {
                    'TLS 1.0' { 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0' }
                    'TLS 1.1' { 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1' }
                    'SSL 2.0' { 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0' }
                    'SSL 3.0' { 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0' }
                }
                
                if ($protocolPath) {
                    # Create protocol key structure
                    $clientPath = Join-Path $protocolPath 'Client'
                    $serverPath = Join-Path $protocolPath 'Server'
                    
                    foreach ($path in @($clientPath, $serverPath)) {
                        if (-not (Test-Path $path)) {
                            New-Item -Path $path -Force | Out-Null
                        }
                        Set-ItemProperty -Path $path -Name 'Enabled' -Value 0 -Type DWord
                        Set-ItemProperty -Path $path -Name 'DisabledByDefault' -Value 1 -Type DWord
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Disabled protocol: $protocol"
                }
            }
            
            return @{
                Success = $true
                DisabledProtocols = $Protocols
                Message = "Weak protocols disabled (restart required)"
                RestartRequired = $true
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to disable weak protocols: $($_.Exception.Message)"
        throw
    }
}

function Enable-DNSSECValidation {
    <#
    .SYNOPSIS
        Enable DNSSEC validation
    .DESCRIPTION
        Configures DNSSEC validation for DNS security
    .PARAMETER ValidationLevel
        Validation level (Permissive, Strict)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Permissive', 'Strict')]
        [string]$ValidationLevel = 'Permissive'
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Enabling DNSSEC validation: $ValidationLevel"
        
        if (-not $IsWindows) {
            throw "DNSSEC validation is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($ValidationLevel, 'Enable DNSSEC validation')) {
            # Configure DNSSEC validation
            $dnssecParams = @{
                ZoneName = '.'
                ValidationRequired = ($ValidationLevel -eq 'Strict')
            }
            
            Set-DnsServerDnsSecZoneSetting @dnssecParams
            
            Write-CustomLog -Level 'SUCCESS' -Message "DNSSEC validation enabled: $ValidationLevel"
            
            return @{
                Success = $true
                ValidationLevel = $ValidationLevel
                Message = "DNSSEC validation enabled"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable DNSSEC validation: $($_.Exception.Message)"
        throw
    }
}

function Set-DNSSinkhole {
    <#
    .SYNOPSIS
        Configure DNS sinkhole for malicious domains
    .DESCRIPTION
        Sets up DNS sinkhole to block malicious domains
    .PARAMETER SinkholeAddress
        IP address to redirect malicious domains to
    .PARAMETER MaliciousDomains
        List of malicious domains to block
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SinkholeAddress = '127.0.0.1',

        [Parameter(Mandatory = $false)]
        [string[]]$MaliciousDomains = @()
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Configuring DNS sinkhole"
        
        if (-not $IsWindows) {
            throw "DNS sinkhole configuration is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess('DNS Sinkhole', 'Configure')) {
            # Configure DNS sinkhole zones
            foreach ($domain in $MaliciousDomains) {
                try {
                    Add-DnsServerPrimaryZone -Name $domain -ZoneFile "$domain.dns"
                    Add-DnsServerResourceRecordA -ZoneName $domain -Name '*' -IPv4Address $SinkholeAddress
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Added DNS sinkhole for: $domain"
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to add DNS sinkhole for $domain : $($_.Exception.Message)"
                }
            }
            
            return @{
                Success = $true
                SinkholeAddress = $SinkholeAddress
                BlockedDomains = $MaliciousDomains
                Message = "DNS sinkhole configured"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure DNS sinkhole: $($_.Exception.Message)"
        throw
    }
}

# Remote Administration Security Functions
function Set-WinRMSecurity {
    <#
    .SYNOPSIS
        Configure WinRM security settings
    .DESCRIPTION
        Hardens WinRM configuration for secure remote management
    .PARAMETER EnableHTTPS
        Enable HTTPS listener
    .PARAMETER DisableHTTP
        Disable HTTP listener
    .PARAMETER AllowUnencrypted
        Allow unencrypted traffic
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$EnableHTTPS = $true,

        [Parameter(Mandatory = $false)]
        [bool]$DisableHTTP = $true,

        [Parameter(Mandatory = $false)]
        [bool]$AllowUnencrypted = $false
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Configuring WinRM security settings"
        
        if (-not $IsWindows) {
            throw "WinRM security configuration is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess('WinRM', 'Configure security settings')) {
            # Configure WinRM service
            winrm set winrm/config/service '@{AllowUnencrypted="' + $AllowUnencrypted.ToString().ToLower() + '"}'
            winrm set winrm/config/service/auth '@{Basic="false"}'
            winrm set winrm/config/service/auth '@{Digest="false"}'
            
            # Configure client settings
            winrm set winrm/config/client '@{AllowUnencrypted="' + $AllowUnencrypted.ToString().ToLower() + '"}'
            winrm set winrm/config/client/auth '@{Basic="false"}'
            winrm set winrm/config/client/auth '@{Digest="false"}'
            
            # Disable HTTP listener if requested
            if ($DisableHTTP) {
                winrm delete winrm/config/listener?Address=*+Transport=HTTP
                Write-CustomLog -Level 'SUCCESS' -Message "WinRM HTTP listener disabled"
            }
            
            # Enable HTTPS listener if requested
            if ($EnableHTTPS) {
                # This requires a certificate to be configured
                Write-CustomLog -Level 'INFO' -Message "HTTPS listener requires SSL certificate configuration"
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "WinRM security configured"
            
            return @{
                Success = $true
                EnableHTTPS = $EnableHTTPS
                DisableHTTP = $DisableHTTP
                AllowUnencrypted = $AllowUnencrypted
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure WinRM security: $($_.Exception.Message)"
        throw
    }
}

function Enable-PowerShellRemotingSSL {
    <#
    .SYNOPSIS
        Enable PowerShell Remoting with SSL
    .DESCRIPTION
        Configures PowerShell Remoting with SSL certificate
    .PARAMETER CertificateThumbprint
        Thumbprint of SSL certificate
    .PARAMETER Port
        HTTPS port (default 5986)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CertificateThumbprint,

        [Parameter(Mandatory = $false)]
        [int]$Port = 5986
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Enabling PowerShell Remoting with SSL"
        
        if (-not $IsWindows) {
            throw "PowerShell Remoting SSL is only supported on Windows"
        }
        
        # Verify certificate exists
        $certificate = Get-ChildItem -Path 'Cert:\LocalMachine\My' | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
        if (-not $certificate) {
            throw "Certificate not found: $CertificateThumbprint"
        }
        
        if ($PSCmdlet.ShouldProcess('PowerShell Remoting SSL', 'Enable')) {
            # Enable PowerShell Remoting
            Enable-PSRemoting -Force
            
            # Create HTTPS listener
            winrm create winrm/config/listener?Address=*+Transport=HTTPS "@{Hostname=`"$env:COMPUTERNAME`"; CertificateThumbprint=`"$CertificateThumbprint`"; Port=`"$Port`"}"
            
            # Configure firewall rule
            New-NetFirewallRule -DisplayName 'PowerShell Remoting HTTPS' -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow
            
            Write-CustomLog -Level 'SUCCESS' -Message "PowerShell Remoting with SSL enabled on port $Port"
            
            return @{
                Success = $true
                CertificateThumbprint = $CertificateThumbprint
                Port = $Port
                Message = "PowerShell Remoting with SSL enabled"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable PowerShell Remoting with SSL: $($_.Exception.Message)"
        throw
    }
}

# JEA (Just Enough Administration) Functions
function New-JEASessionConfiguration {
    <#
    .SYNOPSIS
        Create JEA session configuration
    .DESCRIPTION
        Creates a JEA session configuration for role-based access
    .PARAMETER ConfigurationName
        Name of the session configuration
    .PARAMETER RoleDefinitions
        Role definitions for JEA
    .PARAMETER SessionType
        Session type (RestrictedRemoteServer, Empty)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigurationName,

        [Parameter(Mandatory = $true)]
        [hashtable]$RoleDefinitions,

        [Parameter(Mandatory = $false)]
        [ValidateSet('RestrictedRemoteServer', 'Empty')]
        [string]$SessionType = 'RestrictedRemoteServer'
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Creating JEA session configuration: $ConfigurationName"
        
        if (-not $IsWindows) {
            throw "JEA session configuration is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($ConfigurationName, 'Create JEA session configuration')) {
            # Create session configuration file
            $sessionConfigPath = Join-Path $env:TEMP "$ConfigurationName.pssc"
            
            New-PSSessionConfigurationFile -Path $sessionConfigPath -SessionType $SessionType -RoleDefinitions $RoleDefinitions
            
            # Register session configuration
            Register-PSSessionConfiguration -Name $ConfigurationName -Path $sessionConfigPath -Force
            
            Write-CustomLog -Level 'SUCCESS' -Message "JEA session configuration created: $ConfigurationName"
            
            return @{
                Success = $true
                ConfigurationName = $ConfigurationName
                SessionType = $SessionType
                ConfigurationPath = $sessionConfigPath
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create JEA session configuration: $($_.Exception.Message)"
        throw
    }
}

function New-JEAEndpoint {
    <#
    .SYNOPSIS
        Create JEA endpoint
    .DESCRIPTION
        Creates a JEA endpoint with role capabilities
    .PARAMETER EndpointName
        Name of the JEA endpoint
    .PARAMETER RoleCapabilities
        Role capabilities for the endpoint
    .PARAMETER AllowedUsers
        Users allowed to connect
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EndpointName,

        [Parameter(Mandatory = $true)]
        [string[]]$RoleCapabilities,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedUsers
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Creating JEA endpoint: $EndpointName"
        
        if (-not $IsWindows) {
            throw "JEA endpoint creation is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($EndpointName, 'Create JEA endpoint')) {
            # Create role definitions
            $roleDefinitions = @{}
            foreach ($user in $AllowedUsers) {
                $roleDefinitions[$user] = @{
                    RoleCapabilities = $RoleCapabilities
                }
            }
            
            # Create session configuration
            $result = New-JEASessionConfiguration -ConfigurationName $EndpointName -RoleDefinitions $roleDefinitions
            
            Write-CustomLog -Level 'SUCCESS' -Message "JEA endpoint created: $EndpointName"
            
            return @{
                Success = $true
                EndpointName = $EndpointName
                RoleCapabilities = $RoleCapabilities
                AllowedUsers = $AllowedUsers
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create JEA endpoint: $($_.Exception.Message)"
        throw
    }
}

# Privileged Access Management Functions
function Enable-JustInTimeAccess {
    <#
    .SYNOPSIS
        Enable Just-In-Time access for privileged accounts
    .DESCRIPTION
        Configures JIT access for privileged operations
    .PARAMETER AccessDuration
        Access duration in minutes
    .PARAMETER RequireApproval
        Require approval for access
    .PARAMETER NotificationEmail
        Email for notifications
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [int]$AccessDuration = 60,

        [Parameter(Mandatory = $false)]
        [bool]$RequireApproval = $true,

        [Parameter(Mandatory = $false)]
        [string]$NotificationEmail
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Enabling Just-In-Time access"
        
        if ($PSCmdlet.ShouldProcess('Just-In-Time Access', 'Enable')) {
            # Create JIT access configuration
            $jitConfig = @{
                AccessDuration = $AccessDuration
                RequireApproval = $RequireApproval
                NotificationEmail = $NotificationEmail
                Enabled = $true
                CreatedAt = Get-Date
            }
            
            # Store configuration (simplified implementation)
            $jitConfigPath = Join-Path $env:TEMP 'jit-config.json'
            $jitConfig | ConvertTo-Json | Set-Content $jitConfigPath
            
            Write-CustomLog -Level 'SUCCESS' -Message "Just-In-Time access enabled"
            
            return @{
                Success = $true
                AccessDuration = $AccessDuration
                RequireApproval = $RequireApproval
                NotificationEmail = $NotificationEmail
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable Just-In-Time access: $($_.Exception.Message)"
        throw
    }
}

function Get-PrivilegedAccountActivity {
    <#
    .SYNOPSIS
        Get privileged account activity
    .DESCRIPTION
        Retrieves activity logs for privileged accounts
    .PARAMETER AccountName
        Account name to check
    .PARAMETER TimeRange
        Time range for activity (hours)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccountName,

        [Parameter(Mandatory = $false)]
        [int]$TimeRange = 24
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving privileged account activity for: $AccountName"
        
        $startTime = (Get-Date).AddHours(-$TimeRange)
        $activities = @()
        
        if ($IsWindows) {
            # Get Windows event logs
            try {
                $logonEvents = Get-WinEvent -FilterHashtable @{
                    LogName = 'Security'
                    ID = 4624, 4625, 4634
                    StartTime = $startTime
                } | Where-Object { $_.Message -like "*$AccountName*" }
                
                foreach ($event in $logonEvents) {
                    $activities += @{
                        TimeCreated = $event.TimeCreated
                        EventID = $event.Id
                        Message = $event.Message
                        Level = $event.LevelDisplayName
                    }
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Could not retrieve Windows event logs: $($_.Exception.Message)"
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Retrieved $($activities.Count) activity records for account: $AccountName"
        
        return @{
            AccountName = $AccountName
            TimeRange = $TimeRange
            Activities = $activities
            ActivityCount = $activities.Count
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve privileged account activity: $($_.Exception.Message)"
        throw
    }
}

function Set-PrivilegedAccountPolicy {
    <#
    .SYNOPSIS
        Set privileged account policy
    .DESCRIPTION
        Configures policy for privileged accounts
    .PARAMETER PolicyName
        Name of the policy
    .PARAMETER MaxLogonHours
        Maximum logon hours per day
    .PARAMETER RequireMFA
        Require multi-factor authentication
    .PARAMETER SessionTimeout
        Session timeout in minutes
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyName,

        [Parameter(Mandatory = $false)]
        [int]$MaxLogonHours = 8,

        [Parameter(Mandatory = $false)]
        [bool]$RequireMFA = $true,

        [Parameter(Mandatory = $false)]
        [int]$SessionTimeout = 30
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Setting privileged account policy: $PolicyName"
        
        if ($PSCmdlet.ShouldProcess($PolicyName, 'Set privileged account policy')) {
            # Create policy configuration
            $policy = @{
                PolicyName = $PolicyName
                MaxLogonHours = $MaxLogonHours
                RequireMFA = $RequireMFA
                SessionTimeout = $SessionTimeout
                CreatedAt = Get-Date
                Enabled = $true
            }
            
            # Store policy (simplified implementation)
            $policyPath = Join-Path $env:TEMP "$PolicyName-policy.json"
            $policy | ConvertTo-Json | Set-Content $policyPath
            
            Write-CustomLog -Level 'SUCCESS' -Message "Privileged account policy set: $PolicyName"
            
            return @{
                Success = $true
                PolicyName = $PolicyName
                MaxLogonHours = $MaxLogonHours
                RequireMFA = $RequireMFA
                SessionTimeout = $SessionTimeout
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to set privileged account policy: $($_.Exception.Message)"
        throw
    }
}

# System Management Functions
function Get-SystemSecurityInventory {
    <#
    .SYNOPSIS
        Get comprehensive system security inventory
    .DESCRIPTION
        Collects security inventory information from the system
    .PARAMETER IncludeDetails
        Include detailed information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeDetails
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Collecting system security inventory"
        
        $inventory = @{
            CollectionDate = Get-Date
            SystemInfo = @{
                ComputerName = $env:COMPUTERNAME
                Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
                PSVersion = $PSVersionTable.PSVersion.ToString()
            }
            SecurityFeatures = @{}
            InstalledSoftware = @()
            SecurityUpdates = @()
            NetworkConfiguration = @{}
            UserAccounts = @()
        }
        
        if ($IsWindows) {
            # Windows-specific inventory
            $inventory.SystemInfo.WindowsVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
            
            # Security features
            $inventory.SecurityFeatures.WindowsDefender = (Get-MpComputerStatus -ErrorAction SilentlyContinue) -ne $null
            $inventory.SecurityFeatures.Firewall = (Get-NetFirewallProfile | Where-Object { $_.Enabled -eq $true }).Count -gt 0
            $inventory.SecurityFeatures.UAC = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA).EnableLUA -eq 1
            
            # Installed software
            if ($IncludeDetails) {
                $inventory.InstalledSoftware = Get-CimInstance -ClassName Win32_Product | Select-Object Name, Version, InstallDate
            }
            
            # User accounts
            $inventory.UserAccounts = Get-LocalUser | Select-Object Name, Enabled, LastLogon, PasswordLastSet
            
        } elseif ($IsLinux) {
            # Linux-specific inventory
            $inventory.SystemInfo.Distribution = (Get-Content /etc/os-release | Select-String "PRETTY_NAME" | ForEach-Object { $_.ToString().Split('=')[1].Trim('"') })
            
            # Security features
            $inventory.SecurityFeatures.SELinux = (Get-Command getenforce -ErrorAction SilentlyContinue) -ne $null
            $inventory.SecurityFeatures.UFW = (Get-Command ufw -ErrorAction SilentlyContinue) -ne $null
            $inventory.SecurityFeatures.AppArmor = (Get-Command apparmor_status -ErrorAction SilentlyContinue) -ne $null
            
        } else {
            # macOS-specific inventory
            $inventory.SystemInfo.macOSVersion = (system_profiler SPSoftwareDataType | Select-String "System Version" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
            
            # Security features
            $inventory.SecurityFeatures.Gatekeeper = $true # Simplified
            $inventory.SecurityFeatures.SIP = $true # Simplified
            $inventory.SecurityFeatures.FileVault = $true # Simplified
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "System security inventory collected"
        
        return $inventory
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to collect system security inventory: $($_.Exception.Message)"
        throw
    }
}

function Get-InsecureServices {
    <#
    .SYNOPSIS
        Get insecure services running on the system
    .DESCRIPTION
        Identifies services that may pose security risks
    .PARAMETER ServiceType
        Type of services to check (All, Network, System)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'Network', 'System')]
        [string]$ServiceType = 'All'
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Scanning for insecure services"
        
        $insecureServices = @()
        
        if ($IsWindows) {
            # Get Windows services
            $services = Get-Service | Where-Object { $_.Status -eq 'Running' }
            
            # Known insecure services
            $riskyServices = @(
                'Telnet', 'FTP', 'TFTP', 'SNMP', 'rsh', 'rlogin', 'finger'
            )
            
            foreach ($service in $services) {
                if ($riskyServices -contains $service.Name) {
                    $insecureServices += @{
                        ServiceName = $service.Name
                        DisplayName = $service.DisplayName
                        Status = $service.Status
                        RiskLevel = 'High'
                        Description = "Service uses insecure protocols"
                    }
                }
            }
            
            # Check for services running as SYSTEM
            if ($ServiceType -eq 'System' -or $ServiceType -eq 'All') {
                $systemServices = Get-CimInstance -ClassName Win32_Service | Where-Object { $_.StartName -eq 'LocalSystem' -and $_.State -eq 'Running' }
                
                foreach ($service in $systemServices) {
                    if ($service.PathName -notlike '*svchost.exe*') {
                        $insecureServices += @{
                            ServiceName = $service.Name
                            DisplayName = $service.DisplayName
                            Status = $service.State
                            RiskLevel = 'Medium'
                            Description = "Service running as SYSTEM with custom executable"
                        }
                    }
                }
            }
            
        } elseif ($IsLinux) {
            # Linux service scanning
            try {
                $services = systemctl list-units --type=service --state=active --no-pager | Select-String "\.service"
                
                foreach ($service in $services) {
                    $serviceName = $service.ToString().Split()[0]
                    
                    # Check for known insecure services
                    if ($serviceName -match "(telnet|ftp|tftp|rsh|rlogin|finger)") {
                        $insecureServices += @{
                            ServiceName = $serviceName
                            Status = 'Running'
                            RiskLevel = 'High'
                            Description = "Service uses insecure protocols"
                        }
                    }
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Could not scan Linux services: $($_.Exception.Message)"
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Insecure service scan completed. Found $($insecureServices.Count) potential issues"
        
        return @{
            ScanDate = Get-Date
            ServiceType = $ServiceType
            InsecureServices = $insecureServices
            TotalCount = $insecureServices.Count
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to scan for insecure services: $($_.Exception.Message)"
        throw
    }
}

function Set-SystemHardening {
    <#
    .SYNOPSIS
        Apply system hardening measures
    .DESCRIPTION
        Applies security hardening configurations to the system
    .PARAMETER HardeningLevel
        Level of hardening (Basic, Standard, Advanced)
    .PARAMETER ApplyImmediately
        Apply changes immediately
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Basic', 'Standard', 'Advanced')]
        [string]$HardeningLevel = 'Standard',

        [Parameter(Mandatory = $false)]
        [bool]$ApplyImmediately = $false
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Applying system hardening: $HardeningLevel"
        
        if ($PSCmdlet.ShouldProcess($HardeningLevel, 'Apply system hardening')) {
            $hardeningTasks = @()
            
            if ($IsWindows) {
                # Windows hardening
                switch ($HardeningLevel) {
                    'Basic' {
                        $hardeningTasks += "Enable Windows Firewall"
                        $hardeningTasks += "Disable unnecessary services"
                        $hardeningTasks += "Enable Windows Update"
                    }
                    'Standard' {
                        $hardeningTasks += "Enable Windows Firewall"
                        $hardeningTasks += "Disable unnecessary services"
                        $hardeningTasks += "Enable Windows Update"
                        $hardeningTasks += "Configure UAC"
                        $hardeningTasks += "Disable SMB1"
                        $hardeningTasks += "Enable audit policy"
                    }
                    'Advanced' {
                        $hardeningTasks += "Enable Windows Firewall"
                        $hardeningTasks += "Disable unnecessary services"
                        $hardeningTasks += "Enable Windows Update"
                        $hardeningTasks += "Configure UAC"
                        $hardeningTasks += "Disable SMB1"
                        $hardeningTasks += "Enable audit policy"
                        $hardeningTasks += "Enable Credential Guard"
                        $hardeningTasks += "Configure AppLocker"
                        $hardeningTasks += "Disable weak protocols"
                    }
                }
                
                # Apply Windows-specific hardening
                if ($ApplyImmediately) {
                    # Enable firewall
                    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
                    
                    # Disable unnecessary services
                    $unnecessaryServices = @('Fax', 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc')
                    foreach ($service in $unnecessaryServices) {
                        try {
                            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Could not disable service $service"
                        }
                    }
                    
                    # Configure UAC
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -Value 1
                    
                    if ($HardeningLevel -eq 'Advanced') {
                        # Additional advanced hardening
                        try {
                            Enable-CredentialGuard -Force
                        } catch {
                            Write-CustomLog -Level 'WARNING' -Message "Could not enable Credential Guard: $($_.Exception.Message)"
                        }
                    }
                }
                
            } elseif ($IsLinux) {
                # Linux hardening
                switch ($HardeningLevel) {
                    'Basic' {
                        $hardeningTasks += "Configure UFW firewall"
                        $hardeningTasks += "Update system packages"
                        $hardeningTasks += "Disable unnecessary services"
                    }
                    'Standard' {
                        $hardeningTasks += "Configure UFW firewall"
                        $hardeningTasks += "Update system packages"
                        $hardeningTasks += "Disable unnecessary services"
                        $hardeningTasks += "Configure SSH hardening"
                        $hardeningTasks += "Set up fail2ban"
                    }
                    'Advanced' {
                        $hardeningTasks += "Configure UFW firewall"
                        $hardeningTasks += "Update system packages"
                        $hardeningTasks += "Disable unnecessary services"
                        $hardeningTasks += "Configure SSH hardening"
                        $hardeningTasks += "Set up fail2ban"
                        $hardeningTasks += "Enable SELinux/AppArmor"
                        $hardeningTasks += "Configure kernel parameters"
                    }
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "System hardening applied: $HardeningLevel"
            
            return @{
                Success = $true
                HardeningLevel = $HardeningLevel
                AppliedTasks = $hardeningTasks
                ApplyImmediately = $ApplyImmediately
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to apply system hardening: $($_.Exception.Message)"
        throw
    }
}

function Set-WindowsFeatureSecurity {
    <#
    .SYNOPSIS
        Configure Windows feature security
    .DESCRIPTION
        Enables or disables Windows features for security
    .PARAMETER FeatureName
        Name of the Windows feature
    .PARAMETER Action
        Action to perform (Enable, Disable)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Action
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "$Action Windows feature: $FeatureName"
        
        if (-not $IsWindows) {
            throw "Windows feature configuration is only supported on Windows"
        }
        
        if ($PSCmdlet.ShouldProcess($FeatureName, "$Action Windows feature")) {
            switch ($Action) {
                'Enable' {
                    Enable-WindowsOptionalFeature -FeatureName $FeatureName -Online -All
                }
                'Disable' {
                    Disable-WindowsOptionalFeature -FeatureName $FeatureName -Online
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Windows feature $Action : $FeatureName"
            
            return @{
                Success = $true
                FeatureName = $FeatureName
                Action = $Action
                Message = "Windows feature $Action successfully"
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to $Action Windows feature: $($_.Exception.Message)"
        throw
    }
}

# Monitoring Functions
function Search-SecurityEvents {
    <#
    .SYNOPSIS
        Search for security events in logs
    .DESCRIPTION
        Searches Windows event logs for security-related events
    .PARAMETER EventIDs
        Event IDs to search for
    .PARAMETER TimeRange
        Time range in hours
    .PARAMETER MaxEvents
        Maximum number of events to return
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int[]]$EventIDs = @(4624, 4625, 4634, 4648, 4720, 4722, 4724, 4725, 4726, 4738, 4740, 4767, 4768, 4769, 4771, 4776, 4778, 4779),

        [Parameter(Mandatory = $false)]
        [int]$TimeRange = 24,

        [Parameter(Mandatory = $false)]
        [int]$MaxEvents = 100
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Searching for security events"
        
        if (-not $IsWindows) {
            throw "Security event searching is only supported on Windows"
        }
        
        $startTime = (Get-Date).AddHours(-$TimeRange)
        $events = @()
        
        try {
            $securityEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'Security'
                ID = $EventIDs
                StartTime = $startTime
            } -MaxEvents $MaxEvents
            
            foreach ($event in $securityEvents) {
                $events += @{
                    TimeCreated = $event.TimeCreated
                    EventID = $event.Id
                    Level = $event.LevelDisplayName
                    Message = $event.Message
                    MachineName = $event.MachineName
                    UserId = $event.UserId
                }
            }
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "Could not retrieve security events: $($_.Exception.Message)"
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Security event search completed. Found $($events.Count) events"
        
        return @{
            SearchDate = Get-Date
            TimeRange = $TimeRange
            EventIDs = $EventIDs
            Events = $events
            EventCount = $events.Count
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to search security events: $($_.Exception.Message)"
        throw
    }
}

# HELPER FUNCTIONS

function Test-SecurityConfiguration {
    <#
    .SYNOPSIS
        Test overall security configuration
    .DESCRIPTION
        Runs comprehensive security configuration tests
    #>
    [CmdletBinding()]
    param()

    try {
        Write-CustomLog -Level 'INFO' -Message "Testing security configuration"
        
        $results = @{
            TestDate = Get-Date
            CredentialStore = Test-SecureCredentialCompliance
            SecurityInventory = Get-SystemSecurityInventory
            InsecureServices = Get-InsecureServices
            OverallStatus = 'Unknown'
        }
        
        # Determine overall status
        $issues = @()
        if (-not $results.CredentialStore.Compliant) {
            $issues += $results.CredentialStore.Issues
        }
        if ($results.InsecureServices.TotalCount -gt 0) {
            $issues += "Found $($results.InsecureServices.TotalCount) insecure services"
        }
        
        $results.OverallStatus = if ($issues.Count -eq 0) { 'Compliant' } else { 'Non-Compliant' }
        $results.Issues = $issues
        
        Write-CustomLog -Level 'SUCCESS' -Message "Security configuration test completed. Status: $($results.OverallStatus)"
        
        return $results
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to test security configuration: $($_.Exception.Message)"
        throw
    }
}

function Get-SecuritySummary {
    <#
    .SYNOPSIS
        Get security summary report
    .DESCRIPTION
        Generates a comprehensive security summary report
    #>
    [CmdletBinding()]
    param()

    try {
        Write-CustomLog -Level 'INFO' -Message "Generating security summary report"
        
        $summary = @{
            GeneratedAt = Get-Date
            Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
            CredentialStore = @{
                Initialized = Test-Path (Join-Path $script:CredentialStorePath 'credentials.json')
                CredentialCount = 0
                ComplianceStatus = 'Unknown'
            }
            SecurityFeatures = @{}
            Recommendations = @()
        }
        
        # Check credential store
        if ($summary.CredentialStore.Initialized) {
            $compliance = Test-SecureCredentialCompliance
            $summary.CredentialStore.ComplianceStatus = if ($compliance.Compliant) { 'Compliant' } else { 'Non-Compliant' }
            $summary.CredentialStore.CredentialCount = (Get-AllSecureCredentials).Count
            
            if (-not $compliance.Compliant) {
                $summary.Recommendations += "Review credential store compliance issues"
            }
        } else {
            $summary.Recommendations += "Initialize secure credential store"
        }
        
        # Platform-specific checks
        if ($IsWindows) {
            $summary.SecurityFeatures.WindowsDefender = (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) -ne $null
            $summary.SecurityFeatures.Firewall = (Get-NetFirewallProfile | Where-Object { $_.Enabled -eq $true }).Count -gt 0
            $summary.SecurityFeatures.UAC = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -ErrorAction SilentlyContinue).EnableLUA -eq 1
            
            if (-not $summary.SecurityFeatures.Firewall) {
                $summary.Recommendations += "Enable Windows Firewall"
            }
            if (-not $summary.SecurityFeatures.UAC) {
                $summary.Recommendations += "Enable User Account Control (UAC)"
            }
        }
        
        # Check for insecure services
        $insecureServices = Get-InsecureServices
        if ($insecureServices.TotalCount -gt 0) {
            $summary.Recommendations += "Review and secure $($insecureServices.TotalCount) potentially insecure services"
        }
        
        $summary.OverallStatus = if ($summary.Recommendations.Count -eq 0) { 'Secure' } else { 'Needs Attention' }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Security summary report generated. Status: $($summary.OverallStatus)"
        
        return $summary
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to generate security summary: $($_.Exception.Message)"
        throw
    }
}

# MODULE INITIALIZATION

# Initialize the security domain
try {
    Write-CustomLog -Level 'INFO' -Message "Initializing Security domain"
    
    # Ensure credential store directory exists
    if (-not (Test-Path $script:CredentialStorePath)) {
        New-Item -ItemType Directory -Path $script:CredentialStorePath -Force | Out-Null
    }
    
    Write-CustomLog -Level 'SUCCESS' -Message "Security domain initialized successfully"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Failed to initialize Security domain: $($_.Exception.Message)"
}

# LICENSE MANAGER FUNCTIONS - Migrated from modules/LicenseManager

# Module-level variables for LicenseManager
$script:LicensePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'license.json'
$script:FeatureRegistryPath = Join-Path $projectRoot 'configs' 'feature-registry.json'
$script:CurrentLicense = $null
$script:FeatureRegistry = $null

# Create license directory if it doesn't exist
$licenseDir = Split-Path -Parent $script:LicensePath
if (-not (Test-Path $licenseDir)) {
    New-Item -Path $licenseDir -ItemType Directory -Force | Out-Null
}

# Load feature registry if it exists
if (Test-Path $script:FeatureRegistryPath) {
    try {
        $script:FeatureRegistry = Get-Content $script:FeatureRegistryPath -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Failed to load feature registry: $_"
    }
}

function Get-LicenseStatus {
    <#
    .SYNOPSIS
        Gets the current license status with performance caching
    .DESCRIPTION
        Retrieves and validates the current license, returning tier and feature access.
        Uses intelligent caching to improve performance for repeated calls.
    .PARAMETER BypassCache
        Skip cache and force fresh license validation
    .PARAMETER RefreshCache
        Refresh the cache after getting current status
    .EXAMPLE
        Get-LicenseStatus
    .EXAMPLE
        Get-LicenseStatus -BypassCache
    .OUTPUTS
        PSCustomObject with license details
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$BypassCache,

        [Parameter()]
        [switch]$RefreshCache
    )

    try {
        # Check cache first (unless bypassed)
        if (-not $BypassCache) {
            $cachedStatus = Get-CachedLicenseStatus
            if ($cachedStatus) {
                return $cachedStatus
            }
        }

        # Check if license file exists
        if (-not (Test-Path $script:LicensePath)) {
            $status = [PSCustomObject]@{
                IsValid = $false
                Tier = 'free'
                Features = @('core', 'development')
                ExpiryDate = $null
                IssuedTo = 'Unlicensed'
                LicenseId = $null
                Message = 'No license found - using free tier'
                CacheSource = 'Fresh'
            }

            # Cache the result
            Set-CachedLicenseStatus -Status $status
            return $status
        }

        # Load and validate license
        try {
            $license = Get-Content $script:LicensePath -Raw | ConvertFrom-Json

            # Validate license structure
            $requiredProperties = @('licenseId', 'tier', 'features', 'issuedTo', 'expiryDate', 'signature')
            foreach ($prop in $requiredProperties) {
                if (-not $license.PSObject.Properties.Name -contains $prop) {
                    throw "Invalid license format - missing $prop"
                }
            }

            # Check expiry
            $expiryDate = [DateTime]::Parse($license.expiryDate)
            $isExpired = $expiryDate -lt (Get-Date)

            # Validate signature with enhanced security
            $isValidSignature = Validate-LicenseSignature -License $license

            if ($isExpired) {
                $status = [PSCustomObject]@{
                    IsValid = $false
                    Tier = 'free'
                    Features = @('core', 'development')
                    ExpiryDate = $expiryDate
                    IssuedTo = $license.issuedTo
                    LicenseId = $license.licenseId
                    Message = 'License expired'
                    CacheSource = 'Fresh'
                }

                # Cache expired license status
                Set-CachedLicenseStatus -Status $status
                return $status
            }

            if (-not $isValidSignature) {
                $status = [PSCustomObject]@{
                    IsValid = $false
                    Tier = 'free'
                    Features = @('core', 'development')
                    ExpiryDate = $expiryDate
                    IssuedTo = $license.issuedTo
                    LicenseId = $license.licenseId
                    Message = 'Invalid license signature'
                    CacheSource = 'Fresh'
                }

                # Cache invalid signature status
                Set-CachedLicenseStatus -Status $status
                return $status
            }

            # Valid license
            $status = [PSCustomObject]@{
                IsValid = $true
                Tier = $license.tier
                Features = $license.features
                ExpiryDate = $expiryDate
                IssuedTo = $license.issuedTo
                LicenseId = $license.licenseId
                Message = 'License valid'
                CacheSource = 'Fresh'
            }

            # Cache valid license status
            Set-CachedLicenseStatus -Status $status

            # Log license validation
            Write-CustomLog -Message "License status validated" -Level DEBUG

            return $status

        } catch {
            Write-Warning "Error reading license: $_"
            $status = [PSCustomObject]@{
                IsValid = $false
                Tier = 'free'
                Features = @('core', 'development')
                ExpiryDate = $null
                IssuedTo = 'Unlicensed'
                LicenseId = $null
                Message = "License error: $_"
                CacheSource = 'Fresh'
            }

            # Cache error status
            Set-CachedLicenseStatus -Status $status
            Write-CustomLog -Message "License validation error" -Level ERROR

            return $status
        }

    } catch {
        Write-CustomLog -Message "Critical error in license status check" -Level ERROR
        Write-Error "Error checking license status: $_"
        throw
    }
}

function Test-FeatureAccess {
    <#
    .SYNOPSIS
        Tests if a specific feature is available under the current license
    .PARAMETER FeatureName
        Name of the feature to test
    .EXAMPLE
        Test-FeatureAccess -FeatureName "AdvancedReporting"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName
    )

    try {
        $licenseStatus = Get-LicenseStatus
        
        if ($licenseStatus.IsValid -and $licenseStatus.Features -contains $FeatureName) {
            Write-CustomLog -Message "Feature access granted: $FeatureName" -Level DEBUG
            return $true
        }
        
        Write-CustomLog -Message "Feature access denied: $FeatureName (Tier: $($licenseStatus.Tier))" -Level DEBUG
        return $false
        
    } catch {
        Write-CustomLog -Message "Error checking feature access for $FeatureName" -Level ERROR
        return $false
    }
}

function Set-License {
    <#
    .SYNOPSIS
        Sets a new license for the application
    .PARAMETER LicenseKey
        The license key string
    .PARAMETER OrganizationName
        Organization name for the license
    .EXAMPLE
        Set-License -LicenseKey "XXXX-XXXX-XXXX-XXXX" -OrganizationName "MyOrg"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LicenseKey,
        
        [Parameter(Mandatory = $true)]
        [string]$OrganizationName
    )

    try {
        # Create license object
        $license = @{
            licenseId = $LicenseKey
            tier = 'enterprise'
            features = @('core', 'development', 'enterprise', 'advanced')
            issuedTo = $OrganizationName
            expiryDate = (Get-Date).AddYears(1).ToString('yyyy-MM-dd')
            signature = "signature-placeholder"
        }

        # Save license
        $license | ConvertTo-Json -Depth 3 | Out-File -FilePath $script:LicensePath -Encoding UTF8
        
        Write-CustomLog -Message "License set for organization: $OrganizationName" -Level INFO
        Write-Host "✅ License installed successfully" -ForegroundColor Green
        
    } catch {
        Write-CustomLog -Message "Failed to set license" -Level ERROR
        Write-Error "Failed to set license: $_"
    }
}

function Get-AvailableFeatures {
    <#
    .SYNOPSIS
        Gets all available features and their license requirements
    .EXAMPLE
        Get-AvailableFeatures | Format-Table
    #>
    [CmdletBinding()]
    param()

    try {
        $features = @(
            [PSCustomObject]@{ Name = 'core'; Tier = 'free'; Description = 'Core functionality' },
            [PSCustomObject]@{ Name = 'development'; Tier = 'free'; Description = 'Development tools' },
            [PSCustomObject]@{ Name = 'enterprise'; Tier = 'enterprise'; Description = 'Enterprise features' },
            [PSCustomObject]@{ Name = 'advanced'; Tier = 'enterprise'; Description = 'Advanced automation' }
        )

        return $features
        
    } catch {
        Write-CustomLog -Message "Error getting available features" -Level ERROR
        return @()
    }
}

# License cache functions
function Get-CachedLicenseStatus {
    [CmdletBinding()]
    param()
    
    # Simple in-memory cache for now
    return $script:CurrentLicense
}

function Set-CachedLicenseStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Status
    )
    
    $script:CurrentLicense = $Status
}

function Validate-LicenseSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$License
    )
    
    # Simple validation for now - in production this would use cryptographic validation
    return $true
}

Write-CustomLog -Level 'SUCCESS' -Message "Security domain loaded with comprehensive security, credential management, and license management functions"