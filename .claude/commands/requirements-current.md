# /requirements-current

View the details of the current active requirement.

## Usage
```
/requirements-current
```

## Output
Shows comprehensive view of:
- Requirement name and status
- Initial request
- All questions asked and answered
- Context findings (if Phase 3 complete)
- Current progress

## Example Output
```
📋 Requirement: user-avatar-upload
Status: Active - Detail Questions Phase
Started: 2024-01-15 14:30

Initial Request:
"add user profile picture upload"

Discovery Questions (Complete):
Q1: Will users interact through visual interface? YES
Q2: Does this need to work on mobile? YES (default)
Q3: Should avatars be stored locally? NO
Q4: Will this require authentication? YES
Q5: Should we limit file size? YES

Context Findings:
- Found existing UserProfile component at src/components/UserProfile.tsx
- Identified FileUploadService at src/services/FileUploadService.ts
- Current storage uses AWS S3 (config/aws.json)
- Authentication uses JWT tokens

Detail Questions (In Progress - 2/5):
Q1: Use existing FileUploadService? YES
Q2: Support image cropping? YES
Q3: [Next question pending...]
```