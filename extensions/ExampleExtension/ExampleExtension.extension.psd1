@{
    # Extension Identity
    Name = 'ExampleExtension'
    Version = '1.0.0'
    Description = 'Example extension demonstrating AitherZero extensibility'
    Author = 'AitherZero Team'
    
    # PowerShell modules to load
    Modules = @(
        'modules/ExampleExtension.psm1'
    )
    
    # CLI modes this extension adds
    CLIModes = @(
        @{
            Name = 'Example'
            Handler = 'Invoke-ExampleMode'
            Description = 'Example custom CLI mode'
            Parameters = @('Target', 'Action')
        }
    )
    
    # Commands this extension provides
    Commands = @(
        @{
            Name = 'Get-ExampleData'
            Function = 'Get-ExampleData'
            Description = 'Retrieves example data'
            Alias = @('example')
        }
        @{
            Name = 'Invoke-ExampleTask'
            Function = 'Invoke-ExampleTask'
            Description = 'Executes an example task'
            Alias = @()
        }
    )
    
    # Automation scripts (8000-8999 range for extensions)
    Scripts = @(
        @{
            Number = '8000'
            Name = 'Example-Setup'
            Path = 'scripts/8000_Example-Setup.ps1'
            Category = 'Extensions'
        }
        @{
            Number = '8001'
            Name = 'Example-Status'
            Path = 'scripts/8001_Example-Status.ps1'
            Category = 'Extensions'
        }
    )
    
    # Dependencies on other extensions (none for this example)
    Dependencies = @()
    
    # Initialization script
    Initialize = 'Initialize.ps1'
    
    # Cleanup script
    Cleanup = 'Cleanup.ps1'
    
    # Minimum AitherZero version
    MinimumVersion = '2.0.0'
    
    # Extension configuration defaults
    Configuration = @{
        EnableVerboseLogging = $false
        DataPath = 'data/'
    }
}
