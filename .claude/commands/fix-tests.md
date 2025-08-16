# Fix Tests Command

Run the automated test-fix workflow to systematically resolve all failing tests using AI-powered fixes with Claude Code's test-runner agent.

## Usage

```
fix-tests [options]
```

## Options

- `--reset` - Reset the tracker and start fresh
- `--loops <n>` - Number of issues to fix (default: 10)
- `--status` - Show current tracker status only
- `--issues` - Create GitHub issues for failures
- `--run-tests` - Force running fresh tests first

## Examples

```bash
# Basic usage - fix up to 10 test failures
fix-tests

# Reset tracker and start fresh
fix-tests --reset

# Fix specific number of issues
fix-tests --loops 5

# Create GitHub issues and fix
fix-tests --issues --loops 20

# Just show current status
fix-tests --status
```

## Implementation

The command uses the AitherZero orchestration system with the `test-fix-workflow` playbook to:

1. **Initialize Tracker**: Creates or loads test-fix-tracker.json
2. **Run Tests**: Executes unit tests if needed
3. **Process Results**: Identifies all failing tests
4. **Fix Loop**: For each failure:
   - Creates GitHub issue (if --issues flag)
   - Uses Claude test-runner agent to analyze and fix
   - Validates the fix
   - Commits successful fixes
5. **Reports**: Shows final summary with resolved/open issues

```bash
#!/bin/bash

# Run the Claude test fix script
exec ./automation-scripts/claude-test-fix.sh "$@"
```

## What It Does

The workflow processes one test failure at a time using the test-fix-workflow playbook:

1. **Load & Process** (0751, 0752): Loads tracker and processes test results
2. **GitHub Issue** (0753): Creates GitHub issue for tracking (optional)
3. **Fix with Claude** (0754): Uses test-runner agent to fix the issue
4. **Validate** (0755): Runs the test to verify the fix
5. **Commit** (0756): Commits the fix if validation passes

Each iteration processes one issue, and the command loops until all issues are fixed or the loop limit is reached.

## Integration with Claude Code

The workflow is designed to work with Claude Code's Task tool and test-runner agent:

- The test-runner agent specializes in analyzing and fixing test failures
- Prompts are optimized for the agent's capabilities
- Fix attempts are tracked and can be retried
- GitHub issues are updated with progress

## Related Commands

- `test` - Run the full test suite
- `validate-all` - Run all validation checks
- `debug` - Debug specific test failures

## Notes

- The workflow is idempotent - safe to run multiple times
- Each issue gets up to 3 fix attempts by default
- Fixes are validated before being committed
- Failed fixes after max attempts are marked for manual review
- Use `--issues` to create GitHub issues for better tracking
- The workflow uses orchestration playbooks for reliability