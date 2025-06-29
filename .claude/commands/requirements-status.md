# /requirements-status

Check the progress of the current requirement gathering session and continue where left off.

## Usage
```
/requirements-status
```

## Aliases
- `/requirements-current`

## Output Example
```
📋 Active Requirement: dark-mode-toggle
Phase: Discovery Questions
Progress: 3/5 questions answered

Next: Q4: Should this sync across devices?
(Default if unknown: YES - cross-device sync is expected)
```

## Behavior
- Reads .current-requirement file to identify active session
- Loads metadata.json to check progress
- Determines current phase and next action
- Continues from last answered question
- If no active requirement, prompts to use /requirements-start