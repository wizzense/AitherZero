@{
    RootModule = 'SecurityAutomation.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a7b8c9d0-e1f2-3456-7890-abcdef123456'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero Project'
    Copyright = '(c) 2025 AitherZero Project. All rights reserved.'
    Description = 'PowerShell security automation module for enterprise security management'
    PowerShellVersion = '7.0'
    # RequiredModules = @()
    # Note: ActiveDirectory module is optional and only required for AD-specific functions.
    # Functions that need ActiveDirectory will check for its availability at runtime.
    FunctionsToExport = @(
        # Active Directory
        'Get-ADSecurityAssessment',
        'Set-ADPasswordPolicy', 
        'Enable-ADSmartCardLogon',
        'Get-ADDelegationRisks',
        
        # Certificate Services
        'Install-EnterpriseCA',
        'New-CertificateTemplate',
        'Enable-CertificateAutoEnrollment',
        'Test-PKIHealth',
        
        # Endpoint Hardening
        'Set-WindowsFirewallProfile',
        'Enable-AdvancedAuditPolicy',
        'Set-AppLockerPolicy',
        'Enable-CredentialGuard',
        
        # Network Security
        'Set-IPsecPolicy',
        'Enable-DNSSECValidation',
        'Disable-WeakProtocols',
        'Set-SMBSecurity',
        'Set-DNSSinkhole',
        
        # Remote Administration
        'Enable-PowerShellRemotingSSL',
        'New-JEAEndpoint',
        'Set-WinRMSecurity',
        'Test-RemoteSecurityPosture',
        
        # System Management
        'Get-SystemSecurityInventory',
        
        # Monitoring and Analysis
        'Search-SecurityEvents',
        
        # System Hardening
        'Set-SystemHardening',
        'Get-InsecureServices',
        'Enable-ExploitProtection',
        'Set-WindowsFeatureSecurity',
        
        # Privileged Access Management
        'New-JEASessionConfiguration',
        'Set-PrivilegedAccountPolicy',
        'Get-PrivilegedAccountActivity',
        'Enable-JustInTimeAccess'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Security', 'ActiveDirectory', 'PKI', 'Firewall', 'Hardening', 'Enterprise', 'Compliance')
            ProjectUri = 'https://github.com/Aitherium/AitherZero'
            RequireLicenseAcceptance = $false
        }
    }
    HelpInfoURI = 'https://github.com/Aitherium/AitherZero/docs/SecurityAutomation'
}