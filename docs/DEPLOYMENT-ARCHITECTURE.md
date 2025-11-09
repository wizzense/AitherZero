# Branch Deployment Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     GitHub Repository Branches                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐    ┌──────────┐    ┌──────────────┐   ┌──────────┐  │
│  │   main   │    │   dev    │    │ dev-staging  │   │  ring-*  │  │
│  └────┬─────┘    └────┬─────┘    └──────┬───────┘   └────┬─────┘  │
│       │               │                  │                 │        │
│       │ git push      │ git push         │ git push        │ push   │
│       ▼               ▼                  ▼                 ▼        │
└───────┼───────────────┼──────────────────┼─────────────────┼────────┘
        │               │                  │                 │
        │               │                  │                 │
┌───────▼───────────────▼──────────────────▼─────────────────▼────────┐
│            GitHub Actions: jekyll-gh-pages.yml Workflow              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Job 1: setup (Determine branch configuration)             │    │
│  │  ────────────────────────────────────────────────────────  │    │
│  │  Input: github.ref_name (e.g., "dev-staging")             │    │
│  │                                                             │    │
│  │  Output:                                                    │    │
│  │  - branch-name: "dev-staging"                              │    │
│  │  - destination-dir: "dev-staging"                          │    │
│  │  - base-url: "/dev-staging"                                │    │
│  │  - deployment-url: "https://...github.io/.../dev-staging/" │    │
│  └────────────────┬───────────────────────────────────────────┘    │
│                   │                                                 │
│  ┌────────────────▼───────────────────────────────────────────┐    │
│  │  Job 2: build (Build Jekyll site)                          │    │
│  │  ────────────────────────────────────────────────────────  │    │
│  │  1. Checkout code                                           │    │
│  │  2. Create _config_branch.yml with baseurl                  │    │
│  │  3. Create branch-info.md with deployment details          │    │
│  │  4. Build Jekyll with merged configs                       │    │
│  │  5. Upload artifact: ./_site/                              │    │
│  └────────────────┬───────────────────────────────────────────┘    │
│                   │                                                 │
│  ┌────────────────▼───────────────────────────────────────────┐    │
│  │  Job 3: deploy (Deploy to GitHub Pages)                    │    │
│  │  ────────────────────────────────────────────────────────  │    │
│  │  Action: peaceiris/actions-gh-pages@v3                     │    │
│  │                                                             │    │
│  │  Parameters:                                                │    │
│  │  - publish_dir: ./_site                                    │    │
│  │  - destination_dir: "dev-staging"  ← BRANCH SPECIFIC!     │    │
│  │  - keep_files: true  ← Preserves other branches           │    │
│  │  - target_branch: gh-pages                                 │    │
│  └────────────────┬───────────────────────────────────────────┘    │
│                   │                                                 │
└───────────────────┼─────────────────────────────────────────────────┘
                    │
                    │ Commits to gh-pages branch
                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     gh-pages Branch Structure                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  gh-pages (root)                                                    │
│  ├── index.md                    ← main branch deployment          │
│  ├── deployments.md              ← navigation page                 │
│  ├── library/                                                       │
│  │   ├── reports/                ← main branch reports             │
│  │   └── ...                                                        │
│  ├── docs/                        ← main branch docs               │
│  │                                                                  │
│  ├── dev/                         ← dev branch deployment          │
│  │   ├── index.md                                                  │
│  │   ├── branch-info.md                                            │
│  │   ├── library/                                                  │
│  │   │   ├── reports/            ← dev branch reports             │
│  │   │   └── ...                                                   │
│  │   └── docs/                   ← dev branch docs                │
│  │                                                                  │
│  ├── dev-staging/                ← dev-staging deployment          │
│  │   ├── index.md                                                  │
│  │   ├── branch-info.md                                            │
│  │   ├── library/                                                  │
│  │   │   ├── reports/            ← dev-staging reports ✅         │
│  │   │   └── ...                                                   │
│  │   └── docs/                   ← dev-staging docs               │
│  │                                                                  │
│  ├── develop/                    ← develop branch deployment       │
│  ├── ring-0/                     ← ring-0 deployment               │
│  └── ring-1/                     ← ring-1 deployment               │
│                                                                      │
└──────────────────────┬───────────────────────────────────────────────┘
                       │
                       │ GitHub Pages CDN
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Public URLs (wizzense.github.io)                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  https://wizzense.github.io/AitherZero/                            │
│  ├── (root - main branch)                                          │
│  │   ├── /library/reports/dashboard.html                           │
│  │   └── /docs/                                                     │
│  │                                                                  │
│  ├── /dev/                                                          │
│  │   ├── /dev/library/reports/dashboard.html                       │
│  │   └── /dev/branch-info.html                                     │
│  │                                                                  │
│  ├── /dev-staging/  ✅ NOW WORKS!                                  │
│  │   ├── /dev-staging/library/reports/dashboard.html              │
│  │   └── /dev-staging/branch-info.html                            │
│  │                                                                  │
│  ├── /develop/                                                      │
│  ├── /ring-0/                                                       │
│  └── /ring-1/                                                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Architecture Changes

### Before (❌ Broken)

```
All branches → github-pages environment → Single deployment
                    ↑
                    └── Environment protection blocks dev-staging
```

### After (✅ Working)

```
Each branch → Branch-specific config → Subdirectory deployment
                                              ↓
                                    gh-pages branch (no environment)
                                              ↓
                                    peaceiris/actions-gh-pages
                                              ↓
                                    No protection conflicts!
```

## Deployment Flow Detail

### 1. Branch Push Event
```
Developer: git push origin dev-staging
   ↓
GitHub: Triggers jekyll-gh-pages.yml workflow
   ↓
Workflow: Identifies branch = "dev-staging"
```

### 2. Setup Job
```
Reads: github.ref_name = "dev-staging"
   ↓
Determines:
   - destination_dir = "dev-staging"
   - base_url = "/dev-staging"
   - deployment_url = "https://wizzense.github.io/AitherZero/dev-staging/"
   ↓
Outputs: Configuration for build and deploy jobs
```

### 3. Build Job
```
Creates: _config_branch.yml
   baseurl: "/dev-staging"
   branch: "dev-staging"
   deployment_time: "2025-11-09 22:55:52 UTC"
   ↓
Creates: branch-info.md
   Current branch: dev-staging
   Links to: main, dev, develop
   ↓
Builds: Jekyll with _config.yml + _config_branch.yml
   ↓
Uploads: Artifact with built site
```

### 4. Deploy Job
```
Downloads: Built site from artifact
   ↓
Deploys with: peaceiris/actions-gh-pages@v3
   - target_branch: gh-pages
   - destination_dir: dev-staging  ← Goes to subdirectory!
   - keep_files: true  ← Preserves other branches!
   ↓
Commits to: gh-pages branch
   - Only touches dev-staging/ directory
   - Leaves main/, dev/, develop/ intact
   ↓
GitHub Pages: Publishes updated content
   - CDN propagates in ~5 minutes
   - URL: https://wizzense.github.io/AitherZero/dev-staging/
```

## Concurrency Control

### Per-Branch Concurrency
```
concurrency:
  group: "pages-${{ github.ref_name }}"
  cancel-in-progress: false
```

**Effect:**
- main pushes: group = "pages-main"
- dev pushes: group = "pages-dev"
- dev-staging pushes: group = "pages-dev-staging"

**Result:** All branches can deploy in parallel without conflicts!

## File Preservation

### keep_files: true
```
Before deployment:
gh-pages/
├── main files
├── dev/
├── develop/
└── ring-0/

Deploy dev-staging:
gh-pages/
├── main files (preserved)
├── dev/ (preserved)
├── dev-staging/ (new/updated)
├── develop/ (preserved)
└── ring-0/ (preserved)
```

## Benefits Visualization

```
                    ┌─────────────────┐
                    │  Isolated Data  │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
  ┌──────────┐        ┌──────────┐        ┌──────────┐
  │   main   │        │   dev    │        │dev-stage │
  │  tests   │        │  tests   │        │  tests   │
  │ reports  │        │ reports  │        │ reports  │
  │ metrics  │        │ metrics  │        │ metrics  │
  └──────────┘        └──────────┘        └──────────┘
       ↓                    ↓                    ↓
  Production          Development          Staging
    stable              active              testing
```

**No Cross-Contamination!** Each branch maintains its own data.

---

**Architecture Version**: 2.0  
**Implementation Date**: 2025-11-09  
**Status**: ✅ Production Ready
