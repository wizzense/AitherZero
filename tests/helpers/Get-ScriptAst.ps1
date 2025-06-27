function Get-ScriptAst {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Get-ScriptAst: File not found: $Path"
    }
    try {
        $text = Get-Content -Raw -Encoding UTF8 $Path
    } catch {
        throw "Get-ScriptAst: Failed to read file: $Path. $_"
    }
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
    }
    try {
        $errors = $null
        return [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errors)
    } catch {
        throw "Get-ScriptAst: Failed to parse file: $Path. $_"
    }
}
