# Sheet Music to MIDI Conversion - Detailed Implementation Plan

## Executive Summary

This document provides a comprehensive technical plan for implementing an automation script that uses Ollama's vision recognition models to parse guitar sheet music images and convert them to MIDI files. The feature will be integrated into the AitherZero infrastructure automation platform following its established patterns and conventions.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Technical Architecture](#technical-architecture)
3. [Implementation Phases](#implementation-phases)
4. [Script Specifications](#script-specifications)
5. [Configuration Design](#configuration-design)
6. [Testing Strategy](#testing-strategy)
7. [Documentation Requirements](#documentation-requirements)
8. [Risk Assessment](#risk-assessment)

## Project Overview

### Objective

Create a fully automated pipeline that:
- Accepts guitar sheet music images as input
- Uses Ollama vision models to recognize musical notation
- Parses recognized notation into structured data
- Generates MIDI files from the structured music data
- Supports batch processing and validation

### Scope

**In Scope:**
- Installation and configuration of Ollama runtime
- Integration with Ollama vision models (llava, bakllava)
- Image preprocessing and optimization
- Music notation recognition via vision models
- MIDI file generation from recognized notation
- Batch processing capabilities
- Cross-platform support (Windows, Linux, macOS)
- Integration with AitherZero orchestration system

**Out of Scope (Future Enhancements):**
- Real-time audio playback
- Advanced music theory validation
- Handwritten music recognition
- Multiple instrument support beyond guitar
- Cloud-based processing
- Web interface

### Success Metrics

- Successfully converts standard guitar sheet music to MIDI
- Accuracy rate of 80%+ for simple melodies
- Process time < 30 seconds per page
- Works on all supported platforms
- Zero-configuration setup through AitherZero
- Comprehensive error handling and logging

## Technical Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     User Input                               │
│              (Sheet Music Image Files)                       │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│              Image Preprocessor                              │
│  • Resize/normalize                                          │
│  • Enhance contrast                                          │
│  • Remove noise                                              │
│  • Format validation                                         │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│            Ollama Vision Model                               │
│  • Model: llava/bakllava                                     │
│  • Prompt: "Extract musical notation..."                    │
│  • Output: Structured text description                      │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│           Music Notation Parser                              │
│  • Parse notes, duration, timing                             │
│  • Identify key signature, time signature                    │
│  • Build measure structure                                   │
│  • Validate music theory                                     │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│              MIDI Generator                                  │
│  • Convert to MIDI events                                    │
│  • Set tempo and instrument                                  │
│  • Generate tracks                                           │
│  • Write MIDI file                                           │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│            Output Validator                                  │
│  • Verify MIDI file integrity                                │
│  • Check note ranges                                         │
│  • Validate timing                                           │
│  • Generate quality report                                   │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                 MIDI File Output                             │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

**Primary Technologies:**
- **PowerShell 7.0+**: Main scripting language
- **Ollama**: Vision model runtime
- **Python 3.12+**: Music processing libraries
  - `music21`: Music theory and notation
  - `mido`: MIDI file handling
  - `Pillow`: Image processing
  - `numpy`: Numerical operations

**Supporting Technologies:**
- **AitherZero Modules**: Logging, configuration, UI
- **PackageManager**: Cross-platform installation
- **Git**: Version control

### Data Flow

1. **Input Stage**
   - User provides image file(s) via CLI or interactive menu
   - System validates file format (PNG, JPG, PDF)
   - Images stored in temporary processing directory

2. **Preprocessing Stage**
   - Images resized to optimal dimensions (e.g., 2048px width)
   - Contrast enhancement for better OCR
   - Noise reduction
   - Binarization if needed

3. **Recognition Stage**
   - Image sent to Ollama API with custom prompt
   - Prompt engineered to extract:
     - Note names (C, D, E, F, G, A, B with accidentals)
     - Note durations (whole, half, quarter, eighth, etc.)
     - Time signature (4/4, 3/4, etc.)
     - Key signature
     - Tempo markings

4. **Parsing Stage**
   - Model output (text) parsed into structured data
   - JSON format for intermediate representation:
   ```json
   {
     "timeSignature": "4/4",
     "keySignature": "C major",
     "tempo": 120,
     "measures": [
       {
         "number": 1,
         "notes": [
           {"pitch": "C4", "duration": "quarter", "offset": 0.0},
           {"pitch": "D4", "duration": "quarter", "offset": 1.0}
         ]
       }
     ]
   }
   ```

5. **Generation Stage**
   - Python script processes JSON to MIDI
   - Creates MIDI track with appropriate instrument (Guitar: program 24-31)
   - Sets tempo and time signature
   - Adds notes with proper timing

6. **Validation Stage**
   - MIDI file opened and validated
   - Checks for:
     - Valid note ranges
     - Proper timing
     - Correct instrument assignment
   - Quality score calculated

7. **Output Stage**
   - MIDI file saved to configured output directory
   - Summary report generated
   - Logs written

## Implementation Phases

### Phase 1: Research & Architecture (2-3 days)

**Objectives:**
- Validate Ollama capabilities for music OCR
- Test vision models with sample sheet music
- Prototype music notation parsing
- Finalize technical specifications

**Tasks:**
1. Set up local Ollama instance
2. Test llava and bakllava models with sample images
3. Experiment with prompt engineering
4. Research music21 and mido capabilities
5. Create proof-of-concept script
6. Document findings and recommendations

**Deliverables:**
- Research report with model performance data
- Prototype script demonstrating feasibility
- Updated technical specifications
- Risk assessment

### Phase 2: Prerequisites & Dependencies (1-2 days)

**Objectives:**
- Create Ollama installation script
- Set up Python environment
- Configure dependencies

**Tasks:**
1. Create `0219_Install-Ollama.ps1`
   - Detect platform (Windows/Linux/macOS)
   - Download and install Ollama
   - Pull required vision models
   - Verify installation
   - Configure for local API access

2. Update Python installation script (`0206`)
   - Add music processing libraries
   - Create virtual environment for music tools
   - Install dependencies via pip/poetry

3. Update configuration manifest
   - Add Ollama feature flags
   - Add music processing configuration
   - Define default models and parameters

**Deliverables:**
- `0219_Install-Ollama.ps1` (complete and tested)
- Updated `config.psd1`
- Dependency documentation

### Phase 3: Core Processing Script (3-4 days)

**Objectives:**
- Implement main conversion script
- Build all pipeline stages
- Integrate with AitherZero

**Tasks:**
1. Create `0220_Convert-SheetMusicToMIDI.ps1`
   - Parameter definitions
   - Configuration loading
   - Module imports
   - Main orchestration logic

2. Implement image preprocessing
   - Format validation
   - Resize and normalize
   - Enhancement filters
   - Temporary file management

3. Build Ollama integration
   - API client functions
   - Request/response handling
   - Error handling and retries
   - Model selection logic

4. Create music parser
   - Text-to-data conversion
   - Music theory validation
   - JSON intermediate format

5. Develop MIDI generator (Python)
   - JSON to MIDI conversion
   - Instrument configuration
   - Track management
   - File output

6. Implement batch processing
   - Multi-file support
   - Progress tracking
   - Parallel processing option

**Deliverables:**
- `0220_Convert-SheetMusicToMIDI.ps1` (complete)
- Python helper script for MIDI generation
- Integration with AitherZero logging and UI

### Phase 4: Supporting Infrastructure (2 days)

**Objectives:**
- Add validation and quality checks
- Implement robust error handling
- Create helper utilities

**Tasks:**
1. Build output validator
   - MIDI integrity checks
   - Note range validation
   - Timing verification
   - Quality scoring

2. Enhance error handling
   - Comprehensive try-catch blocks
   - Detailed error messages
   - Recovery strategies
   - Logging integration

3. Create helper functions
   - Image format conversion
   - Model performance testing
   - Configuration validation
   - Cleanup utilities

4. Add progress indicators
   - Progress bars for long operations
   - Status messages
   - Time estimates

**Deliverables:**
- Validation functions
- Error handling framework
- Helper utility library
- Progress tracking UI

### Phase 5: Testing & Documentation (2-3 days)

**Objectives:**
- Comprehensive testing suite
- User and developer documentation
- Performance optimization

**Tasks:**
1. Create unit tests
   - Test image preprocessing
   - Test parser functions
   - Test MIDI generation
   - Test validation logic

2. Create integration tests
   - End-to-end conversion
   - Batch processing
   - Error scenarios
   - Platform-specific tests

3. Build test data set
   - Simple melodies
   - Complex pieces
   - Edge cases
   - Invalid inputs

4. Write documentation
   - User guide
   - API documentation
   - Troubleshooting guide
   - Examples and tutorials

5. Performance testing
   - Benchmark conversion times
   - Memory usage analysis
   - Optimization opportunities

**Deliverables:**
- Test suite (Pester tests)
- Test data repository
- User documentation
- Performance report

### Phase 6: Integration & Polish (1-2 days)

**Objectives:**
- Final integration with AitherZero
- UI polish
- Documentation updates

**Tasks:**
1. Update configuration system
   - Final config.psd1 updates
   - Environment variable support
   - Default settings optimization

2. Add to orchestration
   - Create playbook entries
   - Define dependencies
   - Set execution profiles

3. UI enhancements
   - Interactive menu integration
   - Progress visualization
   - Results display

4. Documentation finalization
   - Update main README
   - Add to feature index
   - Create quick start guide

5. Final testing
   - End-to-end scenarios
   - Cross-platform verification
   - User acceptance testing

**Deliverables:**
- Fully integrated feature
- Complete documentation
- Release notes
- Training materials

## Script Specifications

### 0219_Install-Ollama.ps1

**Purpose:** Install and configure Ollama runtime with vision models

**Parameters:**
```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration,
    
    [Parameter()]
    [string[]]$Models = @('llava', 'bakllava'),
    
    [Parameter()]
    [switch]$SkipModelPull,
    
    [Parameter()]
    [switch]$Force
)
```

**Key Functions:**
- `Test-OllamaInstalled`: Check if Ollama is installed
- `Install-OllamaRuntime`: Install Ollama for current platform
- `Pull-OllamaModel`: Download vision models
- `Test-OllamaAPI`: Verify API is accessible
- `Get-OllamaVersion`: Get installed version

**Exit Codes:**
- 0: Success
- 1: Installation failed
- 2: Model pull failed
- 3: API test failed

### 0220_Convert-SheetMusicToMIDI.ps1

**Purpose:** Convert sheet music images to MIDI files

**Parameters:**
```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string[]]$InputImage,
    
    [Parameter()]
    [string]$OutputPath = './output/midi',
    
    [Parameter()]
    [ValidateSet('llava', 'bakllava', 'auto')]
    [string]$Model = 'auto',
    
    [Parameter()]
    [int]$Tempo = 120,
    
    [Parameter()]
    [ValidateSet('Guitar', 'AcousticGuitar', 'ElectricGuitar')]
    [string]$Instrument = 'AcousticGuitar',
    
    [Parameter()]
    [switch]$Batch,
    
    [Parameter()]
    [switch]$Validate,
    
    [Parameter()]
    [hashtable]$Configuration
)
```

**Key Functions:**
- `Initialize-ConversionEnvironment`: Set up directories and dependencies
- `Test-Prerequisites`: Verify Ollama and Python are available
- `Optimize-SheetMusicImage`: Preprocess image for OCR
- `Invoke-OllamaVisionRecognition`: Call Ollama API
- `ConvertTo-MusicData`: Parse model output to structured data
- `ConvertTo-MIDI`: Generate MIDI file from music data
- `Test-MIDIFile`: Validate output quality
- `Write-ConversionReport`: Generate summary report

**Processing Pipeline:**
1. Validate prerequisites
2. Load configuration
3. Process each input image:
   - Preprocess image
   - Call Ollama vision model
   - Parse response
   - Generate MIDI
   - Validate output
4. Generate report
5. Cleanup temporary files

**Exit Codes:**
- 0: Success
- 1: General error
- 2: Prerequisites not met
- 3: Image processing failed
- 4: Vision model error
- 5: MIDI generation failed
- 6: Validation failed

## Configuration Design

### config.psd1 Updates

```powershell
Features = @{
    Development = @{
        # Existing features...
        
        # Ollama AI Runtime
        Ollama = @{
            Enabled = $false
            InstallScript = '0219'
            Platforms = @('Windows', 'Linux', 'macOS')
            Configuration = @{
                APIUrl = 'http://localhost:11434'
                DefaultModels = @('llava', 'bakllava')
                ModelPath = ''  # Use system default
                Timeout = 300  # API timeout in seconds
                MaxRetries = 3
            }
            Installer = @{
                Windows = 'https://ollama.ai/download/windows'
                Linux = 'package-manager'
                macOS = 'https://ollama.ai/download/mac'
            }
        }
        
        # Music Processing Tools
        MusicProcessing = @{
            Enabled = $false
            InstallScript = '0220'
            Platforms = @('Windows', 'Linux', 'macOS')
            RequiresPython = $true
            Configuration = @{
                # Input settings
                SupportedFormats = @('png', 'jpg', 'jpeg', 'pdf')
                MaxImageSize = '10MB'
                
                # Processing settings
                DefaultModel = 'llava'
                FallbackModel = 'bakllava'
                PreprocessImages = $true
                ImageDPI = 300
                
                # Output settings
                OutputPath = './output/midi'
                DefaultTempo = 120
                DefaultInstrument = 'AcousticGuitar'
                InstrumentMap = @{
                    'AcousticGuitar' = 24
                    'ElectricGuitar' = 27
                    'Guitar' = 24
                }
                
                # Quality settings
                ValidateOutput = $true
                MinimumConfidence = 0.7
                GenerateReport = $true
                
                # Performance
                BatchProcessing = $true
                MaxParallel = 4
                CleanupTemp = $true
            }
            Dependencies = @{
                Python = @('music21', 'mido', 'pillow', 'numpy')
            }
        }
    }
}
```

## Testing Strategy

### Unit Tests

**File:** `tests/automation-scripts/0219_Install-Ollama.Tests.ps1`

```powershell
Describe "0219_Install-Ollama" {
    Context "Platform Detection" {
        It "Detects Windows platform" { }
        It "Detects Linux platform" { }
        It "Detects macOS platform" { }
    }
    
    Context "Installation Validation" {
        It "Checks if Ollama is already installed" { }
        It "Downloads installer for platform" { }
        It "Installs Ollama successfully" { }
    }
    
    Context "Model Management" {
        It "Pulls specified models" { }
        It "Verifies model availability" { }
        It "Handles model pull failures" { }
    }
    
    Context "API Validation" {
        It "Tests API connectivity" { }
        It "Verifies model loading" { }
    }
}
```

**File:** `tests/automation-scripts/0220_Convert-SheetMusicToMIDI.Tests.ps1`

```powershell
Describe "0220_Convert-SheetMusicToMIDI" {
    Context "Prerequisites" {
        It "Checks Ollama installation" { }
        It "Checks Python dependencies" { }
        It "Validates configuration" { }
    }
    
    Context "Image Processing" {
        It "Validates image format" { }
        It "Preprocesses image correctly" { }
        It "Handles invalid images" { }
    }
    
    Context "Vision Recognition" {
        It "Calls Ollama API successfully" { }
        It "Handles API errors" { }
        It "Parses model response" { }
    }
    
    Context "MIDI Generation" {
        It "Converts parsed data to MIDI" { }
        It "Sets correct tempo" { }
        It "Sets correct instrument" { }
        It "Validates output file" { }
    }
    
    Context "Batch Processing" {
        It "Processes multiple files" { }
        It "Handles mixed success/failure" { }
    }
}
```

### Integration Tests

**Test Scenarios:**

1. **Simple Melody Conversion**
   - Input: Single-line melody (C major scale)
   - Expected: Valid MIDI with correct notes in sequence

2. **Complex Piece Conversion**
   - Input: Multi-measure piece with accidentals
   - Expected: MIDI with proper timing and key signature

3. **Batch Processing**
   - Input: Directory with 5 sheet music images
   - Expected: 5 corresponding MIDI files

4. **Error Handling**
   - Input: Invalid image (not sheet music)
   - Expected: Graceful error with helpful message

5. **Cross-Platform**
   - Run all tests on Windows, Linux, macOS
   - Expected: Consistent results

### Test Data

Create `tests/test-data/sheet-music/` directory with:
- `simple-scale.png`: C major scale
- `twinkle-twinkle.png`: Simple melody
- `complex-piece.png`: Multi-measure composition
- `invalid-image.png`: Non-music image
- `corrupted.png`: Corrupted file

## Documentation Requirements

### User Documentation

**File:** `docs/SHEET-MUSIC-TO-MIDI-GUIDE.md`

**Sections:**
1. Introduction and Use Cases
2. Prerequisites and Installation
3. Quick Start Guide
4. Command Reference
5. Configuration Options
6. Batch Processing
7. Troubleshooting
8. FAQ
9. Examples

### Developer Documentation

**File:** `docs/SHEET-MUSIC-TO-MIDI-TECHNICAL.md`

**Sections:**
1. Architecture Overview
2. Component Specifications
3. API Reference
4. Extension Points
5. Testing Guide
6. Performance Considerations
7. Security Considerations
8. Future Enhancements

### API Documentation

**In-code documentation** using comment-based help:

```powershell
<#
.SYNOPSIS
    Converts guitar sheet music images to MIDI files using Ollama vision models.

.DESCRIPTION
    This script uses Ollama's vision recognition capabilities to analyze sheet music
    images and convert them to MIDI format. It supports single file and batch processing.

.PARAMETER InputImage
    Path to the sheet music image file(s). Supports PNG, JPG, and PDF formats.

.PARAMETER OutputPath
    Directory where MIDI files will be saved. Default: ./output/midi

.PARAMETER Model
    Ollama vision model to use. Options: llava, bakllava, auto. Default: auto

.PARAMETER Tempo
    Tempo in beats per minute. Default: 120

.PARAMETER Instrument
    MIDI instrument to use. Default: AcousticGuitar

.EXAMPLE
    ./0220_Convert-SheetMusicToMIDI.ps1 -InputImage "sheet.png"
    
.EXAMPLE
    Get-ChildItem *.png | ./0220_Convert-SheetMusicToMIDI.ps1 -Batch

.NOTES
    Requires Ollama to be installed with vision models.
    Requires Python with music21 and mido libraries.
#>
```

## Risk Assessment

### High-Priority Risks

**Risk 1: Vision Model Accuracy**
- **Description**: Model may not accurately recognize complex musical notation
- **Impact**: High - Core functionality affected
- **Probability**: Medium
- **Mitigation**: 
  - Use multiple models with voting
  - Implement confidence scoring
  - Start with simple notation, iterate complexity
  - Allow manual correction workflow
- **Contingency**: Provide alternative input methods (MusicXML import)

**Risk 2: Platform Compatibility**
- **Description**: Ollama or Python dependencies may not work on all platforms
- **Impact**: Medium - Reduces supported platforms
- **Probability**: Low-Medium
- **Mitigation**:
  - Test on all platforms early
  - Use platform detection and fallbacks
  - Document platform-specific requirements
  - Provide Docker container option
- **Contingency**: Document unsupported platforms clearly

**Risk 3: Performance Issues**
- **Description**: Processing may be too slow for practical use
- **Impact**: Medium - User experience affected
- **Probability**: Medium
- **Mitigation**:
  - Optimize image preprocessing
  - Implement caching
  - Use batch processing
  - Profile and optimize bottlenecks
- **Contingency**: Provide async processing option

### Medium-Priority Risks

**Risk 4: Ollama API Changes**
- **Description**: Ollama API may change breaking compatibility
- **Impact**: Medium
- **Probability**: Low
- **Mitigation**:
  - Version lock dependencies
  - Monitor Ollama releases
  - Abstract API calls behind interface
- **Contingency**: Quick update script

**Risk 5: Music Theory Complexity**
- **Description**: Advanced notation (dynamics, articulations) may be difficult to parse
- **Impact**: Low-Medium
- **Probability**: High
- **Mitigation**:
  - Start with basic notation
  - Clearly document limitations
  - Iterate based on feedback
- **Contingency**: Provide "simple mode" option

**Risk 6: Resource Consumption**
- **Description**: Vision models may require significant RAM/CPU
- **Impact**: Medium
- **Probability**: Medium
- **Mitigation**:
  - Document minimum requirements
  - Implement resource monitoring
  - Provide configuration for model selection
- **Contingency**: Offer cloud processing option (future)

## Timeline Estimate

**Total: 11-16 days**

- Phase 1: Research & Architecture - 2-3 days
- Phase 2: Prerequisites & Dependencies - 1-2 days
- Phase 3: Core Processing Script - 3-4 days
- Phase 4: Supporting Infrastructure - 2 days
- Phase 5: Testing & Documentation - 2-3 days
- Phase 6: Integration & Polish - 1-2 days

## Resource Requirements

### Personnel
- 1 PowerShell Developer (full-time)
- 1 Python Developer (part-time, 25%)
- 1 Technical Writer (part-time, 25%)
- 1 QA Engineer (part-time, 50%)

### Infrastructure
- Development machines (Windows, Linux, macOS)
- Test sheet music sample library
- CI/CD pipeline configuration

### Tools & Services
- Ollama installation
- Python development environment
- Music notation software (for validation)
- Image editing tools

## Success Criteria

### Functional Requirements
- [ ] Successfully installs Ollama on all supported platforms
- [ ] Converts simple guitar sheet music to MIDI
- [ ] Processes batch of multiple images
- [ ] Validates output MIDI files
- [ ] Provides clear error messages
- [ ] Integrates with AitherZero UI

### Non-Functional Requirements
- [ ] Processes single page in < 30 seconds
- [ ] Achieves 80% accuracy on simple melodies
- [ ] Works on Windows, Linux, macOS
- [ ] Memory usage < 2GB during processing
- [ ] Comprehensive logging
- [ ] User documentation complete

### Quality Requirements
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] PSScriptAnalyzer validation passes
- [ ] Code coverage > 80%
- [ ] Documentation complete and reviewed
- [ ] User acceptance testing successful

## Future Enhancements

### Phase 2 Features (Post-Launch)
1. **Advanced Notation Support**
   - Dynamics (forte, piano, crescendo)
   - Articulations (staccato, legato)
   - Ornaments (trills, grace notes)

2. **Multi-Instrument Support**
   - Piano, bass, drums
   - Multiple tracks in single MIDI

3. **Interactive Editing**
   - Visual editor for corrections
   - Manual notation adjustment
   - Undo/redo support

4. **Cloud Processing**
   - Optional cloud API for heavy processing
   - Batch job submission
   - Email notification on completion

5. **Audio Playback**
   - Built-in MIDI player
   - Audio export (MP3, WAV)
   - Soundfont support

6. **Enhanced Recognition**
   - Handwritten music support
   - Multi-page processing
   - Chord recognition

## Conclusion

This implementation plan provides a comprehensive roadmap for adding sheet music to MIDI conversion capabilities to the AitherZero platform. The phased approach allows for iterative development, early validation, and risk mitigation. The feature will integrate seamlessly with AitherZero's existing architecture while providing valuable new functionality for musicians and developers.

The project is feasible with current technology (Ollama vision models) and follows established patterns in the AitherZero codebase. Success depends on thorough testing, clear documentation, and managing expectations around vision model accuracy.

## Approval & Sign-Off

**Project Manager:** _____________________ Date: _______

**Technical Lead:** _____________________ Date: _______

**QA Lead:** _____________________ Date: _______
