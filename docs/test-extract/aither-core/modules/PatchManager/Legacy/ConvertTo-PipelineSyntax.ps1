function ConvertTo-PipelineSyntax {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    # Fix pipeline operators
    $Content = $Content -replace "\s+(ForEach-Object|Where-Object|Select-Object|Sort-Object|Group-Object|Measure-Object)", " | `$1"
    
    # Handle multi-line pipelines that lost their operators
    $lines = $Content -split "`n"
    $output = New-Object System.Text.StringBuilder
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Skip empty lines
        if ([string]::IsNullOrWhiteSpace($line)) {
            [void]$output.AppendLine($line)
            continue
        }
        
        # Check if this line ends with a pipeline target but doesn't have a pipe
        if ($line -match '\s+(ForEach-Object|Where-Object|Select-Object|Sort-Object|Group-Object|Measure-Object)\s*$') {
            # Look back to find what this line should be piped from
            for ($j = $i - 1; $j -ge 0; $j--) {
                $prevLine = $lines[$j].Trim()
                if (-not [string]::IsNullOrWhiteSpace($prevLine) -and -not $prevLine.EndsWith('|')) {
                    $lines[$j] = $prevLine + ' |'
                    break
                }
            }
        }
        
        [void]$output.AppendLine($line)
    }
    
    return $output.ToString()
}

Export-ModuleMember -Function ConvertTo-PipelineSyntax
