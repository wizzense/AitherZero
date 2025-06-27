# Documentation Reorganization Plan

## Current State
- 54+ documentation files scattered throughout /docs
- Mix of current guides and historical summaries
- Difficult to find relevant documentation
- No clear hierarchy

## Proposed Structure

```
/docs/
├── README.md                          # Documentation index
├── INSTALLATION.md                    # Installation guide
├── QUICK-START.md                    # Quick start guide (from root)
├── FEATURES.md                        # Feature overview
├── CHANGELOG.md                       # Consolidated project history
│
├── guides/                            # User and developer guides
│   ├── MODULE-REFERENCE.md            # Module documentation
│   ├── TESTING-GUIDE.md              # Testing documentation
│   ├── PATCHMANAGER-GUIDE.md         # PatchManager guide
│   ├── CLAUDE-CODE-MCP.md           # Claude Code integration
│   └── DEVELOPER-GUIDE.md           # Developer onboarding
│
├── architecture/                      # Technical documentation
│   ├── ARCHITECTURE.md               # System architecture
│   ├── PARAMETERS.md                 # Standardized parameters
│   └── CI-CD.md                      # GitHub Actions guide
│
├── roadmap/                          # Future plans (existing)
│   ├── README.md                     # Roadmap index
│   ├── IMPLEMENTATION-ROADMAP.md     # Implementation plans
│   └── [other roadmap files]
│
└── archive/                          # Historical documentation
    ├── implementations/              # Past implementation summaries
    ├── patches/                      # PatchManager history
    └── reorganizations/              # Project reorganization history
```

## Root Directory Cleanup

Move to /docs:
- QUICK-START-GUIDE.md → /docs/QUICK-START.md
- CONTRIBUTING.md → Keep at root (GitHub standard)
- CLAUDE.md → Keep at root (Claude Code specific)

## Essential Documentation Set

### Core Documentation (7 files)
1. README.md - Documentation index
2. INSTALLATION.md - Setup instructions
3. QUICK-START.md - Getting started
4. FEATURES.md - Feature overview
5. CHANGELOG.md - Version history
6. CONTRIBUTING.md - Contribution guide
7. CLAUDE.md - Claude Code instructions

### User Guides (5 files)
1. MODULE-REFERENCE.md - All modules
2. TESTING-GUIDE.md - Testing instructions
3. PATCHMANAGER-GUIDE.md - Git workflows
4. CLAUDE-CODE-MCP.md - MCP integration
5. DEVELOPER-GUIDE.md - Development setup

### Technical Docs (3 files)
1. ARCHITECTURE.md - System design
2. PARAMETERS.md - Parameter reference
3. CI-CD.md - GitHub Actions

## Benefits
- Clear hierarchy
- Easy navigation
- Separation of current vs historical
- Maintains project history
- Reduces clutter
- Better discoverability

## Migration Steps
1. Create new directory structure
2. Consolidate related documentation
3. Move files to appropriate locations
4. Update all internal references
5. Create comprehensive indexes
6. Archive historical documents