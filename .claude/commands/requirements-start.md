# /requirements-start

Start gathering requirements for a new feature or change.

## Usage
```
/requirements-start [description]
```

## Examples
```
/requirements-start add user profile picture upload
/requirements-start implement dark mode toggle
/requirements-start fix dashboard performance issues
```

## Process
1. Creates a new requirement folder with timestamp
2. Saves the initial request
3. Analyzes the codebase structure
4. Begins Phase 1: Context Discovery Questions (5 yes/no questions)
5. Waits for all answers before proceeding to Phase 2

## Important Rules
- Ask ONE question at a time
- All questions must be yes/no format
- Provide intelligent defaults for each question
- Accept "idk" as valid answer (uses default)
- Wait for all 5 answers before Phase 2

## File Structure Created
```
requirements/YYYY-MM-DD-HHMM-[name]/
├── metadata.json
├── 00-initial-request.md
└── 01-discovery-questions.md
```