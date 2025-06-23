function Write-CustomLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )
    $levelIdx = @{ INFO = 1; WARN = 0; ERROR = 0 }[$Level]

    if (-not (Get-Variable -Name LogFilePath -Scope Script -ErrorAction SilentlyContinue)) {
        $logDir = $env:LAB_LOG_DIR
        if (-not $logDir) { $logDir = if ($IsWindows) { 'C:\\temp' } else { [System.IO.Path]::GetTempPath() } }
        $script:LogFilePath = Join-Path $logDir 'lab.log'
    }

    if (-not (Get-Variable -Name ConsoleLevel -Scope Script -ErrorAction SilentlyContinue)) {
        if ($env:LAB_CONSOLE_LEVEL) {
            $script:ConsoleLevel = [int]$env:LAB_CONSOLE_LEVEL
        } else {
            $script:ConsoleLevel = 1
        }
    }

    $ts  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $fmt = "$ts $Level $Message"
    $fmt | Out-File -FilePath $script:LogFilePath -Encoding utf8 -Append

    if ($levelIdx -le $script:ConsoleLevel) {
        $color = @{ INFO='Gray'; WARN='Yellow'; ERROR='Red' }[$Level]
        Write-Host $fmt -ForegroundColor $color
    }
}

function Read-LoggedInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        [switch]$AsSecureString,
        [string]$DefaultValue = ""
    )
    
    # Check if we're in non-interactive mode (test environment, etc.)
    $IsNonInteractive = ($Host.Name -eq 'Default Host') -or 
                      ([Environment]::UserInteractive -eq $false) -or
                      ($env:PESTER_RUN -eq 'true')
    
    if ($IsNonInteractive) {
        Write-CustomLog "Non-interactive mode detected. Using default value for: $Prompt" 'INFO'
        if ($AsSecureString -and -not [string]::IsNullOrEmpty($DefaultValue)) {
            return ConvertTo-SecureString -String $DefaultValue -AsPlainText -Force
        }
        return $DefaultValue
    }
    
    if ($AsSecureString) {
        Write-CustomLog "$Prompt (secure input)"
        return Read-Host -Prompt $Prompt -AsSecureString
    }
    
    $answer = Read-Host -Prompt $Prompt
    Write-CustomLog "$($Prompt): $answer"
    return $answer
}




