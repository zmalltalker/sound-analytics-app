# Rich Sound Recorder

High-quality audio recording iOS app with real-time frequency spectrum analysis and flexible audio format options.

## Features

- **Real-time Frequency Spectrum**: Live FFT visualization showing 32 logarithmic frequency bands (20 Hz - Nyquist)
- **Input Level Meter**: Visual feedback of recording volume
- **Multiple Microphone Modes**:
  - Wide Spectrum: Raw capture with no processing (best for ML analysis)
  - Standard: Default iOS processing
  - Voice Isolation: Focus on voice, suppress background noise
- **Advanced Audio Settings**:
  - Sample rates: 8 kHz to 96 kHz
  - Channels: Mono/Stereo (hardware-dependent)
  - Encoding: PCM (WAV), AAC, or ALAC (M4A)

## Requirements

- iOS 26.0+
- Xcode 16.0+
- Swift 5.0+
- Microphone permission

## Architecture

The app is built with SwiftUI and follows a modular design:

- `RecordingView`: Full recording interface with spectrum analysis and settings
- `AudioRecorder`: Core recording engine using AVAudioEngine
- `AudioSettings`: Configuration models for audio format and quality
- `ContentView`: Simple launcher/home screen

## Integration

The recording interface can be easily integrated into any SwiftUI flow. See [CLAUDE.md](CLAUDE.md) for detailed integration examples.

## Audio Processing

- Uses `AVAudioEngine` for low-latency audio capture
- Real-time FFT processing with Accelerate framework
- Supports hardware sample rates (typically 48 kHz on iOS devices)
- Records in hardware's native channel format

## Files

Recordings are saved to the app's Documents directory with timestamps:
- Format: `rec_[timestamp].[extension]`
- Extensions: `.wav` (PCM), `.m4a` (AAC/ALAC)

## License

Created by Marius Mathiesen, 2026
