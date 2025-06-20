# ...existing code from /pwsh/modules/CodeFixerMenu.ps1...

function Get-MenuSelection {
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        [string]$Title = 'Select items',
        [switch]$AllowAll,
        [int]$MaxRetries = 3
    )
    $map = @{}
    for ($i=0; $i -lt $Items.Count; $i++) {
        $num = $i + 1
        $item = $Items[$i]
        $prefix = $null
        if ($item -is [string] -and $item.Length -ge 4) {
            $prefix = $item.Substring(0,4)
        }        $map["$num"] = $item
        if ($prefix) { $map[$prefix] = $item }
        $line = "{0}) {1}" -f $num, $item
        Write-CustomLog $line
        if ($env:LAB_CONSOLE_LEVEL -lt 1) { Write-Host $line }
    }
    for ($i = 0; $i -lt $MaxRetries; $i++) {
        $prompt = if ($AllowAll) { "Enter numbers/prefixes (comma separated), 'all', or 'exit'"    } else { "Enter numbers/prefixes or 'exit'"    }
        $input = Read-LoggedInput $prompt
        if ($input -match '^(?i)exit$') { return @() }
        if ($AllowAll -and $input -eq 'all') { return $Items }
        $tokens = $input -split ',' | ForEach-Object{ $_.Trim() } | Where-Object{ $_ }
        $selected = foreach ($t in $tokens) { if ($map.ContainsKey($t)) { $map[$t] } }
        if ($selected) { return $selected }
        $msg = 'Invalid selection. Try again.'
        Write-CustomLog $msg
        if ($env:LAB_CONSOLE_LEVEL -lt 1) { Write-Host $msg }
    }
    return @()
}





