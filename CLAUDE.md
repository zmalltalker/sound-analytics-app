# Integration Guide

## Overview

`RecordingView` is a self-contained SwiftUI view that handles audio recording with a completion callback. It can be integrated into any navigation flow.

## Basic Integration

```swift
NavigationLink("Record Audio") {
    RecordingView { audioFileURL in
        // Handle completed recording
        processAudio(audioFileURL)
    }
}
```

## Integration Patterns

### As Navigation Destination
```swift
NavigationStack {
    VStack {
        NavigationLink("Start Recording") {
            RecordingView { url in
                handleRecording(url)
            }
        }
    }
}
```

### As Modal Sheet
```swift
.sheet(isPresented: $showRecorder) {
    NavigationStack {
        RecordingView { url in
            handleRecording(url)
            showRecorder = false
        }
    }
}
```

### In Tab View
```swift
TabView {
    RecordingView { url in
        uploadToAPI(url)
    }
    .tabItem {
        Label("Record", systemImage: "mic")
    }
}
```

## Callback

The completion handler receives a `URL` pointing to the recorded audio file:

```swift
RecordingView { audioFileURL in
    // audioFileURL points to Documents/rec_[timestamp].wav (or .m4a)
    // Use for: uploading, processing, playback, analysis, etc.
}
```

## Key Files

- **RecordingView.swift**: Complete recording UI with callback
- **AudioRecorder.swift**: Recording engine (AVAudioEngine)
- **AudioSettings.swift**: Audio format models
- **ContentView.swift**: Example integration

## Notes

- View auto-dismisses on completion
- Recording stops automatically when navigating away
- Permissions requested automatically on first use
- Hardware determines actual channel count (typically stereo)
