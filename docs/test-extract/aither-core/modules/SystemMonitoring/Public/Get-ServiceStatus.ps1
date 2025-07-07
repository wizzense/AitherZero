<#
.SYNOPSIS
    Gets the status of specified services or all critical services.

.DESCRIPTION
    Get-ServiceStatus retrieves the current status of system services,
    particularly those critical to AitherZero operations.

.PARAMETER ServiceName
    Name of specific service(s) to check. If not specified, checks all critical services.

.PARAMETER IncludeDetails
    Include detailed service information.

.EXAMPLE
    Get-ServiceStatus
    Gets status of all critical services.

.EXAMPLE
    Get-ServiceStatus -ServiceName "docker", "ssh" -IncludeDetails
    Gets detailed status for docker and ssh services.
#>
function Get-ServiceStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$ServiceName,

        [Parameter()]
        [switch]$IncludeDetails
    )

    begin {
        Write-CustomLog -Message "Checking service status" -Level "DEBUG"
        
        # Define critical services based on platform
        $criticalServices = if ($IsWindows) {
            @('WinRM', 'Hyper-V Virtual Machine Management', 'Docker Desktop Service')
        } else {
            @('ssh', 'docker')
        }
        
        # Use provided services or default to critical
        $servicesToCheck = if ($ServiceName) { $ServiceName } else { $criticalServices }
    }

    process {
        $serviceStatus = @()
        
        foreach ($service in $servicesToCheck) {
            try {
                if ($IsWindows) {
                    $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                    if ($svc) {
                        $status = [PSCustomObject]@{
                            Name = $svc.Name
                            DisplayName = $svc.DisplayName
                            Status = $svc.Status.ToString()
                            Running = $svc.Status -eq 'Running'
                            StartType = $svc.StartType.ToString()
                        }
                        
                        if ($IncludeDetails) {
                            $status | Add-Member -NotePropertyName DependentServices -NotePropertyValue $svc.DependentServices.Name
                            $status | Add-Member -NotePropertyName RequiredServices -NotePropertyValue $svc.RequiredServices.Name
                        }
                        
                        $serviceStatus += $status
                    }
                } else {
                    # Linux/macOS service check
                    $svcOutput = systemctl is-active $service 2>$null
                    $serviceStatus += [PSCustomObject]@{
                        Name = $service
                        Status = if ($svcOutput -eq 'active') { 'Running' } else { 'Stopped' }
                        Running = $svcOutput -eq 'active'
                    }
                }
            } catch {
                Write-CustomLog -Message "Error checking service $service : $($_.Exception.Message)" -Level "WARNING"
                $serviceStatus += [PSCustomObject]@{
                    Name = $service
                    Status = 'Unknown'
                    Running = $false
                    Error = $_.Exception.Message
                }
            }
        }
        
        return $serviceStatus
    }
}

Export-ModuleMember -Function Get-ServiceStatus