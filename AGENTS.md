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

---

## API

The OpenAPI spec is at `openapi.json` in the project root. Read it before working on API-related tasks — note that it is incomplete (some request body schemas are missing or wrong) so cross-reference with the gotchas below.

Base URL: `https://webrecorder.rest.dev.edgeaudioanalytics.no/rest/`

All requests use Bearer token auth via `AuthenticationService`.

### Architecture

- `APIService` — low-level HTTP client (GET/POST), created internally by repositories
- Repositories take `AuthenticationService`, create their own `APIService`
- Models are `Codable` and shared between requests and responses
- Models live in `Models/`, one file per model
- Repositories live in `Repositories/`

### Gotchas

- **UUIDs must be lowercased** — Swift's `UUID().uuidString` is uppercase by default, the API rejects it. Always call `.lowercased()`.
- **`Label` conflicts with SwiftUI** — the model is named `RecorderLabel`
- **Some endpoints use Avro serialization** — the upload endpoints (`/data_upload/annotated_snippets`, `/labels/create` originally) use Avro. We are negotiating JSON support with the backend team.
- **`/labels/create` expects a JSON array**, not a single object
- **`RecorderLabel` has both `uid` and `guid`** — they must be the same value; `guid` is likely a legacy field

### Models

**`RecorderLabel`**: `uid`, `guid` (same value), `name`, `user_id` (from `/whoami` oid), `description`, `duration` (Double, seconds)

**`Project`**: `uid`, `name`, `description`, `owner_uid` (from `/whoami` oid), `labels` (`"[]"`), `guests_uids` (`"[]"`), `input_download_response` (optional)

**`User`** (from `GET /whoami`): `oid`, `email`, `name`

### Endpoints

| Method | Path | Notes |
|--------|------|-------|
| GET | `whoami` | Returns `User` |
| GET | `projects/list` | Returns `[Project]` |
| POST | `projects/create` | Body: single `Project` |
| POST | `projects/{uid}/delete` | No body |
| GET | `labels/get` | Returns `[RecorderLabel]` |
| POST | `labels/create` | Body: `[RecorderLabel]` (array!) |
