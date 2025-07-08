function Get-AllSecureCredentials {
    <#
    .SYNOPSIS
        Lists all secure credentials in the credential store.

    .DESCRIPTION
        Returns a list of all credentials with their metadata. Provides filtering
        options and can include expired credentials if requested.

    .PARAMETER FilterType
        Filter credentials by type (UserPassword, ServiceAccount, APIKey, Certificate).

    .PARAMETER IncludeExpired
        Include credentials that have expired based on their metadata.

    .PARAMETER SortBy
        Sort results by Name, Type, Created, or LastModified.

    .PARAMETER Descending
        Sort in descending order.

    .EXAMPLE
        Get-AllSecureCredentials

    .EXAMPLE
        Get-AllSecureCredentials -FilterType "UserPassword" -SortBy "Created"

    .EXAMPLE
        Get-AllSecureCredentials -IncludeExpired -SortBy "LastModified" -Descending
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('UserPassword', 'ServiceAccount', 'APIKey', 'Certificate')]
        [string]$FilterType,

        [Parameter()]
        [switch]$IncludeExpired,

        [Parameter()]
        [ValidateSet('Name', 'Type', 'Created', 'LastModified')]
        [string]$SortBy = 'Name',

        [Parameter()]
        [switch]$Descending
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Listing all secure credentials" -Context @{
            FilterType = $FilterType
            IncludeExpired = $IncludeExpired.IsPresent
            SortBy = $SortBy
            Descending = $Descending.IsPresent
        } -Category "Security"
    }

    process {
        try {
            $credentials = Get-AllCredentials -FilterType $FilterType -IncludeExpired:$IncludeExpired

            # Sort the results
            switch ($SortBy) {
                'Name' {
                    $credentials = if ($Descending) {
                        $credentials | Sort-Object Name -Descending
                    } else {
                        $credentials | Sort-Object Name
                    }
                }
                'Type' {
                    $credentials = if ($Descending) {
                        $credentials | Sort-Object Type -Descending
                    } else {
                        $credentials | Sort-Object Type
                    }
                }
                'Created' {
                    $credentials = if ($Descending) {
                        $credentials | Sort-Object { [DateTime]$_.Created } -Descending
                    } else {
                        $credentials | Sort-Object { [DateTime]$_.Created }
                    }
                }
                'LastModified' {
                    $credentials = if ($Descending) {
                        $credentials | Sort-Object { [DateTime]$_.LastModified } -Descending
                    } else {
                        $credentials | Sort-Object { [DateTime]$_.LastModified }
                    }
                }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Found $($credentials.Count) credentials" -Context @{
                TotalCredentials = $credentials.Count
                FilterApplied = (-not [string]::IsNullOrEmpty($FilterType))
                ExpiredIncluded = $IncludeExpired.IsPresent
            } -Category "Security"

            return $credentials
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to list credentials: $($_.Exception.Message)" -Category "Security"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed credential listing operation" -Category "Security"
    }
}
