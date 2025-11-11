# CI/CD Pipeline Trigger File
# 
# Workflows added in a PR don't run until after merge
# Modified workflows use the BASE BRANCH version until merged
# This file forces GitHub Actions to re-evaluate workflow status
#
# Last updated: 2025-11-11
# Fixes applied: Concurrency groups, trigger validation, playbook references
