param(
    string$Branch = 'main'
)

Set-ExecutionPolicy -ExecutionPolicy Bypass

$bootstrapUrl = "https://raw.githubusercontent.com/aitherium/aitherlabs/refs/heads/$Branch/core-runner/kicker-bootstrap.ps1"
Invoke-WebRequest -Uri $bootstrapUrl -OutFile '.\kicker-bootstrap.ps1'

if (Test-Path '.\kicker-bootstrap.ps1') {
  Write-CustomLog "Downloaded kicker-bootstrap.ps1 to $(Resolve-Path '.\kicker-bootstrap.ps1')"
  & .\kicker-bootstrap.ps1
} else {
  Write-Error 'kicker-bootstrap.ps1 was not found after download.'
}
