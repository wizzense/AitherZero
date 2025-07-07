function Set-SMBSecurity {
    <#
    .SYNOPSIS
        Configures secure SMB (Server Message Block) protocol settings.
        
    .DESCRIPTION
        Hardens SMB configuration to prevent common attack vectors including
        SMBv1 disabling, SMB signing enforcement, encryption requirements,
        and access controls. Supports both SMB server and client hardening.
        
    .PARAMETER ComputerName
        Target computer names for SMB hardening. Default: localhost
        
    .PARAMETER Credential
        Credentials for remote computer access
        
    .PARAMETER DisableSMBv1
        Disable SMBv1 protocol completely
        
    .PARAMETER RequireSMBSigning
        Require SMB packet signing for all connections
        
    .PARAMETER EnableSMBEncryption
        Enable SMB encryption for all shares
        
    .PARAMETER RestrictAnonymousAccess
        Restrict anonymous access to SMB shares
        
    .PARAMETER ConfigureShares
        Configure security settings for existing shares
        
    .PARAMETER HiddenShares
        Configure administrative hidden shares
        
    .PARAMETER ClientSecurity
        Apply client-side SMB security settings
        
    .PARAMETER TestMode
        Show what would be configured without making changes
        
    .PARAMETER ReportPath
        Path to save SMB security configuration report
        
    .PARAMETER ValidateConfiguration
        Validate SMB security settings after configuration
        
    .PARAMETER BackupSettings
        Create backup of current SMB settings
        
    .EXAMPLE
        Set-SMBSecurity -DisableSMBv1 -RequireSMBSigning -EnableSMBEncryption -ReportPath "C:\Reports\smb-security.html"
        
    .EXAMPLE
        Set-SMBSecurity -ComputerName @("Server1", "Server2") -RestrictAnonymousAccess -ConfigureShares -Credential $Creds
        
    .EXAMPLE
        Set-SMBSecurity -TestMode -ClientSecurity -ValidateConfiguration
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),
        
        [Parameter()]
        [pscredential]$Credential,
        
        [Parameter()]
        [switch]$DisableSMBv1,
        
        [Parameter()]
        [switch]$RequireSMBSigning,
        
        [Parameter()]
        [switch]$EnableSMBEncryption,
        
        [Parameter()]
        [switch]$RestrictAnonymousAccess,
        
        [Parameter()]
        [switch]$ConfigureShares,
        
        [Parameter()]
        [ValidateSet('Disable', 'Enable', 'NoChange')]
        [string]$HiddenShares = 'NoChange',
        
        [Parameter()]
        [switch]$ClientSecurity,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [string]$ReportPath,
        
        [Parameter()]
        [switch]$ValidateConfiguration,
        
        [Parameter()]
        [switch]$BackupSettings
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting SMB security configuration for $($ComputerName.Count) computer(s)"
        
        # Check if running as Administrator
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
        if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This function requires Administrator privileges"
        }
        
        $SMBSecurityResults = @{
            ComputersProcessed = @()
            SMBv1Disabled = 0
            SigningEnabled = 0
            EncryptionEnabled = 0
            SharesConfigured = 0
            BackupsCreated = 0
            ValidationResults = @()
            Errors = @()
            Recommendations = @()
        }
        
        # SMB security configurations
        $SMBConfigurations = @{
            Server = @{
                Registry = @{
                    # SMB Server settings
                    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' = @{
                        'SMB1' = 0                              # Disable SMBv1
                        'RequireSecuritySignature' = 1          # Require SMB signing
                        'EnableSecuritySignature' = 1           # Enable SMB signing
                        'EncryptSmb3Traffic' = 1                # Enable SMB3 encryption
                        'RestrictNullSessAccess' = 1            # Restrict null session access
                        'RequireAuthentication' = 1             # Require authentication
                    }
                    # Network security settings
                    'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' = @{
                        'RestrictAnonymous' = 2                 # Restrict anonymous access
                        'RestrictAnonymousSAM' = 1              # Restrict anonymous SAM access
                        'EveryoneIncludesAnonymous' = 0         # Exclude anonymous from Everyone
                    }
                }
                Features = @{
                    'SMB1Protocol-Server' = 'Disabled'
                    'SMB1Protocol-Client' = 'Disabled'
                }
            }
            Client = @{
                Registry = @{
                    # SMB Client settings
                    'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' = @{
                        'RequireSecuritySignature' = 1          # Require SMB signing
                        'EnableSecuritySignature' = 1           # Enable SMB signing
                        'EnablePlainTextPassword' = 0           # Disable plain text passwords
                    }
                }
            }
        }
    }
    
    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Processing SMB security configuration for: $Computer"
                
                $ComputerResult = @{
                    ComputerName = $Computer
                    ConfigurationTime = Get-Date
                    SMBv1Disabled = $false
                    SigningConfigured = $false
                    EncryptionConfigured = $false
                    SharesConfigured = @()
                    AnonymousAccessRestricted = $false
                    BackupPath = $null
                    RegistryChanges = @()
                    FeatureChanges = @()
                    ShareChanges = @()
                    ValidationResults = @()
                    Errors = @()
                }
                
                try {
                    # Execute SMB security configuration script
                    $ScriptBlock = {
                        param($DisableSMBv1, $RequireSMBSigning, $EnableSMBEncryption, $RestrictAnonymousAccess, $ConfigureShares, $HiddenShares, $ClientSecurity, $TestMode, $ValidateConfiguration, $BackupSettings, $SMBConfigurations)
                        
                        $LocalResult = @{
                            SMBv1Disabled = $false
                            SigningConfigured = $false
                            EncryptionConfigured = $false
                            SharesConfigured = @()
                            AnonymousAccessRestricted = $false
                            BackupPath = $null
                            RegistryChanges = @()
                            FeatureChanges = @()
                            ShareChanges = @()
                            ValidationResults = @()
                            Errors = @()
                        }
                        
                        try {
                            # Create backup if requested
                            if ($BackupSettings) {
                                Write-Progress -Activity "Creating SMB Settings Backup" -PercentComplete 5
                                
                                try {
                                    $BackupDir = 'C:\ProgramData\AitherZero\Backups\SMB'
                                    if (-not (Test-Path $BackupDir)) {
                                        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
                                    }
                                    
                                    $BackupFile = Join-Path $BackupDir "SMB-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
                                    
                                    $BackupData = @{
                                        ComputerName = $env:COMPUTERNAME
                                        BackupTime = Get-Date
                                        RegistrySettings = @{}
                                        SMBShares = @()
                                        SMBFeatures = @()
                                    }
                                    
                                    # Backup registry settings
                                    foreach ($ConfigType in $SMBConfigurations.Keys) {
                                        $Config = $SMBConfigurations[$ConfigType]
                                        
                                        foreach ($RegistryPath in $Config.Registry.Keys) {
                                            try {
                                                $CurrentSettings = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
                                                if ($CurrentSettings) {
                                                    $BackupData.RegistrySettings[$RegistryPath] = $CurrentSettings
                                                }
                                            } catch {
                                                # Ignore errors for non-existent keys
                                            }
                                        }
                                    }
                                    
                                    # Backup SMB shares
                                    try {
                                        $BackupData.SMBShares = Get-SmbShare -ErrorAction SilentlyContinue | 
                                                               Select-Object Name, Path, Description, ShareState, ShareType, ScopeName
                                    } catch {
                                        # SMB cmdlets may not be available
                                    }
                                    
                                    if (-not $TestMode) {
                                        $BackupData | Export-Clixml -Path $BackupFile -Force
                                        $LocalResult.BackupPath = $BackupFile
                                    }
                                } catch {
                                    $LocalResult.Errors += "Failed to create backup: $($_.Exception.Message)"
                                }
                            }
                            
                            # Disable SMBv1 if requested
                            if ($DisableSMBv1) {
                                Write-Progress -Activity "Disabling SMBv1" -PercentComplete 15
                                
                                # Registry method for SMBv1 disable
                                $SMBv1RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                                
                                if (-not (Test-Path $SMBv1RegistryPath) -and -not $TestMode) {
                                    New-Item -Path $SMBv1RegistryPath -Force | Out-Null
                                }
                                
                                $CurrentSMBv1 = $null
                                try {
                                    $CurrentSMBv1 = Get-ItemProperty -Path $SMBv1RegistryPath -Name 'SMB1' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'SMB1'
                                } catch {
                                    $CurrentSMBv1 = $null
                                }
                                
                                if ($CurrentSMBv1 -ne 0) {
                                    $ChangeInfo = @{
                                        Path = $SMBv1RegistryPath
                                        Setting = 'SMB1'
                                        OldValue = $CurrentSMBv1
                                        NewValue = 0
                                        Type = 'SMBv1Disable'
                                    }
                                    
                                    if ($TestMode) {
                                        $LocalResult.RegistryChanges += $ChangeInfo
                                    } else {
                                        Set-ItemProperty -Path $SMBv1RegistryPath -Name 'SMB1' -Value 0 -Force
                                        $LocalResult.RegistryChanges += $ChangeInfo
                                    }
                                }
                                
                                # PowerShell cmdlet method (if available)
                                try {
                                    if (Get-Command 'Disable-WindowsOptionalFeature' -ErrorAction SilentlyContinue) {
                                        $SMBv1Features = @('SMB1Protocol', 'SMB1Protocol-Client', 'SMB1Protocol-Server')
                                        
                                        foreach ($Feature in $SMBv1Features) {
                                            try {
                                                $FeatureState = Get-WindowsOptionalFeature -Online -FeatureName $Feature -ErrorAction SilentlyContinue
                                                
                                                if ($FeatureState -and $FeatureState.State -eq 'Enabled') {
                                                    $FeatureChange = @{
                                                        FeatureName = $Feature
                                                        OldState = 'Enabled'
                                                        NewState = 'Disabled'
                                                        Type = 'SMBv1Feature'
                                                    }
                                                    
                                                    if ($TestMode) {
                                                        $LocalResult.FeatureChanges += $FeatureChange
                                                    } else {
                                                        Disable-WindowsOptionalFeature -Online -FeatureName $Feature -NoRestart
                                                        $LocalResult.FeatureChanges += $FeatureChange
                                                    }
                                                }
                                            } catch {
                                                # Feature may not exist on this system
                                            }
                                        }
                                    }
                                } catch {
                                    # Windows Features cmdlets not available
                                }
                                
                                $LocalResult.SMBv1Disabled = $true
                            }
                            
                            # Configure SMB signing if requested
                            if ($RequireSMBSigning) {
                                Write-Progress -Activity "Configuring SMB Signing" -PercentComplete 30
                                
                                # Server-side signing
                                $ServerConfig = $SMBConfigurations.Server.Registry['HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters']
                                $ServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                                
                                if (-not (Test-Path $ServerPath) -and -not $TestMode) {
                                    New-Item -Path $ServerPath -Force | Out-Null
                                }
                                
                                $SigningSettings = @{
                                    'RequireSecuritySignature' = 1
                                    'EnableSecuritySignature' = 1
                                }
                                
                                foreach ($Setting in $SigningSettings.Keys) {
                                    $Value = $SigningSettings[$Setting]
                                    $CurrentValue = $null
                                    
                                    try {
                                        $CurrentValue = Get-ItemProperty -Path $ServerPath -Name $Setting -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Setting
                                    } catch {
                                        $CurrentValue = $null
                                    }
                                    
                                    if ($CurrentValue -ne $Value) {
                                        $ChangeInfo = @{
                                            Path = $ServerPath
                                            Setting = $Setting
                                            OldValue = $CurrentValue
                                            NewValue = $Value
                                            Type = 'SMBSigning'
                                        }
                                        
                                        if ($TestMode) {
                                            $LocalResult.RegistryChanges += $ChangeInfo
                                        } else {
                                            Set-ItemProperty -Path $ServerPath -Name $Setting -Value $Value -Force
                                            $LocalResult.RegistryChanges += $ChangeInfo
                                        }
                                    }
                                }
                                
                                # Client-side signing if requested
                                if ($ClientSecurity) {
                                    $ClientPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
                                    
                                    if (-not (Test-Path $ClientPath) -and -not $TestMode) {
                                        New-Item -Path $ClientPath -Force | Out-Null
                                    }
                                    
                                    foreach ($Setting in $SigningSettings.Keys) {
                                        $Value = $SigningSettings[$Setting]
                                        $CurrentValue = $null
                                        
                                        try {
                                            $CurrentValue = Get-ItemProperty -Path $ClientPath -Name $Setting -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Setting
                                        } catch {
                                            $CurrentValue = $null
                                        }
                                        
                                        if ($CurrentValue -ne $Value) {
                                            $ChangeInfo = @{
                                                Path = $ClientPath
                                                Setting = $Setting
                                                OldValue = $CurrentValue
                                                NewValue = $Value
                                                Type = 'SMBSigningClient'
                                            }
                                            
                                            if ($TestMode) {
                                                $LocalResult.RegistryChanges += $ChangeInfo
                                            } else {
                                                Set-ItemProperty -Path $ClientPath -Name $Setting -Value $Value -Force
                                                $LocalResult.RegistryChanges += $ChangeInfo
                                            }
                                        }
                                    }
                                }
                                
                                $LocalResult.SigningConfigured = $true
                            }
                            
                            # Configure SMB encryption if requested
                            if ($EnableSMBEncryption) {
                                Write-Progress -Activity "Configuring SMB Encryption" -PercentComplete 45
                                
                                $EncryptionPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                                $EncryptionSettings = @{
                                    'EncryptSmb3Traffic' = 1
                                    'RejectUnencryptedAccess' = 1
                                }
                                
                                if (-not (Test-Path $EncryptionPath) -and -not $TestMode) {
                                    New-Item -Path $EncryptionPath -Force | Out-Null
                                }
                                
                                foreach ($Setting in $EncryptionSettings.Keys) {
                                    $Value = $EncryptionSettings[$Setting]
                                    $CurrentValue = $null
                                    
                                    try {
                                        $CurrentValue = Get-ItemProperty -Path $EncryptionPath -Name $Setting -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Setting
                                    } catch {
                                        $CurrentValue = $null
                                    }
                                    
                                    if ($CurrentValue -ne $Value) {
                                        $ChangeInfo = @{
                                            Path = $EncryptionPath
                                            Setting = $Setting
                                            OldValue = $CurrentValue
                                            NewValue = $Value
                                            Type = 'SMBEncryption'
                                        }
                                        
                                        if ($TestMode) {
                                            $LocalResult.RegistryChanges += $ChangeInfo
                                        } else {
                                            Set-ItemProperty -Path $EncryptionPath -Name $Setting -Value $Value -Force
                                            $LocalResult.RegistryChanges += $ChangeInfo
                                        }
                                    }
                                }
                                
                                $LocalResult.EncryptionConfigured = $true
                            }
                            
                            # Restrict anonymous access if requested
                            if ($RestrictAnonymousAccess) {
                                Write-Progress -Activity "Restricting Anonymous Access" -PercentComplete 60
                                
                                $AnonymousConfig = $SMBConfigurations.Server.Registry['HKLM:\SYSTEM\CurrentControlSet\Control\Lsa']
                                $LSAPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
                                
                                if (-not (Test-Path $LSAPath) -and -not $TestMode) {
                                    New-Item -Path $LSAPath -Force | Out-Null
                                }
                                
                                foreach ($Setting in $AnonymousConfig.Keys) {
                                    $Value = $AnonymousConfig[$Setting]
                                    $CurrentValue = $null
                                    
                                    try {
                                        $CurrentValue = Get-ItemProperty -Path $LSAPath -Name $Setting -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Setting
                                    } catch {
                                        $CurrentValue = $null
                                    }
                                    
                                    if ($CurrentValue -ne $Value) {
                                        $ChangeInfo = @{
                                            Path = $LSAPath
                                            Setting = $Setting
                                            OldValue = $CurrentValue
                                            NewValue = $Value
                                            Type = 'AnonymousAccess'
                                        }
                                        
                                        if ($TestMode) {
                                            $LocalResult.RegistryChanges += $ChangeInfo
                                        } else {
                                            Set-ItemProperty -Path $LSAPath -Name $Setting -Value $Value -Force
                                            $LocalResult.RegistryChanges += $ChangeInfo
                                        }
                                    }
                                }
                                
                                $LocalResult.AnonymousAccessRestricted = $true
                            }
                            
                            # Configure SMB shares if requested
                            if ($ConfigureShares) {
                                Write-Progress -Activity "Configuring SMB Shares" -PercentComplete 75
                                
                                try {
                                    if (Get-Command 'Get-SmbShare' -ErrorAction SilentlyContinue) {
                                        $SMBShares = Get-SmbShare -ErrorAction SilentlyContinue | Where-Object {$_.ShareType -eq 'FileSystemDirectory'}
                                        
                                        foreach ($Share in $SMBShares) {
                                            try {
                                                $ShareChange = @{
                                                    ShareName = $Share.Name
                                                    Changes = @()
                                                }
                                                
                                                # Get current share security settings
                                                $ShareSecurity = Get-SmbShareAccess -Name $Share.Name -ErrorAction SilentlyContinue
                                                
                                                # Check for Everyone with Full Control (security risk)
                                                $EveryoneFullControl = $ShareSecurity | Where-Object {$_.AccountName -eq 'Everyone' -and $_.AccessRight -eq 'Full'}
                                                
                                                if ($EveryoneFullControl) {
                                                    $ShareChange.Changes += "Remove Everyone Full Control access"
                                                    
                                                    if (-not $TestMode) {
                                                        # Remove Everyone Full Control
                                                        Revoke-SmbShareAccess -Name $Share.Name -AccountName 'Everyone' -Force -ErrorAction SilentlyContinue
                                                        # Add Everyone with Read access instead
                                                        Grant-SmbShareAccess -Name $Share.Name -AccountName 'Everyone' -AccessRight Read -Force -ErrorAction SilentlyContinue
                                                    }
                                                }
                                                
                                                # Enable encryption for the share if SMB encryption is enabled
                                                if ($EnableSMBEncryption -and $Share.EncryptData -eq $false) {
                                                    $ShareChange.Changes += "Enable share encryption"
                                                    
                                                    if (-not $TestMode) {
                                                        Set-SmbShare -Name $Share.Name -EncryptData $true -Force -ErrorAction SilentlyContinue
                                                    }
                                                }
                                                
                                                if ($ShareChange.Changes.Count -gt 0) {
                                                    $LocalResult.ShareChanges += $ShareChange
                                                }
                                                
                                            } catch {
                                                $LocalResult.Errors += "Failed to configure share '$($Share.Name)': $($_.Exception.Message)"
                                            }
                                        }
                                        
                                        $LocalResult.SharesConfigured = $LocalResult.ShareChanges
                                    }
                                } catch {
                                    $LocalResult.Errors += "SMB share cmdlets not available: $($_.Exception.Message)"
                                }
                            }
                            
                            # Configure hidden administrative shares
                            if ($HiddenShares -ne 'NoChange') {
                                Write-Progress -Activity "Configuring Hidden Shares" -PercentComplete 85
                                
                                $HiddenSharesPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                                $HiddenShareValue = if ($HiddenShares -eq 'Disable') { 0 } else { 1 }
                                
                                $CurrentHiddenShares = $null
                                try {
                                    $CurrentHiddenShares = Get-ItemProperty -Path $HiddenSharesPath -Name 'AutoShareServer' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'AutoShareServer'
                                } catch {
                                    $CurrentHiddenShares = $null
                                }
                                
                                if ($CurrentHiddenShares -ne $HiddenShareValue) {
                                    $ChangeInfo = @{
                                        Path = $HiddenSharesPath
                                        Setting = 'AutoShareServer'
                                        OldValue = $CurrentHiddenShares
                                        NewValue = $HiddenShareValue
                                        Type = 'HiddenShares'
                                    }
                                    
                                    if ($TestMode) {
                                        $LocalResult.RegistryChanges += $ChangeInfo
                                    } else {
                                        Set-ItemProperty -Path $HiddenSharesPath -Name 'AutoShareServer' -Value $HiddenShareValue -Force
                                        $LocalResult.RegistryChanges += $ChangeInfo
                                    }
                                }
                            }
                            
                            # Validate configuration if requested
                            if ($ValidateConfiguration) {
                                Write-Progress -Activity "Validating Configuration" -PercentComplete 95
                                
                                try {
                                    $ValidationResult = @{
                                        SMBv1Status = 'Unknown'
                                        SigningStatus = 'Unknown'
                                        EncryptionStatus = 'Unknown'
                                        ShareSecurity = @()
                                    }
                                    
                                    # Check SMBv1 status
                                    try {
                                        $SMBv1Registry = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'SMB1' -ErrorAction SilentlyContinue
                                        $ValidationResult.SMBv1Status = if ($SMBv1Registry.SMB1 -eq 0) { 'Disabled' } else { 'Enabled' }
                                    } catch {
                                        $ValidationResult.SMBv1Status = 'Unknown'
                                    }
                                    
                                    # Check signing status
                                    try {
                                        $SigningRegistry = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'RequireSecuritySignature' -ErrorAction SilentlyContinue
                                        $ValidationResult.SigningStatus = if ($SigningRegistry.RequireSecuritySignature -eq 1) { 'Required' } else { 'Optional' }
                                    } catch {
                                        $ValidationResult.SigningStatus = 'Unknown'
                                    }
                                    
                                    # Check encryption status
                                    try {
                                        $EncryptionRegistry = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'EncryptSmb3Traffic' -ErrorAction SilentlyContinue
                                        $ValidationResult.EncryptionStatus = if ($EncryptionRegistry.EncryptSmb3Traffic -eq 1) { 'Enabled' } else { 'Disabled' }
                                    } catch {
                                        $ValidationResult.EncryptionStatus = 'Unknown'
                                    }
                                    
                                    # Check share security
                                    try {
                                        if (Get-Command 'Get-SmbShare' -ErrorAction SilentlyContinue) {
                                            $Shares = Get-SmbShare -ErrorAction SilentlyContinue | Where-Object {$_.ShareType -eq 'FileSystemDirectory'}
                                            
                                            foreach ($Share in $Shares) {
                                                $ShareInfo = @{
                                                    Name = $Share.Name
                                                    EncryptData = $Share.EncryptData
                                                    RequireEncryption = $Share.RequireEncryption
                                                    SecurityDescriptor = 'Unknown'
                                                }
                                                
                                                try {
                                                    $ShareAccess = Get-SmbShareAccess -Name $Share.Name -ErrorAction SilentlyContinue
                                                    $ShareInfo.SecurityDescriptor = ($ShareAccess | ForEach-Object {"$($_.AccountName):$($_.AccessRight)"}) -join ', '
                                                } catch {
                                                    # Share access cmdlet failed
                                                }
                                                
                                                $ValidationResult.ShareSecurity += $ShareInfo
                                            }
                                        }
                                    } catch {
                                        # SMB cmdlets not available
                                    }
                                    
                                    $LocalResult.ValidationResults += $ValidationResult
                                    
                                } catch {
                                    $LocalResult.Errors += "Validation failed: $($_.Exception.Message)"
                                }
                            }
                            
                        } catch {
                            $LocalResult.Errors += "SMB security configuration error: $($_.Exception.Message)"
                        }
                        
                        Write-Progress -Activity "SMB Security Configuration Complete" -PercentComplete 100 -Completed
                        return $LocalResult
                    }
                    
                    # Execute configuration
                    if ($Computer -eq 'localhost') {
                        $Result = & $ScriptBlock $DisableSMBv1 $RequireSMBSigning $EnableSMBEncryption $RestrictAnonymousAccess $ConfigureShares $HiddenShares $ClientSecurity $TestMode $ValidateConfiguration $BackupSettings $SMBConfigurations
                    } else {
                        if ($Credential) {
                            $Result = Invoke-Command -ComputerName $Computer -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $DisableSMBv1, $RequireSMBSigning, $EnableSMBEncryption, $RestrictAnonymousAccess, $ConfigureShares, $HiddenShares, $ClientSecurity, $TestMode, $ValidateConfiguration, $BackupSettings, $SMBConfigurations
                        } else {
                            $Result = Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ArgumentList $DisableSMBv1, $RequireSMBSigning, $EnableSMBEncryption, $RestrictAnonymousAccess, $ConfigureShares, $HiddenShares, $ClientSecurity, $TestMode, $ValidateConfiguration, $BackupSettings, $SMBConfigurations
                        }
                    }
                    
                    # Merge results
                    $ComputerResult.SMBv1Disabled = $Result.SMBv1Disabled
                    $ComputerResult.SigningConfigured = $Result.SigningConfigured
                    $ComputerResult.EncryptionConfigured = $Result.EncryptionConfigured
                    $ComputerResult.SharesConfigured = $Result.SharesConfigured
                    $ComputerResult.AnonymousAccessRestricted = $Result.AnonymousAccessRestricted
                    $ComputerResult.BackupPath = $Result.BackupPath
                    $ComputerResult.RegistryChanges = $Result.RegistryChanges
                    $ComputerResult.FeatureChanges = $Result.FeatureChanges
                    $ComputerResult.ShareChanges = $Result.ShareChanges
                    $ComputerResult.ValidationResults = $Result.ValidationResults
                    $ComputerResult.Errors = $Result.Errors
                    
                    # Update counters
                    if ($Result.SMBv1Disabled) {
                        $SMBSecurityResults.SMBv1Disabled++
                    }
                    if ($Result.SigningConfigured) {
                        $SMBSecurityResults.SigningEnabled++
                    }
                    if ($Result.EncryptionConfigured) {
                        $SMBSecurityResults.EncryptionEnabled++
                    }
                    if ($Result.SharesConfigured.Count -gt 0) {
                        $SMBSecurityResults.SharesConfigured += $Result.SharesConfigured.Count
                    }
                    if ($Result.BackupPath) {
                        $SMBSecurityResults.BackupsCreated++
                    }
                    if ($Result.ValidationResults) {
                        $SMBSecurityResults.ValidationResults += $Result.ValidationResults
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "SMB security configuration completed for $Computer"
                    
                } catch {
                    $Error = "Failed to configure SMB security on $Computer`: $($_.Exception.Message)"
                    $ComputerResult.Errors += $Error
                    Write-CustomLog -Level 'ERROR' -Message $Error
                }
                
                $SMBSecurityResults.ComputersProcessed += $ComputerResult
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during SMB security configuration: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'SUCCESS' -Message "SMB security configuration completed"
        
        # Generate recommendations
        $SMBSecurityResults.Recommendations += "Restart SMB services or reboot systems for all changes to take effect"
        $SMBSecurityResults.Recommendations += "Test file sharing functionality after SMB hardening"
        $SMBSecurityResults.Recommendations += "Monitor SMB event logs for authentication and access issues"
        $SMBSecurityResults.Recommendations += "Regularly audit SMB share permissions and access"
        $SMBSecurityResults.Recommendations += "Consider implementing SMB over VPN for remote access"
        
        if ($SMBSecurityResults.SMBv1Disabled -gt 0) {
            $SMBSecurityResults.Recommendations += "Verify that no legacy applications depend on SMBv1"
        }
        
        if ($SMBSecurityResults.EncryptionEnabled -gt 0) {
            $SMBSecurityResults.Recommendations += "Monitor network performance impact of SMB encryption"
        }
        
        # Generate HTML report if requested
        if ($ReportPath) {
            try {
                $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>SMB Security Configuration Report</title>
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
        <h1>SMB Security Configuration Report</h1>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Computers Processed:</strong> $($SMBSecurityResults.ComputersProcessed.Count)</p>
        <p><strong>SMBv1 Disabled:</strong> <span class='success'>$($SMBSecurityResults.SMBv1Disabled)</span></p>
        <p><strong>Signing Enabled:</strong> <span class='success'>$($SMBSecurityResults.SigningEnabled)</span></p>
        <p><strong>Encryption Enabled:</strong> <span class='success'>$($SMBSecurityResults.EncryptionEnabled)</span></p>
        <p><strong>Shares Configured:</strong> $($SMBSecurityResults.SharesConfigured)</p>
    </div>
"@
                
                foreach ($Computer in $SMBSecurityResults.ComputersProcessed) {
                    $HtmlReport += "<div class='computer'>"
                    $HtmlReport += "<h2>$($Computer.ComputerName)</h2>"
                    $HtmlReport += "<p><strong>SMBv1 Disabled:</strong> $($Computer.SMBv1Disabled)</p>"
                    $HtmlReport += "<p><strong>Signing Configured:</strong> $($Computer.SigningConfigured)</p>"
                    $HtmlReport += "<p><strong>Encryption Configured:</strong> $($Computer.EncryptionConfigured)</p>"
                    $HtmlReport += "<p><strong>Anonymous Access Restricted:</strong> $($Computer.AnonymousAccessRestricted)</p>"
                    
                    if ($Computer.ValidationResults.Count -gt 0) {
                        $HtmlReport += "<h3>Validation Results</h3>"
                        foreach ($Validation in $Computer.ValidationResults) {
                            $HtmlReport += "<table>"
                            $HtmlReport += "<tr><th>Setting</th><th>Status</th></tr>"
                            $HtmlReport += "<tr><td>SMBv1</td><td>$($Validation.SMBv1Status)</td></tr>"
                            $HtmlReport += "<tr><td>SMB Signing</td><td>$($Validation.SigningStatus)</td></tr>"
                            $HtmlReport += "<tr><td>SMB Encryption</td><td>$($Validation.EncryptionStatus)</td></tr>"
                            $HtmlReport += "</table>"
                            
                            if ($Validation.ShareSecurity.Count -gt 0) {
                                $HtmlReport += "<h4>Share Security</h4>"
                                $HtmlReport += "<table><tr><th>Share Name</th><th>Encryption</th><th>Security</th></tr>"
                                
                                foreach ($Share in $Validation.ShareSecurity) {
                                    $HtmlReport += "<tr>"
                                    $HtmlReport += "<td>$($Share.Name)</td>"
                                    $HtmlReport += "<td>$($Share.EncryptData)</td>"
                                    $HtmlReport += "<td>$($Share.SecurityDescriptor)</td>"
                                    $HtmlReport += "</tr>"
                                }
                                
                                $HtmlReport += "</table>"
                            }
                        }
                    }
                    
                    $HtmlReport += "</div>"
                }
                
                $HtmlReport += "<div class='header'><h2>Recommendations</h2>"
                foreach ($Rec in $SMBSecurityResults.Recommendations) {
                    $HtmlReport += "<div class='recommendation'>$Rec</div>"
                }
                $HtmlReport += "</div>"
                
                $HtmlReport += "</body></html>"
                
                $HtmlReport | Out-File -FilePath $ReportPath -Encoding UTF8
                Write-CustomLog -Level 'SUCCESS' -Message "SMB security report saved to: $ReportPath"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to generate report: $($_.Exception.Message)"
            }
        }
        
        # Display summary
        Write-CustomLog -Level 'INFO' -Message "SMB Security Configuration Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($SMBSecurityResults.ComputersProcessed.Count)"
        Write-CustomLog -Level 'INFO' -Message "  SMBv1 Disabled: $($SMBSecurityResults.SMBv1Disabled)"
        Write-CustomLog -Level 'INFO' -Message "  Signing Enabled: $($SMBSecurityResults.SigningEnabled)"
        Write-CustomLog -Level 'INFO' -Message "  Encryption Enabled: $($SMBSecurityResults.EncryptionEnabled)"
        Write-CustomLog -Level 'INFO' -Message "  Shares Configured: $($SMBSecurityResults.SharesConfigured)"
        
        if ($TestMode) {
            Write-CustomLog -Level 'INFO' -Message "TEST MODE: No actual changes were made"
        }
        
        return $SMBSecurityResults
    }
}