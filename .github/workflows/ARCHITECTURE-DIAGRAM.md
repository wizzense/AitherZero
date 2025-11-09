# Workflow Architecture Diagram

## Master Orchestrator Flow

```mermaid
graph TD
    A[Event Trigger] --> B{Master Orchestrator}
    B -->|Analyze Context| C[Context Detection]
    B -->|Detect Changes| D[File Change Detection]
    
    C --> E{Event Type?}
    E -->|Pull Request| F[PR Complete Workflow]
    E -->|Release Tag v*| G[Release Automation]
    E -->|Push main/dev| H[Standalone Jobs]
    E -->|Manual Dispatch| I[User Selection]
    
    D --> J{Files Changed?}
    J -->|PowerShell| K[Enable Tests + Build]
    J -->|Docker| L[Enable Docker Build]
    J -->|Workflows| M[Enable All]
    J -->|Docs| N[Enable Docs]
    J -->|Tests| O[Enable Test Suite]
    
    F --> P[Dashboard + Report]
    G --> Q[Release Artifacts]
    H --> R[CI Validation]
    I --> S[Selected Workflow]
    
    P --> T[Final Summary]
    Q --> T
    R --> T
    S --> T
```

## PR Complete Workflow (Enhanced with Docker)

```mermaid
graph TB
    Start[PR Event] --> Phase1[Phase 1: Quick Validation]
    
    Phase1 --> P1A[Syntax Check]
    Phase1 --> P1B[Config Validation]
    Phase1 --> P1C[Manifest Check]
    
    P1A --> Phase2[Phase 2: Test Matrix Prep]
    P1B --> Phase2
    P1C --> Phase2
    
    Phase2 --> Matrix{Test Matrix}
    
    Matrix -->|Parallel| Unit[Unit Tests<br/>9 ranges]
    Matrix -->|Parallel| Domain[Domain Tests<br/>6 modules]
    Matrix -->|Parallel| Integration[Integration Tests<br/>4 suites]
    
    Unit --> Summary[Test Summary]
    Domain --> Summary
    Integration --> Summary
    
    Summary --> Phase3[Phase 3: Build & Package]
    
    Phase3 --> Build1[Syntax Validation]
    Build1 --> Build2[Generate Metadata]
    Build2 --> Build3[Create Packages]
    Build3 --> Build4[Self-Deployment Test]
    
    Build4 --> Docker[Phase 3B: Docker Build]
    Summary --> Quality[Phase 4: Quality Analysis]
    
    Docker --> D1[Setup Buildx]
    D1 --> D2[Login to GHCR]
    D2 --> D3[Build Multi-Platform]
    D3 --> D4[Tag as pr-NUMBER]
    D4 --> D5[Test Container]
    
    Build4 --> Dashboard[Phase 5: Dashboard]
    D5 --> Dashboard
    Quality --> Dashboard
    
    Dashboard --> Dash1[Generate Changelog]
    Dash1 --> Dash2[Create Recommendations]
    Dash2 --> Dash3[Build Dashboard]
    Dash3 --> Dash4[Generate Reports]
    Dash4 --> Dash5[Create PR Comment]
    Dash5 --> Dash6[Deploy to GitHub Pages]
    
    Dash6 --> End[PR Complete]
```

## Release Workflow

```mermaid
graph LR
    A[Release Tag v*] --> B[Pre-Release Validation]
    B --> C[Syntax + Module + Tests]
    
    C --> D{Validation Pass?}
    D -->|No| E[Fail Release]
    D -->|Yes| F[Create Release]
    
    F --> G[Build Packages]
    F --> H[Build MCP Server]
    F --> I[Build Docker Image]
    
    G --> G1[ZIP Package]
    G --> G2[TAR.GZ Package]
    G --> G3[Build Metadata]
    
    H --> H1[npm install]
    H --> H2[npm build]
    H --> H3[npm test]
    H --> H4[npm pack]
    H --> H5[Publish to GitHub Packages]
    
    I --> I1[Multi-Platform Build]
    I --> I2[Tag: vX.Y.Z, latest, stable]
    I --> I3[Push to GHCR]
    I --> I4[Test Image]
    
    G3 --> J[Generate Release Notes]
    H5 --> J
    I4 --> J
    
    J --> K[Create GitHub Release]
    K --> L[Upload Assets]
    L --> M[Update Latest Tag]
    M --> N[Post-Release Summary]
```

## Playbook Execution Flow

```mermaid
graph TD
    A[Playbook Invocation] --> B[Load Playbook Definition]
    B --> C[pr-ecosystem-build.psd1]
    B --> D[pr-ecosystem-report.psd1]
    B --> E[pr-ecosystem-analyze.psd1]
    
    C --> C1[Validate Scripts Exist]
    C1 --> C2{Parallel Allowed?}
    C2 -->|Yes| C3[Parallel Execution]
    C2 -->|No| C4[Sequential Execution]
    
    C3 --> C5[0407: Syntax]
    C3 --> C6[0902: Package]
    C4 --> C7[0515: Metadata]
    C4 --> C8[0900: Self-Deploy]
    
    C5 --> C9[Collect Artifacts]
    C6 --> C9
    C7 --> C9
    C8 --> C9
    
    D --> D1[Load PR Context]
    D1 --> D2[Sequential Scripts]
    D2 --> D3[0513: Changelog]
    D3 --> D4[0518: Recommendations]
    D4 --> D5[0512: Dashboard]
    D5 --> D6[0519: PR Comment]
    
    E --> E1[Parallel Analysis]
    E1 --> E2[Tests]
    E1 --> E3[Quality]
    E1 --> E4[Security]
    E1 --> E5[Docs]
    
    E2 --> E6[Aggregate Results]
    E3 --> E6
    E4 --> E6
    E5 --> E6
    
    C9 --> Summary[Orchestration Summary]
    D6 --> Summary
    E6 --> Summary
```

## Docker Build Pipeline

```mermaid
graph LR
    A[Docker Build Request] --> B{Build Type?}
    
    B -->|PR| C[PR Docker Build]
    B -->|Release| D[Release Docker Build]
    B -->|Dev Push| E[Dev Docker Build]
    
    C --> C1[Tag: pr-NUMBER]
    C --> C2[Tag: pr-NUMBER-SHA]
    C --> C3[Platform: amd64, arm64]
    C --> C4[Push to GHCR]
    C4 --> C5[Test Container]
    
    D --> D1[Tag: vX.Y.Z]
    D --> D2[Tag: X.Y, X]
    D --> D3[Tag: latest, stable]
    D --> D4[Tag: sha-XXXXXX]
    D --> D5[Platform: amd64, arm64]
    D5 --> D6[Push to GHCR]
    D6 --> D7[Test Container]
    D7 --> D8[Add to Release]
    
    E --> E1[Tag: dev]
    E --> E2[Tag: branch-name]
    E --> E3[Platform: amd64, arm64]
    E3 --> E4[Push to GHCR]
    E4 --> E5[Test Container]
    
    C5 --> Summary[Build Summary]
    D8 --> Summary
    E5 --> Summary
```

## File Change Detection Logic

```mermaid
graph TD
    A[Git Diff] --> B[Changed Files]
    
    B --> C{PowerShell Files?}
    C -->|Yes| C1[Enable Tests]
    C1 --> C2[Enable Build]
    
    B --> D{Docker Files?}
    D -->|Yes| D1[Enable Docker Build]
    
    B --> E{Workflow Files?}
    E -->|Yes| E1[Enable All Tests]
    E1 --> E2[Safety: Full Validation]
    
    B --> F{Doc Files?}
    F -->|Yes| F1[Enable Docs Generation]
    
    B --> G{Test Files?}
    G -->|Yes| G1[Enable Test Suite]
    
    C2 --> Decision[Orchestration Decision]
    D1 --> Decision
    E2 --> Decision
    F1 --> Decision
    G1 --> Decision
    
    Decision --> H[Execute Selected Workflows]
```

## Artifact Flow

```mermaid
graph TB
    A[Build Phase] --> B[Create Artifacts]
    
    B --> B1[Packages]
    B --> B2[Metadata]
    B --> B3[Docker Images]
    
    B1 --> B1a[ZIP: Runtime Files]
    B1 --> B1b[TAR.GZ: Runtime Files]
    
    B2 --> B2a[build-metadata.json]
    B2 --> B2b[build-summary.json]
    
    B3 --> B3a[GHCR: pr-NUMBER]
    B3 --> B3b[Multi-Platform Image]
    
    B1a --> C[Upload to Artifacts]
    B1b --> C
    B2a --> C
    B2b --> C
    B3a --> D[Push to Registry]
    B3b --> D
    
    C --> E[Available in Workflow]
    D --> F[Available Externally]
    
    E --> G[Test Phase Uses]
    E --> H[Report Phase Uses]
    E --> I[Dashboard Uses]
    
    F --> J[Docker Pull]
    F --> K[Release Assets]
```

## Legend

### Shapes
- **Rectangle:** Process/Job
- **Diamond:** Decision Point
- **Parallelogram:** Input/Output
- **Circle:** Start/End

### Colors (in actual Mermaid rendering)
- **Blue:** Primary workflow steps
- **Green:** Success paths
- **Orange:** Parallel execution
- **Red:** Error/Failure paths

---

**Note:** These diagrams use Mermaid syntax and will render properly in:
- GitHub (automatically)
- VS Code (with Mermaid extension)
- Most modern markdown viewers

To view these diagrams:
1. Open this file in GitHub (renders automatically)
2. Use VS Code with Mermaid Preview extension
3. Use online tools like https://mermaid.live
