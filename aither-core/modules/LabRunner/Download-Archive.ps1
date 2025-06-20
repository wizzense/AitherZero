# ...existing code from /pwsh/modules/CodeFixerDownload-Archive.ps1...
function Get-GhDownloadArgs {
    [CmdletBinding()]
    param()
    
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            gh auth status --hostname github.com *> $null
            return @{ UseGh = $true }
        }
        catch {
            Write-Host 'gh authentication failed; using public download URLs.' -ForegroundColor Yellow
        }
    }
    return @{}
}

function Invoke-ArchiveDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Destination,
        [switch]$Required,
        [switch]$UseGh
    )
    if ($UseGh) {
        gh api $Url --output $Destination
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to download $(Split-Path $Destination -Leaf) artifact." -ForegroundColor Yellow
            if ($Required) {
                throw "Download failed for required artifact: $(Split-Path $Destination -Leaf)."
            }
        }
    }
    else {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
            if (-not $?) { throw }
        }
        catch {
            Write-Host "Failed to download $(Split-Path $Destination -Leaf) artifact anonymously." -ForegroundColor Yellow
            if ($Required) {
                throw "Download failed for required artifact: $(Split-Path $Destination -Leaf)."
            }
        }
    }
}





