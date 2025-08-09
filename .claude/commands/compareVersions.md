---
name: compareVersions
description: Compare content versions and highlight changes
allowed-tools: Read, Grep, Task
argument-hint: <version1> <version2>
---

## Context
- Version 1: First version identifier
- Version 2: Second version identifier
- Comparison type: Detailed diff analysis

## Your Task

Compare two versions of content:

1. **Load Versions**:
   - Retrieve both versions from history
   - Validate version identifiers
   - Check compatibility

2. **Structural Comparison**:
   - Metadata changes
   - Platform additions/removals
   - Parameter modifications
   - Query changes

3. **Code Diff Analysis**:
   ```diff
   Platform: Windows
   - $computer = Get-WmiObject Win32_ComputerSystem
   + $computer = Get-CimInstance Win32_ComputerSystem
   
   Platform: Linux
   + # Added new platform support
   + cat /proc/cpuinfo | grep "model name"
   ```

4. **Behavioral Changes**:
   - Output format changes
   - Performance impact
   - Breaking changes
   - Bug fixes

5. **Risk Assessment**:
   - Compatibility impact
   - Security implications
   - Performance changes
   - Data quality effects

6. **Migration Guide**:
   - Required changes
   - Update procedures
   - Rollback plan
   - Testing checklist

Generate detailed comparison report with recommendations.