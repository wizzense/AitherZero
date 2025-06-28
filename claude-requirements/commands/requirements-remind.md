# /requirements-remind

Remind the AI to follow requirements gathering rules.

## Usage
```
/remind
/requirements-remind
```

## When to Use
Use this command when the AI:
- Asks open-ended questions instead of yes/no
- Starts implementing code during requirements
- Asks multiple questions at once
- Provides long explanations instead of being concise
- Forgets to provide defaults for questions

## AI Behavior After Reminder
The AI should:
1. Return to asking ONE yes/no question at a time
2. Provide clear defaults for each question
3. Accept "idk" as valid input
4. Focus only on requirements gathering
5. Save all answers before proceeding

## Example
```
User: /remind
AI: Acknowledged. Returning to requirements gathering format.

Q3: Should this feature require admin approval?
(Default if unknown: NO - most features don't require admin approval)
```