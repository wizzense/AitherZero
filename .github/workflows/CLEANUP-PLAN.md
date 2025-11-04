# Workflow Cleanup Plan

## KEEP (Core workflows - 8 essential)
1. unified-testing.yml - NEW unified test orchestration
2. pr-validation.yml - PR syntax/basic checks
3. quality-validation.yml - Code quality checks
4. validate-config.yml - Config validation
5. validate-manifests.yml - Module manifests
6. copilot-agent-router.yml - Custom agent routing
7. documentation-automation.yml - Auto-generate docs
8. index-automation.yml - Keep indexes updated

## DEPRECATE (Mark but keep temporarily - 7)
1. comprehensive-test-execution.yml - REPLACED by unified-testing.yml
2. auto-generate-tests.yml - Keep for now (test generation)
3. auto-create-issues-from-failures.yml - Useful for issue creation
4. publish-test-reports.yml - Keep for now
5. validate-test-sync.yml - Keep for now
6. workflow-health-check.yml - Keep for diagnostics
7. diagnose-ci-failures.yml - Keep for diagnostics

## DELETE (Bogus/unused - 9)
1. AITHERCORE-INTEGRATION.md - Doc in wrong place
2. README.md - Doc in wrong place
3. archive-documentation.yml - Not needed
4. build-aithercore-packages.yml - Wrong repo
5. comment-release.yml - Duplicate/unused
6. deploy-pr-environment.yml - Not used
7. docker-publish.yml.disabled - Already disabled
8. jekyll-gh-pages.yml - Not needed (using unified-testing)
9. phase2-intelligent-issue-creation.yml - Experimental
10. release-automation.yml - Not ready/not used
