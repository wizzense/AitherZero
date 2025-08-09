---
name: request-review
description: Initiate human review process
allowed-tools: Read, Write, Task, TodoWrite
argument-hint: <content_id>
---

## Context
- Content ID: $ARGUMENTS
- Process: Human review workflow initiation

## Your Task

Initiate the human review process:

1. **Pre-Review Preparation**:
   - Use the Task tool to invoke review-coordinator agent to compile validation results
   - Use the Task tool to invoke quality-gatekeeper agent to generate review package
   - Create comprehensive summary document with all findings

2. **Review Package Contents**:
   ```
   Review Package for: [Content Name]
   ├── validation-results.json
   ├── code-samples.md
   ├── risk-assessment.pdf
   ├── test-results.json
   └── recommendations.md
   ```

3. **Determine Reviewers**:
   Based on content type and risk:
   - Technical review (always required)
   - Security review (if elevated privileges)
   - Compliance review (if PII collected)
   - Performance review (if resource intensive)
   - Manager approval (if high risk)

4. **Create Review Request**:
   ```yaml
   Review Request: #REV-2024-001
   Content: CPU Temperature Scripts
   Risk Level: Medium
   Required Reviews:
     - Technical: 2 reviewers needed
     - Security: 1 reviewer needed
   Timeline: 48 hours
   Priority: High
   ```

5. **Review Tracking**:
   - Create review ticket
   - Set up notifications
   - Track review progress
   - Log all feedback

6. **Review Dashboard Update**:
   - Update review queue
   - Send notifications
   - Set review deadlines
   - Create calendar events

Output review ID and tracking information.