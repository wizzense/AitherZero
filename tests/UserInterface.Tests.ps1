#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for UserInterface.psm1 module
.DESCRIPTION
    Validates the UserInterface module functionality including UI components,
    menus, prompts, and styling
#>

BeforeAll {
    $script:projectRoot = Split-Path $PSScriptRoot -Parent
    $script:modulePath = Join-Path $script:projectRoot "aithercore/UserInterface.psm1"
    
    if (-not (Test-Path $script:modulePath)) {
        throw "UserInterface.psm1 not found at $script:modulePath"
    }
    
    # Import the module globally for tests
    Import-Module $script:modulePath -Force -Global
    
    # Set environment to prevent UI interactions during tests
    $env:CI = "true"
}

AfterAll {
    # Clean up environment variable
    if ($env:CI -eq "true") {
        Remove-Item env:CI -ErrorAction SilentlyContinue
    }
}

Describe "UserInterface Module" {
    Context "Module Loading" {
        It "Module file exists" {
            Test-Path $script:modulePath | Should -Be $true
        }
        
        It "Module loads without errors" {
            { Import-Module $script:modulePath -Force -Global } | Should -Not -Throw
        }
        
        It "Exports expected functions" {
            $exportedFunctions = (Get-Module -Name UserInterface).ExportedFunctions.Keys
            $exportedFunctions | Should -Contain 'Initialize-AitherUI'
            $exportedFunctions | Should -Contain 'Write-UIText'
            $exportedFunctions | Should -Contain 'Show-UIMenu'
            $exportedFunctions | Should -Contain 'Show-UIBorder'
            $exportedFunctions | Should -Contain 'Show-UIProgress'
            $exportedFunctions | Should -Contain 'Show-UINotification'
            $exportedFunctions | Should -Contain 'Show-UIPrompt'
            $exportedFunctions | Should -Contain 'Show-UITable'
            $exportedFunctions | Should -Contain 'Show-UISpinner'
            $exportedFunctions | Should -Contain 'Show-UIWizard'
        }
    }
    
    Context "Initialize-AitherUI" {
        It "Initializes UI without errors with DisableColors" {
            { Initialize-AitherUI -Theme 'Default' -DisableColors } | Should -Not -Throw
        }
        
        It "Accepts Dark theme with DisableColors" {
            { Initialize-AitherUI -Theme 'Dark' -DisableColors } | Should -Not -Throw
        }
        
        It "Accepts Light theme with DisableColors" {
            { Initialize-AitherUI -Theme 'Light' -DisableColors } | Should -Not -Throw
        }
        
        It "Accepts custom theme as hashtable" {
            $customTheme = @{
                Primary = 'Cyan'
                Secondary = 'Blue'
                Success = 'Green'
                Warning = 'Yellow'
                Error = 'Red'
            }
            { Initialize-AitherUI -Theme $customTheme -DisableColors } | Should -Not -Throw
        }
    }
    
    Context "Write-UIText" {
        It "Writes text without errors" {
            { Write-UIText -Message "Test message" } | Should -Not -Throw
        }
        
        It "Accepts color parameter" {
            { Write-UIText -Message "Test" -Color 'Primary' } | Should -Not -Throw
        }
        
        It "Accepts NoNewline switch" {
            { Write-UIText -Message "Test" -NoNewline } | Should -Not -Throw
        }
        
        It "Accepts Indent parameter" {
            { Write-UIText -Message "Test" -Indent 4 } | Should -Not -Throw
        }
        
        It "Handles empty message" {
            { Write-UIText -Message "" } | Should -Not -Throw
        }
    }
    
    Context "Show-UIBorder" {
        It "Shows border without errors" {
            { Show-UIBorder -Title "Test" } | Should -Not -Throw
        }
        
        It "Supports Single style" {
            { Show-UIBorder -Title "Test" -Style 'Single' } | Should -Not -Throw
        }
        
        It "Supports Double style" {
            { Show-UIBorder -Title "Test" -Style 'Double' } | Should -Not -Throw
        }
        
        It "Supports Rounded style" {
            { Show-UIBorder -Title "Test" -Style 'Rounded' } | Should -Not -Throw
        }
        
        It "Supports ASCII style" {
            { Show-UIBorder -Title "Test" -Style 'ASCII' } | Should -Not -Throw
        }
        
        It "Accepts custom width" {
            { Show-UIBorder -Title "Test" -Width 50 } | Should -Not -Throw
        }
    }
    
    Context "Show-UIProgress" {
        It "Shows progress without errors" {
            { Show-UIProgress -Activity "Test" -PercentComplete 50 } | Should -Not -Throw
        }
        
        It "Accepts Status parameter" {
            { Show-UIProgress -Activity "Test" -Status "Processing" -PercentComplete 50 } | Should -Not -Throw
        }
        
        It "Accepts Id parameter" {
            { Show-UIProgress -Activity "Test" -PercentComplete 50 -Id 2 } | Should -Not -Throw
        }
        
        It "Supports Completed switch" {
            { Show-UIProgress -Activity "Test" -PercentComplete 100 -Completed } | Should -Not -Throw
        }
    }
    
    Context "Show-UINotification" {
        It "Shows notification without errors" {
            { Show-UINotification -Message "Test notification" } | Should -Not -Throw
        }
        
        It "Supports Info type" {
            { Show-UINotification -Message "Info" -Type 'Info' } | Should -Not -Throw
        }
        
        It "Supports Success type" {
            { Show-UINotification -Message "Success" -Type 'Success' } | Should -Not -Throw
        }
        
        It "Supports Warning type" {
            { Show-UINotification -Message "Warning" -Type 'Warning' } | Should -Not -Throw
        }
        
        It "Supports Error type" {
            { Show-UINotification -Message "Error" -Type 'Error' } | Should -Not -Throw
        }
        
        It "Accepts Title parameter" {
            { Show-UINotification -Message "Test" -Title "Notice" } | Should -Not -Throw
        }
    }
    
    Context "Show-UITable" {
        It "Shows table without errors" {
            $testData = @(
                [PSCustomObject]@{ Name = "Item1"; Value = 10 }
                [PSCustomObject]@{ Name = "Item2"; Value = 20 }
            )
            { Show-UITable -Data $testData } | Should -Not -Throw
        }
        
        It "Accepts Properties parameter" {
            $testData = @(
                [PSCustomObject]@{ Name = "Item1"; Value = 10; Extra = "A" }
                [PSCustomObject]@{ Name = "Item2"; Value = 20; Extra = "B" }
            )
            { Show-UITable -Data $testData -Properties @('Name', 'Value') } | Should -Not -Throw
        }
        
        It "Accepts Title parameter" {
            $testData = @([PSCustomObject]@{ Name = "Test" })
            { Show-UITable -Data $testData -Title "Test Table" } | Should -Not -Throw
        }
    }
    
    Context "Show-UIMenu" {
        It "Shows menu in non-interactive mode" {
            $items = @("Option 1", "Option 2", "Option 3")
            { Show-UIMenu -Title "Test Menu" -Items $items -NonInteractive } | Should -Not -Throw
        }
    }
}

