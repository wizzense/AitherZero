# AitherZero MCP Server - Example Conversations

Real-world examples of how AI assistants can interact with AitherZero through the MCP server.

## 🎯 Quick Reference

### Available Tools (8)
- `run_script`, `list_scripts`, `search_scripts`, `execute_playbook`
- `get_configuration`, `run_tests`, `run_quality_check`, `get_project_report`

### Available Resources (3)
- `aitherzero://config`, `aitherzero://scripts`, `aitherzero://project-report`

---

## Example 1: Setting Up a Development Environment

**User**: "I need to set up a development environment on this machine"

**AI Assistant**:
1. Uses `search_scripts` with query="setup"
2. Finds scripts: 0000-0099 (environment), 0200-0299 (dev tools)
3. Uses `execute_playbook` with playbookName="setup-dev"
4. Responds: "I'll set up your development environment. This will install PowerShell 7, Git, Node.js, Python, Docker, and VS Code. The setup is running now..."

**Result**: Automated installation of development tools

---

## Example 2: Running Tests Before Deployment

**User**: "I want to deploy, but first run all tests and check code quality"

**AI Assistant**:
1. Uses `run_tests` to execute Pester tests
2. Uses `run_quality_check` on all domains
3. Uses `get_project_report` for metrics
4. Responds: "Test Results:
   - ✅ 45 tests passed, 0 failed
   - ✅ PSScriptAnalyzer: 0 errors, 2 warnings
   - ✅ Code coverage: 87%
   - ✅ All quality checks passed
   
   Your code is ready for deployment!"

**Result**: Confidence in code quality before deployment

---

## Example 3: Finding and Running Docker Scripts

**User**: "What Docker-related automation do we have?"

**AI Assistant**:
1. Uses `search_scripts` with query="docker"
2. Responds: "Found 3 Docker scripts:
   - 0208: Install Docker
   - 0209: Configure Docker networking  
   - 0210: Set up Docker Compose"

**User**: "Install Docker"

**AI Assistant**:
1. Uses `run_script` with scriptNumber="0208"
2. Monitors execution
3. Responds: "Docker installation complete! Docker version 24.0.5 is now installed and running."

**Result**: Quick script discovery and execution

---

## Example 4: Infrastructure Audit

**User**: "Give me a complete audit of the current infrastructure setup"

**AI Assistant**:
1. Reads `aitherzero://config` resource
2. Uses `get_project_report` for metrics
3. Uses `search_scripts` with query="infrastructure"
4. Responds: "Infrastructure Audit Report:
   
   **Configuration**:
   - Profile: Developer
   - Root: /home/user/AitherZero
   - PowerShell: 7.4.1
   
   **Available Infrastructure Scripts**: 12 scripts
   - Hyper-V management
   - Certificate Authority
   - WSL2 integration
   - Network configuration
   
   **Project Health**:
   - 15 domains implemented
   - 200+ automation scripts
   - Test coverage: 87%
   - Last updated: 2 hours ago"

**Result**: Comprehensive infrastructure overview

---

## Example 5: Debugging Failed Tests

**User**: "The tests are failing. Help me figure out why."

**AI Assistant**:
1. Uses `run_tests` to reproduce failure
2. Analyzes output
3. Uses `run_quality_check` on failing domain
4. Uses `get_configuration` to check test settings
5. Responds: "I found the issue. Tests are failing in the Configuration domain because:
   1. The test profile is set to 'Full' which includes some Windows-specific tests
   2. You're running on Linux
   
   To fix: Update config.psd1 to set Testing.Profile = 'Standard'
   
   Would you like me to show you the specific tests that are failing?"

**Result**: Rapid problem diagnosis

---

## Example 6: Scheduled Maintenance

**User**: "I need to run maintenance tasks every week"

**AI Assistant**:
1. Uses `list_scripts` to find maintenance scripts (9000-9999)
2. Uses `get_configuration` to check current settings
3. Responds: "I found these maintenance scripts:
   - 9000: Cleanup temporary files
   - 9001: Archive old logs
   - 9002: Update dependencies
   - 9003: Check for updates
   
   I recommend creating a playbook. Here's what I can do:
   1. Run the quick cleanup (9000)
   2. Archive logs (9001)
   3. Generate a report
   
   Should I create a maintenance playbook for you?"

**User**: "Yes, do the cleanup"

**AI Assistant**:
1. Uses `run_script` with scriptNumber="9000"
2. Uses `run_script` with scriptNumber="9001"
3. Uses `get_project_report`
4. Responds: "Maintenance complete! Removed 2.3GB of temporary files, archived 45 log files."

**Result**: Automated maintenance workflow

---

## Example 7: Learning the System

**User**: "I'm new to AitherZero. What can it do?"

**AI Assistant**:
1. Uses `list_scripts` to get overview
2. Reads `aitherzero://scripts` resource
3. Reads `aitherzero://config` resource
4. Responds: "Welcome to AitherZero! Here's what it can do:
   
   **Environment Management** (0000-0099):
   - PowerShell 7 installation
   - Directory setup
   - Configuration management
   
   **Infrastructure** (0100-0199):
   - Hyper-V setup
   - Certificate Authority
   - WSL2 integration
   
   **Development Tools** (0200-0299):
   - Node.js, Python, Git
   - Docker installation
   - VS Code setup
   
   **Testing & Quality** (0400-0499):
   - Pester tests
   - PSScriptAnalyzer
   - Quality validation
   
   **Reporting** (0500-0599):
   - Project metrics
   - Test reports
   - Documentation generation
   
   Try asking: 'Search for Docker scripts' or 'Run tests' to get started!"

**Result**: Friendly onboarding experience

---

## Example 8: Multi-Step Workflow

**User**: "I need to deploy a new VM with our standard configuration"

**AI Assistant**:
1. Uses `search_scripts` with query="VM"
2. Uses `get_configuration` to check infrastructure settings
3. Responds: "To deploy a VM, I'll need to:
   1. Ensure Hyper-V is installed (script 0105)
   2. Create the VM (script 0150)
   3. Configure networking (script 0151)
   4. Apply standard configuration
   
   Current status:
   - Hyper-V: ✅ Installed
   - Network: ✅ Configured
   - Templates: ✅ Available
   
   Should I proceed with VM creation?"

**User**: "Yes, create a VM named 'dev-vm-01'"

**AI Assistant**:
1. Uses `run_script` with scriptNumber="0150", params={Name: "dev-vm-01"}
2. Monitors progress
3. Responds: "VM 'dev-vm-01' created successfully!
   - OS: Ubuntu 22.04
   - Memory: 4GB
   - Disk: 50GB
   - Network: Connected to Dev VLAN
   - Status: Running
   
   You can access it via SSH at: dev-vm-01.local"

**Result**: Complex infrastructure deployment via conversation

---

## Example 9: Quick Status Check

**User**: "Quick status - how's everything looking?"

**AI Assistant**:
1. Reads `aitherzero://config` resource
2. Reads `aitherzero://project-report` resource
3. Uses `run_tests` with quick profile
4. Responds: "Everything's looking good! 👍
   
   **System**: Healthy
   - PowerShell: 7.4.1 ✅
   - Git: 2.42.0 ✅
   - Docker: 24.0.5 ✅
   
   **Tests**: Passing (45/45) ✅
   
   **Quality**: Good
   - PSScriptAnalyzer: Clean ✅
   - Coverage: 87% ✅
   
   **Recent Activity**:
   - Last test run: 5 minutes ago
   - Last deployment: 2 hours ago
   - Next maintenance: In 3 days"

**Result**: Instant health check

---

## Example 10: Troubleshooting Performance

**User**: "The scripts are running slow. What's going on?"

**AI Assistant**:
1. Uses `get_configuration` to check settings
2. Uses `get_project_report` for performance metrics
3. Uses `search_scripts` with query="performance"
4. Responds: "I've identified potential performance issues:
   
   **Current Configuration**:
   - Max Concurrency: 1 (Running scripts sequentially)
   - Logging: Verbose (lots of disk I/O)
   - Cache: Disabled
   
   **Recommendations**:
   1. Increase MaxConcurrency to 4 for parallel execution
   2. Set logging to 'Information' level
   3. Enable script cache
   
   **Performance Scripts Available**:
   - 0420: Quality validator (can be cached)
   - 0510: Report generator (optimize queries)
   
   Would you like me to help optimize the configuration?"

**Result**: Performance analysis and recommendations

---

## Protocol Examples (Technical)

### Listing Tools

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "run_script",
        "description": "Execute an AitherZero automation script...",
        "inputSchema": {...}
      },
      ...
    ]
  }
}
```

### Calling a Tool

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "run_tests",
    "arguments": {
      "path": "./tests/unit/Configuration.Tests.ps1"
    }
  }
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Tests Passed: 15/15\nCoverage: 94%\n..."
      }
    ]
  }
}
```

### Reading a Resource

**Request**:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "resources/read",
  "params": {
    "uri": "aitherzero://config"
  }
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "contents": [
      {
        "uri": "aitherzero://config",
        "mimeType": "application/json",
        "text": "{\"Core\":{\"Profile\":\"Developer\"},...}"
      }
    ]
  }
}
```

---

## Common Patterns

### Pattern 1: Search → Execute
```
User: "Find X" → AI uses search_scripts
User: "Do it" → AI uses run_script
```

### Pattern 2: Check → Report
```
User: "How's X?" → AI uses get_configuration + get_project_report
```

### Pattern 3: Validate → Deploy
```
User: "Deploy X" → AI uses run_tests + run_quality_check first
If OK → AI uses execute_playbook or run_script
```

### Pattern 4: Learn → Guide
```
User: "How do I X?" → AI uses list_scripts or search_scripts
AI provides step-by-step guidance
```

---

## Tips for AI Assistants

1. **Always search first**: Use `search_scripts` before `run_script` to verify script exists
2. **Check configuration**: Use `get_configuration` to understand current state
3. **Validate before execute**: Use `run_tests` before deployment operations
4. **Provide context**: Always explain what you're doing and why
5. **Handle errors gracefully**: Check stderr and provide troubleshooting steps
6. **Use resources efficiently**: Cache `aitherzero://scripts` listing for quick lookups
7. **Suggest playbooks**: For multi-step operations, recommend or create playbooks
8. **Monitor long operations**: Some scripts take minutes - keep user informed
9. **Security awareness**: Warn about privileged operations (infrastructure changes)
10. **Document results**: After execution, summarize what was done

---

## Next Steps

Try these yourself:
1. Set up the MCP server (see QUICKSTART.md)
2. Ask your AI assistant: "List all AitherZero scripts"
3. Experiment with different queries
4. Share your favorite conversation patterns!

## Resources

- Full documentation: `docs/AITHERZERO-MCP-SERVER.md`
- Quick start: `mcp-server/QUICKSTART.md`
- Implementation details: `mcp-server/IMPLEMENTATION-SUMMARY.md`
