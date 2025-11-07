# AitherZero Local Configuration Override Template
#
# This file allows you to override settings from config.psd1 without modifying
# the base configuration file. It's gitignored by default, so your local settings
# stay private.
#
# Usage:
# 1. Copy this file to config.local.psd1 in the repository root
# 2. Uncomment and modify the sections you want to override
# 3. The hierarchy is: custom config > config.local.psd1 > config.psd1
#
# Example: Override testing concurrency for local development
# @{
#     Testing = @{
#         MaxConcurrency = 2  # Reduce for local dev
#     }
# }

@{
    # Core Settings
    # Core = @{
    #     Environment = "Development"
    #     LogLevel = "Debug"
    # }

    # Automation Settings
    # Automation = @{
    #     MaxConcurrency = 2  # Reduce for slower machines
    #     DefaultMode = "Sequential"  # Force sequential for debugging
    #     TimeoutMinutes = 30
    # }

    # Testing Settings
    # Testing = @{
    #     MaxConcurrency = 2
    #     Profile = "Quick"  # Use Quick profile locally
    #     CacheResults = $true
    # }

    # Infrastructure Settings
    # Infrastructure = @{
    #     Provider = "opentofu"
    #     DefaultVMPath = "D:/VMs"  # Custom VM location
    #     DefaultMemory = "4GB"  # More memory for local VMs
    # }

    # Logging Settings
    # Logging = @{
    #     Level = "Debug"  # More verbose logging locally
    #     Path = "./logs"
    #     Targets = @("Console", "File")
    # }

    # UI Settings (for interactive mode)
    # UI = @{
    #     Theme = "Dark"
    #     ShowBanner = $true
    #     EnableColors = $true
    # }

    # Development Tools
    # Development = @{
    #     Git = @{
    #         AutoCommit = $false  # Disable auto-commit locally
    #         DefaultBranch = "feature/my-work"
    #     }
    # }

    # Feature Flags (enable/disable features)
    # Features = @{
    #     Git = $true
    #     Docker = $true
    #     Kubernetes = $false  # Disable K8s for local dev
    # }
}
