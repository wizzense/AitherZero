# CLI Quality of Life - Phase 1 Implementation Plan

**Objective:** Implement critical UX improvements for CLI and interactive menu  
**Timeline:** 5-8 days  
**Status:** 🟡 PLANNING  

---

## Phase 1 Features (Prioritized)

### 1. Session Management ⭐ **HIGHEST PRIORITY**
**Effort:** 2-3 days  
**Value:** Massive productivity boost for daily users

#### Implementation Tasks

**Task 1.1: Create SessionManager Module** (4 hours)
```powershell
# File: domains/experience/SessionManager.psm1
- Create module structure
- Define session schema (JSON format)
- Implement session storage (~/.aitherzero/sessions/)
```

**Task 1.2: Core Session Functions** (6 hours)
```powershell
function Save-AitherSession {
    param([string]$Name, [switch]$Auto)
    # Save: breadcrumb path, command state, variables, timestamp
}

function Restore-AitherSession {
    param([string]$Name)
    # Restore saved session state to UnifiedMenu
}

function Get-SavedSessions {
    # List sessions with metadata (name, date, description)
}

function Remove-AitherSession {
    param([string]$Name)
    # Delete saved session
}
```

**Task 1.3: UnifiedMenu Integration** (4 hours)
```powershell
# Modify domains/experience/UnifiedMenu.psm1
- Add "Sessions" menu option (key: 'S')
- Add auto-save on exit (if enabled)
- Add restore on startup (if session specified)
- Add session indicator in UI
```

**Task 1.4: CLI Integration** (2 hours)
```powershell
# Modify Start-AitherZero.ps1
- Add -Session parameter
- Add -SaveSession parameter
- Add -ListSessions switch
```

**Task 1.5: Tests** (3 hours)
```powershell
# File: tests/unit/domains/experience/SessionManager.Tests.ps1
- Test session save/restore
- Test session list/delete
- Test session validation
- Test auto-save behavior
```

**Task 1.6: Documentation** (2 hours)
```powershell
# File: docs/SESSION-MANAGEMENT.md
- Usage guide
- Session file format
- CLI examples
- Troubleshooting
```

**Deliverables:**
- [ ] SessionManager.psm1 module
- [ ] UnifiedMenu integration
- [ ] CLI parameters
- [ ] Unit tests (100% coverage)
- [ ] Documentation

---

### 2. Favorites/Bookmarks ⭐ **HIGH PRIORITY**
**Effort:** 1-2 days  
**Value:** Quick access to frequently-used commands

#### Implementation Tasks

**Task 2.1: Create BookmarkManager Module** (3 hours)
```powershell
# File: domains/experience/BookmarkManager.psm1
- Create module structure
- Define bookmark schema (JSON format)
- Implement bookmark storage (~/.aitherzero/bookmarks.json)
```

**Task 2.2: Core Bookmark Functions** (4 hours)
```powershell
function Add-AitherBookmark {
    param(
        [string]$Name,
        [hashtable]$Command,
        [string]$Category = 'General',
        [string]$Description
    )
    # Add command to bookmarks
}

function Get-AitherBookmarks {
    param([string]$Category)
    # List bookmarks, track usage count
}

function Invoke-AitherBookmark {
    param([string]$Name)
    # Execute bookmarked command
}

function Remove-AitherBookmark {
    param([string]$Name)
}

function Update-AitherBookmark {
    param([string]$Name, [hashtable]$NewCommand)
}
```

**Task 2.3: InteractiveUI Integration** (3 hours)
```powershell
# Modify domains/experience/InteractiveUI.psm1
- Add "Bookmarks" menu option
- Add "Bookmark This" quick action
- Show usage statistics
- Sort by usage frequency
```

**Task 2.4: CLI Integration** (2 hours)
```powershell
# Modify Start-AitherZero.ps1
- Add -Bookmark parameter (execute bookmark by name)
- Add -AddBookmark parameter
- Add -ListBookmarks switch
```

**Task 2.5: Tests** (2 hours)
```powershell
# File: tests/unit/domains/experience/BookmarkManager.Tests.ps1
- Test bookmark CRUD operations
- Test usage tracking
- Test category filtering
```

**Task 2.6: Documentation** (1 hour)
```powershell
# File: docs/BOOKMARKS-GUIDE.md
- Usage examples
- Best practices
- CLI reference
```

**Deliverables:**
- [ ] BookmarkManager.psm1 module
- [ ] InteractiveUI integration
- [ ] CLI parameters
- [ ] Unit tests (100% coverage)
- [ ] Documentation

---

### 3. Interactive Filtering ⭐ **MEDIUM-HIGH PRIORITY**
**Effort:** 2-3 days  
**Value:** Faster navigation in large lists

#### Implementation Tasks

**Task 3.1: Enhance BetterMenu** (6 hours)
```powershell
# Modify domains/experience/BetterMenu.psm1
function Show-FilterableMenu {
    param(
        [array]$Items,
        [string]$Title,
        [int]$MinItemsForFilter = 10
    )
    
    # Features:
    # - Type to filter (real-time)
    # - ESC to clear filter
    # - Backspace to edit filter
    # - Show filter in footer
    # - Highlight matching text
}
```

**Task 3.2: Filter Logic** (4 hours)
```powershell
function Get-FilteredItems {
    param(
        [array]$Items,
        [string]$Filter,
        [switch]$CaseSensitive
    )
    
    # Filter by:
    # - Name contains filter
    # - Description contains filter
    # - Number starts with filter
    # - Tags contain filter (if available)
}
```

**Task 3.3: Visual Enhancements** (3 hours)
```powershell
# Add to filtering UI:
- Show filter input at bottom
- Show match count (e.g., "5 of 42 items")
- Highlight matched portions in items
- Show "No matches" message
```

**Task 3.4: UnifiedMenu Integration** (2 hours)
```powershell
# Replace all Show-Menu calls with Show-FilterableMenu
- Script list menus
- Playbook list menus
- Category menus (if > 10 items)
```

**Task 3.5: Tests** (3 hours)
```powershell
# File: tests/unit/domains/experience/FilterableMenu.Tests.ps1
- Test filter matching
- Test case sensitivity
- Test special characters
- Test empty results
- Test filter UI rendering
```

**Task 3.6: Documentation** (1 hour)
```powershell
# File: docs/INTERACTIVE-FILTERING.md
- Usage guide
- Keyboard shortcuts
- Filter syntax
```

**Deliverables:**
- [ ] Enhanced BetterMenu with filtering
- [ ] Filter matching logic
- [ ] Visual enhancements
- [ ] Integration in all menus
- [ ] Unit tests (100% coverage)
- [ ] Documentation

---

## Configuration Changes

### config.psd1 Additions
```powershell
Experience = @{
    # Existing settings...
    
    # NEW: Session Management
    Sessions = @{
        Enabled = $true
        AutoSave = $true  # Auto-save on exit
        SaveLocation = "$env:HOME/.aitherzero/sessions"
        MaxSessions = 20  # Delete oldest when exceeded
        DefaultSession = ""  # Auto-load this session on startup
    }
    
    # NEW: Bookmarks
    Bookmarks = @{
        Enabled = $true
        SaveLocation = "$env:HOME/.aitherzero/bookmarks.json"
        Categories = @('General', 'Testing', 'Deployment', 'Infrastructure', 'Maintenance')
        TrackUsage = $true  # Track usage count and last used
        SortBy = 'UsageCount'  # or 'Name', 'LastUsed'
    }
    
    # NEW: Interactive Filtering
    InteractiveFiltering = @{
        Enabled = $true
        MinItemsForFilter = 10  # Show filter when list > 10 items
        CaseSensitive = $false
        HighlightMatches = $true
    }
}
```

---

## Module Integration

### Load Order in AitherZero.psm1
```powershell
# Add after existing experience modules
Import-Module (Join-Path $DomainsPath "experience/SessionManager.psm1") -Force
Import-Module (Join-Path $DomainsPath "experience/BookmarkManager.psm1") -Force
```

### Function Exports in AitherZero.psd1
```powershell
FunctionsToExport = @(
    # ... existing functions ...
    
    # Session Management
    'Save-AitherSession',
    'Restore-AitherSession',
    'Get-SavedSessions',
    'Remove-AitherSession',
    
    # Bookmarks
    'Add-AitherBookmark',
    'Get-AitherBookmarks',
    'Invoke-AitherBookmark',
    'Remove-AitherBookmark',
    'Update-AitherBookmark'
)
```

---

## Testing Strategy

### Unit Tests (Required for each feature)
```powershell
# SessionManager.Tests.ps1
Describe "Session Management" {
    Context "Save Session" {
        It "Should save session with valid name"
        It "Should include breadcrumb path"
        It "Should include command state"
        It "Should include timestamp"
    }
    
    Context "Restore Session" {
        It "Should restore saved session"
        It "Should fail gracefully on missing session"
        It "Should validate session structure"
    }
    
    Context "List Sessions" {
        It "Should list all sessions"
        It "Should show metadata"
        It "Should handle empty session directory"
    }
}
```

### Integration Tests
```powershell
# File: tests/integration/SessionManagement.Tests.ps1
Describe "Session Management Integration" {
    It "Should save and restore full workflow state" {
        # Save session in middle of workflow
        # Restore and verify state matches
    }
    
    It "Should work with UnifiedMenu" {
        # Test menu integration
    }
}
```

### Manual Testing Checklist
- [ ] Save session in interactive menu
- [ ] Restore session and verify breadcrumb path
- [ ] Auto-save on exit (if enabled)
- [ ] Bookmark a command from menu
- [ ] Execute bookmarked command
- [ ] Filter large script list by typing
- [ ] Clear filter with ESC
- [ ] Verify filter shows match count

---

## Documentation Updates

### New Documentation Files
1. **docs/SESSION-MANAGEMENT.md** (Session guide)
2. **docs/BOOKMARKS-GUIDE.md** (Bookmark usage)
3. **docs/INTERACTIVE-FILTERING.md** (Filter usage)

### Update Existing Documentation
1. **docs/UNIFIED-MENU-DESIGN.md** - Add session/bookmark sections
2. **.github/copilot-instructions.md** - Add QoL feature patterns
3. **README.md** - Add Phase 1 features to feature list
4. **DOCUMENTATION-INDEX.md** - Add new docs

### CLI Help Updates
```powershell
# Update Start-AitherZero.ps1 comment-based help
.PARAMETER Session
    Name of saved session to restore on startup

.PARAMETER SaveSession
    Save current session with given name

.PARAMETER ListSessions
    List all saved sessions with metadata

.PARAMETER Bookmark
    Execute a bookmarked command by name

.PARAMETER AddBookmark
    Add current command to bookmarks

.PARAMETER ListBookmarks
    List all bookmarked commands
```

---

## Validation Script

Create validation script to verify all features work:

```powershell
# File: automation-scripts/0966_Validate-QoLFeatures.ps1
<#
.SYNOPSIS
    Validates Phase 1 QoL features are working correctly
#>

param([switch]$Detailed)

$tests = @(
    @{
        Name = "Session Management"
        Tests = @(
            { Test-Path "$env:HOME/.aitherzero/sessions" }
            { Get-Command Save-AitherSession -ErrorAction SilentlyContinue }
            { Get-Command Restore-AitherSession -ErrorAction SilentlyContinue }
        )
    }
    @{
        Name = "Bookmarks"
        Tests = @(
            { Test-Path "$env:HOME/.aitherzero/bookmarks.json" -ErrorAction SilentlyContinue }
            { Get-Command Add-AitherBookmark -ErrorAction SilentlyContinue }
            { Get-Command Get-AitherBookmarks -ErrorAction SilentlyContinue }
        )
    }
    @{
        Name = "Interactive Filtering"
        Tests = @(
            { Get-Command Show-FilterableMenu -ErrorAction SilentlyContinue }
        )
    }
)

# Run tests and report results
foreach ($feature in $tests) {
    Write-Host "`nTesting: $($feature.Name)" -ForegroundColor Cyan
    $passed = 0
    $failed = 0
    
    foreach ($test in $feature.Tests) {
        try {
            if (& $test) {
                $passed++
                Write-Host "  ✓ Passed" -ForegroundColor Green
            } else {
                $failed++
                Write-Host "  ✗ Failed" -ForegroundColor Red
            }
        } catch {
            $failed++
            Write-Host "  ✗ Error: $_" -ForegroundColor Red
        }
    }
    
    Write-Host "  Result: $passed passed, $failed failed"
}
```

---

## Risk Mitigation

### Backwards Compatibility
- All features are **opt-in** via config.psd1
- Default to disabled for first release
- Gradual rollout via feature flags

### Rollback Plan
```powershell
# If issues arise:
1. Disable in config.psd1:
   Experience.Sessions.Enabled = $false
   Experience.Bookmarks.Enabled = $false

2. Revert module imports in AitherZero.psm1

3. Remove CLI parameters from Start-AitherZero.ps1
```

### Data Safety
- Session files are JSON (human-readable, easy to debug)
- Bookmarks have versioning in schema
- Auto-backup before updates

---

## Success Criteria

### Functional Requirements
- [ ] Sessions save in < 500ms
- [ ] Sessions restore in < 1s
- [ ] Bookmarks execute in < 100ms
- [ ] Filter updates in real-time (< 50ms)

### User Experience
- [ ] No breaking changes to existing workflows
- [ ] Intuitive UI for new features
- [ ] Clear error messages
- [ ] Comprehensive help documentation

### Quality
- [ ] 100% unit test coverage
- [ ] All integration tests pass
- [ ] PSScriptAnalyzer clean
- [ ] Documentation complete

---

## Timeline

### Week 1: Core Implementation
- **Day 1-2:** SessionManager module + tests
- **Day 3:** BookmarkManager module + tests  
- **Day 4-5:** Interactive filtering + tests

### Week 2: Integration & Polish
- **Day 1:** UnifiedMenu/CLI integration
- **Day 2:** Documentation
- **Day 3:** Validation script + testing
- **Day 4:** Code review + fixes
- **Day 5:** Final testing + release prep

---

## Next Steps

1. **Review and approve** this implementation plan
2. **Create GitHub issue** for Phase 1 implementation
3. **Assign developers** to features
4. **Set up project board** with tasks
5. **Begin implementation** following task order

---

**Status:** 📋 READY FOR APPROVAL  
**Est. Completion:** 5-8 days (1-2 weeks with testing/review)  
**Impact:** HIGH - Addresses top user pain points
