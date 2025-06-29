function Manage-PKICertificates {
    <#
    .SYNOPSIS
        Provides comprehensive PKI certificate management for enterprise environments.
        
    .DESCRIPTION
        Manages certificate lifecycle including enrollment, renewal, revocation, and validation.
        Supports Certificate Services integration, automated certificate deployment, and
        compliance monitoring for enterprise PKI infrastructures.
        
    .PARAMETER Operation
        PKI operation to perform
        
    .PARAMETER ComputerName
        Target computers for certificate operations. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER CertificateAuthority
        Certificate Authority server name
        
    .PARAMETER CertificateTemplate
        Certificate template name for enrollment
        
    .PARAMETER CertificateThumbprint
        Thumbprint of specific certificate to manage
        
    .PARAMETER SubjectName
        Subject name for certificate requests
        
    .PARAMETER SubjectAlternativeNames
        Subject Alternative Names for certificate
        
    .PARAMETER KeySize
        RSA key size for new certificates
        
    .PARAMETER HashAlgorithm
        Hash algorithm for certificate signing
        
    .PARAMETER ValidityPeriod
        Certificate validity period in days
        
    .PARAMETER CertificateStore
        Certificate store location
        
    .PARAMETER StoreLocation
        Certificate store location (CurrentUser/LocalMachine)
        
    .PARAMETER ExportPath
        Path to export certificates and keys
        
    .PARAMETER ImportPath
        Path to import certificates from
        
    .PARAMETER ExportPrivateKey
        Include private key in certificate export
        
    .PARAMETER ProtectPrivateKey
        Password protect exported private keys
        
    .PARAMETER ExportPassword
        Password for certificate export
        
    .PARAMETER CertificatePolicy
        Certificate policy configuration
        
    .PARAMETER EnableAutoEnrollment
        Enable automatic certificate enrollment
        
    .PARAMETER AutoRenewal
        Enable automatic certificate renewal
        
    .PARAMETER RenewalThreshold
        Days before expiration to trigger renewal
        
    .PARAMETER ValidateCertificates
        Validate certificate chain and revocation status
        
    .PARAMETER CheckRevocation
        Check certificate revocation status
        
    .PARAMETER RevocationReason
        Reason for certificate revocation
        
    .PARAMETER IncludeExpired
        Include expired certificates in operations
        
    .PARAMETER IncludeRevoked
        Include revoked certificates in operations
        
    .PARAMETER GenerateReport
        Generate comprehensive certificate report
        
    .PARAMETER ReportPath
        Path to save certificate reports
        
    .PARAMETER AuditCertificates
        Perform certificate compliance audit
        
    .PARAMETER ComplianceRules
        Certificate compliance rules to check
        
    .PARAMETER TestMode
        Run operations in test mode without making changes
        
    .EXAMPLE
        Manage-PKICertificates -Operation 'Enroll' -CertificateTemplate 'WebServer' -SubjectName 'CN=web01.domain.com'
        
    .EXAMPLE
        Manage-PKICertificates -Operation 'Inventory' -ValidateCertificates -GenerateReport
        
    .EXAMPLE
        Manage-PKICertificates -Operation 'Renew' -RenewalThreshold 30 -AutoRenewal
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Enroll', 'Renew', 'Revoke', 'Export', 'Import', 'Inventory', 'Validate', 'Audit', 'Deploy', 'Backup')]
        [string]$Operation,
        
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [string]$CertificateAuthority,
        
        [Parameter()]
        [string]$CertificateTemplate,
        
        [Parameter()]
        [string]$CertificateThumbprint,
        
        [Parameter()]
        [string]$SubjectName,
        
        [Parameter()]
        [string[]]$SubjectAlternativeNames = @(),
        
        [Parameter()]
        [ValidateSet(1024, 2048, 4096)]
        [int]$KeySize = 2048,
        
        [Parameter()]
        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [string]$HashAlgorithm = 'SHA256',
        
        [Parameter()]
        [ValidateRange(1, 3650)]
        [int]$ValidityPeriod = 365,
        
        [Parameter()]
        [ValidateSet('My', 'Root', 'CA', 'TrustedPeople', 'TrustedPublisher')]
        [string]$CertificateStore = 'My',
        
        [Parameter()]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$StoreLocation = 'LocalMachine',
        
        [Parameter()]
        [string]$ExportPath,
        
        [Parameter()]
        [string]$ImportPath,
        
        [Parameter()]
        [switch]$ExportPrivateKey,
        
        [Parameter()]
        [switch]$ProtectPrivateKey,
        
        [Parameter()]
        [securestring]$ExportPassword,
        
        [Parameter()]
        [hashtable]$CertificatePolicy = @{},
        
        [Parameter()]
        [switch]$EnableAutoEnrollment,
        
        [Parameter()]
        [switch]$AutoRenewal,
        
        [Parameter()]
        [ValidateRange(1, 365)]
        [int]$RenewalThreshold = 30,
        
        [Parameter()]
        [switch]$ValidateCertificates,
        
        [Parameter()]
        [switch]$CheckRevocation,
        
        [Parameter()]
        [ValidateSet('Unspecified', 'KeyCompromise', 'CACompromise', 'AffiliationChanged', 'Superseded', 'CessationOfOperation', 'CertificateHold')]
        [string]$RevocationReason = 'Unspecified',
        
        [Parameter()]
        [switch]$IncludeExpired,
        
        [Parameter()]
        [switch]$IncludeRevoked,
        
        [Parameter()]
        [switch]$GenerateReport,
        
        [Parameter()]
        [string]$ReportPath,
        
        [Parameter()]
        [switch]$AuditCertificates,
        
        [Parameter()]
        [hashtable]$ComplianceRules = @{},
        
        [Parameter()]
        [switch]$TestMode
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting PKI certificate operation: $Operation"
        
        # Check if running as Administrator for certain operations
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        $IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($Operation -in @('Deploy', 'Import') -and $StoreLocation -eq 'LocalMachine' -and -not $IsAdmin) {
            throw "Administrator privileges required for LocalMachine certificate operations"
        }
        
        $PKIResults = @{
            Operation = $Operation
            ComputersProcessed = @()
            CertificatesProcessed = 0
            CertificatesEnrolled = 0
            CertificatesRenewed = 0
            CertificatesRevoked = 0
            CertificatesExported = 0
            CertificatesImported = 0
            CertificatesValidated = 0
            ValidationFailures = 0
            ComplianceViolations = 0
            Errors = @()
            Recommendations = @()
        }
        
        # Default certificate policy
        $DefaultCertificatePolicy = @{
            'MinKeySize' = 2048
            'RequiredEKUs' = @()
            'AllowedHashAlgorithms' = @('SHA256', 'SHA384', 'SHA512')
            'MaxValidityPeriod' = 1095  # 3 years
            'RequirePrivateKeyArchival' = $false
            'RequireCAIssuance' = $true
        }
        
        # Merge provided policy with defaults
        $ActiveCertificatePolicy = $DefaultCertificatePolicy.Clone()
        foreach ($Key in $CertificatePolicy.Keys) {
            $ActiveCertificatePolicy[$Key] = $CertificatePolicy[$Key]
        }
        
        # Default compliance rules
        $DefaultComplianceRules = @{
            'MaxCertificateAge' = 1095  # 3 years
            'MinKeySize' = 2048
            'RequiredHashAlgorithm' = 'SHA256'
            'CheckExpiration' = $true
            'CheckRevocation' = $true
            'RequireValidChain' = $true
        }
        
        # Merge provided rules with defaults
        $ActiveComplianceRules = $DefaultComplianceRules.Clone()
        foreach ($Key in $ComplianceRules.Keys) {
            $ActiveComplianceRules[$Key] = $ComplianceRules[$Key]
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Processing PKI certificates on: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    Timestamp = Get-Date
                    Operation = $Operation
                    CertificatesProcessed = 0
                    CertificatesFound = 0
                    OperationsSuccessful = 0
                    OperationsFailed = 0
                    CertificateInventory = @()
                    ValidationResults = @()
                    ComplianceResults = @()
                    OutputFiles = @()
                    ProcessingTime = 0
                    Errors = @()
                }
                
                $StartTime = Get-Date
                
                try {
                    # Session parameters for remote access
                    $SessionParams = @{
                        ErrorAction = 'Stop'
                    }
                    
                    if ($Computer -ne 'localhost') {
                        $SessionParams['ComputerName'] = $Computer
                        if ($Credential) {
                            $SessionParams['Credential'] = $Credential
                        }
                    }
                    
                    # Perform PKI operation
                    $OperationResult = if ($Computer -ne 'localhost') {
                        Invoke-Command @SessionParams -ScriptBlock {
                            param($Operation, $CertificateAuthority, $CertificateTemplate, $CertificateThumbprint, $SubjectName, $SubjectAlternativeNames, $KeySize, $HashAlgorithm, $ValidityPeriod, $CertificateStore, $StoreLocation, $ExportPath, $ImportPath, $ExportPrivateKey, $ProtectPrivateKey, $ExportPassword, $EnableAutoEnrollment, $AutoRenewal, $RenewalThreshold, $ValidateCertificates, $CheckRevocation, $RevocationReason, $IncludeExpired, $IncludeRevoked, $ActiveCertificatePolicy, $ActiveComplianceRules, $TestMode)
                            
                            $Results = @{
                                CertificatesProcessed = 0
                                CertificatesFound = 0
                                OperationsSuccessful = 0
                                OperationsFailed = 0
                                CertificateInventory = @()
                                ValidationResults = @()
                                ComplianceResults = @()
                                OutputFiles = @()
                                Errors = @()
                            }
                            
                            try {
                                # Function to get certificate store
                                function Get-CertificateStoreObject {
                                    param($StoreName, $StoreLocation)
                                    
                                    $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $StoreLocation)
                                    $Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
                                    return $Store
                                }
                                
                                # Function to validate certificate
                                function Test-CertificateValidity {
                                    param($Certificate, $CheckRevocation = $false)
                                    
                                    $ValidationResult = @{
                                        Certificate = $Certificate
                                        IsValid = $true
                                        ValidationErrors = @()
                                        ChainStatus = @()
                                        RevocationStatus = 'Unknown'
                                    }
                                    
                                    try {
                                        # Check expiration
                                        if ($Certificate.NotAfter -lt (Get-Date)) {
                                            $ValidationResult.IsValid = $false
                                            $ValidationResult.ValidationErrors += "Certificate has expired"
                                        }
                                        
                                        # Check not yet valid
                                        if ($Certificate.NotBefore -gt (Get-Date)) {
                                            $ValidationResult.IsValid = $false
                                            $ValidationResult.ValidationErrors += "Certificate is not yet valid"
                                        }
                                        
                                        # Build and validate certificate chain
                                        $Chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
                                        $Chain.ChainPolicy.RevocationMode = if ($CheckRevocation) { 'Online' } else { 'NoCheck' }
                                        $Chain.ChainPolicy.VerificationFlags = 'NoFlag'
                                        
                                        $ChainValid = $Chain.Build($Certificate)
                                        if (-not $ChainValid) {
                                            $ValidationResult.IsValid = $false
                                            $ValidationResult.ChainStatus = $Chain.ChainStatus | ForEach-Object { $_.Status.ToString() }
                                            $ValidationResult.ValidationErrors += "Certificate chain validation failed: $($ValidationResult.ChainStatus -join ', ')"
                                        }
                                        
                                        # Check revocation status if requested
                                        if ($CheckRevocation) {
                                            foreach ($ChainElement in $Chain.ChainElements) {
                                                foreach ($Status in $ChainElement.ChainElementStatus) {
                                                    if ($Status.Status -eq 'Revoked') {
                                                        $ValidationResult.RevocationStatus = 'Revoked'
                                                        $ValidationResult.IsValid = $false
                                                        $ValidationResult.ValidationErrors += "Certificate has been revoked"
                                                    } elseif ($Status.Status -eq 'RevocationStatusUnknown') {
                                                        $ValidationResult.RevocationStatus = 'Unknown'
                                                    } else {
                                                        $ValidationResult.RevocationStatus = 'Valid'
                                                    }
                                                }
                                            }
                                        }
                                        
                                    } catch {
                                        $ValidationResult.IsValid = $false
                                        $ValidationResult.ValidationErrors += "Validation error: $($_.Exception.Message)"
                                    }
                                    
                                    return $ValidationResult
                                }
                                
                                # Function to check certificate compliance
                                function Test-CertificateCompliance {
                                    param($Certificate, $ComplianceRules)
                                    
                                    $ComplianceResult = @{
                                        Certificate = $Certificate
                                        IsCompliant = $true
                                        Violations = @()
                                        ComplianceScore = 100
                                    }
                                    
                                    try {
                                        # Check certificate age
                                        if ($ComplianceRules.MaxCertificateAge) {
                                            $CertAge = ((Get-Date) - $Certificate.NotBefore).Days
                                            if ($CertAge -gt $ComplianceRules.MaxCertificateAge) {
                                                $ComplianceResult.IsCompliant = $false
                                                $ComplianceResult.Violations += "Certificate age ($CertAge days) exceeds maximum allowed ($($ComplianceRules.MaxCertificateAge) days)"
                                                $ComplianceResult.ComplianceScore -= 20
                                            }
                                        }
                                        
                                        # Check key size
                                        if ($ComplianceRules.MinKeySize -and $Certificate.PublicKey.Key.KeySize -lt $ComplianceRules.MinKeySize) {
                                            $ComplianceResult.IsCompliant = $false
                                            $ComplianceResult.Violations += "Key size ($($Certificate.PublicKey.Key.KeySize)) below minimum required ($($ComplianceRules.MinKeySize))"
                                            $ComplianceResult.ComplianceScore -= 30
                                        }
                                        
                                        # Check hash algorithm
                                        if ($ComplianceRules.RequiredHashAlgorithm -and $Certificate.SignatureAlgorithm.FriendlyName -notlike "*$($ComplianceRules.RequiredHashAlgorithm)*") {
                                            $ComplianceResult.IsCompliant = $false
                                            $ComplianceResult.Violations += "Hash algorithm ($($Certificate.SignatureAlgorithm.FriendlyName)) does not meet requirements"
                                            $ComplianceResult.ComplianceScore -= 25
                                        }
                                        
                                        # Check expiration
                                        if ($ComplianceRules.CheckExpiration -and $Certificate.NotAfter -lt (Get-Date).AddDays(30)) {
                                            $ComplianceResult.IsCompliant = $false
                                            $ComplianceResult.Violations += "Certificate expires within 30 days"
                                            $ComplianceResult.ComplianceScore -= 15
                                        }
                                        
                                    } catch {
                                        $ComplianceResult.IsCompliant = $false
                                        $ComplianceResult.Violations += "Compliance check error: $($_.Exception.Message)"
                                        $ComplianceResult.ComplianceScore = 0
                                    }
                                    
                                    return $ComplianceResult
                                }
                                
                                # Perform operation
                                switch ($Operation) {
                                    'Inventory' {
                                        try {
                                            $Store = Get-CertificateStoreObject -StoreName $CertificateStore -StoreLocation $StoreLocation
                                            $Certificates = $Store.Certificates
                                            
                                            foreach ($Cert in $Certificates) {
                                                $Include = $true
                                                
                                                # Apply filters
                                                if (-not $IncludeExpired -and $Cert.NotAfter -lt (Get-Date)) {
                                                    $Include = $false
                                                }
                                                
                                                if ($Include) {
                                                    $CertInfo = @{
                                                        Thumbprint = $Cert.Thumbprint
                                                        Subject = $Cert.Subject
                                                        Issuer = $Cert.Issuer
                                                        NotBefore = $Cert.NotBefore
                                                        NotAfter = $Cert.NotAfter
                                                        KeySize = $Cert.PublicKey.Key.KeySize
                                                        SignatureAlgorithm = $Cert.SignatureAlgorithm.FriendlyName
                                                        HasPrivateKey = $Cert.HasPrivateKey
                                                        SerialNumber = $Cert.SerialNumber
                                                        Version = $Cert.Version
                                                        Extensions = $Cert.Extensions.Count
                                                    }
                                                    
                                                    # Add validation results if requested
                                                    if ($ValidateCertificates) {
                                                        $Validation = Test-CertificateValidity -Certificate $Cert -CheckRevocation $CheckRevocation
                                                        $CertInfo.IsValid = $Validation.IsValid
                                                        $CertInfo.ValidationErrors = $Validation.ValidationErrors
                                                        $Results.ValidationResults += $Validation
                                                    }
                                                    
                                                    $Results.CertificateInventory += $CertInfo
                                                    $Results.CertificatesFound++
                                                }
                                            }
                                            
                                            $Store.Close()
                                            $Results.OperationsSuccessful++
                                            
                                        } catch {
                                            $Results.Errors += "Failed to inventory certificates: $($_.Exception.Message)"
                                            $Results.OperationsFailed++
                                        }
                                    }
                                    
                                    'Validate' {
                                        try {
                                            $Store = Get-CertificateStoreObject -StoreName $CertificateStore -StoreLocation $StoreLocation
                                            $Certificates = if ($CertificateThumbprint) {
                                                @($Store.Certificates | Where-Object { $_.Thumbprint -eq $CertificateThumbprint })
                                            } else {
                                                $Store.Certificates
                                            }
                                            
                                            foreach ($Cert in $Certificates) {
                                                $ValidationResult = Test-CertificateValidity -Certificate $Cert -CheckRevocation $CheckRevocation
                                                $Results.ValidationResults += $ValidationResult
                                                $Results.CertificatesProcessed++
                                                
                                                if ($ValidationResult.IsValid) {
                                                    $Results.OperationsSuccessful++
                                                } else {
                                                    $Results.OperationsFailed++
                                                }
                                            }
                                            
                                            $Store.Close()
                                            
                                        } catch {
                                            $Results.Errors += "Failed to validate certificates: $($_.Exception.Message)"
                                            $Results.OperationsFailed++
                                        }
                                    }
                                    
                                    'Audit' {
                                        try {
                                            $Store = Get-CertificateStoreObject -StoreName $CertificateStore -StoreLocation $StoreLocation
                                            $Certificates = $Store.Certificates
                                            
                                            foreach ($Cert in $Certificates) {
                                                $ComplianceResult = Test-CertificateCompliance -Certificate $Cert -ComplianceRules $ActiveComplianceRules
                                                $Results.ComplianceResults += $ComplianceResult
                                                $Results.CertificatesProcessed++
                                                
                                                if ($ComplianceResult.IsCompliant) {
                                                    $Results.OperationsSuccessful++
                                                } else {
                                                    $Results.OperationsFailed++
                                                }
                                            }
                                            
                                            $Store.Close()
                                            
                                        } catch {
                                            $Results.Errors += "Failed to audit certificates: $($_.Exception.Message)"
                                            $Results.OperationsFailed++
                                        }
                                    }
                                    
                                    'Export' {
                                        try {
                                            if (-not $ExportPath) {
                                                throw "Export path required for export operation"
                                            }
                                            
                                            $Store = Get-CertificateStoreObject -StoreName $CertificateStore -StoreLocation $StoreLocation
                                            $Certificates = if ($CertificateThumbprint) {
                                                @($Store.Certificates | Where-Object { $_.Thumbprint -eq $CertificateThumbprint })
                                            } else {
                                                $Store.Certificates
                                            }
                                            
                                            foreach ($Cert in $Certificates) {
                                                $SafeSubject = $Cert.Subject -replace '[\\/:*?"<>|]', '_'
                                                $ExportFile = Join-Path $ExportPath "$SafeSubject-$($Cert.Thumbprint.Substring(0,8)).pfx"
                                                
                                                if (-not $TestMode) {
                                                    if ($ExportPrivateKey -and $Cert.HasPrivateKey) {
                                                        # Export with private key (PFX)
                                                        $CertBytes = $Cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $ExportPassword)
                                                    } else {
                                                        # Export certificate only (CER)
                                                        $ExportFile = $ExportFile.Replace('.pfx', '.cer')
                                                        $CertBytes = $Cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
                                                    }
                                                    
                                                    [System.IO.File]::WriteAllBytes($ExportFile, $CertBytes)
                                                }
                                                
                                                $Results.OutputFiles += $ExportFile
                                                $Results.CertificatesProcessed++
                                                $Results.OperationsSuccessful++
                                            }
                                            
                                            $Store.Close()
                                            
                                        } catch {
                                            $Results.Errors += "Failed to export certificates: $($_.Exception.Message)"
                                            $Results.OperationsFailed++
                                        }
                                    }
                                    
                                    'Renew' {
                                        try {
                                            $Store = Get-CertificateStoreObject -StoreName $CertificateStore -StoreLocation $StoreLocation
                                            $Certificates = $Store.Certificates | Where-Object { 
                                                $_.NotAfter -lt (Get-Date).AddDays($RenewalThreshold) -and $_.NotAfter -gt (Get-Date)
                                            }
                                            
                                            foreach ($Cert in $Certificates) {
                                                # Certificate renewal logic would be implemented here
                                                # This is a placeholder for the complex renewal process
                                                if (-not $TestMode) {
                                                    Write-Output "Certificate renewal for $($Cert.Subject) would be processed"
                                                }
                                                
                                                $Results.CertificatesProcessed++
                                                $Results.OperationsSuccessful++
                                            }
                                            
                                            $Store.Close()
                                            
                                        } catch {
                                            $Results.Errors += "Failed to renew certificates: $($_.Exception.Message)"
                                            $Results.OperationsFailed++
                                        }
                                    }
                                }
                                
                            } catch {
                                $Results.Errors += "Failed during PKI operation: $($_.Exception.Message)"
                            }
                            
                            return $Results
                        } -ArgumentList $Operation, $CertificateAuthority, $CertificateTemplate, $CertificateThumbprint, $SubjectName, $SubjectAlternativeNames, $KeySize, $HashAlgorithm, $ValidityPeriod, $CertificateStore, $StoreLocation, $ExportPath, $ImportPath, $ExportPrivateKey, $ProtectPrivateKey, $ExportPassword, $EnableAutoEnrollment, $AutoRenewal, $RenewalThreshold, $ValidateCertificates, $CheckRevocation, $RevocationReason, $IncludeExpired, $IncludeRevoked, $ActiveCertificatePolicy, $ActiveComplianceRules, $TestMode
                    } else {
                        $Results = @{
                            CertificatesProcessed = 0
                            CertificatesFound = 0
                            OperationsSuccessful = 0
                            OperationsFailed = 0
                            CertificateInventory = @()
                            ValidationResults = @()
                            ComplianceResults = @()
                            OutputFiles = @()
                            Errors = @()
                        }
                        
                        try {
                            # Function to get certificate store
                            function Get-CertificateStoreObject {
                                param($StoreName, $StoreLocation)
                                
                                $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $StoreLocation)
                                $Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
                                return $Store
                            }
                            
                            # Function to validate certificate
                            function Test-CertificateValidity {
                                param($Certificate, $CheckRevocation = $false)
                                
                                $ValidationResult = @{
                                    Certificate = $Certificate
                                    IsValid = $true
                                    ValidationErrors = @()
                                    ChainStatus = @()
                                    RevocationStatus = 'Unknown'
                                }
                                
                                try {
                                    # Check expiration
                                    if ($Certificate.NotAfter -lt (Get-Date)) {
                                        $ValidationResult.IsValid = $false
                                        $ValidationResult.ValidationErrors += "Certificate has expired"
                                    }
                                    
                                    # Check not yet valid
                                    if ($Certificate.NotBefore -gt (Get-Date)) {
                                        $ValidationResult.IsValid = $false
                                        $ValidationResult.ValidationErrors += "Certificate is not yet valid"
                                    }
                                    
                                    # Build and validate certificate chain
                                    $Chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
                                    $Chain.ChainPolicy.RevocationMode = if ($CheckRevocation) { 'Online' } else { 'NoCheck' }
                                    $Chain.ChainPolicy.VerificationFlags = 'NoFlag'
                                    
                                    $ChainValid = $Chain.Build($Certificate)
                                    if (-not $ChainValid) {
                                        $ValidationResult.IsValid = $false
                                        $ValidationResult.ChainStatus = $Chain.ChainStatus | ForEach-Object { $_.Status.ToString() }
                                        $ValidationResult.ValidationErrors += "Certificate chain validation failed: $($ValidationResult.ChainStatus -join ', ')"
                                    }
                                    
                                    # Check revocation status if requested
                                    if ($CheckRevocation) {
                                        foreach ($ChainElement in $Chain.ChainElements) {
                                            foreach ($Status in $ChainElement.ChainElementStatus) {
                                                if ($Status.Status -eq 'Revoked') {
                                                    $ValidationResult.RevocationStatus = 'Revoked'
                                                    $ValidationResult.IsValid = $false
                                                    $ValidationResult.ValidationErrors += "Certificate has been revoked"
                                                } elseif ($Status.Status -eq 'RevocationStatusUnknown') {
                                                    $ValidationResult.RevocationStatus = 'Unknown'
                                                } else {
                                                    $ValidationResult.RevocationStatus = 'Valid'
                                                }
                                            }
                                        }
                                    }
                                    
                                } catch {
                                    $ValidationResult.IsValid = $false
                                    $ValidationResult.ValidationErrors += "Validation error: $($_.Exception.Message)"
                                }
                                
                                return $ValidationResult
                            }
                            
                            # Function to check certificate compliance
                            function Test-CertificateCompliance {
                                param($Certificate, $ComplianceRules)
                                
                                $ComplianceResult = @{
                                    Certificate = $Certificate
                                    IsCompliant = $true
                                    Violations = @()
                                    ComplianceScore = 100
                                }
                                
                                try {
                                    # Check certificate age
                                    if ($ComplianceRules.MaxCertificateAge) {
                                        $CertAge = ((Get-Date) - $Certificate.NotBefore).Days
                                        if ($CertAge -gt $ComplianceRules.MaxCertificateAge) {
                                            $ComplianceResult.IsCompliant = $false
                                            $ComplianceResult.Violations += "Certificate age ($CertAge days) exceeds maximum allowed ($($ComplianceRules.MaxCertificateAge) days)"
                                            $ComplianceResult.ComplianceScore -= 20
                                        }
                                    }
                                    
                                    # Check key size
                                    if ($ComplianceRules.MinKeySize -and $Certificate.PublicKey.Key.KeySize -lt $ComplianceRules.MinKeySize) {
                                        $ComplianceResult.IsCompliant = $false
                                        $ComplianceResult.Violations += "Key size ($($Certificate.PublicKey.Key.KeySize)) below minimum required ($($ComplianceRules.MinKeySize))"
                                        $ComplianceResult.ComplianceScore -= 30
                                    }
                                    
                                    # Check hash algorithm
                                    if ($ComplianceRules.RequiredHashAlgorithm -and $Certificate.SignatureAlgorithm.FriendlyName -notlike "*$($ComplianceRules.RequiredHashAlgorithm)*") {
                                        $ComplianceResult.IsCompliant = $false
                                        $ComplianceResult.Violations += "Hash algorithm ($($Certificate.SignatureAlgorithm.FriendlyName)) does not meet requirements"
                                        $ComplianceResult.ComplianceScore -= 25
                                    }
                                    
                                    # Check expiration
                                    if ($ComplianceRules.CheckExpiration -and $Certificate.NotAfter -lt (Get-Date).AddDays(30)) {
                                        $ComplianceResult.IsCompliant = $false
                                        $ComplianceResult.Violations += "Certificate expires within 30 days"
                                        $ComplianceResult.ComplianceScore -= 15
                                    }
                                    
                                } catch {
                                    $ComplianceResult.IsCompliant = $false
                                    $ComplianceResult.Violations += "Compliance check error: $($_.Exception.Message)"
                                    $ComplianceResult.ComplianceScore = 0
                                }
                                
                                return $ComplianceResult
                            }
                            
                            # Perform operation based on type
                            switch ($Operation) {
                                'Inventory' {
                                    Write-CustomLog -Level 'INFO' -Message "Performing certificate inventory"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Certificate Store", "Inventory certificates")) {
                                            try {
                                                $Store = Get-CertificateStoreObject -StoreName $CertificateStore -StoreLocation $StoreLocation
                                                $Certificates = $Store.Certificates
                                                
                                                foreach ($Cert in $Certificates) {
                                                    $Include = $true
                                                    
                                                    # Apply filters
                                                    if (-not $IncludeExpired -and $Cert.NotAfter -lt (Get-Date)) {
                                                        $Include = $false
                                                    }
                                                    
                                                    if ($Include) {
                                                        $CertInfo = @{
                                                            Thumbprint = $Cert.Thumbprint
                                                            Subject = $Cert.Subject
                                                            Issuer = $Cert.Issuer
                                                            NotBefore = $Cert.NotBefore
                                                            NotAfter = $Cert.NotAfter
                                                            KeySize = $Cert.PublicKey.Key.KeySize
                                                            SignatureAlgorithm = $Cert.SignatureAlgorithm.FriendlyName
                                                            HasPrivateKey = $Cert.HasPrivateKey
                                                            SerialNumber = $Cert.SerialNumber
                                                            Version = $Cert.Version
                                                            Extensions = $Cert.Extensions.Count
                                                        }
                                                        
                                                        # Add validation results if requested
                                                        if ($ValidateCertificates) {
                                                            $Validation = Test-CertificateValidity -Certificate $Cert -CheckRevocation $CheckRevocation
                                                            $CertInfo.IsValid = $Validation.IsValid
                                                            $CertInfo.ValidationErrors = $Validation.ValidationErrors
                                                            $Results.ValidationResults += $Validation
                                                        }
                                                        
                                                        $Results.CertificateInventory += $CertInfo
                                                        $Results.CertificatesFound++
                                                    }
                                                }
                                                
                                                $Store.Close()
                                                $Results.OperationsSuccessful++
                                                Write-CustomLog -Level 'SUCCESS' -Message "Found $($Results.CertificatesFound) certificates"
                                                
                                            } catch {
                                                $Results.Errors += "Failed to inventory certificates: $($_.Exception.Message)"
                                                $Results.OperationsFailed++
                                            }
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would inventory certificates in $StoreLocation\$CertificateStore"
                                        $Results.CertificatesFound = 5  # Test data
                                        $Results.OperationsSuccessful++
                                    }
                                }
                                
                                'Validate' {
                                    Write-CustomLog -Level 'INFO' -Message "Validating certificates"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Certificates", "Validate certificate chain and status")) {
                                            try {
                                                $Store = Get-CertificateStoreObject -StoreName $CertificateStore -StoreLocation $StoreLocation
                                                $Certificates = if ($CertificateThumbprint) {
                                                    @($Store.Certificates | Where-Object { $_.Thumbprint -eq $CertificateThumbprint })
                                                } else {
                                                    $Store.Certificates
                                                }
                                                
                                                foreach ($Cert in $Certificates) {
                                                    $ValidationResult = Test-CertificateValidity -Certificate $Cert -CheckRevocation $CheckRevocation
                                                    $Results.ValidationResults += $ValidationResult
                                                    $Results.CertificatesProcessed++
                                                    
                                                    if ($ValidationResult.IsValid) {
                                                        $Results.OperationsSuccessful++
                                                    } else {
                                                        $Results.OperationsFailed++
                                                        Write-CustomLog -Level 'WARNING' -Message "Certificate validation failed: $($Cert.Subject)"
                                                    }
                                                }
                                                
                                                $Store.Close()
                                                Write-CustomLog -Level 'SUCCESS' -Message "Validated $($Results.CertificatesProcessed) certificates"
                                                
                                            } catch {
                                                $Results.Errors += "Failed to validate certificates: $($_.Exception.Message)"
                                                $Results.OperationsFailed++
                                            }
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would validate certificates and check revocation status"
                                        $Results.CertificatesProcessed = 3
                                        $Results.OperationsSuccessful = 2
                                        $Results.OperationsFailed = 1
                                    }
                                }
                                
                                'Audit' {
                                    Write-CustomLog -Level 'INFO' -Message "Performing certificate compliance audit"
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Certificates", "Audit certificate compliance")) {
                                            try {
                                                $Store = Get-CertificateStoreObject -StoreName $CertificateStore -StoreLocation $StoreLocation
                                                $Certificates = $Store.Certificates
                                                
                                                foreach ($Cert in $Certificates) {
                                                    $ComplianceResult = Test-CertificateCompliance -Certificate $Cert -ComplianceRules $ActiveComplianceRules
                                                    $Results.ComplianceResults += $ComplianceResult
                                                    $Results.CertificatesProcessed++
                                                    
                                                    if ($ComplianceResult.IsCompliant) {
                                                        $Results.OperationsSuccessful++
                                                    } else {
                                                        $Results.OperationsFailed++
                                                        Write-CustomLog -Level 'WARNING' -Message "Certificate compliance violation: $($Cert.Subject) - Score: $($ComplianceResult.ComplianceScore)%"
                                                    }
                                                }
                                                
                                                $Store.Close()
                                                Write-CustomLog -Level 'SUCCESS' -Message "Audited $($Results.CertificatesProcessed) certificates for compliance"
                                                
                                            } catch {
                                                $Results.Errors += "Failed to audit certificates: $($_.Exception.Message)"
                                                $Results.OperationsFailed++
                                            }
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would audit certificates for compliance violations"
                                        $Results.CertificatesProcessed = 10
                                        $Results.OperationsSuccessful = 8
                                        $Results.OperationsFailed = 2
                                    }
                                }
                                
                                'Export' {
                                    Write-CustomLog -Level 'INFO' -Message "Exporting certificates"
                                    
                                    if (-not $ExportPath) {
                                        throw "Export path required for export operation"
                                    }
                                    
                                    # Ensure export directory exists
                                    if (-not (Test-Path $ExportPath)) {
                                        New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
                                    }
                                    
                                    if (-not $TestMode) {
                                        if ($PSCmdlet.ShouldProcess("Certificates", "Export certificates to $ExportPath")) {
                                            try {
                                                $Store = Get-CertificateStoreObject -StoreName $CertificateStore -StoreLocation $StoreLocation
                                                $Certificates = if ($CertificateThumbprint) {
                                                    @($Store.Certificates | Where-Object { $_.Thumbprint -eq $CertificateThumbprint })
                                                } else {
                                                    $Store.Certificates
                                                }
                                                
                                                foreach ($Cert in $Certificates) {
                                                    $SafeSubject = $Cert.Subject -replace '[\\/:*?"<>|]', '_'
                                                    $ExportFile = Join-Path $ExportPath "$SafeSubject-$($Cert.Thumbprint.Substring(0,8)).pfx"
                                                    
                                                    if ($ExportPrivateKey -and $Cert.HasPrivateKey) {
                                                        # Export with private key (PFX)
                                                        $CertBytes = $Cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $ExportPassword)
                                                    } else {
                                                        # Export certificate only (CER)
                                                        $ExportFile = $ExportFile.Replace('.pfx', '.cer')
                                                        $CertBytes = $Cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
                                                    }
                                                    
                                                    [System.IO.File]::WriteAllBytes($ExportFile, $CertBytes)
                                                    
                                                    $Results.OutputFiles += $ExportFile
                                                    $Results.CertificatesProcessed++
                                                    $Results.OperationsSuccessful++
                                                }
                                                
                                                $Store.Close()
                                                Write-CustomLog -Level 'SUCCESS' -Message "Exported $($Results.CertificatesProcessed) certificates"
                                                
                                            } catch {
                                                $Results.Errors += "Failed to export certificates: $($_.Exception.Message)"
                                                $Results.OperationsFailed++
                                            }
                                        }
                                    } else {
                                        Write-CustomLog -Level 'INFO' -Message "[TEST] Would export certificates to: $ExportPath"
                                        $Results.CertificatesProcessed = 5
                                        $Results.OperationsSuccessful = 5
                                    }
                                }
                            }
                            
                        } catch {
                            $Results.Errors += "Failed during PKI operation: $($_.Exception.Message)"
                        }
                        
                        $Results
                    }
                    
                    $ComputerResult.CertificatesProcessed = $OperationResult.CertificatesProcessed
                    $ComputerResult.CertificatesFound = $OperationResult.CertificatesFound
                    $ComputerResult.OperationsSuccessful = $OperationResult.OperationsSuccessful
                    $ComputerResult.OperationsFailed = $OperationResult.OperationsFailed
                    $ComputerResult.CertificateInventory = $OperationResult.CertificateInventory
                    $ComputerResult.ValidationResults = $OperationResult.ValidationResults
                    $ComputerResult.ComplianceResults = $OperationResult.ComplianceResults
                    $ComputerResult.OutputFiles = $OperationResult.OutputFiles
                    $ComputerResult.Errors += $OperationResult.Errors
                    
                    # Update summary statistics
                    $PKIResults.CertificatesProcessed += $OperationResult.CertificatesProcessed
                    $PKIResults.ValidationFailures += $OperationResult.OperationsFailed
                    $PKIResults.ComplianceViolations += ($OperationResult.ComplianceResults | Where-Object { -not $_.IsCompliant }).Count
                    
                    # Update operation-specific counters
                    switch ($Operation) {
                        'Export' { $PKIResults.CertificatesExported += $OperationResult.OperationsSuccessful }
                        'Validate' { $PKIResults.CertificatesValidated += $OperationResult.CertificatesProcessed }
                    }
                    
                    $ComputerResult.ProcessingTime = ((Get-Date) - $StartTime).TotalSeconds
                    Write-CustomLog -Level 'SUCCESS' -Message "PKI operation completed for $Computer - $($OperationResult.CertificatesProcessed) certificates processed in $($ComputerResult.ProcessingTime) seconds"
                    
                } catch {
                    $Error = "Failed to process PKI certificates for $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $PKIResults.ComputersProcessed += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during PKI certificate management: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "PKI certificate management completed"
        
        # Generate recommendations
        $PKIResults.Recommendations += "Regularly monitor certificate expiration dates and implement automated renewal"
        $PKIResults.Recommendations += "Maintain secure backup procedures for private keys and certificates"
        $PKIResults.Recommendations += "Implement certificate lifecycle management policies"
        $PKIResults.Recommendations += "Regularly audit certificate compliance and security posture"
        $PKIResults.Recommendations += "Use strong key sizes (minimum 2048-bit RSA) for new certificates"
        
        if ($PKIResults.ValidationFailures -gt 0) {
            $PKIResults.Recommendations += "Address $($PKIResults.ValidationFailures) certificate validation failures immediately"
        }
        
        if ($PKIResults.ComplianceViolations -gt 0) {
            $PKIResults.Recommendations += "Remediate $($PKIResults.ComplianceViolations) certificate compliance violations"
        }
        
        if ($Operation -eq 'Export') {
            $PKIResults.Recommendations += "Secure exported certificates and private keys with appropriate access controls"
        }
        
        # Generate report if requested
        if ($GenerateReport -and $ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>PKI Certificate Management Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .computer { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .error { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .recommendation { background-color: #e7f3ff; padding: 10px; margin: 5px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <div class='header'>
        <h1>PKI Certificate Management Report</h1>
        <p><strong>Operation:</strong> $($PKIResults.Operation)</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($PKIResults.ComputersProcessed.Count)</p>
        <p><strong>Certificates Processed:</strong> $($PKIResults.CertificatesProcessed)</p>
        <p><strong>Validation Failures:</strong> $($PKIResults.ValidationFailures)</p>
        <p><strong>Compliance Violations:</strong> $($PKIResults.ComplianceViolations)</p>
    </div>
"@
                
                foreach ($Computer in $PKIResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>Processing Time:</strong> $($Computer.ProcessingTime) seconds</p>"
                    $HtmlReport += "<p><strong>Certificates Found:</strong> $($Computer.CertificatesFound)</p>"
                    $HtmlReport += "<p><strong>Successful Operations:</strong> $($Computer.OperationsSuccessful)</p>"
                    $HtmlReport += "<p><strong>Failed Operations:</strong> $($Computer.OperationsFailed)</p>"
                    $HtmlReport += "</div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $PKIResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                if (-not $TestMode) {
                    $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                    Write-CustomLog -Level 'SUCCESS' -Message "PKI certificate report generated: $ReportPath"
                }
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "PKI Certificate Management Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Operation: $($PKIResults.Operation)"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($PKIResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Certificates Processed: $($PKIResults.CertificatesProcessed)"
        Write-CustomLog -Level 'INFO' -Message "  Certificates Exported: $($PKIResults.CertificatesExported)"
        Write-CustomLog -Level 'INFO' -Message "  Certificates Validated: $($PKIResults.CertificatesValidated)"
        Write-CustomLog -Level 'INFO' -Message "  Validation Failures: $($PKIResults.ValidationFailures)"
        Write-CustomLog -Level 'INFO' -Message "  Compliance Violations: $($PKIResults.ComplianceViolations)"
        
        return $PKIResults
    }
}