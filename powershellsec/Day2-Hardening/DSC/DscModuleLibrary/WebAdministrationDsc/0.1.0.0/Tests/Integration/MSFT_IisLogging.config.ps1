configuration MSFT_IisLogging_Rollover
{
    Import-DscResource -ModuleName @{ModuleName='WebAdministrationDsc'; RequiredVersion='0.1.0.0'}

    IisLogging Logging
    {
        LogPath = 'C:\IISLogFiles'
        Logflags = @('Date','Time','ClientIP','UserName','ServerIP')
        LoglocalTimeRollover = $true
        LogPeriod = 'Hourly'
        LogFormat = 'W3C'
    }
}

configuration MSFT_IisLogging_Truncate
{
    Import-DscResource -ModuleName WebAdministrationDsc

    IisLogging Logging
    {
        LogPath = 'C:\IISLogFiles'
        Logflags = @('Date','Time','ClientIP','UserName','ServerIP')
        LoglocalTimeRollover = $true
        LogTruncateSize = '2097152'
        LogFormat = 'W3C'
    }
}
