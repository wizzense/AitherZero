# /requirements-list

List all requirements with their current status.

## Usage
```
/requirements-list
```

## Output Format
```
📁 Requirements Summary

✅ COMPLETE (3)
- dark-mode-toggle - Ready for implementation
- user-notifications - Spec generated 2024-01-14
- data-export - Completed 2024-01-10

🔴 ACTIVE (1)
- payment-integration - Detail Questions 3/5

⚠️ INCOMPLETE (2)
- mobile-offline-mode - Paused at Discovery 2/5 (3 days ago)
- api-rate-limiting - Paused at Context Analysis (1 week ago)

📊 Total: 6 requirements
```

## Features
- Groups by status (Complete/Active/Incomplete)
- Shows progress for incomplete items
- Displays last activity time
- Links to individual requirement folders

## Sorting
- Active requirements first
- Then incomplete by most recent
- Complete requirements last by date