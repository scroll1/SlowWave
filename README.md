# SlowWave

A free, native macOS audio player by **BrennanLabs** that lets you slow down (or speed up) audio files without changing their pitch.

## Features
- **Studio-Grade Pitch-Preserving Time Stretching**: Powered by `AVAudioEngine` and **Signalsmith Stretch** (MIT) for phase-locked clarity on strings, vocals, and acoustic instruments—with pitch locked to `0 st` (0 cents).
- **Focused Slowdown Controls**: Quick speed presets (`0.25×`, `0.5×`, `0.65×`, `0.75×`, `0.85×`, `0.9×`, `1.0×`, `1.5×`, `2.0×`), a preset-aligned speed slider, and `±5%` steppers.
- **Interactive Waveform & A–B Practice Markers**: Click or drag on the waveform to scrub, place **A** and **B** markers (drag markers directly or nudge by `±0.2s` with a 1.5s cut preview on **B**), toggle **Start from A** (pausing with `Space` returns to **A** and playback stops at **B**), or toggle **Loop** to repeat A→B continuously.
- **Broad Audio & Video Format Support**: Drag & drop or open `MP3`, `M4A`, `WAV`, `AIFF`, `FLAC`, `CAF`, plus `MP4`, `MOV`, and `M4V` video files (plays audio only).
- **Keyboard Shortcuts**:
  - `Space` — Play / Pause
  - `⌘O` — Open Audio File
  - `⌘←` / `⌘→` — Skip Back / Forward 5 seconds
  - `⌘-` / `⌘+` — Slower / Faster by 5%
  - `⌘0` — Reset Speed to `1.0×`

## Download & Install
1. Download the latest `SlowWave-1.2.0.dmg` from the [Releases](../../releases) page.
2. Open the `.dmg` file and drag **SlowWave** into **Applications**.
3. **First launch note (macOS Gatekeeper)**: Because SlowWave is free, open-source software and is not notarized with a paid Apple Developer certificate, macOS may block it the first time you open it. To open it:
   - Try launching **SlowWave** once, then open **System Settings → Privacy & Security** and click **Open Anyway**, *or*
   - Run `xattr -cr /Applications/SlowWave.app` in Terminal.

## Requirements
- macOS 14.0 (Sonoma) or later (Apple Silicon)
- Swift 6 / Xcode 16+ (to build from source)

## Building from Source

Run tests:
```bash
swift test
```

Build the standalone macOS app bundle (`build/SlowWave.app`):
```bash
./scripts/build-app.sh
open build/SlowWave.app
```

Build the distributable `.dmg` installer (`build/SlowWave-1.2.0.dmg`):
```bash
./scripts/build-dmg.sh
```

## Built With
SlowWave was coded in **Google Antigravity** using Swift, SwiftUI, Apple's `AVFoundation`, and [Signalsmith Stretch](https://github.com/Signalsmith-Audio/signalsmith-stretch) (MIT).

## License
SlowWave is open-source software licensed under the [MIT License](LICENSE).
