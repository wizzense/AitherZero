param(
    [string]$Branch = 'main'
)

Set-ExecutionPolicy -ExecutionPolicy Bypass

$bootstrapUrl = "https://raw.githubusercontent.com/aitherium/aitherlabs/refs/heads/$Branch/core-runner/kicker-bootstrap.ps1"

# PowerShell 5.1 compatible download
try {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        Invoke-WebRequest -Uri $bootstrapUrl -OutFile '.\kicker-bootstrap.ps1'
    } else {
        # PowerShell 5.1 fallback using .NET WebClient
        $webClient = New-Object System.Net.WebClient
        $outputPath = Join-Path $PWD.Path 'kicker-bootstrap.ps1'
        $webClient.DownloadFile($bootstrapUrl, $outputPath)
        $webClient.Dispose()
    }
} catch {
    Write-Error "Failed to download kicker-bootstrap.ps1: $($_.Exception.Message)"
}

if (Test-Path '.\kicker-bootstrap.ps1') {
  Write-CustomLog "Downloaded kicker-bootstrap.ps1 to $(Resolve-Path '.\kicker-bootstrap.ps1')"
  & .\kicker-bootstrap.ps1
} else {
  Write-Error 'kicker-bootstrap.ps1 was not found after download.'
}
