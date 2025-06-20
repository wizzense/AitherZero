function Invoke-LabWebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [string]$OutFile,
        [switch]$UseBasicParsing
    )
    Invoke-WebRequest @PSBoundParameters
}

# Provide a module-scoped wrapper so tests can mock Invoke-WebRequest via
# -ModuleName LabSetup. This delegates to the built-in cmdlet.
function Invoke-WebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [string]$OutFile,
        [switch]$UseBasicParsing
    )
    Microsoft.PowerShell.Utility\Invoke-WebRequest @PSBoundParameters
}

function Invoke-LabNpm {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Args
    )
    npm @Args
}



