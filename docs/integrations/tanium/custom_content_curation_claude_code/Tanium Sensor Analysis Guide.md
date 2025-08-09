# Tanium Sensor Analysis Guide

This comprehensive guide provides context for understanding and analyzing Tanium sensors, particularly when working with JSON exports of sensor definitions.

## Table of Contents
1. [Overview](#overview)
2. [Tanium Architecture](#tanium-architecture)
3. [Sensor Fundamentals](#sensor-fundamentals)
4. [JSON Structure Analysis](#json-structure-analysis)
5. [Script Components](#script-components)
6. [Platform Support](#platform-support)
7. [Performance Considerations](#performance-considerations)
8. [Security Considerations](#security-considerations)
9. [Best Practices](#best-practices)
10. [Common Analysis Patterns](#common-analysis-patterns)

## Overview

Tanium sensors are scripts that execute on endpoints to collect data in response to Tanium questions. They form the foundation of Tanium's real-time endpoint visibility and management capabilities.

### Key Concepts
- **Sensor**: A script that runs on an endpoint to compute a response to a Tanium question
- **JSON Export**: Structured representation of sensor definitions including metadata, scripts, and configuration

## Tanium Architecture

### Core Components
- **Tanium Server**: Central management and question distribution
- **Tanium Client**: Lightweight agent (32-bit) running on endpoints
- **Tanium Data Service (TDS)**: Primary data caching layer for recent sensor data

### Client Environment
**Installation Paths:**
- Windows: `C:\Program Files (x86)\Tanium\Tanium Client`
- Linux/macOS/Solaris/AIX: `/opt/Tanium/TaniumClient`
- macOS: `/Library/Tanium/TaniumClient`

**Execution Context:**
- Windows: Local System privileges
- Unix-like systems: uid0 (root) privileges

## Sensor Fundamentals

### Execution Model
- **Timeout**: 60 seconds maximum execution time (quarantined if exceeded)
- **Question Lifetime**: 10 minutes
- **Answer Limit**: Maximum 100 answer rows per sensor
- **Target Performance**: <1 second execution time

### Data Flow
1. **Input**: Questions from Tanium Server
2. **Processing**: Script execution on endpoint
3. **Output**: Results via stdout (stderr not captured unless explicitly handled)
4. **Transport**: Results flow back through Tanium proprietary linear-chain architecture

## JSON Structure Analysis

### Top-Level Structure
```json
{
  "content_set": {
    "id": number,
    "name": "string"
  },
  "id": number,
  "name": "string",
  "hash": number,
  "string_count": number,
  "category": "string",
  "description": "string",
  "creation_time": "ISO8601",
  "modification_time": "ISO8601",
  "last_modified_by": "email",
  "mod_user": { ... },
  "queries": [ ... ],
  "parameter_definition": "JSON string",
  "value_type": "String|Numeric|...",
  "max_age_seconds": number,
  "ignore_case_flag": boolean,
  "hidden_flag": boolean,
  "keep_duplicates_flag": boolean,
  "delimiter": "string",
  "subcolumns": [ ... ],
  "source_id": number
}
```

### Critical Fields for Analysis

#### Metadata Fields
- **id**: Unique sensor identifier
- **name**: Sensor name (avoid parser keywords: where, with, greater than, less than, contains, and, or)
- **hash**: Script content hash for change detection
- **category**: Classification for organization
- **creation_time/modification_time**: Timestamps for tracking changes
- **string_count**: Current unique answer count (affects memory usage)

#### Configuration Fields
- **max_age_seconds**: Cache duration (recommended minimum: 600 seconds/10 minutes)
- **delimiter**: Result separator (use single characters when possible)
- **value_type**: Expected data type of results
- **ignore_case_flag**: Case sensitivity for string comparisons
- **keep_duplicates_flag**: Whether to store duplicate results

#### Output Structure
- **subcolumns**: Defines multi-column output structure
  - **name**: Column identifier
  - **index**: Position in delimited output
  - **value_type**: Data type for this column
  - **ignore_case_flag**: Column-specific case handling

## Script Components

### Query Structure
```json
"queries": [
  {
    "platform": "Windows|Linux|Mac|Solaris|AIX",
    "script": "script content",
    "script_type": "Powershell|VBScript|Python|UnixShell"
  }
]
```

### Supported Languages by Platform
- **Windows**: VBScript, WMI Query, BES Relevance Expression, PowerShell, Python
- **Linux/macOS**: Shell, Python
- **Solaris/AIX**: Shell

### Script Size Limitations
- **Windows**: ~26,000 characters maximum
- **Non-Windows**: Share 26,000 character limit across all platforms
- **Answers**: ~1,000 answer lines maximum per sensor

## Platform Support

### Windows-Specific Considerations
- Local System execution context
- Registry access available
- WMI/CIM cmdlets in PowerShell
- COM object access in VBScript

### Unix-Like Platforms
- Root execution context
- Standard Unix utilities available
- Shell scripting with /bin/sh compatibility
- File system access with full privileges

### Cross-Platform Strategies
- Provide platform-specific implementations
- Use "Not available on [Platform]" for unsupported platforms
- Consider data availability differences between platforms

## Performance Considerations

### Memory Impact
- **String Storage**: One of largest RAM consumers
- **Optimization Strategies**:
  - Adjust max_age_seconds appropriately
  - Reduce sensor output volume
  - Implement result bucketing
  - Minimize unique string count

### Execution Efficiency
- Target <1 second execution time
- Avoid file system modifications
- Minimize external executable calls
- Use built-in platform capabilities

### Scaling Factors
- **Question Frequency**: Balance data freshness with performance
- **Result Cardinality**: Fewer unique strings = better performance
- **Network Load**: Distributed through linear-chain architecture

## Security Considerations

### Input Validation
- Never trust user input
- Use `Tanium.UnescapeFromUTF8()` for parameter processing
- Implement parameter injection prevention
- Validate all external data sources

### Privilege Management
- Sensors run with high privileges (System/root)
- Implement least-privilege principles where possible
- Avoid privilege escalation opportunities
- Be cautious with external tool execution

### Data Protection
- **Never return PII** (Personally Identifiable Information)
- Implement data sanitization
- Consider data sensitivity in output
- Follow organizational data classification policies

### Execution Safety
- Avoid shell execution when possible
- Use Tanium-provided modules (e.g., tanium.subproc for Python)
- Implement error handling
- Prevent code injection attacks

## Best Practices

### Development Guidelines

#### Always Do
- Use strict modes (`Option Explicit` in VBS, `Set-StrictMode` in PowerShell)
- Set `$ErrorActionPreference = "Stop"` in PowerShell
- Output something (even if "No results found")
- Use Tanium-provided tools and modules
- Review existing Tanium content for patterns

#### Rarely Do
- Create long-running sensors
- Modify endpoint configuration
- Execute external binaries
- Access network resources

#### Never Do
- Access remote resources
- Create shared resource dependencies
- Prompt users (must be headless)
- Create or modify files on endpoints

### Output Format Guidelines
- **Delimiter Selection**: Choose characters unlikely to appear in data
- **Consistent Output**: Always produce output, even for error conditions
- **Error Handling**: Distinguish between "no results" and "error occurred"
- **Unicode Support**: UTF-8 encoding supported for international data

### Parameter Design
- **Parameter Definition Structure**:
  - Parameter type
  - Key identifier
  - User-friendly label
  - Help text
  - Prompt text
  - Validation expression

### Naming Conventions
- Avoid Tanium parser keywords in sensor names
- Use descriptive, searchable names
- Consider organizational naming standards
- Include version information if applicable

## Common Analysis Patterns

### Multi-Platform Sensors
Look for sensors that provide different implementations per platform:
```json
"queries": [
  {"platform": "Windows", "script": "PowerShell implementation"},
  {"platform": "Linux", "script": "Bash implementation"},
  {"platform": "Mac", "script": "macOS-specific version"}
]
```

### Parameterized Sensors
Identify sensors with user inputs:
```json
"parameter_definition": "{\"parameters\":[{\"key\":\"param1\",\"label\":\"User Input\"}]}"
```

### Multi-Column Output
Analyze complex data structures:
```json
"subcolumns": [
  {"name": "Column1", "index": 0, "value_type": "String"},
  {"name": "Column2", "index": 1, "value_type": "Numeric"}
]
```

### Performance-Critical Sensors
Identify sensors requiring optimization:
- High `string_count` values
- Long execution history
- Complex script logic
- Multiple external dependencies

### Security-Sensitive Sensors
Flag sensors requiring security review:
- Registry access patterns
- File system enumeration
- Network configuration queries
- User account information

### Error Handling Patterns
Standard approaches for robust sensors:
- Try-catch blocks with meaningful error messages
- Platform capability detection
- Graceful degradation for missing dependencies
- Consistent error reporting format

### Data Aggregation Sensors
Sensors that combine multiple data sources:
- WMI + Registry queries
- File system + process information
- Network + service status
- Multiple log source correlation

## Analysis Workflow

### 1. Initial Assessment
- Review sensor metadata (name, category, description)
- Check platform support and script types
- Examine parameter requirements
- Assess output structure complexity

### 2. Script Analysis
- Understand data collection methodology
- Identify external dependencies
- Evaluate error handling approach
- Check security practices

### 3. Performance Evaluation
- Review execution complexity
- Assess potential resource usage
- Check for optimization opportunities
- Consider scaling implications

### 4. Security Review
- Validate input handling
- Check privilege usage
- Review data exposure
- Assess attack surface

### 5. Deployment Considerations
- Verify platform compatibility
- Test parameter validation
- Confirm output format expectations
- Validate error scenarios

This guide provides the foundation for comprehensive Tanium sensor analysis, enabling effective evaluation of sensor implementations, security posture, and performance characteristics.