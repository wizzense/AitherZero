function Export-EventHistory {
    <#
    .SYNOPSIS
        Export event history to file
    .DESCRIPTION
        Exports the message bus event history to various formats for analysis
    .PARAMETER OutputPath
        Path to save the exported history
    .PARAMETER Format
        Export format (JSON, CSV, XML)
    .PARAMETER StartDate
        Filter events from this date
    .PARAMETER EndDate
        Filter events until this date
    .PARAMETER EventTypes
        Filter specific event types
    .PARAMETER IncludeData
        Include full event data in export
    .EXAMPLE
        Export-EventHistory -OutputPath "events.json" -Format JSON -StartDate (Get-Date).AddDays(-7)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [ValidateSet('JSON', 'CSV', 'XML')]
        [string]$Format = 'JSON',

        [Parameter()]
        [datetime]$StartDate,

        [Parameter()]
        [datetime]$EndDate,

        [Parameter()]
        [string[]]$EventTypes = @(),

        [Parameter()]
        [switch]$IncludeData
    )

    try {
        # Get event history
        $events = @($script:MessageBus.EventHistory.ToArray())

        if ($events.Count -eq 0) {
            Write-CustomLog -Level 'WARNING' -Message "No events to export"
            return @{
                Success = $false
                Message = "No events in history"
                EventCount = 0
            }
        }

        # Apply filters
        $filteredEvents = $events

        if ($StartDate) {
            $filteredEvents = $filteredEvents | Where-Object { $_.Timestamp -ge $StartDate }
        }

        if ($EndDate) {
            $filteredEvents = $filteredEvents | Where-Object { $_.Timestamp -le $EndDate }
        }

        if ($EventTypes.Count -gt 0) {
            $filteredEvents = $filteredEvents | Where-Object { $_.Name -in $EventTypes }
        }

        # Prepare export data
        $exportData = @()
        foreach ($event in $filteredEvents) {
            $exportItem = @{
                Id = $event.Id
                Name = $event.Name
                Timestamp = $event.Timestamp
                Channel = $event.Channel
                Source = $event.Source
            }

            if ($IncludeData) {
                $exportItem.Data = $event.Data
            } else {
                $exportItem.DataSummary = if ($event.Data -is [hashtable]) {
                    "Object with $($event.Data.Keys.Count) properties"
                } else {
                    $event.Data.GetType().Name
                }
            }

            $exportData += $exportItem
        }

        # Export based on format
        switch ($Format) {
            'JSON' {
                $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
            }
            'CSV' {
                # Flatten data for CSV
                $csvData = @()
                foreach ($item in $exportData) {
                    $csvRow = @{
                        Id = $item.Id
                        Name = $item.Name
                        Timestamp = $item.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                        Channel = $item.Channel
                        SourceModule = $item.Source.Module
                        SourceCommand = $item.Source.Command
                        SourceUser = $item.Source.User
                        SourceMachine = $item.Source.Machine
                    }

                    if ($IncludeData) {
                        $csvRow.DataJson = $item.Data | ConvertTo-Json -Compress
                    } else {
                        $csvRow.DataSummary = $item.DataSummary
                    }

                    $csvData += New-Object PSObject -Property $csvRow
                }
                $csvData | Export-Csv -Path $OutputPath -NoTypeInformation
            }
            'XML' {
                $exportData | ConvertTo-Xml -NoTypeInformation | Out-File -FilePath $OutputPath -Encoding UTF8
            }
        }

        $fileSizeKB = [math]::Round((Get-Item $OutputPath).Length / 1KB, 2)

        Write-CustomLog -Level 'SUCCESS' -Message "Event history exported: $OutputPath ($fileSizeKB KB, $($exportData.Count) events)"

        return @{
            Success = $true
            OutputPath = $OutputPath
            Format = $Format
            EventCount = $exportData.Count
            FilteredFrom = $events.Count
            FileSizeKB = $fileSizeKB
            DateRange = @{
                Start = if ($StartDate) { $StartDate } else { ($events | Measure-Object Timestamp -Minimum).Minimum }
                End = if ($EndDate) { $EndDate } else { ($events | Measure-Object Timestamp -Maximum).Maximum }
            }
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to export event history: $_"
        throw
    }
}
