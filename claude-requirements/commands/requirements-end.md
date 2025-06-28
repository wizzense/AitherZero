# /requirements-end

End the current requirement gathering session.

## Usage
```
/requirements-end
```

## Options
User will be prompted to choose:
1. **Generate Spec** - Create requirements document with current information
2. **Mark Incomplete** - Save progress for later continuation
3. **Cancel** - Delete the requirement folder

## Behavior by Phase
- **If all phases complete**: Automatically generates final spec
- **If partially complete**: Prompts for action (generate/pause/cancel)
- **If just started**: Confirms cancellation

## Final Output
When generating spec, creates:
```
requirements/[name]/06-requirements-spec.md
```

Contains:
- Executive summary
- Functional requirements from all answers
- Technical requirements with file paths
- Implementation guidelines
- Acceptance criteria
- Next steps

## Cleanup
- Clears .current-requirement file
- Updates requirements/index.md with final status