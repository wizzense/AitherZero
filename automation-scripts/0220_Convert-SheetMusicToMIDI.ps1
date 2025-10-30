#Requires -Version 7.0
# Stage: Development
# Dependencies: Ollama, Python3
# Description: Convert guitar sheet music images to MIDI files using Ollama vision recognition
# Tags: development, ai, music, midi, ollama, vision

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('Path', 'FullName')]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
            throw "File not found: $_"
        }
        $extension = [System.IO.Path]::GetExtension($_).ToLower()
        if ($extension -notin @('.png', '.jpg', '.jpeg', '.pdf')) {
            throw "Unsupported file format: $extension. Supported formats: .png, .jpg, .jpeg, .pdf"
        }
        return $true
    })]
    [string[]]$InputImage,
    
    [Parameter()]
    [string]$OutputPath = './output/midi',
    
    [Parameter()]
    [ValidateSet('llava', 'bakllava', 'auto')]
    [string]$Model = 'auto',
    
    [Parameter()]
    [ValidateRange(40, 240)]
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

begin {
    # Initialize logging
    $script:LoggingAvailable = $false
    try {
        $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/Logging.psm1"
        if (Test-Path $loggingPath) {
            Import-Module $loggingPath -Force -Global
            $script:LoggingAvailable = $true
        }
    } catch {
        # Fallback to basic output
        Write-Verbose "Could not load logging module"
    }

    function Write-ScriptLog {
        param(
            [string]$Message,
            [string]$Level = 'Information'
        )

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message $Message -Level $Level
        } else {
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $prefix = switch ($Level) {
                'Error' { 'ERROR' }
                'Warning' { 'WARN' }
                'Debug' { 'DEBUG' }
                default { 'INFO' }
            }
            Write-Host "[$timestamp] [$prefix] $Message"
        }
    }

    function Test-Prerequisite {
        <#
        .SYNOPSIS
            Verify that all required dependencies are installed
        #>
        Write-ScriptLog "Checking prerequisites..." -Level 'Debug'
        
        $issues = @()
        
        # Check Ollama
        $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
        if (-not $ollamaCmd) {
            $issues += "Ollama is not installed. Run: az 0219"
        } else {
            # Check if Ollama service is running
            try {
                $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/tags' -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
                if (-not $response) {
                    $issues += "Ollama service is not running. Start with: ollama serve"
                }
            } catch {
                $issues += "Ollama API is not accessible. Start with: ollama serve"
            }
        }
        
        # Check Python
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pythonCmd) {
            $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
        }
        
        if (-not $pythonCmd) {
            $issues += "Python is not installed. Run: az 0206"
        }
        
        if ($issues.Count -gt 0) {
            Write-ScriptLog "Prerequisites check failed:" -Level 'Error'
            foreach ($issue in $issues) {
                Write-ScriptLog "  - $issue" -Level 'Error'
            }
            return $false
        }
        
        Write-ScriptLog "Prerequisites check passed" -Level 'Debug'
        return $true
    }

    function Test-ImageFile {
        <#
        .SYNOPSIS
            Validate image file for processing
        #>
        param(
            [Parameter(Mandatory)]
            [string]$ImagePath
        )
        
        if (-not (Test-Path $ImagePath -PathType Leaf)) {
            Write-ScriptLog "Image file not found: $ImagePath" -Level 'Error'
            return $false
        }
        
        $fileInfo = Get-Item $ImagePath
        $maxSize = 10MB
        
        if ($fileInfo.Length -gt $maxSize) {
            Write-ScriptLog "Image file too large: $($fileInfo.Length / 1MB)MB (max: 10MB)" -Level 'Warning'
            return $false
        }
        
        return $true
    }

    function Invoke-OllamaVision {
        <#
        .SYNOPSIS
            Call Ollama vision API with an image and prompt
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$ImagePath,
            
            [Parameter(Mandatory)]
            [string]$Prompt,
            
            [Parameter()]
            [string]$Model = 'llava',
            
            [Parameter()]
            [string]$APIUrl = 'http://localhost:11434',
            
            [Parameter()]
            [int]$Timeout = 300
        )
        
        Write-ScriptLog "Calling Ollama API with model: $Model" -Level 'Debug'
        
        try {
            # Convert image to base64
            $imageBytes = [System.IO.File]::ReadAllBytes($ImagePath)
            $base64Image = [Convert]::ToBase64String($imageBytes)
            
            # Build request
            $requestBody = @{
                model = $Model
                prompt = $Prompt
                images = @($base64Image)
                stream = $false
            } | ConvertTo-Json -Depth 10
            
            # Call API
            $response = Invoke-RestMethod `
                -Uri "$APIUrl/api/generate" `
                -Method Post `
                -Body $requestBody `
                -ContentType 'application/json' `
                -TimeoutSec $Timeout
            
            return $response.response
        } catch {
            Write-ScriptLog "Ollama API error: $_" -Level 'Error'
            throw
        }
    }

    function Get-MusicRecognitionPrompt {
        <#
        .SYNOPSIS
            Generate prompt for music recognition
        #>
        param(
            [Parameter()]
            [ValidateSet('Simple', 'Advanced')]
            [string]$Type = 'Simple'
        )
        
        if ($Type -eq 'Simple') {
            return @"
Analyze this guitar sheet music image. Extract musical information and format as JSON.

Extract:
- Time signature (e.g., "4/4", "3/4")
- Key signature (e.g., "C major", "G major")
- Tempo (BPM if visible, otherwise estimate 120)

For each measure, list notes from left to right:
- Pitch: Use scientific notation (C4, D4, E4, etc.)
- Duration: In beats (1.0 = quarter note, 2.0 = half note, 0.5 = eighth note)
- Offset: Position in measure (0.0 = start)

Format as JSON:
{
  "timeSignature": "4/4",
  "keySignature": "C major",
  "tempo": 120,
  "measures": [
    {
      "number": 1,
      "notes": [
        {"pitch": "C4", "duration": 1.0, "offset": 0.0}
      ]
    }
  ]
}

Be precise. For guitar, range is E2 to E6. Include only visible information.
"@
        } else {
            return @"
You are a music transcription expert. Analyze this guitar sheet music image precisely.

Extract:
1. Metadata:
   - Time signature (e.g., "4/4")
   - Key signature (e.g., "C major" or "1 sharp, G major")
   - Tempo (BPM if marked)
   - Clef type (treble for guitar)

2. For each measure:
   - Measure number
   - Notes in order:
     * Pitch (scientific notation: C4, D#4, Eb5)
     * Duration (beats: 4=whole, 2=half, 1=quarter, 0.5=eighth, 0.25=sixteenth)
     * Accidental (sharp, flat, natural, none)
     * Tied to next note (true/false)
     * Offset from measure start (beats)

3. Special markings if visible:
   - Dynamics (forte, piano, etc.)
   - Articulations (staccato, legato)
   - Repeat signs

Format as valid JSON:
{
  "timeSignature": "4/4",
  "keySignature": "C major",
  "tempo": 120,
  "clef": "treble",
  "measures": [
    {
      "number": 1,
      "notes": [
        {
          "pitch": "C4",
          "duration": 1.0,
          "accidental": "none",
          "tied": false,
          "offset": 0.0
        }
      ]
    }
  ],
  "dynamics": [],
  "articulations": []
}

Important:
- Guitar range: E2 to E6
- Use decimal duration values
- Be precise with pitch names including octaves
- If uncertain, omit rather than guess
"@
        }
    }

    function ConvertTo-MusicData {
        <#
        .SYNOPSIS
            Parse Ollama response to extract music data
        #>
        param(
            [Parameter(Mandatory)]
            [string]$ModelResponse
        )
        
        Write-ScriptLog "Parsing model response..." -Level 'Debug'
        
        try {
            # Extract JSON from response (model may include explanatory text)
            $jsonMatch = [regex]::Match($ModelResponse, '\{[\s\S]*\}', [Text.RegularExpressions.RegexOptions]::Singleline)
            
            if (-not $jsonMatch.Success) {
                Write-ScriptLog "Could not extract JSON from model response" -Level 'Error'
                Write-ScriptLog "Response preview: $($ModelResponse.Substring(0, [Math]::Min(200, $ModelResponse.Length)))" -Level 'Debug'
                throw "Could not extract JSON from model response"
            }
            
            $json = $jsonMatch.Value
            $musicData = $json | ConvertFrom-Json
            
            # Validate required fields
            $requiredFields = @('timeSignature', 'keySignature', 'tempo', 'measures')
            foreach ($field in $requiredFields) {
                if (-not $musicData.PSObject.Properties[$field]) {
                    Write-ScriptLog "Missing required field: $field" -Level 'Warning'
                }
            }
            
            # Set defaults if missing
            if (-not $musicData.timeSignature) { $musicData | Add-Member -NotePropertyName 'timeSignature' -NotePropertyValue '4/4' }
            if (-not $musicData.keySignature) { $musicData | Add-Member -NotePropertyName 'keySignature' -NotePropertyValue 'C major' }
            if (-not $musicData.tempo) { $musicData | Add-Member -NotePropertyName 'tempo' -NotePropertyValue 120 }
            if (-not $musicData.measures) { $musicData | Add-Member -NotePropertyName 'measures' -NotePropertyValue @() }
            
            Write-ScriptLog "Parsed music data: $($musicData.measures.Count) measures, tempo $($musicData.tempo) BPM" -Level 'Debug'
            
            return $musicData
        } catch {
            Write-ScriptLog "Error parsing music data: $_" -Level 'Error'
            throw
        }
    }

    function ConvertTo-MIDI {
        <#
        .SYNOPSIS
            Convert music data to MIDI file using Python
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [object]$MusicData,
            
            [Parameter(Mandatory)]
            [string]$OutputFile,
            
            [Parameter()]
            [string]$InstrumentName = 'AcousticGuitar'
        )
        
        Write-ScriptLog "Generating MIDI file: $OutputFile" -Level 'Debug'
        
        # Create temporary JSON file
        $tempJson = [System.IO.Path]::GetTempFileName() + '.json'
        $MusicData | ConvertTo-Json -Depth 10 | Set-Content $tempJson
        
        # Create Python script for MIDI generation
        $pythonScript = @'
import json
import sys
from pathlib import Path

try:
    # Try to import music21
    from music21 import stream, note, tempo, instrument, key, meter, chord
    use_music21 = True
except ImportError:
    print("Warning: music21 not found, falling back to mido", file=sys.stderr)
    use_music21 = False
    try:
        import mido
        from mido import MidiFile, MidiTrack, Message, MetaMessage
    except ImportError:
        print("Error: Neither music21 nor mido is installed. Please install at least one of these Python packages.", file=sys.stderr)
        sys.exit(1)

def note_to_midi(note_name):
    """Convert note name to MIDI number"""
    note_map = {
        'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3,
        'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8,
        'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11
    }
    pitch = note_name[:-1]
    octave = int(note_name[-1])
    return (octave + 1) * 12 + note_map.get(pitch, 0)

def create_midi_music21(data, output_file, instrument_name):
    """Create MIDI using music21"""
    # Create score
    score = stream.Score()
    part = stream.Part()
    
    # Set instrument
    if instrument_name == 'AcousticGuitar':
        part.insert(0, instrument.AcousticGuitar())
    elif instrument_name == 'ElectricGuitar':
        part.insert(0, instrument.ElectricGuitar())
    else:
        part.insert(0, instrument.Guitar())
    
    # Set tempo
    tempo_bpm = data.get('tempo', 120)
    part.insert(0, tempo.MetronomeMark(number=tempo_bpm))
    
    # Set key signature
    key_sig = data.get('keySignature', 'C major')
    part.insert(0, key.Key(key_sig))
    
    # Set time signature
    time_sig = data.get('timeSignature', '4/4')
    numerator, denominator = map(int, time_sig.split('/'))
    part.insert(0, meter.TimeSignature(f'{numerator}/{denominator}'))
    
    # Process measures
    for measure_data in data.get('measures', []):
        measure = stream.Measure(number=measure_data.get('number', 1))
        
        for note_data in measure_data.get('notes', []):
            pitch_str = note_data.get('pitch', 'C4')
            duration = note_data.get('duration', 1.0)
            
            if pitch_str.lower() == 'rest':
                r = note.Rest()
                r.quarterLength = duration
                measure.append(r)
            else:
                n = note.Note(pitch_str)
                n.quarterLength = duration
                measure.append(n)
        
        part.append(measure)
    
    # Add part to score
    score.insert(0, part)
    
    # Write MIDI file
    score.write('midi', fp=output_file)
    return True

def create_midi_mido(data, output_file):
    """Create MIDI using mido (fallback)"""
    mid = MidiFile()
    track = MidiTrack()
    mid.tracks.append(track)
    
    # Set tempo
    tempo_bpm = data.get('tempo', 120)
    tempo_mpb = int(60_000_000 / tempo_bpm)
    track.append(MetaMessage('set_tempo', tempo=tempo_mpb))
    
    # Set time signature
    time_sig = data.get('timeSignature', '4/4')
    numerator, denominator = map(int, time_sig.split('/'))
    track.append(MetaMessage('time_signature', numerator=numerator, denominator=denominator))
    
    # Set instrument (guitar = 24)
    track.append(Message('program_change', program=24))
    
    # Process notes
    ticks_per_beat = 480
    for measure_data in data.get('measures', []):
        for note_data in measure_data.get('notes', []):
            pitch_str = note_data.get('pitch', 'C4')
            duration = note_data.get('duration', 1.0)
            
            if pitch_str.lower() != 'rest':
                midi_note = note_to_midi(pitch_str)
                duration_ticks = int(duration * ticks_per_beat)
                
                track.append(Message('note_on', note=midi_note, velocity=64, time=0))
                track.append(Message('note_off', note=midi_note, velocity=64, time=duration_ticks))
    
    mid.save(output_file)
    return True

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python script.py <input.json> <output.mid> [instrument]")
        sys.exit(1)
    
    json_file = sys.argv[1]
    output_file = sys.argv[2]
    instrument_name = sys.argv[3] if len(sys.argv) > 3 else 'AcousticGuitar'
    
    try:
        with open(json_file, 'r') as f:
            data = json.load(f)
        
        if use_music21:
            create_midi_music21(data, output_file, instrument_name)
        else:
            create_midi_mido(data, output_file)
        
        print(f"MIDI file created: {output_file}")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
'@
        
        # Save Python script temporarily
        $pythonScriptPath = [System.IO.Path]::GetTempFileName() + '.py'
        $pythonScript | Set-Content $pythonScriptPath
        
        try {
            # Find Python command
            $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
            if (-not $pythonCmd) {
                $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
            }
            
            if (-not $pythonCmd) {
                throw "Python not found"
            }
            
            # Run Python script
            $result = & $pythonCmd.Source $pythonScriptPath $tempJson $OutputFile $InstrumentName 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-ScriptLog "Python script failed: $result" -Level 'Error'
                throw "MIDI generation failed"
            }
            
            Write-ScriptLog "MIDI file created successfully: $OutputFile" -Level 'Debug'
            return $true
        } catch {
            Write-ScriptLog "Error generating MIDI: $_" -Level 'Error'
            throw
        } finally {
            # Cleanup temp files
            if (Test-Path $tempJson) { Remove-Item $tempJson -Force -ErrorAction SilentlyContinue }
            if (Test-Path $pythonScriptPath) { Remove-Item $pythonScriptPath -Force -ErrorAction SilentlyContinue }
        }
    }

    function Test-MIDIFile {
        <#
        .SYNOPSIS
            Validate generated MIDI file
        #>
        param(
            [Parameter(Mandatory)]
            [string]$MIDIPath
        )
        
        if (-not (Test-Path $MIDIPath)) {
            Write-ScriptLog "MIDI file not found: $MIDIPath" -Level 'Error'
            return $false
        }
        
        $fileInfo = Get-Item $MIDIPath
        if ($fileInfo.Length -eq 0) {
            Write-ScriptLog "MIDI file is empty" -Level 'Error'
            return $false
        }
        
        # Basic MIDI file validation (check header)
        $bytes = [System.IO.File]::ReadAllBytes($MIDIPath)
        if ($bytes.Length -lt 4) {
            Write-ScriptLog "MIDI file too small" -Level 'Error'
            return $false
        }
        
        # Check for MThd header
        $header = [System.Text.Encoding]::ASCII.GetString($bytes[0..3])
        if ($header -ne 'MThd') {
            Write-ScriptLog "Invalid MIDI file header" -Level 'Error'
            return $false
        }
        
        Write-ScriptLog "MIDI file validation passed" -Level 'Debug'
        return $true
    }

    # Initialize
    Write-ScriptLog "═══════════════════════════════════════════════════════"
    Write-ScriptLog "Sheet Music to MIDI Conversion"
    Write-ScriptLog "═══════════════════════════════════════════════════════"
    
    # Check prerequisites
    if (-not (Test-Prerequisite)) {
        throw "Prerequisites not met. Please install required dependencies."
    }
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-ScriptLog "Created output directory: $OutputPath"
    }
    
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }
    
    # Determine model to use
    if ($Model -eq 'auto') {
        $Model = if (
            $config.Features -and
            $config.Features.Development -and
            $config.Features.Development.MusicProcessing -and
            $config.Features.Development.MusicProcessing.SheetMusicToMIDI -and
            $config.Features.Development.MusicProcessing.SheetMusicToMIDI.Configuration -and
            $config.Features.Development.MusicProcessing.SheetMusicToMIDI.Configuration.DefaultModel
        ) {
            $config.Features.Development.MusicProcessing.SheetMusicToMIDI.Configuration.DefaultModel
        } else {
            'llava'
        }
        Write-ScriptLog "Auto-selected model: $Model"
    }
    
    $processedCount = 0
    $successCount = 0
    $failureCount = 0
    $results = @()
}

process {
    foreach ($imagePath in $InputImage) {
        $processedCount++
        
        Write-ScriptLog "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        Write-ScriptLog "Processing [$processedCount]: $imagePath"
        Write-ScriptLog "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        try {
            # Validate image
            if (-not (Test-ImageFile -ImagePath $imagePath)) {
                throw "Image validation failed"
            }
            
            # Generate output filename
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($imagePath)
            $outputFile = Join-Path $OutputPath "$baseName.mid"
            
            Write-ScriptLog "Output: $outputFile"
            
            # Call Ollama vision model
            Write-ScriptLog "Analyzing sheet music with $Model model..."
            Write-ScriptLog "This may take 20-30 seconds..."
            
            $prompt = Get-MusicRecognitionPrompt -Type 'Simple'
            $modelResponse = Invoke-OllamaVision `
                -ImagePath $imagePath `
                -Prompt $prompt `
                -Model $Model
            
            # Parse response
            Write-ScriptLog "Parsing musical notation..."
            $musicData = ConvertTo-MusicData -ModelResponse $modelResponse
            
            # Generate MIDI
            Write-ScriptLog "Generating MIDI file..."
            if ($PSCmdlet.ShouldProcess($outputFile, 'Generate MIDI')) {
                $null = ConvertTo-MIDI `
                    -MusicData $musicData `
                    -OutputFile $outputFile `
                    -InstrumentName $Instrument
            }
            
            # Validate output
            if ($Validate) {
                Write-ScriptLog "Validating MIDI file..."
                if (-not (Test-MIDIFile -MIDIPath $outputFile)) {
                    throw "MIDI validation failed"
                }
            }
            
            $successCount++
            Write-ScriptLog "✓ Conversion successful" -Level 'Information'
            
            $results += [PSCustomObject]@{
                Input = $imagePath
                Output = $outputFile
                Success = $true
                Tempo = $musicData.tempo
                TimeSignature = $musicData.timeSignature
                KeySignature = $musicData.keySignature
                Measures = $musicData.measures.Count
                Error = $null
            }
            
        } catch {
            $failureCount++
            Write-ScriptLog "✗ Conversion failed: $_" -Level 'Error'
            
            $results += [PSCustomObject]@{
                Input = $imagePath
                Output = $null
                Success = $false
                Tempo = $null
                TimeSignature = $null
                KeySignature = $null
                Measures = 0
                Error = $_.Exception.Message
            }
        }
    }
}

end {
    Write-ScriptLog "═══════════════════════════════════════════════════════"
    Write-ScriptLog "Conversion Summary"
    Write-ScriptLog "═══════════════════════════════════════════════════════"
    Write-ScriptLog "Total processed: $processedCount"
    Write-ScriptLog "Successful: $successCount"
    Write-ScriptLog "Failed: $failureCount"
    
    if ($successCount -gt 0) {
        Write-ScriptLog ""
        Write-ScriptLog "Generated MIDI files:"
        foreach ($result in $results | Where-Object { $_.Success }) {
            Write-ScriptLog "  • $($result.Output)"
        }
    }
    
    if ($failureCount -gt 0) {
        Write-ScriptLog ""
        Write-ScriptLog "Failed conversions:" -Level 'Warning'
        foreach ($result in $results | Where-Object { -not $_.Success }) {
            Write-ScriptLog "  • $($result.Input): $($result.Error)" -Level 'Warning'
        }
    }
    
    Write-ScriptLog "═══════════════════════════════════════════════════════"
    
    # Return results
    return $results
}
