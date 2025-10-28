# Installing Claude GitHub Apps in Your Enterprise

## Overview

This guide helps you install and configure Claude and Claude for GitHub apps in your enterprise, so they work with the AitherZero workflows already set up.

## Prerequisites

- Enterprise admin access
- GitHub organization admin privileges
- Anthropic account (for API access)

## Installation Steps

### Step 1: Install Claude for GitHub

**Option A: Via GitHub Marketplace (if available)**

1. **Visit GitHub Marketplace:**
   ```
   https://github.com/marketplace
   ```

2. **Search for:**
   - "Claude" or "Anthropic"
   - Look for official Anthropic apps

3. **Install to Organization:**
   - Click "Install it for free" or "Set up a plan"
   - Select organization: `wizzense`
   - Choose repositories: All repositories or select AitherZero
   - Grant permissions

4. **Configure Access:**
   - Repository access: All repositories (recommended) or specific ones
   - Permissions needed:
     - ✅ Read access to code
     - ✅ Read and write access to issues
     - ✅ Read and write access to pull requests
     - ✅ Read access to metadata

**Option B: Via Anthropic Console**

1. **Login to Anthropic:**
   ```
   https://console.anthropic.com/
   ```

2. **Navigate to Integrations:**
   - Look for "GitHub" or "Integrations" section
   - Find "Claude for GitHub" integration

3. **Connect to GitHub:**
   - Authorize Anthropic to access your GitHub
   - Select organization: `wizzense`
   - Choose repositories
   - Complete OAuth flow

**Option C: Enterprise GitHub App Installation**

If your enterprise has specific requirements:

1. **Contact Anthropic:**
   - Email: enterprise@anthropic.com
   - Request: GitHub App installation for enterprise

2. **Follow Enterprise Process:**
   - May require security review
   - Custom installation process
   - Enterprise agreement

### Step 2: Verify Installation

**Check if installed:**

1. **Repository level:**
   ```
   https://github.com/wizzense/AitherZero/settings/installations
   ```
   - Should see "Claude" or "Anthropic" app listed

2. **Organization level:**
   ```
   https://github.com/organizations/wizzense/settings/installations
   ```
   - Verify app is installed org-wide

3. **Personal level:**
   ```
   https://github.com/settings/installations
   ```
   - Check if you personally authorized it

**Test the app:**

1. Create a test issue in AitherZero
2. Comment: `@Claude hello, can you see this?`
3. Wait 10-30 seconds
4. Claude should respond

### Step 3: Configure Permissions

**Required permissions for full functionality:**

```yaml
Repository permissions:
  contents: read          # Read code
  issues: read/write      # Comment on issues
  pull_requests: read/write  # Review PRs
  metadata: read          # Access repo info
  checks: write           # Create status checks (optional)

Organization permissions:
  members: read           # See team members (optional)
```

**To adjust permissions:**

1. Go to app settings
2. Click "Configure" on installed app
3. Review and grant permissions
4. Save changes

### Step 4: Configure API Access (Optional)

For direct API access via workflows:

1. **Get Anthropic API Key:**
   ```
   https://console.anthropic.com/settings/keys
   ```
   - Create new API key
   - Copy the key (starts with `sk-ant-api03-...`)

2. **Add to GitHub Secrets:**
   ```
   Repository Settings > Secrets and variables > Actions > New repository secret

   Name: ANTHROPIC_API_KEY
   Secret: sk-ant-api03-your-key-here
   ```

3. **Verify secret is set:**
   ```
   Settings > Secrets > Actions
   ```
   - Should see `ANTHROPIC_API_KEY` listed

**Note:** The API key is optional! The GitHub App works without it.

### Step 5: Enable Workflows

All workflows are already committed to your branch. Once you merge the PR:

1. **Check workflows are enabled:**
   ```
   Actions > All workflows
   ```

2. **Enable if needed:**
   - Claude Coordinator ✅
   - Claude AI Assistant ✅
   - AI Agent Coordinator ✅
   - Automated Copilot Agent ✅
   - Copilot PR Automation ✅

3. **Set workflow permissions:**
   ```
   Settings > Actions > General > Workflow permissions
   ```
   - Select: "Read and write permissions"
   - Check: "Allow GitHub Actions to create and approve pull requests"

## What to Expect After Installation

### Immediate Effects

**On new PRs:**
1. Claude for GitHub will be available for mentions
2. Coordinator workflow will detect Claude's activity
3. Multi-agent collaboration will activate automatically

**On comments:**
- `@Claude` mentions will trigger the app
- Claude will respond with reviews/suggestions
- Coordinator will bridge to Copilot

**On issues:**
- Can mention `@Claude` for help
- Claude analyzes and provides guidance
- Coordinator facilitates implementation

### Automatic Behaviors

Once installed, these happen automatically:

```
PR Created
  ↓
Wait for @Claude mention
  ↓
Claude reviews (via GitHub App)
  ↓
Coordinator detects and bridges (via workflow)
  ↓
Copilot implements (via your existing workflow)
  ↓
AitherZero validates (via existing workflow)
  ↓
Ready for human review
```

## Testing After Installation

### Quick Test Checklist

- [ ] **Test 1: Claude responds to mentions**
  ```
  1. Create test issue
  2. Comment: @Claude please help with X
  3. Verify: Claude responds within 30 seconds
  ```

- [ ] **Test 2: PR review works**
  ```
  1. Create test PR
  2. Comment: @Claude please review
  3. Verify: Claude provides review
  ```

- [ ] **Test 3: Coordinator activates**
  ```
  1. After Claude reviews PR
  2. Check Actions tab
  3. Verify: "Claude Coordination" workflow ran
  4. Check: Coordinator posted bridge comment
  ```

- [ ] **Test 4: Multi-agent coordination**
  ```
  1. Create PR with changes
  2. Request: @Claude review security
  3. Verify: Claude reviews
  4. Verify: Coordinator notifies Copilot
  5. Check: AitherZero validation runs
  ```

- [ ] **Test 5: Manual coordination**
  ```
  1. Go to Actions > AI Agent Coordinator
  2. Run workflow with: Agent Type = multi-agent
  3. Verify: All agents activated
  4. Check: Coordination report generated
  ```

### Detailed Test Procedure

**Test the full workflow:**

1. **Create test branch:**
   ```bash
   git checkout -b test/claude-integration
   echo "# Test" > test-file.ps1
   git add test-file.ps1
   git commit -m "test: Claude integration"
   git push origin test/claude-integration
   ```

2. **Create PR on GitHub**

3. **Trigger Claude:**
   ```
   Comment: @Claude please review this test PR
   ```

4. **Monitor the flow:**
   - [ ] Claude for GitHub responds (within 30-60 seconds)
   - [ ] Coordinator workflow triggers (check Actions tab)
   - [ ] Coordinator posts bridge comment
   - [ ] Copilot notified (if mentioned in coordinator)
   - [ ] AitherZero validation runs
   - [ ] All checks complete

5. **Verify outputs:**
   - Check PR comments for all agent activity
   - Check Actions tab for workflow runs
   - Review coordination summary
   - Confirm no errors in logs

## Troubleshooting

### Claude for GitHub Not Responding

**Symptom:** `@Claude` mentions don't get responses

**Solutions:**

1. **Check installation:**
   ```
   Settings > Installations
   Should see Claude/Anthropic app
   ```

2. **Check permissions:**
   ```
   App settings > Permissions
   Ensure issues and PR permissions are granted
   ```

3. **Wait longer:**
   - First response may take 1-2 minutes
   - Subsequent responses are faster

4. **Try different format:**
   ```
   @Claude review this
   @Claude can you help?
   Claude: what do you think?  (without @)
   ```

5. **Check app status:**
   - Visit Anthropic status page
   - Check for GitHub API issues

### Coordinator Not Triggering

**Symptom:** Coordinator workflow doesn't run after Claude comments

**Solutions:**

1. **Check workflow is enabled:**
   ```
   Actions > All workflows > Claude Coordination
   Should show "enabled" not "disabled"
   ```

2. **Check workflow permissions:**
   ```
   Settings > Actions > General
   Workflow permissions: Read and write
   ```

3. **Check trigger conditions:**
   - Coordinator triggers on comment creation
   - Must be from a bot that includes "claude" in username
   - Check workflow file for exact trigger logic

4. **Manual trigger:**
   ```
   Actions > Claude Coordination > Run workflow
   ```

5. **Check logs:**
   ```
   Actions > Recent runs > View logs
   Look for error messages
   ```

### API Key Issues

**Symptom:** API-based workflows say "API key not configured"

**Solution:**

This is normal if you haven't added the API key. The GitHub App works without it!

**If you want API access:**
```
1. Get key: https://console.anthropic.com/
2. Add to secrets: ANTHROPIC_API_KEY
3. Re-run workflow
```

### Workflows Conflicting

**Symptom:** Multiple workflows triggering at once

**Solution:**

This is actually fine! They coordinate:
- Claude for GitHub = Quick review
- Coordinator = Orchestration
- Copilot = Implementation
- AitherZero = Validation

Each has a specific role. They complement, not conflict.

**If you want to disable some:**
```
Actions > Specific workflow > ⋯ > Disable workflow
```

## Enterprise-Specific Considerations

### Security Review

If your enterprise requires security review:

1. **Provide to security team:**
   - App permissions list
   - Data flow diagram
   - Privacy policy: https://www.anthropic.com/privacy
   - Terms of service: https://www.anthropic.com/terms

2. **Key points:**
   - Claude analyzes code sent to it
   - Anthropic's privacy policy applies
   - Data retention per Anthropic's terms
   - No code stored unless explicitly configured

### Compliance

**Data residency:**
- Claude API is hosted by Anthropic
- Check if multi-region is available
- May need specific deployment

**Access control:**
- Use GitHub teams for access control
- App inherits repository permissions
- Configure via GitHub's native controls

### Cost Management

**GitHub App usage:**
- May have usage limits based on plan
- Check with Anthropic for enterprise pricing

**API usage (if using API key):**
- Billed per API call
- Monitor at https://console.anthropic.com/
- Set up billing alerts

## Success Criteria

Installation is successful when:

✅ Claude for GitHub responds to `@Claude` mentions
✅ Coordinator workflow runs after Claude comments
✅ Multi-agent coordination works end-to-end
✅ No errors in workflow logs
✅ All tests pass

## Next Steps

After successful installation:

1. **Use it naturally:**
   - Create PRs as normal
   - Use `@Claude` for reviews
   - Let coordination happen automatically

2. **Monitor initially:**
   - Watch first few coordinations
   - Check logs for issues
   - Adjust if needed

3. **Train your team:**
   - Share Multi-Agent-Setup-Complete.md
   - Show how to use `@Claude`
   - Demonstrate coordination flow

4. **Iterate:**
   - Collect feedback
   - Adjust workflows
   - Add custom analysis types

## Support

**For installation issues:**
- Anthropic support: support@anthropic.com
- GitHub support: Enterprise support portal
- Check status: https://status.anthropic.com/

**For workflow issues:**
- Check workflow logs in Actions tab
- Review documentation in docs/
- Create issue with `workflow` label

**For enterprise support:**
- Contact: enterprise@anthropic.com
- Include: Organization name, use case, team size

## Summary

Once you complete the installation:

1. Claude and Claude for GitHub will be active
2. All workflows are already configured
3. Just use `@Claude` in PRs and issues
4. Multi-agent coordination works automatically
5. No additional setup needed!

The workflows I created are **ready and waiting** for the apps to be installed!

---

**Status:** Waiting for app installation
**When ready:** Just mention `@Claude` and everything activates
**Documentation:** See Multi-Agent-Setup-Complete.md for usage guide
