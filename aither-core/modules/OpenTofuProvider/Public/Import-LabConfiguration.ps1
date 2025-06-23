function Import-LabConfiguration {
    <#
    .SYNOPSIS
    Imports and validates lab configuration for infrastructure deployment.
    
    .DESCRIPTION
    Imports lab configuration from various sources:
    - YAML configuration files
    - JSON configuration files
    - Template-based configurations
    - Remote configuration sources
    
    .PARAMETER ConfigPath
    Path to the configuration file or directory.
    
    .PARAMETER ConfigFormat
    Configuration format: 'YAML', 'JSON', 'Auto'.
    
    .PARAMETER ValidateConfiguration
    Perform comprehensive configuration validation.
    
    .PARAMETER MergeWith
    Path to additional configuration to merge.
    
    .EXAMPLE
    Import-LabConfiguration -ConfigPath "lab_config.yaml" -ValidateConfiguration
    
    .EXAMPLE
    Import-LabConfiguration -ConfigPath "base_config.yaml" -MergeWith "environment_overrides.yaml"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,
        
        [Parameter()]
        [ValidateSet('YAML', 'JSON', 'Auto')]
        [string]$ConfigFormat = 'Auto',
        
        [Parameter()]
        [switch]$ValidateConfiguration,
        
        [Parameter()]
        [string]$MergeWith
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Importing lab configuration from: $ConfigPath"
    }
    
    process {
        try {
            # Determine configuration format
            if ($ConfigFormat -eq 'Auto') {
                $extension = [System.IO.Path]::GetExtension($ConfigPath).ToLower()
                $ConfigFormat = switch ($extension) {
                    '.yaml' { 'YAML' }
                    '.yml' { 'YAML' }
                    '.json' { 'JSON' }
                    default { 'YAML' }
                }
                Write-CustomLog -Level 'INFO' -Message "Auto-detected configuration format: $ConfigFormat"
            }
            
            # Load primary configuration
            Write-CustomLog -Level 'INFO' -Message "Loading primary configuration..."
            $primaryConfig = switch ($ConfigFormat) {
                'YAML' {
                    Get-Content $ConfigPath -Raw | ConvertFrom-Yaml
                }
                'JSON' {
                    Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
                }
            }
            
            if (-not $primaryConfig) {
                throw "Failed to load configuration from: $ConfigPath"
            }
            
            # Merge with additional configuration if specified
            if ($MergeWith) {
                Write-CustomLog -Level 'INFO' -Message "Merging with additional configuration: $MergeWith"
                
                if (-not (Test-Path $MergeWith)) {
                    throw "Merge configuration file not found: $MergeWith"
                }
                
                $mergeFormat = if ([System.IO.Path]::GetExtension($MergeWith).ToLower() -in @('.yaml', '.yml')) { 'YAML' } else { 'JSON' }
                $mergeConfig = switch ($mergeFormat) {
                    'YAML' {
                        Get-Content $MergeWith -Raw | ConvertFrom-Yaml
                    }
                    'JSON' {
                        Get-Content $MergeWith -Raw | ConvertFrom-Json -AsHashtable
                    }
                }
                
                $primaryConfig = Merge-Configuration -BaseConfig $primaryConfig -OverrideConfig $mergeConfig
                Write-CustomLog -Level 'INFO' -Message "Configuration merged successfully"
            }
            
            # Add metadata
            $configMetadata = @{
                SourcePath = $ConfigPath
                Format = $ConfigFormat
                LoadedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                MergedWith = $MergeWith
                Version = $primaryConfig.version -or "1.0.0"
            }
            
            $primaryConfig._metadata = $configMetadata
            
            # Validate configuration if requested
            if ($ValidateConfiguration) {
                Write-CustomLog -Level 'INFO' -Message "Performing configuration validation..."
                $validationResult = Test-LabConfigurationValidity -Configuration $primaryConfig
                
                if (-not $validationResult.Valid) {
                    $issues = $validationResult.Issues -join '; '
                    Write-CustomLog -Level 'WARN' -Message "Configuration validation issues: $issues"
                    
                    # Add validation results to metadata
                    $configMetadata.ValidationIssues = $validationResult.Issues
                    $configMetadata.ValidationWarnings = $validationResult.Warnings
                } else {
                    Write-CustomLog -Level 'SUCCESS' -Message "Configuration validation passed"
                    $configMetadata.ValidationStatus = 'Passed'
                }
            }
            
            # Extract key configuration sections for summary
            $configSummary = @{
                HypervHost = $primaryConfig.hyperv.host
                VmCount = if ($primaryConfig.vms) { $primaryConfig.vms.Count } else { 0 }
                SwitchName = $primaryConfig.switch.name
                HasCertificates = ($null -ne $primaryConfig.hyperv.cert_path)
                SecurityEnabled = ($primaryConfig.hyperv.https -and -not $primaryConfig.hyperv.insecure)
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Lab configuration imported successfully"
            Write-CustomLog -Level 'INFO' -Message "Configuration summary: Host=$($configSummary.HypervHost), VMs=$($configSummary.VmCount), Switch=$($configSummary.SwitchName)"
            
            return @{
                Success = $true
                Configuration = $primaryConfig
                Metadata = $configMetadata
                Summary = $configSummary
                ValidationResult = if ($ValidateConfiguration) { $validationResult } else { $null }
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Configuration import failed: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'INFO' -Message "Lab configuration import completed"
    }
}
