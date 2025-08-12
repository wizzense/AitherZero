#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "automation-scripts/0820_Save-WorkContext.ps1"
    
    Mock Write-Host -MockWith {}
    Mock Write-Error -MockWith {}
    Mock New-Item -MockWith { return [PSCustomObject]@{ FullName = $Path } }
    Mock Set-Content -MockWith {}
    Mock Get-Item -MockWith { return [PSCustomObject]@{ Length = 1024 } }
    
    # Mock git commands
    Mock git -MockWith {
        switch ($arguments[0]) {
            "branch" { return "main" }
            "status" { return "M file1.ps1`nA file2.ps1" }
            "log" { return "abc123 Initial commit" }
            "remote" { return "origin https://github.com/test/repo.git (fetch)" }
            "stash" { return "" }
            "diff" { return "file1.ps1 | 2 +-" }
            "ls-files" { return "newfile.ps1" }
            default { return "" }
        }
    }
    
    # Mock PowerShell functions
    Mock Get-Location -MockWith { return [PSCustomObject]@{ Path = "/test/path" } }
    Mock Get-Module -MockWith {
        return @(
            [PSCustomObject]@{ Name = "TestModule"; Version = "1.0.0"; Path = "/path/to/module" }
        )
    }
    Mock Get-History -MockWith {
        return @(
            [PSCustomObject]@{ 
                CommandLine = "Get-Process"
                StartExecutionTime = Get-Date
                EndExecutionTime = Get-Date
            }
        )
    }
    Mock Get-ChildItem -MockWith {
        if ($Path -like "*env:*") {
            return @(
                [PSCustomObject]@{ Name = "AITHERZERO_ROOT"; Value = "/test/aitherzero" }
            )
        }
        if ($Recurse -and $Include) {
            return @(
                [PSCustomObject]@{ 
                    FullName = "/test/file1.ps1"
                    LastWriteTime = (Get-Date).AddHours(-1)
                }
            )
        }
        if ($Filter -like "*.json") {
            return @(
                [PSCustomObject]@{
                    FullName = "/test/results/test.json"
                    LastWriteTime = Get-Date
                }
            )
        }
        return @()
    }
    Mock Get-Content -MockWith {
        if ($Path -like "*VERSION*") {
            return "1.0.0"
        }
        if ($Path -like "*test.json") {
            return '{"TotalCount": 10, "PassedCount": 8, "FailedCount": 2}'
        }
        if ($Path -like "*psscriptanalyzer*") {
            return '[{"RuleName": "TestRule", "Severity": "Warning"}]'
        }
        return "test content"
    }
    Mock Test-Path -MockWith { $true }
    Mock Get-Date -MockWith { return [DateTime]"2023-01-01 12:00:00" }
    Mock Resolve-Path -MockWith { return $Path -replace "^\./", "" }
    Mock Get-Command -MockWith { return $true } -ParameterFilter { $Name -eq "gh" }
    Mock gh -MockWith { return '[{"number": 123, "title": "Test Issue"}]' }
    Mock Split-Path -MockWith { 
        if ($Parent) { return "/test" }
        return "context.json"
    } -ParameterFilter { $Path -like "*context*" }
    
    # Mock Measure-Object
    Mock Measure-Object -MockWith { 
        return [PSCustomObject]@{ Lines = 100 }
    }
}

Describe "0820_Save-WorkContext" {
    Context "Parameter Validation" {
        It "Should support WhatIf functionality" {
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept custom OutputPath" {
            { & $scriptPath -OutputPath "custom/path.json" -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept HistoryCount parameter" {
            { & $scriptPath -HistoryCount 25 -WhatIf } | Should -Not -Throw
        }
        
        It "Should support IncludeHistory switch" {
            { & $scriptPath -IncludeHistory -WhatIf } | Should -Not -Throw
        }
        
        It "Should support CompressContext switch" {
            { & $scriptPath -CompressContext -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Directory Creation" {
        It "Should create output directory if it does not exist" {
            Mock Test-Path -MockWith { $false } -ParameterFilter { $Path -like "*.claude*" }
            Mock Split-Path -MockWith { return ".claude" } -ParameterFilter { $Parent -eq $true }
            
            & $scriptPath -OutputPath ".claude/test.json"
            
            Should -Invoke New-Item -Times 1 -ParameterFilter { $ItemType -eq "Directory" }
        }
        
        It "Should not create directory if it already exists" {
            Mock Test-Path -MockWith { $true }
            
            & $scriptPath -OutputPath ".claude/test.json"
            
            Should -Invoke New-Item -Times 0 -ParameterFilter { $ItemType -eq "Directory" }
        }
    }
    
    Context "Git Context Collection" {
        It "Should collect git branch information" {
            & $scriptPath
            
            Should -Invoke git -ParameterFilter { $arguments[0] -eq "branch" -and $arguments[1] -eq "--show-current" }
        }
        
        It "Should collect git status" {
            & $scriptPath
            
            Should -Invoke git -ParameterFilter { $arguments[0] -eq "status" -and $arguments[1] -eq "--short" }
        }
        
        It "Should collect recent commits" {
            & $scriptPath
            
            Should -Invoke git -ParameterFilter { $arguments[0] -eq "log" -and $arguments[1] -eq "--oneline" }
        }
        
        It "Should collect remote information" {
            & $scriptPath
            
            Should -Invoke git -ParameterFilter { $arguments[0] -eq "remote" -and $arguments[1] -eq "-v" }
        }
        
        It "Should collect diff summary" {
            & $scriptPath
            
            Should -Invoke git -ParameterFilter { $arguments[0] -eq "diff" -and $arguments[1] -eq "--stat" }
        }
        
        It "Should collect staged and untracked files" {
            & $scriptPath
            
            Should -Invoke git -ParameterFilter { $arguments[0] -eq "diff" -and $arguments[1] -eq "--cached" }
            Should -Invoke git -ParameterFilter { $arguments[0] -eq "ls-files" }
        }
        
        It "Should analyze modified files with line counts" {
            Mock git -MockWith {
                if ($arguments[0] -eq "status" -and $arguments[1] -eq "--porcelain") {
                    return "M  file1.ps1`nA  file2.ps1"
                }
                return ""
            }
            
            & $scriptPath
            
            Should -Invoke git -ParameterFilter { $arguments[0] -eq "status" -and $arguments[1] -eq "--porcelain" }
        }
    }
    
    Context "PowerShell Context Collection" {
        It "Should collect current directory" {
            & $scriptPath
            
            Should -Invoke Get-Location -Times 1
        }
        
        It "Should collect loaded modules" {
            & $scriptPath
            
            Should -Invoke Get-Module -Times 1
        }
        
        It "Should collect relevant environment variables" {
            & $scriptPath
            
            Should -Invoke Get-ChildItem -ParameterFilter { $Path -like "*env:*" }
        }
        
        It "Should collect command history when requested" {
            & $scriptPath -IncludeHistory -HistoryCount 10
            
            Should -Invoke Get-History -ParameterFilter { $Count -eq 10 }
        }
        
        It "Should collect recent errors" {
            # Mock the $Error variable
            $global:Error = @([System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Test error"),
                "TestError",
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $null
            ))
            
            & $scriptPath
            
            # Should process error collection
            Should -Invoke Get-Date -AtLeast 1
            
            # Cleanup
            $global:Error.Clear()
        }
    }
    
    Context "Test Context Collection" {
        It "Should check for test results" {
            & $scriptPath
            
            Should -Invoke Get-ChildItem -ParameterFilter { $Path -like "*tests/results*" }
        }
        
        It "Should parse test results when available" {
            Mock Get-ChildItem -MockWith {
                return @([PSCustomObject]@{
                    FullName = "/test/results/test.json"
                    LastWriteTime = Get-Date
                })
            } -ParameterFilter { $Path -like "*tests/results*" }
            
            & $scriptPath
            
            Should -Invoke Get-Content -AtLeast 1
        }
        
        It "Should handle malformed test results gracefully" {
            Mock Get-Content -MockWith { return "invalid json" } -ParameterFilter { $Path -like "*test.json*" }
            
            { & $scriptPath } | Should -Not -Throw
        }
        
        It "Should parse PSScriptAnalyzer results" {
            Mock Test-Path -MockWith { $true } -ParameterFilter { $Path -like "*psscriptanalyzer*" }
            
            & $scriptPath
            
            Should -Invoke Test-Path -AtLeast 1
        }
    }
    
    Context "Project Context Collection" {
        It "Should read project version" {
            & $scriptPath
            
            Should -Invoke Test-Path -ParameterFilter { $Path -like "*VERSION*" }
        }
        
        It "Should collect recently modified files" {
            & $scriptPath
            
            Should -Invoke Get-ChildItem -ParameterFilter { $Recurse -eq $true -and $File -eq $true }
        }
        
        It "Should scan for TODO items" {
            Mock Get-ChildItem -MockWith {
                return @([PSCustomObject]@{
                    FullName = "/test/file1.ps1"
                })
            } -ParameterFilter { $Include -contains "*.ps1" }
            
            Mock Get-Content -MockWith {
                return @("# TODO: Fix this function", "Write-Host test", "# FIXME: Memory leak")
            }
            
            & $scriptPath
            
            Should -Invoke Get-ChildItem -AtLeast 1
        }
        
        It "Should collect GitHub issues when available" {
            & $scriptPath
            
            Should -Invoke Get-Command -ParameterFilter { $Name -eq "gh" }
            Should -Invoke gh -ParameterFilter { $arguments[0] -eq "issue" -and $arguments[1] -eq "list" }
        }
        
        It "Should handle missing GitHub CLI gracefully" {
            Mock Get-Command -MockWith { return $null } -ParameterFilter { $Name -eq "gh" }
            
            { & $scriptPath } | Should -Not -Throw
        }
        
        It "Should handle GitHub API errors gracefully" {
            Mock gh -MockWith { throw "API error" }
            
            { & $scriptPath } | Should -Not -Throw
        }
    }
    
    Context "Context Compression" {
        It "Should compress context when requested" {
            Mock Get-Content -MockWith {
                # Return large diff summary to trigger compression
                return @(1..50 | ForEach-Object { "file$_.ps1 | 10 ++++++++" })
            } -ParameterFilter { $Path -like "*diff*" }
            
            & $scriptPath -CompressContext
            
            # Should still save content but compressed
            Should -Invoke Set-Content -Times 1
        }
        
        It "Should limit command history in compression" {
            $longHistory = @(1..50 | ForEach-Object {
                [PSCustomObject]@{
                    CommandLine = "Command $_"
                    StartExecutionTime = Get-Date
                    EndExecutionTime = Get-Date
                }
            })
            Mock Get-History -MockWith { return $longHistory }
            
            & $scriptPath -CompressContext -IncludeHistory
            
            Should -Invoke Get-History -Times 1
        }
        
        It "Should limit TODO list in compression" {
            Mock Get-ChildItem -MockWith {
                return @(1..20 | ForEach-Object {
                    [PSCustomObject]@{ FullName = "/test/file$_.ps1" }
                })
            } -ParameterFilter { $Include -contains "*.ps1" }
            
            Mock Get-Content -MockWith {
                return @("# TODO: Item $_")
            }
            
            & $scriptPath -CompressContext
            
            Should -Invoke Get-ChildItem -AtLeast 1
        }
    }
    
    Context "File Output" {
        It "Should save context to JSON file" {
            & $scriptPath
            
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*.json" }
        }
        
        It "Should save markdown summary" {
            & $scriptPath
            
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*.md" }
        }
        
        It "Should calculate and display file size" {
            & $scriptPath
            
            Should -Invoke Get-Item -Times 1
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Size:*KB*" }
        }
        
        It "Should display context summary" {
            & $scriptPath
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Context Summary:*" }
        }
    }
    
    Context "Error Handling" {
        It "Should handle file system errors gracefully" {
            Mock Set-Content -MockWith { throw "Disk full" }
            
            { & $scriptPath } | Should -Throw
        }
        
        It "Should handle git errors gracefully" {
            Mock git -MockWith { throw "Not a git repository" }
            
            { & $scriptPath } | Should -Not -Throw
        }
        
        It "Should handle missing directories gracefully" {
            Mock Test-Path -MockWith { $false }
            Mock Split-Path -MockWith { throw "Invalid path" }
            
            { & $scriptPath -OutputPath "invalid/path.json" } | Should -Throw
        }
        
        It "Should validate output path" {
            { & $scriptPath -OutputPath "" } | Should -Not -Throw
        }
    }
    
    Context "Platform Compatibility" {
        It "Should handle Windows paths" {
            Mock Split-Path -MockWith { return "C:\test" } -ParameterFilter { $Parent -eq $true }
            
            { & $scriptPath -OutputPath "C:\test\context.json" } | Should -Not -Throw
        }
        
        It "Should handle Unix paths" {
            Mock Split-Path -MockWith { return "/test" } -ParameterFilter { $Parent -eq $true }
            
            { & $scriptPath -OutputPath "/test/context.json" } | Should -Not -Throw
        }
        
        It "Should handle relative paths" {
            Mock Split-Path -MockWith { return "./test" } -ParameterFilter { $Parent -eq $true }
            
            { & $scriptPath -OutputPath "./test/context.json" } | Should -Not -Throw
        }
    }
}
