function Get-SystemSecurityInventory {
    <#
    .SYNOPSIS
        Performs comprehensive security-focused system inventory using WMI and CIM.

    .DESCRIPTION
        Collects detailed system information for security analysis.

    .PARAMETER ComputerName
        Target computer names for inventory. Default: localhost

    .PARAMETER InventoryCategories
        Specific inventory categories to collect

    .PARAMETER OutputFormat
        Output format: Object, JSON, HTML, or CSV

    .PARAMETER ReportPath
        Path to save inventory report

    .PARAMETER SecurityFocus
        Include additional security-specific information

    .EXAMPLE
        Get-SystemSecurityInventory -SecurityFocus
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$ComputerName = @('localhost'),

        [Parameter()]
        [ValidateSet('Hardware', 'OperatingSystem', 'Security', 'Network')]
        [string[]]$InventoryCategories = @('Hardware', 'OperatingSystem', 'Security'),

        [Parameter()]
        [ValidateSet('Object', 'JSON', 'HTML', 'CSV')]
        [string]$OutputFormat = 'Object',

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [switch]$SecurityFocus
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting system security inventory"
        $InventoryResults = @()
    }

    process {
        try {
            foreach ($Computer in $ComputerName) {
                Write-CustomLog -Level 'INFO' -Message "Collecting inventory for: $Computer"

                $InventoryData = @{
                    ComputerName = $Computer
                    CollectionTime = Get-Date
                    Categories = @{}
                    SecurityFindings = @()
                    Errors = @()
                }

                try {
                    # Hardware Information
                    if ($InventoryCategories -contains 'Hardware') {
                        $HardwareData = @{}
                        
                        try {
                            $HardwareData.ComputerSystem = Get-CimInstance -ClassName 'Win32_ComputerSystem' -ComputerName $Computer -ErrorAction Stop |
                                Select-Object Name, Domain, Manufacturer, Model
                        } catch {
                            $HardwareData.ComputerSystem = $null
                        }
                        
                        try {
                            $HardwareData.BIOS = Get-CimInstance -ClassName 'Win32_BIOS' -ComputerName $Computer -ErrorAction Stop |
                                Select-Object Name, Version, SerialNumber
                        } catch {
                            $HardwareData.BIOS = $null
                        }
                        
                        $InventoryData.Categories['Hardware'] = $HardwareData
                    }

                    # Operating System Information
                    if ($InventoryCategories -contains 'OperatingSystem') {
                        $OSData = @{}
                        
                        try {
                            $OSData.OS = Get-CimInstance -ClassName 'Win32_OperatingSystem' -ComputerName $Computer -ErrorAction Stop |
                                Select-Object Caption, BuildNumber, Version
                        } catch {
                            $OSData.OS = $null
                        }
                        
                        try {
                            $OSData.Hotfixes = Get-CimInstance -ClassName 'Win32_QuickFixEngineering' -ComputerName $Computer -ErrorAction Stop |
                                Select-Object HotFixID, Description
                        } catch {
                            $OSData.Hotfixes = $null
                        }
                        
                        $InventoryData.Categories['OperatingSystem'] = $OSData
                    }

                    # Security Information
                    if ($InventoryCategories -contains 'Security') {
                        $SecurityData = @{}
                        
                        try {
                            if ($Computer -eq 'localhost' -or $Computer -eq $env:COMPUTERNAME) {
                                $SecurityData.LocalAdministrators = Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue |
                                    Select-Object Name, ObjectClass
                            } else {
                                $SecurityData.LocalAdministrators = $null
                            }
                        } catch {
                            $SecurityData.LocalAdministrators = $null
                        }
                        
                        $SecurityData.UAC = @{
                            Status = "Unknown"
                        }
                        
                        $InventoryData.Categories['Security'] = $SecurityData
                        
                        # Security findings
                        if ($SecurityFocus -and $SecurityData.LocalAdministrators -and $SecurityData.LocalAdministrators.Count -gt 3) {
                            $InventoryData.SecurityFindings += "High number of local administrators: $($SecurityData.LocalAdministrators.Count)"
                        }
                    }

                } catch {
                    $ErrorMsg = "Failed to collect inventory for $Computer`: " + $_.Exception.Message
                    $InventoryData.Errors += $ErrorMsg
                    Write-CustomLog -Level 'ERROR' -Message $ErrorMsg
                }

                $InventoryResults += $InventoryData
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error during inventory collection: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'SUCCESS' -Message "System security inventory completed"

        # Format results based on output format
        switch ($OutputFormat) {
            'Object' { $FormattedResults = $InventoryResults }
            'JSON' { $FormattedResults = $InventoryResults | ConvertTo-Json -Depth 10 }
            'HTML' { 
                $FormattedResults = "<html><body><h1>System Security Inventory Report</h1>"
                foreach ($Result in $InventoryResults) {
                    $FormattedResults += "<h2>$($Result.ComputerName)</h2>"
                    $FormattedResults += "<p><strong>Collection Time:</strong> $($Result.CollectionTime)</p>"
                }
                $FormattedResults += "</body></html>"
            }
            'CSV' { 
                $FormattedResults = $InventoryResults | ForEach-Object {
                    [PSCustomObject]@{
                        ComputerName = $_.ComputerName
                        CollectionTime = $_.CollectionTime
                        SecurityFindings = ($_.SecurityFindings -join '; ')
                        ErrorCount = $_.Errors.Count
                    }
                }
            }
        }

        # Save report if path specified
        if ($ReportPath) {
            try {
                switch ($OutputFormat) {
                    'JSON' { $FormattedResults | Out-File -FilePath $ReportPath -Encoding UTF8 }
                    'HTML' { $FormattedResults | Out-File -FilePath $ReportPath -Encoding UTF8 }
                    'CSV' { $FormattedResults | Export-Csv -Path $ReportPath -NoTypeInformation }
                    default { $FormattedResults | Export-Clixml -Path $ReportPath }
                }
                Write-CustomLog -Level 'SUCCESS' -Message "Inventory report saved to: $ReportPath"
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Failed to save report: $($_.Exception.Message)"
            }
        }

        # Display summary
        $TotalFindings = ($InventoryResults | ForEach-Object {$_.SecurityFindings.Count} | Measure-Object -Sum).Sum
        Write-CustomLog -Level 'INFO' -Message "Inventory Summary:"
        Write-CustomLog -Level 'INFO' -Message "  Computers: $($InventoryResults.Count)"
        Write-CustomLog -Level 'INFO' -Message "  Categories: $($InventoryCategories -join ', ')"
        Write-CustomLog -Level 'INFO' -Message "  Security Findings: $TotalFindings"

        return $FormattedResults
    }
}