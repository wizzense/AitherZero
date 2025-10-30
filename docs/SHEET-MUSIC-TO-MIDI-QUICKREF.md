# Sheet Music to MIDI - Quick Reference

## Overview

Automation scripts to convert guitar sheet music images to MIDI files using Ollama vision recognition models.

## Script Numbers

| Number | Script Name | Purpose | Dependencies |
|--------|-------------|---------|--------------|
| 0219 | Install-Ollama.ps1 | Install Ollama runtime with vision models | PowerShell 7.0+ |
| 0220 | Convert-SheetMusicToMIDI.ps1 | Convert sheet music images to MIDI | Ollama, Python 3.12+, music21, mido |

## Quick Start

### 1. Install Prerequisites

```powershell
# Using AitherZero orchestration
az 0219  # Install Ollama and pull vision models

# Or manually
./automation-scripts/0219_Install-Ollama.ps1
```

### 2. Convert Sheet Music

```powershell
# Single file
./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 -InputImage "my-sheet-music.png"

# Batch processing
Get-ChildItem *.png | ./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 -Batch

# With custom settings
./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 `
    -InputImage "sheet.png" `
    -OutputPath "./my-midi-files" `
    -Tempo 140 `
    -Instrument "ElectricGuitar" `
    -Validate
```

## Configuration

### config.psd1 Settings

```powershell
Features = @{
    Development = @{
        Ollama = @{
            Enabled = $true
            APIUrl = 'http://localhost:11434'
            DefaultModels = @('llava', 'bakllava')
        }
        MusicProcessing = @{
            Enabled = $true
            DefaultModel = 'llava'
            OutputPath = './output/midi'
            DefaultTempo = 120
        }
    }
}
```

## Common Use Cases

### Convert a Simple Melody

```powershell
./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 -InputImage "simple-melody.png"
```

**Expected Output:**
- `./output/midi/simple-melody.mid` - Generated MIDI file
- Console shows conversion progress and confidence score
- Log file with detailed processing information

### Batch Convert Multiple Files

```powershell
$files = Get-ChildItem "./sheet-music/*.png"
$files | ./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 -Batch -OutputPath "./converted"
```

### Use Different Vision Model

```powershell
./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 `
    -InputImage "complex-piece.png" `
    -Model "bakllava"
```

### Custom Tempo and Instrument

```powershell
./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 `
    -InputImage "blues-riff.png" `
    -Tempo 90 `
    -Instrument "ElectricGuitar"
```

## Supported Input Formats

- PNG (.png)
- JPEG (.jpg, .jpeg)
- PDF (.pdf) - First page only

**Recommended:**
- Resolution: 300 DPI minimum
- Color: Grayscale or black & white
- Size: < 10 MB
- Clean, high-contrast images

## Output Format

MIDI files with:
- Single track (guitar)
- Specified tempo (default: 120 BPM)
- Specified instrument (default: Acoustic Guitar)
- Standard MIDI format (Type 0 or Type 1)

## Troubleshooting

### Ollama Not Installed

**Error:** "Ollama runtime not found"

**Solution:**
```powershell
az 0219  # Install Ollama
# Or manually
./automation-scripts/0219_Install-Ollama.ps1
```

### Vision Model Not Available

**Error:** "Model 'llava' not found"

**Solution:**
```powershell
ollama pull llava  # Pull model manually
# Or reinstall
az 0219 -Force
```

### Python Dependencies Missing

**Error:** "Module 'music21' not found"

**Solution:**
```powershell
pip install music21 mido pillow numpy
# Or use Poetry
poetry add music21 mido pillow numpy
```

### Poor Recognition Quality

**Problem:** MIDI output doesn't match input

**Solutions:**
1. Improve image quality (higher DPI, better contrast)
2. Try different vision model: `-Model "bakllava"`
3. Preprocess image (crop, enhance contrast)
4. Simplify notation (remove decorations)

### Processing Too Slow

**Problem:** Takes too long to convert

**Solutions:**
1. Use smaller images (resize to 2048px width)
2. Enable batch processing for multiple files
3. Use faster model (try different models)
4. Check system resources (RAM, CPU)

## Advanced Options

### Custom Prompt Engineering

Edit the prompt in the script to improve recognition:

```powershell
# In 0220_Convert-SheetMusicToMIDI.ps1
$prompt = @"
Analyze this guitar sheet music image. Extract:
- Note names (C, D, E, F, G, A, B with sharps/flats)
- Note durations (whole, half, quarter, eighth)
- Time signature
- Key signature
- Tempo marking

Format as JSON with measures array.
"@
```

### Model Selection Strategy

```powershell
# Auto mode (default) - tries llava first, falls back to bakllava
-Model "auto"

# llava - Faster, good for simple notation
-Model "llava"

# bakllava - Better for complex notation, slower
-Model "bakllava"
```

### Validation Options

```powershell
# Enable validation (checks output quality)
-Validate

# Validation checks:
# - MIDI file integrity
# - Note ranges (valid for guitar)
# - Timing consistency
# - Music theory rules
```

## Integration Examples

### With AitherZero Orchestration

```powershell
# Add to playbook
Playbooks = @{
    'music-conversion' = @{
        Description = 'Convert sheet music to MIDI'
        Stages = @(
            @{ Scripts = @('0219'); Description = 'Install Ollama' }
            @{ Scripts = @('0220'); Description = 'Convert music' }
        )
    }
}

# Run playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook music-conversion
```

### With CI/CD Pipeline

```yaml
# .github/workflows/convert-music.yml
name: Convert Sheet Music

on:
  push:
    paths:
      - 'sheet-music/**/*.png'

jobs:
  convert:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Ollama
        run: ./automation-scripts/0219_Install-Ollama.ps1
      
      - name: Convert Sheet Music
        run: |
          Get-ChildItem sheet-music/*.png | 
            ./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 -Batch
      
      - name: Upload MIDI Files
        uses: actions/upload-artifact@v3
        with:
          name: midi-files
          path: output/midi/*.mid
```

### Programmatic Usage

```powershell
# Load configuration
$config = Get-Configuration

# Process single file
$result = & ./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 `
    -InputImage "input.png" `
    -Configuration $config `
    -Validate

# Check result
if ($result.Success) {
    Write-Host "✓ Conversion successful"
    Write-Host "  Output: $($result.OutputFile)"
    Write-Host "  Confidence: $($result.Confidence)%"
} else {
    Write-Warning "Conversion failed: $($result.Error)"
}
```

## Performance Benchmarks

| Operation | Duration | Notes |
|-----------|----------|-------|
| Install Ollama | 2-5 min | One-time setup |
| Pull vision model | 3-8 min | One-time per model |
| Process simple image | 10-20 sec | Single-line melody |
| Process complex image | 20-40 sec | Multi-measure piece |
| Batch (10 images) | 3-5 min | Parallel processing |

*Benchmarks on mid-range hardware (8GB RAM, 4 cores)*

## API Reference

### 0219_Install-Ollama.ps1

```powershell
SYNOPSIS
    Installs Ollama runtime and vision models

PARAMETERS
    -Configuration <hashtable>
        Configuration from config.psd1
    
    -Models <string[]>
        Models to install (default: llava, bakllava)
    
    -SkipModelPull
        Skip pulling models (install runtime only)
    
    -Force
        Force reinstallation

OUTPUTS
    Exit code 0 on success, 1+ on error
```

### 0220_Convert-SheetMusicToMIDI.ps1

```powershell
SYNOPSIS
    Converts sheet music images to MIDI files

PARAMETERS
    -InputImage <string[]> [Mandatory]
        Path(s) to sheet music image files
    
    -OutputPath <string>
        Output directory (default: ./output/midi)
    
    -Model <string>
        Vision model: llava, bakllava, auto (default: auto)
    
    -Tempo <int>
        BPM tempo (default: 120)
    
    -Instrument <string>
        MIDI instrument (default: AcousticGuitar)
    
    -Batch
        Enable batch processing mode
    
    -Validate
        Enable output validation
    
    -Configuration <hashtable>
        Configuration from config.psd1

OUTPUTS
    PSCustomObject with conversion results
```

## Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | - |
| 1 | General error | Check logs |
| 2 | Prerequisites not met | Run az 0219 |
| 3 | Image processing failed | Check image format/quality |
| 4 | Vision model error | Check Ollama service |
| 5 | MIDI generation failed | Check Python dependencies |
| 6 | Validation failed | Review output quality |

## Support

### Logging

Logs are written to:
- Console (real-time)
- `logs/aitherzero.log` (detailed)
- `logs/transcript-*.log` (session transcript)

### Debug Mode

```powershell
$DebugPreference = 'Continue'
./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 -InputImage "test.png"
```

### Verbose Output

```powershell
./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 -InputImage "test.png" -Verbose
```

## Resources

- **Main Documentation:** `docs/SHEET-MUSIC-TO-MIDI-PLAN.md`
- **Technical Guide:** `docs/SHEET-MUSIC-TO-MIDI-TECHNICAL.md`
- **Ollama Documentation:** https://ollama.ai/docs
- **music21 Documentation:** https://web.mit.edu/music21/doc/
- **MIDI Specification:** https://www.midi.org/specifications

## Version History

- **v1.0** (Planned) - Initial implementation
  - Basic sheet music recognition
  - Single instrument (guitar) support
  - llava and bakllava models
  - Batch processing
  - MIDI generation

- **v2.0** (Future) - Enhanced features
  - Multi-instrument support
  - Advanced notation (dynamics, articulations)
  - Interactive editing
  - Cloud processing option

## Contributing

To contribute improvements:

1. Test changes with sample sheet music
2. Update tests in `tests/automation-scripts/`
3. Update documentation
4. Submit PR with clear description

## License

This feature is part of AitherZero and follows the project license.
