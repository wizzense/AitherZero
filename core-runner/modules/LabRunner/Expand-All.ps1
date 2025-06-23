# ...existing code from /pwsh/modules/CodeFixerExpand-All.ps1...
function Expand-All {
    # Expand-All -ZipFile "C:\path\to\your\archive.zip"
    param(
        [string]$ZipFile
    )
      # Ensure logging helpers are available for each invocation
    if (-not (Get-Command Read-LoggedInput -ErrorAction SilentlyContinue)) {
        $logger = Join-Path $PSScriptRoot '..\LabRunner\Logger.ps1'
        if (Test-Path $logger) { . $logger }
        if (-not (Get-Command Read-LoggedInput -ErrorAction SilentlyContinue)) {
            function Read-LoggedInput { 
                param($Prompt, [switch]$AsSecureString, [string]$DefaultValue = "")
                
                # Check if we're in non-interactive mode (test environment, etc.)
                $IsNonInteractive = ($Host.Name -eq 'Default Host') -or 
                                  ([Environment]::UserInteractive -eq $false) -or
                                  ($env:PESTER_RUN -eq 'true')
                
                if ($IsNonInteractive) {
                    Write-Verbose "Non-interactive mode detected. Using default value for: $Prompt"
                    if ($AsSecureString -and -not [string]::IsNullOrEmpty($DefaultValue)) {
                        return ConvertTo-SecureString -String $DefaultValue -AsPlainText -Force
                    }
                    return $DefaultValue
                } else {
                    if ($AsSecureString) {
                        return Read-Host -Prompt $Prompt -AsSecureString
                    } else {
                        return Read-Host $Prompt 
                    }
                }
            }
        }
    }
    if ($ZipFile) {
        # Expand a specific zip file if provided
        if (-not (Test-Path $ZipFile)) {
            Write-CustomLog "File '$ZipFile' does not exist."
            return
        }
        Write-CustomLog "Specified ZIP file: $ZipFile"
        $confirmation = Read-LoggedInput "Do you want to expand this archive? (y/n)"
        if ($confirmation -ne 'y') {
            Write-CustomLog "Operation canceled."
            return
        }
        $destination = Join-Path -Path (Split-Path $ZipFile -Parent) -ChildPath (Split-Path $ZipFile -LeafBase)
        Write-CustomLog "Expanding archive: $ZipFile to $destination"
        Expand-Archive -Path $ZipFile -DestinationPath $destination -Force
        Write-CustomLog "Archive expanded."
    }
    else {
        # Expand all zip files recursively in the current directory
        $currentDir = Get-Location
        Write-CustomLog "Current Directory: $currentDir"
        $confirmation = Read-LoggedInput "Do you want to expand all archives in this directory and its subdirectories? (y/n)"
        if ($confirmation -ne 'y') {
            Write-CustomLog "Operation canceled."
            return
        }
        Get-ChildItem -Path $currentDir -Recurse -Filter *.zip | ForEach-Object{
            $destination = Join-Path -Path $_.DirectoryName -ChildPath $_.BaseName
            Write-CustomLog "Expanding archive: $($_.FullName) to $destination"
            Expand-Archive -Path $_.FullName -DestinationPath $destination -Force
        }
        Write-CustomLog "All archives expanded."
    }
}





