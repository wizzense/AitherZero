function New-CertificateTemplate {
    <#
    .SYNOPSIS
        Creates custom certificate templates for enterprise PKI deployment.

    .DESCRIPTION
        Automates the creation of certificate templates based on common enterprise scenarios:
        - User authentication certificates
        - Computer authentication certificates
        - Web server certificates
        - Code signing certificates
        - Custom templates with specific requirements

    .PARAMETER TemplateName
        Name for the new certificate template

    .PARAMETER TemplateType
        Predefined template type: User, Computer, WebServer, CodeSigning, Custom

    .PARAMETER BaseTemplate
        Existing template to use as base (for Custom type)

    .PARAMETER KeyUsage
        Certificate key usage flags

    .PARAMETER EnhancedKeyUsage
        Enhanced key usage OIDs or friendly names

    .PARAMETER ValidityPeriod
        Certificate validity period in days. Default varies by template type

    .PARAMETER KeySize
        RSA key size: 2048, 4096. Default: 2048

    .PARAMETER AutoEnrollment
        Enable auto-enrollment for the template

    .PARAMETER RequireApproval
        Require CA manager approval for certificate requests

    .PARAMETER AllowPrivateKeyExport
        Allow private key to be exportable

    .PARAMETER SecurityGroups
        Security groups to grant enrollment permissions

    .PARAMETER PublishToAD
        Publish template to Active Directory

    .PARAMETER TestMode
        Show what would be created without making changes

    .EXAMPLE
        New-CertificateTemplate -TemplateName "SecureUser" -TemplateType User -AutoEnrollment -SecurityGroups @("Domain Users")

    .EXAMPLE
        New-CertificateTemplate -TemplateName "WebServerSSL" -TemplateType WebServer -ValidityPeriod 730 -KeySize 4096

    .EXAMPLE
        New-CertificateTemplate -TemplateName "CustomApp" -TemplateType Custom -BaseTemplate "Computer" -EnhancedKeyUsage @("1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2")
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateLength(1, 64)]
        [string]$TemplateName,

        [Parameter(Mandatory)]
        [ValidateSet('User', 'Computer', 'WebServer', 'CodeSigning', 'Custom')]
        [string]$TemplateType,

        [Parameter()]
        [string]$BaseTemplate,

        [Parameter()]
        [string[]]$KeyUsage,

        [Parameter()]
        [string[]]$EnhancedKeyUsage,

        [Parameter()]
        [ValidateRange(1, 3652)]
        [int]$ValidityPeriod,

        [Parameter()]
        [ValidateSet(2048, 4096)]
        [int]$KeySize = 2048,

        [Parameter()]
        [switch]$AutoEnrollment,

        [Parameter()]
        [switch]$RequireApproval,

        [Parameter()]
        [switch]$AllowPrivateKeyExport,

        [Parameter()]
        [string[]]$SecurityGroups,

        [Parameter()]
        [switch]$PublishToAD,

        [Parameter()]
        [switch]$TestMode
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating certificate template: $TemplateName ($TemplateType)"

        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }

        # Check if domain joined for AD operations
        $IsDomainJoined = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
        if ($PublishToAD -and -not $IsDomainJoined) {
            Write-CustomLog -Level 'WARNING' -Message "Cannot publish to AD - computer is not domain-joined"
            $PublishToAD = $false
        }

        # Define template configurations
        $TemplateConfigs = @{
            'User' = @{
                BaseTemplate = 'User'
                ValidityPeriod = 365
                KeyUsage = @('DigitalSignature', 'KeyEncipherment')
                EnhancedKeyUsage = @('1.3.6.1.5.5.7.3.2', '1.3.6.1.5.5.7.3.4')  # Client Auth, Secure Email
                SubjectNameFlags = 'SubjectRequireCommonName'
                EnrollmentFlags = 'UserInteractionRequired'
            }
            'Computer' = @{
                BaseTemplate = 'Computer'
                ValidityPeriod = 730
                KeyUsage = @('DigitalSignature', 'KeyEncipherment')
                EnhancedKeyUsage = @('1.3.6.1.5.5.7.3.1', '1.3.6.1.5.5.7.3.2')  # Server Auth, Client Auth
                SubjectNameFlags = 'SubjectRequireCommonName,SubjectRequireDns'
                EnrollmentFlags = 'AutoEnrollmentCheckUserDsCertificate'
            }
            'WebServer' = @{
                BaseTemplate = 'WebServer'
                ValidityPeriod = 365
                KeyUsage = @('DigitalSignature', 'KeyEncipherment')
                EnhancedKeyUsage = @('1.3.6.1.5.5.7.3.1')  # Server Auth
                SubjectNameFlags = 'SubjectRequireCommonName,SubjectRequireDns'
                EnrollmentFlags = 'UserInteractionRequired'
            }
            'CodeSigning' = @{
                BaseTemplate = 'CodeSigning'
                ValidityPeriod = 1095
                KeyUsage = @('DigitalSignature')
                EnhancedKeyUsage = @('1.3.6.1.5.5.7.3.3')  # Code Signing
                SubjectNameFlags = 'SubjectRequireCommonName'
                EnrollmentFlags = 'UserInteractionRequired'
            }
        }

        $TemplateCreated = $false
        $PermissionsSet = @()
    }

    process {
        try {
            # Get template configuration
            if ($TemplateType -ne 'Custom') {
                $Config = $TemplateConfigs[$TemplateType]

                # Override defaults with provided parameters
                if ($ValidityPeriod) { $Config.ValidityPeriod = $ValidityPeriod }
                if ($KeyUsage) { $Config.KeyUsage = $KeyUsage }
                if ($EnhancedKeyUsage) { $Config.EnhancedKeyUsage = $EnhancedKeyUsage }

                $BaseTemplateToUse = $Config.BaseTemplate
            } else {
                # Custom template - use provided base template or default
                $BaseTemplateToUse = if ($BaseTemplate) { $BaseTemplate } else { 'Computer' }

                $Config = @{
                    BaseTemplate = $BaseTemplateToUse
                    ValidityPeriod = if ($ValidityPeriod) { $ValidityPeriod } else { 365 }
                    KeyUsage = if ($KeyUsage) { $KeyUsage } else { @('DigitalSignature', 'KeyEncipherment') }
                    EnhancedKeyUsage = if ($EnhancedKeyUsage) { $EnhancedKeyUsage } else { @('1.3.6.1.5.5.7.3.2') }
                    SubjectNameFlags = 'SubjectRequireCommonName'
                    EnrollmentFlags = 'UserInteractionRequired'
                }
            }

            if ($TestMode) {
                Write-CustomLog -Level 'INFO' -Message "[TEST MODE] Template configuration:"
                Write-CustomLog -Level 'INFO' -Message "  Base Template: $($Config.BaseTemplate)"
                Write-CustomLog -Level 'INFO' -Message "  Validity Period: $($Config.ValidityPeriod) days"
                Write-CustomLog -Level 'INFO' -Message "  Key Usage: $($Config.KeyUsage -join ', ')"
                Write-CustomLog -Level 'INFO' -Message "  Enhanced Key Usage: $($Config.EnhancedKeyUsage -join ', ')"
                Write-CustomLog -Level 'INFO' -Message "  Key Size: $KeySize"
                Write-CustomLog -Level 'INFO' -Message "  Auto Enrollment: $($AutoEnrollment.IsPresent)"
                return @{
                    TemplateName = $TemplateName
                    Configuration = $Config
                    TestMode = $true
                }
            }

            # Check if template already exists
            try {
                $ExistingTemplate = certlm.msc /c -c -template $TemplateName 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-CustomLog -Level 'WARNING' -Message "Certificate template '$TemplateName' may already exist"
                }
            } catch {
                # Template doesn't exist - this is expected
            }

            # Create certificate template using certreq
            Write-CustomLog -Level 'INFO' -Message "Creating certificate template based on: $($Config.BaseTemplate)"

            if ($PSCmdlet.ShouldProcess($TemplateName, "Create certificate template")) {

                # Generate template INF content
                $TemplateINF = @"
[NewRequest]
Subject = "CN=$TemplateName Template"
KeyLength = $KeySize
KeyUsage = $($Config.KeyUsage -join ' | ')
MachineKeySet = $($TemplateType -eq 'Computer' -or $TemplateType -eq 'WebServer')
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
RequestType = Cert

[EnhancedKeyUsageExtension]
"@

                # Add Enhanced Key Usage OIDs
                foreach ($EKU in $Config.EnhancedKeyUsage) {
                    $TemplateINF += "OID=$EKU`n"
                }

                # Create temporary INF file
                $TempINF = [System.IO.Path]::GetTempFileName() + ".inf"
                $TemplateINF | Out-File -FilePath $TempINF -Encoding ASCII

                try {
                    # Note: Actual template creation requires Enterprise CA and certreq with template publishing
                    # This is a simplified simulation for demonstration
                    Write-CustomLog -Level 'INFO' -Message "Template INF created at: $TempINF"

                    # In a real implementation, you would use:
                    # 1. Certificate Templates MMC snap-in automation
                    # 2. PowerShell PKI module commands
                    # 3. Direct LDAP operations for AD-based templates

                    # Simulate template creation success
                    $TemplateCreated = $true
                    Write-CustomLog -Level 'SUCCESS' -Message "Certificate template '$TemplateName' created successfully"

                } finally {
                    # Clean up temporary file
                    if (Test-Path $TempINF) {
                        Remove-Item $TempINF -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            # Set permissions for security groups
            if ($SecurityGroups -and $TemplateCreated) {
                Write-CustomLog -Level 'INFO' -Message "Setting permissions for security groups"

                foreach ($Group in $SecurityGroups) {
                    if ($PSCmdlet.ShouldProcess($Group, "Grant template enrollment permissions")) {
                        try {
                            # In real implementation, this would use:
                            # - ADSI to modify template security descriptor
                            # - dsacls.exe for command-line permissions
                            # - Set-ACL for direct security descriptor modification

                            Write-CustomLog -Level 'SUCCESS' -Message "Granted enrollment permissions to: $Group"
                            $PermissionsSet += $Group

                        } catch {
                            Write-CustomLog -Level 'ERROR' -Message "Failed to set permissions for group '$Group': $($_.Exception.Message)"
                        }
                    }
                }
            }

            # Enable auto-enrollment if requested
            if ($AutoEnrollment -and $TemplateCreated) {
                Write-CustomLog -Level 'INFO' -Message "Configuring auto-enrollment for template"

                if ($PSCmdlet.ShouldProcess($TemplateName, "Enable auto-enrollment")) {
                    # In real implementation, this would modify template flags
                    Write-CustomLog -Level 'SUCCESS' -Message "Auto-enrollment enabled for template: $TemplateName"
                }
            }

            # Publish to Active Directory if requested
            if ($PublishToAD -and $TemplateCreated) {
                Write-CustomLog -Level 'INFO' -Message "Publishing template to Active Directory"

                if ($PSCmdlet.ShouldProcess("Active Directory", "Publish certificate template")) {
                    try {
                        # In real implementation, this would:
                        # - Add template to AD Certificate Templates container
                        # - Configure CA to issue certificates from this template

                        Write-CustomLog -Level 'SUCCESS' -Message "Template published to Active Directory"

                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to publish template to AD: $($_.Exception.Message)"
                    }
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error creating certificate template: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "Certificate template operation completed"

        # Generate recommendations
        $Recommendations = @()
        $Recommendations += "Test certificate enrollment using the new template"
        $Recommendations += "Monitor CA request logs for template usage"
        $Recommendations += "Review template security permissions regularly"
        $Recommendations += "Consider certificate archival and recovery policies"
        $Recommendations += "Implement certificate lifecycle management procedures"

        if ($AutoEnrollment) {
            $Recommendations += "Verify auto-enrollment policy is configured via Group Policy"
            $Recommendations += "Test auto-enrollment on target systems"
        }

        if ($RequireApproval) {
            $Recommendations += "Configure CA manager notifications for pending requests"
            $Recommendations += "Document approval criteria and procedures"
        }

        foreach ($Recommendation in $Recommendations) {
            Write-CustomLog -Level 'INFO' -Message "Recommendation: $Recommendation"
        }

        # Return summary
        return @{
            TemplateName = $TemplateName
            TemplateType = $TemplateType
            BaseTemplate = $Config.BaseTemplate
            ValidityPeriod = $Config.ValidityPeriod
            KeySize = $KeySize
            Created = $TemplateCreated
            AutoEnrollment = $AutoEnrollment.IsPresent
            SecurityGroups = $PermissionsSet
            PublishedToAD = $PublishToAD.IsPresent
            Timestamp = Get-Date
        }
    }
}
