# Building-Block Reorganization Plan

**Date**: 2025-11-04  
**Status**: Proposed  
**Impact**: Documentation update, no script renumbering required

## Current Issue

The Git automation blocks (0700-0799 range) are separated from development tools (0200-0299), creating an artificial distinction. Git is fundamentally a development tool and should be categorized with other development tools for better discoverability and logical organization.

## Proposed Reorganization

### New Categorization Schema

Instead of renumbering existing scripts (which would break existing playbooks), we'll **update documentation** to reflect a more logical conceptual grouping:

#### 0200-0299: Development Tools & Workflows

This range now encompasses **all** development-related automation:

**0200-0219: Core Development Tools**
- Tool installation (Git, Node, Python, Docker, VS Code, etc.)
- Package managers and utilities
- Development environment configuration

**0220-0249: [Reserved for Future Tool Installation]**

**0250-0259: Git Workflow Automation** (Logical grouping of 0700-0709)
- Branch management
- Commit operations
- Pull request creation
- Git environment setup

**0260-0279: GitHub/CI Integration** (Logical grouping of 0720-0729)
- GitHub runners setup
- CI/CD environment configuration
- Matrix runner management

**0280-0299: AI-Powered Development** (Logical grouping of 0730-0749)
- AI code review and generation
- AI-assisted testing and documentation
- Copilot integration
- AI workflow optimization

#### 0700-0799: Advanced Infrastructure & Automation

This range is repurposed for **advanced infrastructure automation**:

**0750-0759: MCP Servers & Protocol Tools**
- Model Context Protocol server management
- AI infrastructure integration
- Advanced tooling protocols

**0760-0799: [Reserved for Advanced Infrastructure]**
- Container orchestration
- Service mesh configuration
- Advanced networking
- Infrastructure as Code (advanced)

## Implementation Strategy

### Phase 1: Documentation Update (Immediate)
✅ Update `docs/BUILDING-BLOCKS.md` with new logical grouping  
✅ Create cross-reference mapping in documentation  
✅ Update playbook templates with new categorization  
✅ Add "Logical Location" metadata to script headers  

### Phase 2: Metadata Enhancement (Next Sprint)
- Add `LogicalCategory` field to script metadata
- Scripts remain in current numbers (0700s) but document logical grouping
- Example:
  ```powershell
  # Stage: Development
  # LogicalCategory: Git Workflow (0250-0259 equivalent)
  # PhysicalLocation: 0701
  # Description: Create feature branch
  ```

### Phase 3: Search & Discovery (Future)
- Update orchestration engine to understand logical categories
- Support both physical and logical references:
  - `0701` (physical) → Works as-is
  - `logical:git-workflow` → Maps to 0700-0709 scripts
  - `category:development` → Includes 0200-0299 AND 0700-0759

### Phase 4: Migration Path (Optional, Long-term)
If script renumbering becomes necessary:
1. Create new numbered scripts in target range
2. Keep old scripts as aliases/redirects
3. Update all playbooks to use new numbers
4. Deprecation period (6 months)
5. Remove old numbered scripts

## Updated Building-Block Reference

### 🛠️ Development Tools & Workflows (0200-0299)

#### Core Tools (0200-0219)
| Block | Tool | Type | Platform |
|-------|------|------|----------|
| 0201 | Node.js | Runtime | Cross-platform |
| 0204 | Poetry | Python Package Manager | Cross-platform |
| 0205 | Sysinternals | Windows Utilities | Windows |
| 0206 | Python | Runtime | Cross-platform |
| 0207 | Git | VCS | Cross-platform |
| 0208 | Docker | Container | Cross-platform |
| 0209 | 7-Zip | Archive Tool | Cross-platform |
| 0210 | VS Code | IDE | Cross-platform |
| 0211 | VS Build Tools | Build System | Windows |
| 0212 | Azure CLI | Cloud CLI | Cross-platform |
| 0213 | AWS CLI | Cloud CLI | Cross-platform |
| 0214 | Packer | Image Builder | Cross-platform |
| 0215 | MCP Servers Config | AI Tools | Cross-platform |
| 0216 | PowerShell Profile | Shell Config | Cross-platform |
| 0217 | Claude Code | AI Assistant | Cross-platform |
| 0218 | Gemini CLI | AI Assistant | Cross-platform |
| 0219 | Chocolatey | Package Manager | Windows |

#### Git Workflows (0700-0709) *Logically 0250-0259*
| Block | Operation | Type | Dependencies |
|-------|-----------|------|--------------|
| 0700 | Setup Git Environment | Configuration | Git |
| 0701 | Create Feature Branch | Branch Management | Git |
| 0702 | Create Commit | Commit Operation | Git |
| 0703 | Create Pull Request | PR Management | Git, GitHub |
| 0704 | Stage Files | File Management | Git |
| 0705 | Push Branch | Remote Operation | Git |
| 0709 | Post PR Comment | PR Interaction | Git, GitHub |

#### GitHub/CI Integration (0720-0729) *Logically 0260-0279*
| Block | Operation | Type | Platform |
|-------|-----------|------|----------|
| 0720 | Setup GitHub Runners | CI Infrastructure | Cross-platform |
| 0721 | Configure Runner Environment | CI Configuration | Cross-platform |
| 0722 | Install Runner Services | CI Services | Cross-platform |
| 0723 | Setup Matrix Runners | CI Scaling | Cross-platform |

#### AI-Powered Development (0730-0749) *Logically 0280-0299*
| Block | Operation | Type | Dependencies |
|-------|-----------|------|--------------|
| 0730 | Setup AI Agents | AI Infrastructure | MCP |
| 0731 | AI Code Review | Code Analysis | AI Provider |
| 0732 | Generate AI Tests | Test Generation | AI Provider |
| 0733 | Create AI Docs | Documentation | AI Provider |
| 0734 | Optimize AI Performance | Performance | AI Provider |
| 0735 | Analyze AI Security | Security Scan | AI Provider |
| 0736 | Generate AI Workflow | Workflow Gen | AI Provider |
| 0737 | Monitor AI Usage | Monitoring | AI Provider |
| 0738 | Train AI Context | Context Building | AI Provider |
| 0739 | Validate AI Output | Validation | AI Provider |
| 0740 | Integrate AI Tools | Integration | AI Provider |
| 0741 | Generate AI Commit Message | Git Helper | AI Provider |
| 0742 | Create AI-Powered PR | PR Automation | AI Provider |
| 0743 | Enable Automated Copilot | Copilot Config | GitHub Copilot |
| 0744 | Generate Auto Documentation | Docs Gen | AI Provider |
| 0745 | Generate Project Indexes | Index Gen | AI Provider |
| 0746 | Generate All Documentation | Docs Suite | AI Provider |

### 🔧 Advanced Infrastructure (0750-0799)

#### MCP Servers & Protocol Tools (0750-0759)
| Block | Operation | Type | Platform |
|-------|-----------|------|----------|
| 0750 | Build MCP Server | Build | Node.js |
| 0751 | Start MCP Server | Service | Node.js |
| 0752 | Demo MCP Server | Testing | Node.js |
| 0753 | Use MCP Server | Integration | Node.js |
| 0754 | Create MCP Server | Scaffolding | Node.js |

#### Git Utilities (0798-0799)
| Block | Operation | Type | Dependencies |
|-------|-----------|------|--------------|
| 0798 | Generate Changelog | Documentation | Git |
| 0799 | Cleanup Old Tags | Maintenance | Git |

## Benefits of This Approach

### 1. **No Breaking Changes**
- Existing playbooks continue to work
- Script numbers remain unchanged
- Zero migration effort required

### 2. **Better Logical Organization**
- Development tools are conceptually grouped together
- Clear separation between basic tools and advanced infrastructure
- AI tools are properly categorized as development tools

### 3. **Improved Discoverability**
- Users looking for "development tools" find Git workflows naturally
- Logical categories make sense conceptually
- Documentation reflects how developers think about tools

### 4. **Future-Proof**
- Can support both physical and logical addressing
- Enables flexible reorganization without breaking changes
- Supports evolving categorization schemes

### 5. **Search & Filter Enhancement**
```powershell
# Find all development-related scripts
Get-AitherScripts -Category "Development"  # Returns 0200-0299 + 0700-0759

# Find just Git workflow scripts
Get-AitherScripts -LogicalCategory "Git Workflow"  # Returns 0700-0709

# Find AI development tools
Get-AitherScripts -LogicalCategory "AI Development"  # Returns 0730-0749
```

## Documentation Updates Required

### Files to Update
1. ✅ `docs/BUILDING-BLOCKS.md` - Primary reference
2. ✅ `orchestration/playbooks/templates/custom-playbook-template.json` - Template comments
3. ⬜ `README.md` - Quick reference section
4. ⬜ `orchestration/README.md` - Orchestration guide
5. ⬜ `.github/copilot-instructions.md` - AI agent instructions
6. ⬜ Individual script headers - Add LogicalCategory metadata

### Playbook Updates
Update example playbooks to reference logical categories:
```json
{
  "stages": [
    {
      "name": "Development Setup",
      "description": "Install development tools including Git workflows",
      "sequences": [
        "0207",  // Git installation
        "0701",  // Git workflow: Create branch (logically 0250)
        "0702"   // Git workflow: Commit (logically 0251)
      ]
    }
  ]
}
```

## Migration Examples

### Old Documentation (Confusing)
```
Git Automation (0700-0799)
- 0701: Create branch
- 0702: Commit
- 0703: Create PR

Development Tools (0200-0299)
- 0207: Install Git
```

### New Documentation (Clear)
```
Development Tools & Workflows (0200-0299)

Core Tools (0200-0219)
- 0207: Install Git

Git Workflows (0250-0259 logical, 0700-0709 physical)
- 0701: Create branch
- 0702: Commit  
- 0703: Create PR

AI Development (0280-0299 logical, 0730-0749 physical)
- 0731: AI code review
- 0732: Generate AI tests
```

## Rollout Timeline

**Week 1**: Documentation updates (this PR)  
**Week 2**: Gather feedback from users  
**Week 3**: Update playbook templates and examples  
**Week 4**: Add LogicalCategory metadata to scripts  
**Month 2**: Enhance orchestration engine with logical addressing  
**Month 3+**: Consider script renumbering if needed

## Open Questions

1. Should we create aliases? (e.g., `0250` → `0701`)
2. Do we need a migration tool for existing custom playbooks?
3. Should logical categories be enforced or advisory?
4. Do we want to support range queries like `0250-0259` even though scripts are in 0700s?

## Conclusion

This reorganization provides **immediate value** through better documentation while preserving **backward compatibility**. It sets the foundation for future enhancements like logical addressing and flexible categorization without forcing disruptive changes on existing users.

The approach respects the existing numbering system while acknowledging that it could be more intuitive. By treating script numbers as physical addresses and introducing logical categories, we get the best of both worlds: stability and clarity.
