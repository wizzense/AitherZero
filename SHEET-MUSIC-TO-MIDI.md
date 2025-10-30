# Sheet Music to MIDI Conversion

Automated conversion of guitar sheet music images to MIDI files using Ollama AI vision recognition.

## Quick Start

### 1. Install Prerequisites

```powershell
# Install Ollama with vision models
./automation-scripts/0219_Install-Ollama.ps1

# Or via AitherZero
az 0219
```

### 2. Install Python Dependencies

```bash
# Using pip
pip install -r requirements-music.txt

# Or using Poetry
poetry add music21 mido pillow numpy
```

### 3. Convert Sheet Music

```powershell
# Single file
./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 -InputImage "my-sheet-music.png"

# Batch processing
Get-ChildItem *.png | ./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1

# Custom settings
./automation-scripts/0220_Convert-SheetMusicToMIDI.ps1 `
    -InputImage "blues.png" `
    -OutputPath "./my-midi" `
    -Tempo 90 `
    -Instrument "ElectricGuitar" `
    -Validate

# Via AitherZero
az 0220 -InputImage "sheet.png"
```

## Features

- **Input**: PNG, JPEG, PDF sheet music images
- **Processing**: Ollama vision models (llava, bakllava)
- **Output**: Standard MIDI files
- **Instruments**: Acoustic Guitar, Electric Guitar
- **Tempo**: Configurable (40-240 BPM)
- **Batch**: Process multiple files at once
- **Validation**: Optional output quality checks

## Configuration

Enable in `config.psd1`:

```powershell
Features = @{
    Development = @{
        AITools = @{
            Ollama = @{
                Enabled = $true
                DefaultModels = @('llava', 'bakllava')
            }
        }
        MusicProcessing = @{
            SheetMusicToMIDI = @{
                Enabled = $true
                DefaultTempo = 120
                OutputPath = './output/midi'
            }
        }
    }
}
```

## Requirements

- **PowerShell 7.0+**
- **Ollama** with vision models (llava/bakllava)
- **Python 3.8+** with music21, mido, pillow, numpy

## Documentation

- **Complete Guide**: `docs/SHEET-MUSIC-TO-MIDI-QUICKREF.md`
- **Implementation Plan**: `docs/SHEET-MUSIC-TO-MIDI-PLAN.md`
- **Technical Research**: `docs/SHEET-MUSIC-TO-MIDI-RESEARCH.md`
- **Executive Summary**: `docs/SHEET-MUSIC-TO-MIDI-EXECUTIVE-SUMMARY.md`

## Examples

### Convert Simple Melody

```powershell
az 0220 -InputImage "simple-scale.png"
```

Output: `./output/midi/simple-scale.mid`

### Batch Convert with Validation

```powershell
Get-ChildItem ./sheet-music/*.png | az 0220 -Validate
```

### Use Different Model

```powershell
az 0220 -InputImage "complex-piece.png" -Model "bakllava"
```

## Troubleshooting

### Ollama Not Found
```powershell
# Install Ollama
az 0219
```

### Python Dependencies Missing
```bash
pip install -r requirements-music.txt
```

### Poor Recognition Quality
1. Use higher resolution images (300+ DPI)
2. Ensure good contrast
3. Try different model: `-Model "bakllava"`
4. Simplify notation if possible

### Service Not Running
```bash
# Start Ollama service
ollama serve
```

## Performance

- **Processing Time**: ~20-30 seconds per page
- **Accuracy**: 80%+ for simple melodies, 60%+ for complex notation
- **Memory Usage**: < 2GB
- **Platforms**: Windows, Linux, macOS

## Support

For issues or questions:
1. Check documentation in `docs/SHEET-MUSIC-TO-MIDI-*.md`
2. Review logs in `logs/aitherzero.log`
3. Open GitHub issue with sample image and error details

## License

Part of AitherZero - Infrastructure Automation Platform
