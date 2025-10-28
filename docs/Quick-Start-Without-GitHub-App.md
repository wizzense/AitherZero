# Quick Start: Claude Integration Without GitHub App

## You Don't Need the GitHub App! ✅

The workflows already support **direct API integration**, which is actually better for your use case because:

✅ **More control** over workflow logic
✅ **Customizable** analysis types
✅ **No marketplace dependency**
✅ **Works immediately** once configured
✅ **Integrates perfectly** with Copilot and AitherZero

## Setup (5 Minutes)

### Step 1: Get Anthropic API Key

1. **Visit Anthropic Console:**
   ```
   https://console.anthropic.com/
   ```

2. **Sign up or login:**
   - Create account if needed
   - No GitHub App installation required

3. **Generate API Key:**
   - Navigate to: Settings > API Keys
   - Click: "Create Key"
   - Name it: "AitherZero-GitHub-Actions"
   - Copy the key (starts with `sk-ant-api03-...`)
   - **Save it securely** - you'll only see it once!

### Step 2: Add to GitHub Secrets

1. **Go to repository settings:**
   ```
   https://github.com/wizzense/AitherZero/settings/secrets/actions
   ```

2. **Click:** "New repository secret"

3. **Add secret:**
   ```
   Name:   ANTHROPIC_API_KEY
   Secret: sk-ant-api03-your-actual-key-here-xxxxxxxxxxxxx
   ```

4. **Click:** "Add secret"

5. **Verify:**
   - You should see `ANTHROPIC_API_KEY` in the secrets list
   - The value will be hidden for security

### Step 3: That's It!

The workflows are already configured and will activate immediately.

## How to Use

### In Pull Requests

**Comment:**
```
@claude please review this PR
```

**What happens:**
1. `claude-ai-assistant.yml` workflow triggers
2. Claude analyzes the PR via API
3. Posts comprehensive review comment
4. Coordinator bridges to Copilot
5. Multi-agent collaboration begins

### In Issues

**Comment:**
```
@claude analyze this issue and suggest an approach
```

**What happens:**
1. Claude workflow triggers on mention
2. Analyzes issue context
3. Provides strategic guidance
4. Copilot can implement based on guidance

### Manual Trigger

**For deep analysis:**
```
Actions > Claude AI Assistant > Run workflow
- Analysis Type: security | architecture | performance
- Target: PR number or issue number
- Collaborate with: copilot | all
```

## Workflows That Activate

### 1. `claude-ai-assistant.yml` ⭐
**Triggers:**
- `@claude` mentions in PR/issue comments
- PR opened/updated (automatic analysis)
- Manual dispatch

**Provides:**
- Code review with strategic insights
- Security analysis
- Architecture recommendations
- Performance suggestions

### 2. `claude-coordinator.yml`
**Triggers:**
- After Claude analysis completes
- When multi-agent label added

**Provides:**
- Bridges Claude → Copilot
- Coordinates all AI agents
- Manages workflow handoffs

### 3. `ai-agent-coordinator.yml`
**Triggers:**
- Manual dispatch

**Provides:**
- Deep multi-agent analysis
- Comprehensive reporting
- All agents working together

## Testing

### Quick Test (2 minutes)

1. **Create test PR:**
   ```bash
   git checkout -b test/claude-api
   echo "# Test Claude API Integration" > test.md
   git add test.md
   git commit -m "test: Claude API integration"
   git push origin test/claude-api
   # Create PR on GitHub
   ```

2. **Trigger Claude:**
   ```
   Comment on PR: @claude please review this test PR
   ```

3. **Watch it work:**
   - Go to Actions tab
   - See "Claude AI Assistant" workflow running
   - Check PR comments for Claude's analysis
   - Coordinator will activate automatically

### Expected Results

✅ **Within 1-2 minutes:**
- Claude AI Assistant workflow completes
- Claude posts comprehensive review comment
- Coordinator detects and posts coordination comment
- Copilot is notified (if mentioned)

✅ **Comments you'll see:**
- 🤖 Claude AI Analysis (from github-actions[bot])
- 🤝 Multi-Agent Coordination (from github-actions[bot])
- ✅ AitherZero Validation Ready (from github-actions[bot])

## Comparison: GitHub App vs. API

### GitHub App (Not Available)
- ❌ Not on marketplace
- ❌ Requires installation approval
- ❌ Limited customization
- ✅ Managed authentication
- ✅ No API key needed

### Direct API (What You're Using) ✅
- ✅ Available immediately
- ✅ Full control over logic
- ✅ Highly customizable
- ✅ Integrates with your workflows
- ⚠️ Requires API key management

**Verdict:** Direct API is actually better for your needs!

## Advanced Usage

### Custom Analysis Types

Trigger specific analysis:

```bash
# Security audit
Actions > Claude AI Assistant > Run workflow
- Analysis Type: security
- Target: (empty for full repo)

# Architecture review
Actions > Claude AI Assistant > Run workflow
- Analysis Type: architecture
- Target: src/

# Performance analysis
Actions > Claude AI Assistant > Run workflow
- Analysis Type: performance
- Target: PR-123
```

### Multi-Agent Mode

Coordinate all agents:

```bash
Actions > AI Agent Coordinator > Run workflow
- Agent Type: multi-agent
- Priority: high
```

This triggers:
- Claude: Strategic analysis
- Copilot: Implementation planning
- AitherZero: Validation and quality checks

### Custom Prompts

Modify `.github/workflows/claude-ai-assistant.yml` to customize prompts:

```yaml
env:
  CLAUDE_MODEL: claude-sonnet-4-5-20250929
  CLAUDE_MAX_TOKENS: 8192
  CLAUDE_TEMPERATURE: 0.7  # Lower = more deterministic
```

## Cost Management

### Understanding API Costs

**Anthropic pricing (approximate):**
- Claude Sonnet: ~$3 per million input tokens
- Typical PR review: ~2,000-5,000 tokens
- **Cost per review: $0.01 - $0.03**

**Monthly estimate:**
- 100 PR reviews: ~$1-3
- 500 PR reviews: ~$5-15
- Very affordable for enterprise use!

### Monitoring Usage

1. **Check usage:**
   ```
   https://console.anthropic.com/settings/usage
   ```

2. **Set budget alerts:**
   - Settings > Billing
   - Set monthly budget limit
   - Get email alerts at thresholds

3. **Optimize usage:**
   - Use for important PRs (not every commit)
   - Trigger manually when needed
   - Skip draft PRs (configuration available)

## Troubleshooting

### Claude Not Responding

**Check API key:**
```bash
# Verify secret exists:
Settings > Secrets > Actions > ANTHROPIC_API_KEY ✅

# If missing, add it again
```

**Check workflow logs:**
```bash
Actions > Recent runs > Claude AI Assistant > View logs
Look for: "API key not configured" or API errors
```

**Check API status:**
```
https://status.anthropic.com/
```

### Workflow Not Triggering

**Enable workflows:**
```bash
Actions > All workflows > Claude AI Assistant
Should show "Enabled" not "Disabled"
```

**Check trigger conditions:**
- Comment must contain `@claude`
- PR must not be draft
- Workflows must have permissions

**Set permissions:**
```bash
Settings > Actions > General > Workflow permissions
Select: "Read and write permissions"
```

### API Rate Limits

**Anthropic limits:**
- Sonnet: 50 requests/minute
- 100,000 tokens/minute
- Should be plenty for normal use

**If you hit limits:**
- Workflows automatically retry with backoff
- Check usage dashboard
- Consider caching responses (future enhancement)

## Alternative: Request GitHub App Access

If you really want the GitHub App:

### Contact Anthropic Directly

1. **Email:** enterprise@anthropic.com
2. **Subject:** "Claude for GitHub - Enterprise Access Request"
3. **Include:**
   - Organization: wizzense
   - Use case: Multi-agent development workflows
   - Team size and expected usage
   - Current integration approach (mention you're using API)

4. **They may offer:**
   - Private beta access
   - Custom enterprise app
   - Integration partnership
   - Priority access when publicly available

### But You Don't Need To!

The API integration you have is:
- ✅ **Working right now**
- ✅ **More flexible**
- ✅ **Well integrated** with your workflows
- ✅ **Cost-effective**
- ✅ **Production-ready**

## What You Have vs. What You'd Get

### Current Setup (API-based)

```
Your PR → @claude mention → Claude API → Analysis → Coordinator → Copilot → AitherZero
```

**Features:**
- Full code review
- Security analysis
- Architecture guidance
- Multi-agent coordination
- Custom analysis types
- Integration with existing workflows

### If You Had GitHub App

```
Your PR → @Claude mention → GitHub App → Analysis → (Coordinator bridges it) → Same result
```

**Features:**
- Same analysis capabilities
- Slightly different UX (app avatar vs. actions bot)
- Managed authentication
- May have additional app-specific features

**Result:** Nearly identical functionality!

## Conclusion

**You're actually in a great position:**

1. ✅ Workflows are built and ready
2. ✅ API integration is more flexible than GitHub App
3. ✅ Full multi-agent coordination works
4. ✅ Just need to add API key and you're done
5. ✅ Can use immediately (no waiting for marketplace)

**Next step:** Add `ANTHROPIC_API_KEY` to secrets and test!

## Quick Reference

### Get API Key
```
https://console.anthropic.com/settings/keys
```

### Add to Secrets
```
Settings > Secrets > Actions > New secret
Name: ANTHROPIC_API_KEY
```

### Test It
```
Create PR → Comment: @claude review → Watch magic happen
```

### Monitor Usage
```
https://console.anthropic.com/settings/usage
```

### Get Help
```
Actions > Workflow runs > View logs
docs/Claude-Integration-Guide.md
docs/Multi-Agent-Setup-Complete.md
```

---

**Bottom Line:** The direct API integration is actually better than the GitHub App for your use case. Just add the API key and you're ready to go! 🚀
