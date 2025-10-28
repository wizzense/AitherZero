# GitHub Apps Integration Guide

## Overview

This guide explains how to integrate existing GitHub Apps (like Claude for GitHub) with AitherZero workflows.

## Understanding GitHub Apps vs. API Keys

### GitHub Apps (What You Have)
```
┌─────────────┐       ┌──────────────┐       ┌─────────────┐
│   GitHub    │──────▶│  GitHub App  │──────▶│  Claude API │
│   Events    │       │  (Installed) │       │             │
└─────────────┘       └──────────────┘       └─────────────┘
     Webhooks         JWT/Installation        API calls
                         Tokens
```

**Pros:**
- ✅ Managed authentication (no API keys to manage)
- ✅ Fine-grained permissions
- ✅ Can have its own UI
- ✅ Organization-level installation

**Cons:**
- ❌ Less control over workflow logic
- ❌ Depends on app's features
- ❌ May have rate limits

### API-based Integration (What I Built)
```
┌─────────────┐       ┌──────────────┐       ┌─────────────┐
│   GitHub    │──────▶│GitHub Actions│──────▶│  Claude API │
│   Actions   │       │  Workflows   │       │             │
└─────────────┘       └──────────────┘       └─────────────┘
   Triggers           Your custom logic      API Key Auth
```

**Pros:**
- ✅ Full control over logic
- ✅ Customizable workflows
- ✅ Integrates with your CI/CD
- ✅ Can combine multiple AI providers

**Cons:**
- ❌ Need to manage API keys
- ❌ More setup required
- ❌ Pay for API usage directly

## How to Use Your Existing GitHub App

### Step 1: Identify Your GitHub App

Check what you have installed:

1. **Repository Level:**
   ```
   https://github.com/wizzense/AitherZero/settings/installations
   ```

2. **Organization Level:**
   ```
   https://github.com/organizations/wizzense/settings/installations
   ```

3. **Personal Apps:**
   ```
   https://github.com/settings/installations
   ```

### Step 2: Understand How It Works

GitHub Apps typically work in these ways:

#### A. Automatic Webhooks
The app automatically receives events when:
- PRs are opened/updated
- Issues are created
- Comments are posted

**No workflow needed!** The app handles everything.

#### B. Trigger via Comments
The app responds to specific phrases:
```
@app-name review this PR
@claude-bot analyze security
```

#### C. Trigger via Labels
Add specific labels to trigger:
```
Labels: 'claude-review', 'ai-analysis', etc.
```

#### D. Trigger via Check Runs
The app creates GitHub Check Runs that appear in PR status checks.

### Step 3: Configure Integration

Choose your integration strategy:

#### Strategy 1: Let GitHub App Work Independently

If your GitHub App already does what you need:

**Just use it!** No additional workflow needed.

The app will:
- Automatically receive webhook events
- Post comments/reviews
- Update PR status
- Create check runs

**Your existing workflows** (Copilot, AitherZero) will work alongside it.

#### Strategy 2: Trigger GitHub App from Workflows

If you want workflow control:

```yaml
# In your workflow:
- name: Trigger Claude GitHub App
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.issues.createComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.issue.number,
        body: '@claude-app review this' // Adjust to your app's trigger
      });
```

#### Strategy 3: Use GitHub App Token in Workflows

If you have App ID and Private Key:

```yaml
- name: Generate App Token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.CLAUDE_APP_ID }}
    private-key: ${{ secrets.CLAUDE_APP_PRIVATE_KEY }}

- name: Use App Token
  env:
    GH_TOKEN: ${{ steps.generate-token.outputs.token }}
  run: |
    # Use the token for authenticated API calls
    gh api /repos/${{ github.repository }}/issues
```

#### Strategy 4: Hybrid Approach (Recommended)

Combine both:
- Use GitHub App for automatic triggers
- Use API-based workflows for custom logic

```yaml
# Let GitHub App handle automatic reviews
# Use custom workflow for specific analysis:
on:
  workflow_dispatch:
    inputs:
      analysis_type:
        type: choice
        options: ['deep-security', 'performance', 'architecture']
```

## Configuration Examples

### Example 1: GitHub App Handles Everything

```yaml
# .github/workflows/coordinate-with-github-app.yml
name: Coordinate with Claude GitHub App

on:
  pull_request:
    types: [opened]

jobs:
  prepare-for-claude:
    runs-on: ubuntu-latest
    steps:
      - name: Add label to trigger Claude App
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.pull_request.number,
              labels: ['claude-review']  // Triggers your GitHub App
            });

      - name: Wait for Claude App Review
        run: |
          echo "Claude GitHub App will now review the PR automatically"
          echo "Check PR comments and status checks for results"
```

### Example 2: Fallback to API if App Not Available

```yaml
# .github/workflows/claude-with-fallback.yml
name: Claude Review with Fallback

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  claude-review:
    runs-on: ubuntu-latest
    steps:
      - name: Check if GitHub App is Installed
        id: check-app
        uses: actions/github-script@v7
        with:
          script: |
            // Check for Claude GitHub App
            // Set output based on whether it's found
            core.setOutput('app-installed', 'false'); // Implement actual check

      - name: Trigger GitHub App
        if: steps.check-app.outputs.app-installed == 'true'
        run: echo "Triggering GitHub App..."

      - name: Fallback to API
        if: steps.check-app.outputs.app-installed == 'false'
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          echo "GitHub App not found, using direct API"
          # Use API-based integration
```

### Example 3: Coordinate Multiple Apps

```yaml
# .github/workflows/multi-app-coordination.yml
name: Multi-App Coordination

on:
  pull_request:
    types: [opened]

jobs:
  coordinate:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Claude GitHub App
        uses: actions/github-script@v7
        with:
          script: |
            // Trigger Claude app for strategic review
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.pull_request.number,
              body: '@claude-app review architecture'
            });

      - name: Wait for Claude
        run: sleep 30

      - name: Trigger Copilot based on Claude's Review
        uses: actions/github-script@v7
        with:
          script: |
            // Get Claude's review
            const comments = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.pull_request.number
            });

            // Find Claude's comment
            const claudeComment = comments.data.find(c =>
              c.user.login.includes('claude')
            );

            if (claudeComment) {
              // Trigger Copilot with Claude's recommendations
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.payload.pull_request.number,
                body: `@copilot please implement based on Claude's review above`
              });
            }
```

## Common GitHub Apps and Their Triggers

### If you have "Claude for GitHub" (hypothetical)

**Triggers:**
```bash
# Comment triggers:
@claude review
@claude analyze security
@claude suggest improvements

# Label triggers:
Labels: 'claude-review', 'ai-analysis'

# Automatic:
- On PR open
- On PR update
- On new commits
```

### Custom GitHub App

If you created your own:

**Check your app settings:**
```
https://github.com/settings/apps/your-app-name
```

**Look for:**
- Webhook events it subscribes to
- Permissions it has
- How to trigger it (comment, label, etc.)

## Troubleshooting

### GitHub App Not Responding

```bash
# 1. Check if app is installed
Repository Settings > Integrations > Installed GitHub Apps

# 2. Check app permissions
Click on app > Configure > Permissions
Ensure it has:
- Read access to code
- Write access to pull requests
- Write access to issues

# 3. Check app status
Visit app's status page (if available)
Check recent activity/logs

# 4. Check webhooks
Repository Settings > Webhooks
Ensure webhook is active and delivering
```

### App and Workflows Conflicting

```yaml
# Solution: Coordinate them

# Option 1: Run workflows only when app is done
on:
  check_run:
    types: [completed]
    # Trigger when GitHub App's check completes

# Option 2: Skip workflow if app is handling it
jobs:
  my-workflow:
    runs-on: ubuntu-latest
    if: |
      !contains(github.event.pull_request.labels.*.name, 'claude-app-active')
```

### Want Both App and API Integration

```yaml
# Use both!

# Let GitHub App handle automatic reviews
# Use API-based workflow for custom analysis

# No conflict - they complement each other:
# - GitHub App: General reviews, quick feedback
# - API workflow: Deep analysis, custom prompts, specific use cases
```

## Recommendations

### For Your Setup

Based on having both GitHub App and wanting custom workflows:

**Recommended Architecture:**

```
PR Created
  │
  ├─▶ Claude GitHub App (automatic)
  │   └─ General code review
  │   └─ Quick feedback
  │
  └─▶ Custom Workflows (triggered)
      ├─ Deep security analysis
      ├─ Architecture review
      ├─ Performance testing
      └─ Multi-agent coordination
```

**How to implement:**

1. **Keep GitHub App as-is** - Let it handle automatic reviews
2. **Add custom workflows** for specific needs
3. **Coordinate them** - Workflows can read app's output and build on it
4. **Use both strengths**:
   - App: Quick, automatic, managed
   - Workflow: Custom, controlled, integrated with CI/CD

## Setup Checklist

- [ ] Identify which Claude GitHub Apps you have installed
- [ ] Understand how they are triggered (comment/label/automatic)
- [ ] Test if they're working: Create a test PR and see if app responds
- [ ] If app works: Keep it and add custom workflows alongside
- [ ] If app doesn't work: Check permissions, webhooks, and configuration
- [ ] Add API key for custom workflows: `ANTHROPIC_API_KEY` in secrets
- [ ] Test both: Create PR and verify both app and workflows respond
- [ ] Coordinate: Ensure they complement rather than conflict

## Need Help?

1. **Check GitHub App logs:**
   - App Settings > Advanced > Webhook deliveries

2. **Check workflow logs:**
   - Actions > Recent runs > View logs

3. **Test independently:**
   - Disable workflows and test GitHub App alone
   - Then enable workflows and test coordination

4. **Contact app support:**
   - Check app's documentation
   - Contact app developer if needed

---

**Key Takeaway:** GitHub Apps and API-based workflows can work together! Use the app for automatic general tasks, and workflows for custom specific analysis.
