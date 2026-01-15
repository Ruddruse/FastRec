# FastRec

A lightweight macOS menu bar application for capturing system audio.

## Overview

FastRec sits quietly in your menu bar and lets you quickly record any audio playing on your Mac. Whether you're capturing music, audio from videos, or any other system sounds, FastRec makes it simple with just one click.

## Features

- **System Audio Capture** - Records all audio playing on your Mac using ScreenCaptureKit
- **Menu Bar Integration** - Compact, always-accessible menu bar icon (turns red when recording)
- **Real-Time Waveform** - Dynamic 35-dot waveform visualization during recording and playback
- **Multiple Export Formats** - Save recordings as WAV, AIFF, or M4A/AAC
- **Playback Controls** - Preview your recordings before saving
- **Elapsed Time Display** - Track recording duration in real-time
- **Minimal Footprint** - No dock icon, stays out of your way

## Requirements

- macOS 13.0 or later
- Screen Recording permission (required for system audio capture)

## Installation

### Download

Download the latest `FastRec-1.0.dmg` from the repository and drag FastRec to your Applications folder.

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/Ruddruse/FastRec.git
   ```

2. Open `FastRec.xcodeproj` in Xcode

3. Build and run (⌘R)

## Usage

1. **Launch** - FastRec appears as an icon in your menu bar
2. **Record** - Click the menu bar icon to open the recorder, then click the record button
3. **Grant Permission** - On first use, allow Screen Recording permission when prompted
4. **Stop** - Click the stop button when done recording
5. **Preview** - Use the play button to preview your recording
6. **Save** - Click Save, choose your format (WAV/AIFF/M4A), and select a destination

### Menu Bar Controls

- **Left-click** - Toggle the recorder window
- **Right-click** - Access context menu (Show/Quit)

## Audio Formats

| Format | Type | Best For |
|--------|------|----------|
| WAV | Lossless | Maximum quality, editing |
| AIFF | Lossless | Mac-native lossless format |
| M4A | Compressed | Smaller file size, sharing |

## Project Structure

```
FastRec/
├── FastRecApp.swift          # App entry point
├── AppDelegate.swift         # Menu bar setup & window management
├── Audio/
│   ├── SystemAudioCapture.swift  # ScreenCaptureKit integration
│   ├── AudioRecorder.swift       # Temp file recording
│   └── AudioEncoder.swift        # Format conversion
├── Models/
│   └── RecorderState.swift       # State management
├── Views/
│   ├── RecorderWindow.swift      # Floating window panel
│   ├── ContentView.swift         # Main UI
│   ├── RecordButton.swift        # Record/play button
│   └── WaveformView.swift        # Waveform visualization
└── Resources/
    └── Assets.xcassets/          # App icons
```

## Technical Details

- **Audio Quality**: 44.1kHz stereo (CD quality)
- **Frameworks**: SwiftUI, AVFoundation, ScreenCaptureKit, Combine
- **Dependencies**: None (uses only Apple frameworks)

## Privacy

FastRec requires Screen Recording permission to capture system audio. This permission can be granted in **System Settings > Privacy & Security > Screen Recording**.

No data is collected or transmitted - all recordings stay on your device.

## License

This project is available for use. See the repository for license details.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.
