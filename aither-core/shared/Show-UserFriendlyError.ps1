# User-Friendly Error System for AitherZero
# Converts technical errors into actionable user guidance

function Show-UserFriendlyError {
    <#
    .SYNOPSIS
        Displays user-friendly error messages with actionable solutions
    
    .DESCRIPTION
        Converts technical PowerShell errors into clear, user-friendly messages
        with specific solutions and next steps
    
    .PARAMETER ErrorRecord
        The original error record from PowerShell
    
    .PARAMETER Context
        Additional context about what was being attempted
    
    .PARAMETER Module
        The module where the error occurred
    
    .EXAMPLE
        Show-UserFriendlyError -ErrorRecord $_ -Context "Starting AitherZero" -Module "Core"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = "Operation",
        
        [Parameter(Mandatory = $false)]
        [string]$Module = "AitherZero"
    )
    
    # Extract error details
    $errorMessage = $ErrorRecord.Exception.Message
    $errorCategory = $ErrorRecord.CategoryInfo.Category
    $errorType = $ErrorRecord.Exception.GetType().Name
    $scriptName = $ErrorRecord.InvocationInfo.ScriptName
    $lineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
    
    # User-friendly error mapping
    $userFriendlyError = Get-UserFriendlyErrorInfo -ErrorMessage $errorMessage -ErrorType $errorType -ErrorCategory $errorCategory -Context $Context
    
    # Display user-friendly error
    Write-Host "" -ForegroundColor Yellow
    Write-Host "┌─────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "│                                ⚠️  ERROR                                        │" -ForegroundColor Yellow
    Write-Host "├─────────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor Yellow
    Write-Host "│                                                                                 │" -ForegroundColor White
    Write-Host "│  $($userFriendlyError.Title.PadRight(77))  │" -ForegroundColor White
    Write-Host "│                                                                                 │" -ForegroundColor White
    Write-Host "├─────────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor Yellow
    Write-Host "│                                                                                 │" -ForegroundColor White
    Write-Host "│  What happened:                                                                 │" -ForegroundColor Cyan
    
    # Word wrap the description
    $description = $userFriendlyError.Description
    $descriptionLines = Format-TextForBox -Text $description -Width 75
    foreach ($line in $descriptionLines) {
        Write-Host "│  $($line.PadRight(77))  │" -ForegroundColor White
    }
    
    Write-Host "│                                                                                 │" -ForegroundColor White
    Write-Host "│  How to fix it:                                                                 │" -ForegroundColor Green
    
    # Display solutions
    for ($i = 0; $i -lt $userFriendlyError.Solutions.Count; $i++) {
        $solution = $userFriendlyError.Solutions[$i]
        Write-Host "│  $($i + 1). $($solution.PadRight(74))  │" -ForegroundColor Green
    }
    
    Write-Host "│                                                                                 │" -ForegroundColor White
    
    # Display commands if available
    if ($userFriendlyError.Commands.Count -gt 0) {
        Write-Host "│  Quick fix commands:                                                            │" -ForegroundColor Magenta
        foreach ($command in $userFriendlyError.Commands) {
            Write-Host "│  > $($command.PadRight(75))  │" -ForegroundColor Magenta
        }
        Write-Host "│                                                                                 │" -ForegroundColor White
    }
    
    # Display help link
    if ($userFriendlyError.HelpLink) {
        Write-Host "│  More help: $($userFriendlyError.HelpLink.PadRight(66))  │" -ForegroundColor Cyan
        Write-Host "│                                                                                 │" -ForegroundColor White
    }
    
    Write-Host "└─────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    
    # Optional: Show technical details in verbose mode
    if ($VerbosePreference -eq 'Continue') {
        Write-Host "Technical details (for support):" -ForegroundColor DarkGray
        Write-Host "  Error Type: $errorType" -ForegroundColor DarkGray
        Write-Host "  Category: $errorCategory" -ForegroundColor DarkGray
        Write-Host "  Script: $scriptName" -ForegroundColor DarkGray
        Write-Host "  Line: $lineNumber" -ForegroundColor DarkGray
        Write-Host "  Original Message: $errorMessage" -ForegroundColor DarkGray
        Write-Host ""
    }
}

function Get-UserFriendlyErrorInfo {
    <#
    .SYNOPSIS
        Maps technical errors to user-friendly information
    #>
    [CmdletBinding()]
    param(
        [string]$ErrorMessage,
        [string]$ErrorType,
        [string]$ErrorCategory,
        [string]$Context
    )
    
    # Common error patterns and their user-friendly equivalents
    $errorMappings = @{
        # PowerShell version errors
        "PowerShell.*version.*required" = @{
            Title = "PowerShell Version Issue"
            Description = "AitherZero needs PowerShell 7.0 or newer to run properly."
            Solutions = @(
                "Install PowerShell 7 using: winget install Microsoft.PowerShell",
                "Or download from: https://aka.ms/powershell-release",
                "After installation, run this script again"
            )
            Commands = @("winget install Microsoft.PowerShell")
            HelpLink = "https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell"
        }
        
        # Module not found errors
        "Could not load.*module|module.*not found" = @{
            Title = "Missing Module or Component"
            Description = "A required component couldn't be found. This usually means AitherZero wasn't installed completely."
            Solutions = @(
                "Run the setup wizard: ./Start-AitherZero.ps1 -Setup",
                "Check if all files were extracted properly",
                "Try downloading AitherZero again"
            )
            Commands = @("./Start-AitherZero.ps1 -Setup")
            HelpLink = "https://github.com/wizzense/AitherZero/blob/main/README.md"
        }
        
        # Permission errors
        "Access.*denied|permission.*denied|unauthorized" = @{
            Title = "Permission Problem"
            Description = "You don't have the necessary permissions to perform this action."
            Solutions = @(
                "Run PowerShell as Administrator (Windows)",
                "Check file permissions and ownership",
                "Make sure you have write access to the directory"
            )
            Commands = @("Start-Process powershell -Verb RunAs")
            HelpLink = "https://docs.microsoft.com/en-us/powershell/scripting/security/remoting/running-remote-commands"
        }
        
        # Network/connectivity errors
        "network.*error|connection.*failed|timeout" = @{
            Title = "Network Connection Issue"
            Description = "Couldn't connect to the internet or a required service."
            Solutions = @(
                "Check your internet connection",
                "Try again in a few minutes",
                "If behind a firewall, check proxy settings"
            )
            Commands = @("Test-NetConnection -ComputerName google.com -Port 80")
            HelpLink = "https://docs.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection"
        }
        
        # File not found errors
        "file.*not found|path.*not found|cannot find" = @{
            Title = "File or Path Not Found"
            Description = "A required file or directory is missing."
            Solutions = @(
                "Check if the file path is correct",
                "Make sure AitherZero is in the right directory",
                "Try re-installing AitherZero"
            )
            Commands = @("Get-Location", "Test-Path ./Start-AitherZero.ps1")
            HelpLink = "https://github.com/wizzense/AitherZero/blob/main/README.md"
        }
        
        # Configuration errors
        "configuration.*invalid|config.*error" = @{
            Title = "Configuration Problem"
            Description = "There's an issue with the configuration settings."
            Solutions = @(
                "Reset configuration: ./Start-AitherZero.ps1 -Setup",
                "Check configuration files for errors",
                "Try with default settings first"
            )
            Commands = @("./Start-AitherZero.ps1 -Setup")
            HelpLink = "https://github.com/wizzense/AitherZero/blob/main/docs/CONFIGURATION.md"
        }
        
        # Generic PowerShell errors
        "command.*not recognized|not recognized as.*cmdlet" = @{
            Title = "Command Not Available"
            Description = "A required command or function is missing."
            Solutions = @(
                "Make sure all modules are loaded properly",
                "Run setup to install missing components",
                "Check if the command name is spelled correctly"
            )
            Commands = @("./Start-AitherZero.ps1 -Setup", "Get-Module -ListAvailable")
            HelpLink = "https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-module"
        }
    }
    
    # Find matching error pattern
    $matchedError = $null
    foreach ($pattern in $errorMappings.Keys) {
        if ($ErrorMessage -match $pattern) {
            $matchedError = $errorMappings[$pattern]
            break
        }
    }
    
    # Default error info if no specific match found
    if (-not $matchedError) {
        $matchedError = @{
            Title = "Unexpected Error in $Context"
            Description = "Something went wrong that we didn't expect. This might be a bug or an unusual situation."
            Solutions = @(
                "Try running the operation again",
                "Check if all prerequisites are met",
                "Report this issue if it continues to happen"
            )
            Commands = @("./Start-AitherZero.ps1 -Setup")
            HelpLink = "https://github.com/wizzense/AitherZero/issues"
        }
    }
    
    return $matchedError
}

function Format-TextForBox {
    <#
    .SYNOPSIS
        Formats text to fit within a specified width
    #>
    [CmdletBinding()]
    param(
        [string]$Text,
        [int]$Width = 75
    )
    
    $words = $Text -split '\s+'
    $lines = @()
    $currentLine = ""
    
    foreach ($word in $words) {
        if (($currentLine + " " + $word).Length -le $Width) {
            if ($currentLine) {
                $currentLine += " " + $word
            } else {
                $currentLine = $word
            }
        } else {
            if ($currentLine) {
                $lines += $currentLine
            }
            $currentLine = $word
        }
    }
    
    if ($currentLine) {
        $lines += $currentLine
    }
    
    return $lines
}

# Export functions only if running as a module
if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function Show-UserFriendlyError
}