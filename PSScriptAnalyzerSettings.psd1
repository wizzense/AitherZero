# PSScriptAnalyzer Configuration for AitherZero
# Enterprise-grade PowerShell automation framework
# Security-focused rules with cross-platform compatibility

@{
    # Include all default rules by default
    IncludeDefaultRules = $true
    
    # Severity levels to analyze
    Severity = @('Error', 'Warning', 'Information')
    
    # Explicitly include high-priority rules
    IncludeRules = @(
        # Security Rules (Critical)
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSUsePSCredentialType',
        'PSAvoidHardcodedCredentials',
        'PSAvoidUsingWriteHost',
        'PSAvoidUsingInvokeExpression',
        
        # Cross-Platform Compatibility Rules
        'PSUseCompatibleCmdlets',
        'PSUseCompatibleSyntax',
        'PSUseCompatibleTypes',
        'PSUseCompatibleCommands',
        
        # Code Quality Rules
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPositionalParameters',
        'PSUseCmdletCorrectly',
        'PSUseOutputTypeCorrectly',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSProvideCommentHelp',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSUseBOMForUnicodeEncodedFile',
        'PSMissingModuleManifestField',
        'PSUseConsistentWhitespace',
        'PSUseConsistentIndentation',
        'PSAlignAssignmentStatement',
        'PSUseCorrectCasing',
        
        # Performance Rules
        'PSAvoidAssignmentToAutomaticVariable',
        'PSAvoidGlobalVars',
        'PSAvoidUsingFilePath',
        'PSAvoidUsingComputerNameHardcoded',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidDefaultValueForMandatoryParameter',
        'PSAvoidNullOrEmptyHelpMessageAttribute',
        'PSAvoidLongLines',
        'PSAvoidMultipleTypeAttributes',
        'PSAvoidSemicolonsAsLineTerminators',
        'PSAvoidTrailingWhitespace',
        'PSAvoidUsingDoubleQuotesForConstantString',
        'PSAvoidOverwritingBuiltInCmdlets',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSAvoidExclaimOperator',
        'PSAvoidLongLines',
        'PSAvoidMultipleTypeAttributes',
        'PSAvoidSemicolonsAsLineTerminators',
        'PSAvoidTrailingWhitespace',
        'PSAvoidUsingDoubleQuotesForConstantString',
        'PSAvoidOverwritingBuiltInCmdlets',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSAvoidExclaimOperator',
        
        # Best Practices
        'PSUseSingularNouns',
        'PSUseApprovedVerbs',
        'PSAvoidUsingWMICmdlet',
        'PSAvoidUsingGet-WmiObject',
        'PSUseSupportsShouldProcess',
        'PSAvoidGlobalAliases',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSUsePSCredentialType',
        'PSAvoidHardcodedCredentials'
    )
    
    # Rules to exclude with business justification
    ExcludeRules = @(
        # Framework-specific exclusions
        'PSAvoidUsingWriteHost',              # Allowed in interactive modules and startup experience
        'PSUseShouldProcessForStateChangingFunctions',  # Not applicable for all utility functions
        'PSAvoidUsingInvokeExpression',       # Required for dynamic configuration and template processing
        'PSAvoidGlobalVars',                  # Framework requires some global state management
        'PSAvoidUsingCmdletAliases',          # Some legacy compatibility required
        'PSUseApprovedVerbs',                 # Framework uses custom verbs like 'Download-Archive'
        'PSAvoidUsingComputerNameHardcoded',  # Lab environments use predefined computer names
        'PSAvoidUsingPositionalParameters',   # Some utility functions benefit from positional params
        'PSAvoidAssignmentToAutomaticVariable', # Framework manages some automatic variables
        'PSUseSingularNouns',                 # Some nouns are inherently plural (e.g., 'Credentials')
        'PSAvoidUsingWMICmdlet',              # Legacy systems may require WMI for compatibility
        'PSAvoidUsingGet-WmiObject',          # Legacy systems may require WMI for compatibility
        'PSReservedCmdletChar',               # Framework uses custom characters for specialized functions
        'PSReservedParams',                   # Framework may use reserved parameter names for compatibility
        'PSUseBOMForUnicodeEncodedFile',      # Cross-platform compatibility prefers UTF-8 without BOM
        'PSMissingModuleManifestField',       # Some manifests are minimal by design
        'PSAvoidUsingFilePath',               # Framework requires file path operations
        'PSAvoidUsingEmptyCatchBlock',        # Some error handling patterns use empty catch blocks
        'PSAvoidDefaultValueSwitchParameter', # Some switches have meaningful defaults
        'PSAvoidDefaultValueForMandatoryParameter', # Some mandatory parameters have computed defaults
        'PSAvoidNullOrEmptyHelpMessageAttribute', # Some parameters have self-evident purposes
        'PSAvoidLongLines',                   # Some lines exceed limits due to URL strings or complex expressions
        'PSAvoidMultipleTypeAttributes',      # Some parameters require multiple type constraints
        'PSAvoidSemicolonsAsLineTerminators', # Some generated code uses semicolons
        'PSAvoidTrailingWhitespace',          # Handled by formatting tools
        'PSAvoidUsingDoubleQuotesForConstantString', # Framework uses double quotes for consistency
        'PSAvoidOverwritingBuiltInCmdlets',   # Framework may extend built-in cmdlets
        'PSAvoidUsingDeprecatedManifestFields', # Some fields may be deprecated but still functional
        'PSAvoidExclaimOperator',             # Some expressions require logical NOT operator
        'PSUseSupportsShouldProcess',         # Not all functions need ShouldProcess
        'PSAvoidGlobalAliases',               # Framework defines global aliases for user convenience
        'PSUseOutputTypeCorrectly',           # Some functions have complex output types
        'PSUseCmdletCorrectly',               # Some cmdlets are used in non-standard ways for framework functionality
        'PSUseConsistentWhitespace',          # Handled by formatting tools
        'PSUseConsistentIndentation',         # Handled by formatting tools
        'PSAlignAssignmentStatement',         # Handled by formatting tools
        'PSUseCorrectCasing',                 # Framework uses consistent casing conventions
        'PSProvideCommentHelp',               # Some internal functions don't need comment help
        'PSUseDeclaredVarsMoreThanAssignments' # Some variables are used for side effects
    )
    
    # Custom rules for AitherZero framework
    CustomRulePath = @(
        # Path to custom rules (to be implemented)
        # './PSScriptAnalyzerCustomRules'
    )
    
    # Rules configuration for specific scenarios
    Rules = @{
        # Security rules - treat as errors
        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
            Severity = 'Error'
        }
        PSAvoidUsingUsernameAndPasswordParams = @{
            Enable = $true
            Severity = 'Error'
        }
        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
            Severity = 'Error'
        }
        PSUsePSCredentialType = @{
            Enable = $true
            Severity = 'Error'
        }
        PSAvoidHardcodedCredentials = @{
            Enable = $true
            Severity = 'Error'
        }
        
        # Cross-platform compatibility
        PSUseCompatibleCmdlets = @{
            Enable = $true
            Severity = 'Warning'
            PowerShellVersion = @('5.1', '6.0', '7.0', '7.1', '7.2', '7.3', '7.4')
        }
        PSUseCompatibleSyntax = @{
            Enable = $true
            Severity = 'Warning'
            PowerShellVersion = @('5.1', '6.0', '7.0', '7.1', '7.2', '7.3', '7.4')
        }
        PSUseCompatibleTypes = @{
            Enable = $true
            Severity = 'Warning'
            PowerShellVersion = @('5.1', '6.0', '7.0', '7.1', '7.2', '7.3', '7.4')
        }
        PSUseCompatibleCommands = @{
            Enable = $true
            Severity = 'Warning'
            PowerShellVersion = @('5.1', '6.0', '7.0', '7.1', '7.2', '7.3', '7.4')
        }
        
        # Code formatting and style
        PSUseConsistentWhitespace = @{
            Enable = $true
            Severity = 'Information'
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckSeparator = $true
            CheckPipe = $true
            CheckPipeForRedundantWhitespace = $true
            CheckParameter = $true
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            Severity = 'Information'
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationAfterEveryPipeline'
            Kind = 'space'
        }
        PSAlignAssignmentStatement = @{
            Enable = $true
            Severity = 'Information'
            CheckHashtable = $true
        }
        PSUseCorrectCasing = @{
            Enable = $true
            Severity = 'Information'
        }
        
        # Performance and best practices
        PSAvoidLongLines = @{
            Enable = $true
            Severity = 'Information'
            MaximumLineLength = 120
        }
        PSAvoidTrailingWhitespace = @{
            Enable = $true
            Severity = 'Information'
        }
        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
            Severity = 'Information'
        }
        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $true
            Severity = 'Information'
        }
        
        # Framework-specific rules
        PSUseApprovedVerbs = @{
            Enable = $true
            Severity = 'Warning'
            # Allow framework-specific verbs
            # Note: This will be overridden by module-specific configs
        }
        PSUseSingularNouns = @{
            Enable = $true
            Severity = 'Warning'
            # Allow framework-specific plural nouns
        }
        PSProvideCommentHelp = @{
            Enable = $true
            Severity = 'Information'
            # Only for public functions
        }
    }
    
    # Output configuration
    OutputFormat = 'JSON'
    SendTelemetry = $false
    
    # Parallel processing
    EnableParallelProcessing = $true
    
    # Exclude certain file patterns
    ExcludeFilePath = @(
        # Backup files
        '*/backups/*',
        '*/tmp/*',
        '*/temp/*',
        
        # Generated files
        '*/build/*',
        '*/output/*',
        '*/artifacts/*',
        
        # Legacy files (to be phased out)
        '*/deprecated/*',
        '*/legacy/*',
        
        # Test data files
        '*/test-data/*',
        '*/mock-data/*',
        
        # Template files that may contain placeholder syntax
        '*/templates/*'
    )
    
    # Include file patterns
    IncludeFilePath = @(
        '*.ps1',
        '*.psm1',
        '*.psd1'
    )
    
    # Recursive analysis
    Recurse = $true
    
    # Fail on first error for security rules
    ExitOnFirstError = $false
    
    # Verbose output for debugging
    Verbose = $false
    
    # Profile-specific settings
    Profile = @{
        # Security-critical modules
        SecurityModules = @(
            'SecureCredentials',
            'SecurityAutomation',
            'LicenseManager'
        )
        
        # Core framework modules
        CoreModules = @(
            'PatchManager',
            'ModuleCommunication',
            'ParallelExecution',
            'TestingFramework'
        )
        
        # Utility modules
        UtilityModules = @(
            'LabRunner',
            'BackupManager',
            'ISOManager',
            'ISOCustomizer',
            'SystemMonitoring',
            'RemoteConnection'
        )
        
        # Interactive modules (relaxed Write-Host rules)
        InteractiveModules = @(
            'StartupExperience',
            'SetupWizard',
            'DevEnvironment'
        )
    }
    
    # Framework metadata
    Framework = @{
        Name = 'AitherZero'
        Version = '0.6.25'
        PowerShellVersion = '7.0'
        CrossPlatform = $true
        SecurityFocused = $true
        EnterpriseGrade = $true
    }
}