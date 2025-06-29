# AitherZero Unified Platform API Guide

**Version 2.0.0 | Complete API Gateway Implementation**

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Platform Initialization](#platform-initialization)
4. [Service Categories](#service-categories)
5. [Common Usage Patterns](#common-usage-patterns)
6. [Advanced Features](#advanced-features)
7. [Error Handling](#error-handling)
8. [Performance Optimization](#performance-optimization)
9. [Troubleshooting](#troubleshooting)
10. [API Reference](#api-reference)

## Overview

The AitherZero Unified Platform API provides a **single, consistent interface** to all AitherZero modules through an intelligent API gateway. Instead of importing and managing individual modules, you work with one platform object that provides organized access to all functionality.

### Key Benefits

- **🚀 Single Entry Point**: One initialization command gives access to everything
- **🎯 Organized Interface**: Logical grouping of functions by purpose
- **💡 Intelligent Defaults**: Smart module availability checking and graceful degradation
- **📊 Built-in Monitoring**: Comprehensive health checking and performance tracking
- **🔄 Profile Support**: Minimal, Standard, and Full profiles for different use cases
- **⚡ Performance Optimized**: Caching, background services, and resource optimization

### Architecture

```
┌─────────────────────────────────────────┐
│           AitherZero Platform           │
│              API Gateway                │
├─────────────────────────────────────────┤
│  Lab │ Config │ Test │ Infra │ ISO │..  │
├─────────────────────────────────────────┤
│     Module Communication Layer          │
├─────────────────────────────────────────┤
│ LabRunner │ ConfigCore │ OpenTofu │... │
└─────────────────────────────────────────┘
```

## Getting Started

### Quick Start (30 seconds)

```powershell
# 1. Import AitherCore
Import-Module "./aither-core/AitherCore.psm1"

# 2. Initialize platform
$aither = Initialize-AitherPlatform -Profile "Standard"

# 3. Use the API!
$aither.Quick.SystemHealth()
```

### Installation Verification

```powershell
# Check platform status
$status = $aither.Platform.Status()
Write-Host "Platform Ready: $($status.Platform.Status)"
Write-Host "Modules Loaded: $($status.Modules.Loaded)"

# Quick health check
$health = $aither.Platform.Health()
Write-Host "Overall Health: $($health.Overall) ($($health.Score)%)"
```

## Platform Initialization

### Basic Initialization

```powershell
# Standard initialization (recommended)
$aither = Initialize-AitherPlatform -Profile "Standard"

# Minimal initialization (fastest startup)
$aither = Initialize-AitherPlatform -Profile "Minimal"

# Full initialization (all features)
$aither = Initialize-AitherPlatform -Profile "Full"
```

### Advanced Initialization

```powershell
# With performance optimization
$aither = Initialize-AitherPlatform -Profile "Standard"
Optimize-PlatformPerformance -CacheLevel Standard -EnableBackgroundOptimization

# With enhanced error handling
Initialize-PlatformErrorHandling -ErrorHandlingLevel Advanced -ErrorRecovery

# Start platform services
Start-PlatformServices -Platform $aither
```

### Profile Comparison

| Feature | Minimal | Standard | Full |
|---------|---------|----------|------|
| Core Infrastructure | ✅ | ✅ | ✅ |
| Lab Automation | ✅ | ✅ | ✅ |
| Configuration Management | ❌ | ✅ | ✅ |
| Development Tools | ❌ | ❌ | ✅ |
| ISO Management | ❌ | ✅ | ✅ |
| Testing Framework | ❌ | ✅ | ✅ |
| Orchestration Engine | ❌ | ✅ | ✅ |
| **Startup Time** | ~2s | ~5s | ~8s |
| **Memory Usage** | ~50MB | ~100MB | ~150MB |

## Service Categories

The platform organizes functionality into logical service categories:

### 🔬 Lab Operations (`$aither.Lab`)

```powershell
# Execute lab operations
$aither.Lab.Execute("DeployInfrastructure")
$aither.Lab.Deploy("./configs/lab-config.json")

# Check lab status
$status = $aither.Lab.Status()
$scripts = $aither.Lab.Scripts()

# Automated lab workflows
$aither.Lab.Automation()  # Full automation mode
```

### ⚙️ Configuration Management (`$aither.Configuration`)

```powershell
# Get/Set configuration
$config = $aither.Configuration.Get("LabRunner")
$aither.Configuration.Set("LabRunner", "MaxConcurrency", 4)

# Environment switching
$aither.Configuration.Switch("Production")

# Configuration validation
$isValid = $aither.Configuration.Validate("LabRunner")

# Repository operations
$aither.Configuration.Repository("Clone", @{
    RepositoryUrl = "https://github.com/user/config.git"
    LocalPath = "./custom-config"
})
```

### 🔄 Orchestration (`$aither.Orchestration`)

```powershell
# Run playbooks
$result = $aither.Orchestration.RunPlaybook("deployment-workflow", @{
    environment = "staging"
    deployTarget = "lab-01"
})

# Workflow management
$status = $aither.Orchestration.GetStatus()
$playbooks = $aither.Orchestration.ListPlaybooks()
$aither.Orchestration.StopWorkflow("workflow-id-123")
```

### 🛠️ Development & Patches (`$aither.Patch`)

```powershell
# Create patches with GitHub integration
$aither.Patch.Create("Fix authentication bug", {
    # Your changes here
    Edit-File "auth.ps1" -Find "old code" -Replace "new code"
}, -CreatePR)

# Patch management
$aither.Patch.Rollback("LastCommit")
$aither.Patch.Validate("ModuleName")
$status = $aither.Patch.Status()
```

### 🧪 Testing (`$aither.Testing`)

```powershell
# Run different test levels
$aither.Testing.Run("Quick")        # 30 seconds
$aither.Testing.Run("Standard")     # 2-5 minutes  
$aither.Testing.Run("Complete")     # 10-15 minutes

# Module-specific testing
$aither.Testing.Module("PatchManager")

# Test analysis
$aither.Testing.Coverage()
$aither.Testing.Performance()
```

### 🏗️ Infrastructure (`$aither.Infrastructure`)

```powershell
# OpenTofu/Terraform operations
$aither.Infrastructure.Plan("./templates/hyperv-lab.tf")
$aither.Infrastructure.Deploy("./templates/hyperv-lab.tf", @{
    vm_count = 3
    vm_memory = "4GB"
})

# Infrastructure management
$status = $aither.Infrastructure.Status()
$aither.Infrastructure.Destroy("./templates/hyperv-lab.tf")
```

### 💿 ISO Management (`$aither.ISO`)

```powershell
# ISO workflow
$iso = $aither.ISO.Download("Windows11", "./downloads")
$customISO = $aither.ISO.Customize($iso.FilePath, "server-profile")

# ISO management
$inventory = $aither.ISO.Inventory()
$aither.ISO.Repository("./iso-storage")
```

### 🔧 Maintenance (`$aither.Maintenance`)

```powershell
# Backup operations
$aither.Maintenance.Backup("Full")
$aither.Maintenance.Clean()

# System maintenance
$aither.Maintenance.Unified("Quick")  # Quick maintenance
$health = $aither.Maintenance.Health()
```

### 📊 Progress Tracking (`$aither.Progress`)

```powershell
# Track long operations
$opId = $aither.Progress.Start("Deploying Infrastructure", 5)
$aither.Progress.Update($opId, "Creating VMs")
$aither.Progress.Update($opId, "Configuring Network")
$aither.Progress.Complete($opId)

# Multi-operation tracking
$ops = @(
    @{Name = "Setup"; Steps = 3},
    @{Name = "Deploy"; Steps = 8},
    @{Name = "Validate"; Steps = 2}
)
$multiOp = $aither.Progress.Multi("Full Deployment", $ops)
```

### 🚀 Quick Actions (`$aither.Quick`)

```powershell
# One-command operations
$aither.Quick.SystemHealth()     # Complete health check
$aither.Quick.RunTests("Quick")  # Fast test run
$aither.Quick.CreateISO("Windows11")  # Download & customize ISO
$aither.Quick.LabSetup()         # Complete lab setup
$aither.Quick.ModuleStatus()     # Detailed module status
```

## Common Usage Patterns

### Daily Developer Workflow

```powershell
# 1. Initialize development environment
$aither = Initialize-AitherPlatform -Profile "Full"

# 2. Check system health
$health = $aither.Quick.SystemHealth()
if ($health.CoreHealth) {
    Write-Host "✅ System ready for development"
}

# 3. Run quick tests before changes
$aither.Testing.Run("Quick")

# 4. Make changes and create patch
$aither.Patch.Create("Add new feature", {
    # Development work here
    New-Item "feature.ps1" -ItemType File
    Add-Content "feature.ps1" "# New feature implementation"
}, -CreatePR)

# 5. Run comprehensive tests
$aither.Testing.Run("Standard")
```

### Operations/Production Workflow

```powershell
# 1. Initialize for operations
$aither = Initialize-AitherPlatform -Profile "Standard"
Optimize-PlatformPerformance -CacheLevel Aggressive

# 2. Switch to production configuration
$aither.Configuration.Switch("Production")

# 3. Deploy infrastructure
$deployResult = $aither.Infrastructure.Deploy("./prod-template.tf")

# 4. Run health monitoring
$health = $aither.Platform.Health()
if ($health.Score -lt 90) {
    Write-Warning "Health score below threshold: $($health.Score)%"
}

# 5. Schedule maintenance
$aither.Maintenance.Unified("Full")
```

### Lab Automation Workflow

```powershell
# 1. Setup lab environment
$aither = Initialize-AitherPlatform -Profile "Standard"

# 2. Download and prepare ISOs
$aither.Workflows.ISO(@{
    ISOName = "Windows11"
    CustomizationProfile = "Lab"
})

# 3. Deploy lab infrastructure
$aither.Workflows.Lab(@{
    VMCount = 5
    NetworkConfig = "Internal"
})

# 4. Run validation
$aither.Testing.Performance()
```

## Advanced Features

### Workflow Orchestration

```powershell
# Complex integrated workflows
$aither.Workflows.Development(@{
    PatchDescription = "Multi-module update"
    TestLevel = "Complete"
    CreateBackup = $true
})

$aither.Workflows.Maintenance(@{
    BackupFirst = $true
    CleanupLevel = "Aggressive"
    HealthValidation = $true
})
```

### Event-Driven Operations

```powershell
# Subscribe to platform events
$aither.Communication.Subscribe("system", "health-warning", {
    param($EventData)
    Write-Warning "Health issue detected: $($EventData.Issue)"
    # Trigger automated response
})

# Publish custom events
$aither.Communication.Publish("custom", "deployment-complete", @{
    Environment = "Production"
    Timestamp = Get-Date
})
```

### Background Services

```powershell
# Start comprehensive monitoring
Start-PlatformServices -Platform $aither -Services @(
    'HealthMonitor',
    'ConfigurationWatcher', 
    'BackgroundJobs'
)
```

## Error Handling

### Graceful Degradation

The platform automatically handles missing modules:

```powershell
# This works even if PatchManager isn't loaded
try {
    $aither.Patch.Create("Test patch", { Write-Host "Test" })
} catch {
    Write-Host "Patch management not available in current profile"
}
```

### Advanced Error Handling

```powershell
# Enable comprehensive error handling
Initialize-PlatformErrorHandling -ErrorHandlingLevel Advanced -ErrorRecovery

# Errors are automatically logged and recovery attempted
$aither.Platform.Health()  # Shows error statistics
```

### Error Recovery

```powershell
# Manual recovery operations
$aither.Platform.Reload(-Force)  # Reload all modules
$health = $aither.Platform.Health()  # Check recovery success
```

## Performance Optimization

### Caching Configuration

```powershell
# Basic caching (30s TTL)
Optimize-PlatformPerformance -CacheLevel Basic

# Standard caching (2min TTL)  
Optimize-PlatformPerformance -CacheLevel Standard

# Aggressive caching (5min TTL)
Optimize-PlatformPerformance -CacheLevel Aggressive -EnableBackgroundOptimization
```

### Performance Monitoring

```powershell
# Monitor platform performance
$perf = $aither.Platform.Status().Performance
Write-Host "Memory Usage: $($perf.MemoryUsage) MB"
Write-Host "Module Load Time: $($perf.ModuleLoadTime) seconds"

# Detailed performance metrics
$lifecycle = $aither.Platform.Lifecycle()
$lifecycle.CurrentState.LoadOrder  # Module load order and timing
```

## Troubleshooting

### Common Issues

**Problem**: Platform initialization fails
```powershell
# Solution: Check module paths and dependencies
$aither = Initialize-AitherPlatform -Profile "Minimal" -Force
$status = $aither.Platform.Modules()
# Check which modules failed to load
```

**Problem**: Slow API responses
```powershell
# Solution: Enable performance optimization
Optimize-PlatformPerformance -CacheLevel Aggressive
```

**Problem**: Module not available errors
```powershell
# Solution: Check current profile and module availability
$status = $aither.Platform.Status()
Write-Host "Current capabilities:"
$status.Capabilities | Format-Table
```

### Diagnostic Commands

```powershell
# Platform health analysis
$health = $aither.Platform.Health()
$health.Issues        # List of detected issues
$health.Recommendations  # Suggested fixes

# Module dependency analysis
$lifecycle = $aither.Platform.Lifecycle(-IncludeDependencies)
$lifecycle.DependencyAnalysis.MissingDependencies

# Performance profiling
Measure-Command { $aither.Platform.Status() }
```

## API Reference

### Platform Object Structure

```powershell
$aither = @{
    # Core services
    Lab = @{ Execute, Status, Scripts, Deploy, Automation }
    Configuration = @{ Get, Set, Switch, Validate, Repository }
    Orchestration = @{ RunPlaybook, GetStatus, StopWorkflow, ListPlaybooks }
    
    # Development
    Patch = @{ Create, Rollback, Validate, Status }
    Testing = @{ Run, Module, Coverage, Performance, Quick }
    
    # Infrastructure & Operations  
    Infrastructure = @{ Deploy, Plan, Destroy, Status }
    ISO = @{ Download, Customize, Inventory, Repository }
    Maintenance = @{ Backup, Clean, Health, Unified }
    
    # Monitoring & Communication
    Progress = @{ Start, Update, Complete, Multi }
    Communication = @{ Publish, Subscribe, API }
    
    # Platform management
    Platform = @{ Status, Modules, Health, Toolset, Lifecycle, Reload }
    
    # Convenience functions
    Quick = @{ CreateISO, RunTests, LabSetup, SystemHealth, ModuleStatus }
    Workflows = @{ ISO, Development, Lab, Maintenance }
    
    # Security & Remote
    Security = @{ GetCredential, SetCredential, Automation }
    Remote = @{ Connect, Test, Disconnect }
}
```

### Function Signatures

#### Core Platform Functions

```powershell
Initialize-AitherPlatform -Profile <String> [-Environment <String>] [-Force] [-SkipHealthCheck] [-AutoStart]

Get-PlatformStatus [-Detailed]

Get-PlatformHealth [-Quick]

Get-PlatformLifecycle [-IncludeDependencies]

Start-PlatformServices -Platform <Object> [-Services <String[]>]

Optimize-PlatformPerformance -CacheLevel <String> [-OptimizeModuleLoading] [-EnableBackgroundOptimization]

Initialize-PlatformErrorHandling -ErrorHandlingLevel <String> [-EnableDiagnostics] [-ErrorRecovery]
```

### Return Object Examples

#### Platform Status
```powershell
@{
    Platform = @{
        Version = "2.0.0"
        Status = "Ready"
        InitializedAt = [DateTime]
    }
    Modules = @{
        Total = 25
        Loaded = 18
        Available = 23
        LoadedModules = @("Logging", "LabRunner", ...)
    }
    Capabilities = @{
        LabAutomation = $true
        ConfigurationManagement = $true
        # ... other capabilities
    }
}
```

#### Platform Health
```powershell
@{
    Overall = "Excellent"
    Score = 95
    Categories = @{
        Core = @{ Status = "Healthy"; Score = 100 }
        Modules = @{ Status = "Good"; Score = 90 }
        # ... other categories
    }
    Issues = @()
    Recommendations = @()
}
```

---

## Getting Help

- **Documentation**: This guide and inline help (`Get-Help Initialize-AitherPlatform`)
- **Health Checks**: `$aither.Platform.Health()` for diagnostics
- **Status Information**: `$aither.Platform.Status()` for current state
- **Quick Actions**: `$aither.Quick.SystemHealth()` for rapid troubleshooting

**The AitherZero Unified Platform API makes complex infrastructure automation simple, powerful, and reliable.**