# AitherZero Playbooks

**Navigation**: [🏠 Root](../../index.md) → [orchestration](../index.md) → **playbooks**

⬆️ **Parent**: [orchestration](../index.md)

## 🎯 Quick Start

**New users**: Start with the [core playbooks](./core/README.md) - consolidated, well-documented playbooks organized by category.

**Existing users**: See [Migration Guide](./MIGRATION-GUIDE.md) for transitioning from legacy playbooks.

## 📖 Overview

This directory contains orchestration playbooks for the AitherZero automation platform. Playbooks define sequences of automation scripts (0000-9999) that work together to accomplish specific goals.

### 🚀 Recent Updates (2025-11-02)

**Major Consolidation Initiative**: Modernizing 42 playbooks into ~23 focused core playbooks.

- ✅ New `core/` directory with organized categories
- ✅ Standardized v2.0 schema with metadata
- ✅ Profile support for customization
- ✅ Comprehensive documentation (28KB)
- 🔄 Migration in progress (see docs below)

## 📚 Documentation

### Essential Reading

1. **[Core Playbooks README](./core/README.md)** - Start here for new playbooks
   - Complete usage guide with examples
   - Category overview and comparison tables
   - Profile explanations and troubleshooting

2. **[Migration Guide](./MIGRATION-GUIDE.md)** - Transition from legacy playbooks
   - Legacy → New playbook mappings
   - Step-by-step instructions
   - Breaking changes and rollback plan

3. **[Consolidation Plan](./CONSOLIDATION-PLAN.md)** - Strategic planning document
   - Category-by-category consolidation strategy
   - Final target structure (42 → 23)
   - Timeline and success metrics

4. **[Executive Summary](./EXECUTIVE-SUMMARY.md)** - High-level overview
   - Key findings and analysis results
   - Benefits and recommendations
   - Risk mitigation and next steps

## 📁 Directory Structure

### Core Playbooks (New - Recommended)

```
core/
├── testing/          # Fast, focused testing playbooks
├── git/              # Git workflow automation
├── devtools/         # Development tool installation
├── setup/            # Environment setup
├── infrastructure/   # Infrastructure automation
├── operations/       # CI/CD and deployment
├── analysis/         # Code analysis and reporting
└── ai/               # AI-powered workflows
```

**Status**: 7 of ~15 core playbooks created (see [core/README.md](./core/README.md))

### Legacy Categories (In Transition)

- [📂 **analysis**](./analysis/index.md) - 4 playbooks (moving to core/)
- [📂 **git**](./git/index.md) - 7 playbooks (consolidating to 3)
- [📂 **ops**](./ops/index.md) - 5 playbooks (consolidating to 3)
- [📂 **setup**](./setup/index.md) - 4 playbooks (moving to core/)
- [📂 **testing**](./testing/index.md) - 11 playbooks (consolidating to 5)
- [📂 **workflows**](./workflows/index.md) - 11 playbooks (reorganizing)

## 🎯 Quick Reference

### Most Used Playbooks

| Playbook | New Location | References | Purpose |
|----------|--------------|------------|---------|
| test-quick | core/testing/ | 14 | Fast development validation |
| test-full | core/testing/ | 11 | Complete validation + coverage |
| test-ci | core/testing/ | 7 | CI/CD optimized testing |
| tech-debt-analysis | core/analysis/ | 6 | Technical debt analysis |

### Common Tasks

```powershell
# Quick validation during development
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Pre-commit validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-standard

# Complete feature workflow
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook git-feature

# Install essential dev tools
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook devtools-minimal
```

## 📊 Statistics

- **Total Playbooks**: 42 (transitioning to ~23 core)
- **Schema Versions**: 
  - v1.0: 29 playbooks (69% - legacy)
  - v2.0: 13 playbooks (31% - modern + all new core)
- **All Playbooks Referenced**: 100% (no defunct playbooks found)
- **Documentation**: 4 major docs, 28KB total

## 🔄 Migration Status

### Phase 1: Core Infrastructure (✅ Complete)
- ✅ Analysis and planning
- ✅ Core directory structure
- ✅ 7 core playbooks created
- ✅ Comprehensive documentation

### Phase 2: Remaining Core Playbooks (🔄 In Progress)
- 🔄 8 more core playbooks needed
- 🔄 v2.0 conversions
- 🔄 Testing and validation

### Phase 3: Deprecation & Migration (📋 Planned)
- 📋 Add deprecation warnings
- 📋 Update all references
- 📋 Archive legacy playbooks

## 💡 Key Improvements

1. **Reduced Duplication**: 11 testing playbooks → 5 core playbooks
2. **Clear Organization**: Category-based directory structure
3. **Profile Support**: Customize playbook behavior without modification
4. **Enhanced Metadata**: Better discovery and documentation
5. **Consistent Schema**: All new playbooks use v2.0 format

## 🤝 Contributing

When creating or updating playbooks:

1. Use v2.0 schema (see [core/README.md](./core/README.md))
2. Add to appropriate category in `core/`
3. Include comprehensive metadata
4. Define profiles for different use cases
5. Add validation conditions
6. Document in category README

## 📞 Support

- 📖 **Documentation**: [Core Playbooks README](./core/README.md)
- 🗺️ **Migration**: [Migration Guide](./MIGRATION-GUIDE.md)
- 🐛 **Issues**: [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)

## 📄 Additional Files

- ⚙️ [tdd-development-cycle.json](./tdd-development-cycle.json) - TDD workflow
- 📝 [CONSOLIDATION-PLAN.md](./CONSOLIDATION-PLAN.md) - Strategic plan
- 📝 [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md) - Migration instructions
- 📝 [EXECUTIVE-SUMMARY.md](./EXECUTIVE-SUMMARY.md) - High-level overview

---

*Last updated: 2025-11-02* • **Status**: Active modernization in progress
