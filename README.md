# Rich Sound Recorder

`Rich Sound Recorder` is an iPhone app for:

- recording audio
- assigning a label before upload
- uploading the recording to the backend
- listing recordings returned by the backend
- browsing multiple versions of the same recording
- exporting backend audio data to `.wav`
- playing exported `.wav` files inside the app

## What The App Does

There are three main tabs:

- `Projects`
  Create projects, delete projects, and assign labels to a project.

- `Labels`
  Create labels and view existing labels from the backend.

- `Recordings`
  Record audio on the device, choose a label, upload the file, then browse recordings returned by the API.

## Recording Flow

The normal recording flow is:

1. Open the `Recordings` tab.
2. Tap `Start Recording`.
3. Record audio and stop the recording.
4. Pick a label in the upload sheet.
5. The app uploads the file and its timing metadata.
6. The backend recording appears in the recordings list.

## What You Can Do With Listed Recordings

For each recording returned by the backend, the app can:

- group versions by `data_id`
- show multiple backend versions of the same recording
- export a selected version to a local `.wav` file
- play that exported `.wav` file in the app

## Backend Notes

The backend is not plain JSON-only.

- Upload uses `multipart/form-data`
- Labels and projects use normal JSON APIs
- Recording listing currently comes back as Avro
- The app contains a focused Avro decoder for the recording list endpoint

The recordings list endpoint returns versioned records, so the app groups items by `data_id` and shows versions in a separate sheet.

## Main Files

If you need to find your way around the codebase, these are the most important files:

- [ContentView.swift](Rich%20sound%20recorder/Views/ContentView.swift)
  App entry flow. Decides whether to show login or the main app.

- [MainView.swift](Rich%20sound%20recorder/Views/MainView.swift)
  Main tab UI for projects, labels, and recordings.

- [RecordingView.swift](Rich%20sound%20recorder/Views/RecordingView.swift)
  The recording screen itself.

- [AudioRecorder.swift](Rich%20sound%20recorder/AudioRecorder.swift)
  Low-level audio recording engine using `AVAudioEngine`.

- [RecordingRepository.swift](Rich%20sound%20recorder/Repositories/RecordingRepository.swift)
  Uploads completed recordings.

- [RecordingListRepository.swift](Rich%20sound%20recorder/Repositories/RecordingListRepository.swift)
  Loads backend recordings and groups them by `data_id`.

- [RecordingWAVExportService.swift](Rich%20sound%20recorder/Services/RecordingWAVExportService.swift)
  Converts backend sample data into `.wav` files.

- [LabelRepository.swift](Rich%20sound%20recorder/Repositories/LabelRepository.swift)
  Lists and creates labels.

- [ProjectRepository.swift](Rich%20sound%20recorder/Repositories/ProjectRepository.swift)
  Lists, creates, deletes, and updates projects.

- [APIService.swift](Rich%20sound%20recorder/Services/APIService.swift)
  Shared authenticated HTTP client.

## Audio And File Notes

- Local recordings are saved in the app’s `Documents` directory.
- Exported backend recordings are also written to `Documents` as `.wav`.
- The app supports PCM, AAC, and ALAC recording.
- The backend recording list currently exposes a theoretical sample rate, and that value is used when exporting `.wav`.

## Requirements

- iOS 26.0+
- Xcode 16.0+
- Microphone permission
- Login access to the backend

## In Plain English

This app is a recorder plus a backend browser.

You can record something on the phone, tag it with a label, send it to the server, and later fetch server-side recordings back into the app, including different versions of the same recording. If the backend sends sample data, the app can turn that data back into a playable `.wav` file.

## License

Created by Marius Mathiesen, 2026.
