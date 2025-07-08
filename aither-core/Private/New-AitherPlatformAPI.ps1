function New-AitherPlatformAPI {
    <#
    .SYNOPSIS
        Create the unified AitherZero Platform API object
    .DESCRIPTION
        Creates a fluent interface object that provides access to all platform capabilities
    .PARAMETER Profile
        Package profile being used
    .PARAMETER Environment
        Current environment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Profile,

        [Parameter(Mandatory)]
        [string]$Environment
    )

    # Create the main platform API object with fluent interface
    $platformAPI = [PSCustomObject]@{
        # Core properties
        Profile = $Profile
        Environment = $Environment
        InitializedAt = Get-Date
        Version = "1.0.0"  # TODO: Get from manifest

        # Core infrastructure APIs
        Lab = $null
        Infrastructure = $null
        Configuration = $null
        Communication = $null

        # Platform service APIs
        Orchestration = $null
        Progress = $null

        # Feature APIs (only available in standard/full)
        ISO = $null
        Security = $null
        Remote = $null
        Monitoring = $null
        API = $null

        # Development APIs (only available in full)
        Development = $null
        Testing = $null
        Patching = $null
        AI = $null

        # Operations APIs
        Backup = $null
        Maintenance = $null
        Scripts = $null
        Setup = $null

        # Platform methods
        GetStatus = $null
        GetModules = $null
        GetMetrics = $null
        Shutdown = $null
    }

    # Initialize core infrastructure APIs (always available)
    $platformAPI.Lab = New-LabAPI
    $platformAPI.Infrastructure = New-InfrastructureAPI
    $platformAPI.Configuration = New-ConfigurationAPI -Environment $Environment
    $platformAPI.Communication = New-CommunicationAPI

    # Initialize platform service APIs based on profile
    if ($Profile -in @('standard', 'full')) {
        $platformAPI.Orchestration = New-OrchestrationAPI
        $platformAPI.Progress = New-ProgressAPI

        # Feature APIs
        $platformAPI.ISO = New-ISOAPI
        $platformAPI.Security = New-SecurityAPI
        $platformAPI.Remote = New-RemoteAPI
        $platformAPI.Monitoring = New-MonitoringAPI
        $platformAPI.API = New-RestAPIGateway

        # Operations APIs
        $platformAPI.Backup = New-BackupAPI
        $platformAPI.Maintenance = New-MaintenanceAPI
        $platformAPI.Scripts = New-ScriptsAPI
        $platformAPI.Setup = New-SetupAPI
    }

    # Initialize development APIs (only for full profile)
    if ($Profile -eq 'full') {
        $platformAPI.Development = New-DevelopmentAPI
        $platformAPI.Testing = New-TestingAPI
        $platformAPI.Patching = New-PatchingAPI
        $platformAPI.AI = New-AIToolsAPI
    }

    # Initialize platform methods
    $platformAPI.GetStatus = {
        return Get-PlatformStatus -PlatformAPI $this
    }.GetNewClosure()

    $platformAPI.GetModules = {
        return Get-PlatformModules -PlatformAPI $this
    }.GetNewClosure()

    $platformAPI.GetMetrics = {
        return Get-PlatformMetrics -PlatformAPI $this
    }.GetNewClosure()

    $platformAPI.Shutdown = {
        param([switch]$Graceful = $true)
        return Stop-PlatformServices -PlatformAPI $this -Graceful:$Graceful
    }.GetNewClosure()

    # Add type information for better experience
    $platformAPI.PSObject.TypeNames.Insert(0, 'AitherZero.Platform.API')

    return $platformAPI
}
