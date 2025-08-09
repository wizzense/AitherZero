---
name: generateDocs
description: Create comprehensive documentation
allowed-tools: Read, Write, Task, TodoWrite
argument-hint: <content_id>
---

## Context
- Content ID: $ARGUMENTS
- Documentation type: Comprehensive guide

## Your Task

Generate complete documentation package:

1. **Technical Documentation**:
   - API reference
   - Parameter descriptions
   - Return value schemas
   - Platform differences

2. **Implementation Guide**:
   ```markdown
   # Scripts: [Name]
   
   ## Overview
   [Description and purpose]
   
   ## Supported Platforms
   - Windows: [Version requirements]
   - Linux: [Distribution support]
   - macOS: [Version requirements]
   
   ## Usage
   [How to deploy and use]
   
   ## Examples
   [Real-world usage examples]
   
   ## Parameters
   | Name | Type | Required | Default | Description |
   |------|------|----------|---------|-------------|
   
   ## Output Format
   [Detailed output schema]
   
   ## Performance Considerations
   [Resource usage and optimization tips]
   
   ## Troubleshooting
   [Common issues and solutions]
   ```

3. **Integration Documentation**:
   - How to use in questions
   - Combining with other Scripts
   - Best practices

4. **Compliance Documentation**:
   - Data collection notice
   - Privacy implications
   - Retention policies

5. **Auto-generate**:
   - README files
   - CHANGELOG entries
   - Migration guides
   - Quick reference cards

Output to ./docs/ in multiple formats (MD, HTML, PDF).