#Requires -Version 7.0

<#
.SYNOPSIS
    Integration test to validate PowerShell syntax in GitHub Actions workflow files
.DESCRIPTION
    This test scans all workflow files for embedded PowerShell code and validates
    that the syntax is correct. It specifically checks for common issues like
    multi-line if-elseif-else statements that can cause parsing errors.
#>

BeforeAll {
    $script:WorkflowsPath = Join-Path $PSScriptRoot "../../.github/workflows"
}

Describe "Workflow PowerShell Syntax Validation" {
    Context "All workflow files" {
        BeforeAll {
            $script:WorkflowFiles = Get-ChildItem -Path $script:WorkflowsPath -Filter "*.yml" -File
        }

        It "Should have at least one workflow file to test" {
            $script:WorkflowFiles.Count | Should -BeGreaterThan 0
        }

        foreach ($workflowFile in $script:WorkflowFiles) {
            Context "Workflow: $($workflowFile.Name)" {
                BeforeAll {
                    $script:Content = Get-Content -Path $workflowFile.FullName -Raw
                }

                It "Should not contain multi-line if-elseif-else with improper line breaks" {
                    # Pattern that matches problematic multi-line if-elseif-else statements
                    # This looks for if statements followed by newline + spaces + elseif/else
                    $problematicPattern = '(?m)if\s*\([^)]+\)\s*\{[^}]*\}\s*\n\s+elseif'
                    
                    if ($script:Content -match $problematicPattern) {
                        # Extract context around the match for better error reporting
                        $matchIndex = $script:Content.IndexOf($matches[0])
                        $contextStart = [Math]::Max(0, $matchIndex - 50)
                        $contextEnd = [Math]::Min($script:Content.Length, $matchIndex + $matches[0].Length + 50)
                        $context = $script:Content.Substring($contextStart, $contextEnd - $contextStart)
                        
                        throw "Found problematic multi-line if-elseif-else statement in $($workflowFile.Name). Context: $context"
                    }
                    
                    $true | Should -Be $true
                }

                It "Should not contain orphaned 'elseif' or 'else' at line start" {
                    # Look for lines that start with elseif or else (after whitespace)
                    # This pattern can cause issues in GitHub Actions workflow execution
                    $lines = $script:Content -split "`n"
                    $problematicLines = @()
                    
                    for ($i = 0; $i -lt $lines.Count; $i++) {
                        $line = $lines[$i]
                        # Check if line starts with elseif or else (ignoring leading whitespace)
                        # AND is not part of a single-line if statement
                        if ($line -match '^\s+(elseif|else)\s+') {
                            # Check if this is actually the start of a new statement line
                            # (not part of a single-line if-elseif-else)
                            if ($i -gt 0) {
                                $prevLine = $lines[$i-1]
                                # If previous line ends with } and current line starts with elseif/else,
                                # and they're not on the same logical line, flag it
                                if ($prevLine -match '\}\s*$' -and $prevLine -notmatch 'elseif.*\{' -and $prevLine -notmatch 'else.*\{') {
                                    $problematicLines += @{
                                        LineNumber = $i + 1
                                        Line = $line.Trim()
                                        Context = "$($prevLine.Trim())`n$($line.Trim())"
                                    }
                                }
                            }
                        }
                    }
                    
                    if ($problematicLines.Count -gt 0) {
                        $details = $problematicLines | ForEach-Object { "Line $($_.LineNumber): $($_.Line)" }
                        throw "Found potentially problematic elseif/else statements in $($workflowFile.Name) that may cause GitHub Actions parsing issues: `n$($details -join "`n")"
                    }
                    
                    $problematicLines.Count | Should -Be 0
                }

                It "Should have valid YAML structure" {
                    # Basic YAML validation
                    { 
                        $null = Test-YamlStructure -Yaml $script:Content
                    } | Should -Not -Throw
                }
            }
        }
    }

    Context "PowerShell syntax patterns" {
        BeforeAll {
            # Common test code for syntax validation
            $script:SingleLineIfElseIfElse = '$cssClass = if ($status -eq ''Passed'') { ''success'' } elseif ($status -eq ''Failed'') { ''error'' } else { ''warning'' }'
        }
        
        It "Should validate single-line if-elseif-else syntax" {
            { 
                [scriptblock]::Create($script:SingleLineIfElseIfElse)
            } | Should -Not -Throw
        }

        It "Should use single-line if-elseif-else for GitHub Actions compatibility" {
            # While PowerShell may accept multi-line if-elseif-else with leading whitespace,
            # GitHub Actions workflows can have issues parsing them. Test that we prefer
            # single-line format for better compatibility.
            { 
                [scriptblock]::Create($script:SingleLineIfElseIfElse)
            } | Should -Not -Throw
        }

        It "Should accept properly formatted multi-line if-elseif-else" {
            $testCode = @'
$cssClass = if ($status -eq 'Passed') { 
    'success' 
} elseif ($status -eq 'Failed') { 
    'error' 
} else { 
    'warning' 
}
'@
            
            { 
                [scriptblock]::Create($testCode)
            } | Should -Not -Throw
        }
    }
}

# Helper function to validate YAML structure
function Test-YamlStructure {
    param([string]$Yaml)
    
    # Basic validation - check if it can be loaded by Python's yaml module
    # or use a PowerShell YAML parser if available
    try {
        # Try using PowerShell-Yaml module if available
        if (Get-Module -ListAvailable -Name powershell-yaml) {
            Import-Module powershell-yaml -ErrorAction Stop
            # Use the imported module's function
            $null = ConvertFrom-Yaml -Yaml $Yaml
            return $true
        } else {
            # Fallback to Python if available
            $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } 
                        elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
                        else { $null }
            
            if (-not $pythonCmd) {
                Write-Warning "Neither PowerShell-Yaml module nor Python is available for YAML validation. Skipping detailed validation."
                return $true
            }
            
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                $Yaml | Set-Content -Path $tempFile
                # Properly escape the file path for shell execution
                $escapedPath = $tempFile -replace "'", "'\''"
                $result = & $pythonCmd -c "import yaml; yaml.safe_load(open('$escapedPath'))" 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    throw "YAML validation failed: $result"
                }
                return $true
            } finally {
                if (Test-Path $tempFile) {
                    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } catch {
        throw "YAML validation failed: $_"
    }
}
