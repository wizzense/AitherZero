---
name: Ring Deployment Pull Request
about: Pull request for ring-based deployment
title: '[RING] '
labels: ''
assignees: ''
---

## 🎯 Ring Deployment Information

**Source Ring**: <!-- e.g., ring-0, ring-1, dev -->
**Target Ring**: <!-- e.g., ring-0-integrations, ring-2, main -->
**Deployment Type**: <!-- Promotion / Demotion / Same Level -->

---

## 📋 Description

<!-- Provide a clear and concise description of the changes in this PR -->

### What changed?
<!-- Describe the changes made -->

### Why was this change made?
<!-- Explain the motivation behind this change -->

### Related Issues
<!-- Link to related issues: Fixes #123, Relates to #456 -->

---

## ✅ Pre-Promotion Checklist

### Testing
- [ ] All tests pass in source ring
- [ ] Integration tests validated (for -integrations rings)
- [ ] Performance tests pass (ring-1-integrations and higher)
- [ ] Security scan completed with no critical issues

### Code Quality
- [ ] Code review completed
- [ ] PSScriptAnalyzer passes
- [ ] No breaking changes (or documented if present)
- [ ] Code coverage maintained or improved

### Documentation
- [ ] Documentation updated (if applicable)
- [ ] CHANGELOG updated (for releases)
- [ ] Breaking changes documented
- [ ] Migration guide provided (if needed)

### Ring-Specific Requirements

#### For Ring 0 → Ring 0-Integrations
- [ ] Integration tests added/updated
- [ ] External dependencies validated
- [ ] Smoke tests pass

#### For Ring 1 → Ring 1-Integrations
- [ ] Cross-component testing completed
- [ ] Performance benchmarks meet targets
- [ ] Load testing completed

#### For Ring 2 → Dev
- [ ] End-to-end testing completed
- [ ] Stakeholder review requested
- [ ] Deployment plan reviewed

#### For Dev → Main (Production)
- [ ] Production deployment plan approved
- [ ] Rollback plan documented
- [ ] Monitoring/alerts configured
- [ ] Post-deployment validation plan ready

---

## 🧪 Test Results

### Test Profile: <!-- quick / integration / standard / comprehensive / full / production -->
**Estimated Duration**: <!-- e.g., 5-10 minutes -->

### Test Execution
<!-- Provide test execution details or link to workflow run -->
- **Unit Tests**: ✅ Pass / ❌ Fail / ⏭️ Skip
- **Integration Tests**: ✅ Pass / ❌ Fail / ⏭️ Skip
- **Security Scan**: ✅ Pass / ❌ Fail / ⏭️ Skip
- **Performance Tests**: ✅ Pass / ❌ Fail / ⏭️ Skip

### Test Coverage
- **Line Coverage**: <!-- e.g., 85% -->
- **Branch Coverage**: <!-- e.g., 78% -->

---

## 🔍 Review Focus Areas

<!-- Highlight specific areas that need reviewer attention -->

### Critical Changes
<!-- List critical changes that require careful review -->

### Potential Risks
<!-- Identify any potential risks or concerns -->

### Testing Strategy
<!-- Describe how this change was tested -->

---

## 📸 Screenshots / Demos

<!-- If applicable, add screenshots or demo links -->

---

## 🚀 Deployment Notes

### Pre-Deployment
<!-- Any actions needed before deployment -->

### Post-Deployment
<!-- Actions to take after deployment -->

### Rollback Plan
<!-- Describe rollback procedure if needed -->

---

## 📊 Impact Assessment

### Affected Components
<!-- List components affected by this change -->

### Breaking Changes
<!-- List any breaking changes -->
- None
<!-- OR -->
- ❗ Breaking change 1: Description
- ❗ Breaking change 2: Description

### Migration Required
<!-- Describe any migration steps needed -->
- None
<!-- OR -->
- Step 1: Description
- Step 2: Description

---

## 🔗 References

### Documentation
<!-- Links to relevant documentation -->

### Related PRs
<!-- Links to related PRs in other rings -->

### External Resources
<!-- Links to external resources, if any -->

---

## 👥 Reviewers

<!-- Tag specific reviewers or teams -->

**Code Review**: <!-- @username -->
**Security Review**: <!-- @username (if applicable) -->
**Performance Review**: <!-- @username (if applicable) -->

---

## 📝 Additional Notes

<!-- Any additional information reviewers should know -->

---

<!-- 
🤖 This PR will be automatically labeled based on ring detection.
The ring-based deployment workflow will run appropriate tests based on the target ring.

Ring Labels:
- ring:source:<ring> - Automatically applied
- ring:target:<ring> - Automatically applied  
- ring:promotion - Applied if promoting to higher ring
- ring:demotion - Applied if demoting to lower ring

For more information, see: docs/RING-DEPLOYMENT-STRATEGY.md
-->
