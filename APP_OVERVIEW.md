# Rich Sound Recorder App Overview

## Purpose

Rich Sound Recorder is an iPhone app used to collect, train, deploy, and run sound-based AI models on top of Expert Analytics' industrial AI platform.

The platform is used to detect patterns and anomalies in real-world operations, including:

- early signs of technical failure from sound signatures
- material weaknesses that later result in product failure
- characteristic sound patterns from industrial processes
- distinct acoustic signatures such as minerals in mining environments

In practical terms, the app connects field data collection and model usage on mobile:

- capture labeled audio for training
- trigger cloud training for project-specific models
- download trained model versions to the phone
- run local detection using the installed models

## Who The App Is For

The app is designed for professional users working with industrial sound intelligence, including:

- field engineers collecting training data on site
- operations teams monitoring equipment behavior
- domain experts defining labels and building project datasets
- technical specialists validating trained model versions
- pilot and deployment teams demonstrating AI-assisted detection in real environments

It is best suited for organizations that need a structured way to move from raw sound capture to deployable on-device detection.

## What The App Provides

## Core capabilities

- secure sign-in through Azure-backed authentication
- project-based organization of data and models
- label management for supervised sound classification
- configurable audio recording on the device
- upload of recorded audio clips to the backend platform
- readiness checks for whether a project has enough labeled data to train
- cloud training of new model versions
- download and install of trained model versions to the device
- local on-device detection using installed models
- model version management, including default-model selection and removal of on-device copies

## App sections

### Train

The Train workspace is where users prepare data and trigger training. It provides:

- current project context
- readiness status based on label coverage and recording counts
- a direct entry point to record audio
- access to cloud-trained model versions for the active project
- training status and progress feedback
- installation of the latest trained version to the device

### Detect

The Detect workspace is where users run local inference. It provides:

- selection of an installed model version for the active project
- device-side audio recording for detection
- inference on the recorded clip
- event-level results with time ranges and confidence values

### Models

The Models workspace is where users manage model versions available for the active project. It provides:

- visibility into cloud versions and on-device versions
- install of cloud versions to the phone
- default-model selection for detection
- removal of downloaded on-device model files
- visibility into storage use and label count per model

### Settings

The Settings workspace is where users manage account, setup, and app configuration. It provides:

- access to the signed-in account
- project management
- label management
- recording settings for future recordings

## The Different Modes And Situations In Which The App Is Used

## 1. Setup mode

Used when a team is preparing a new use case or onboarding a new project.

Typical activities:

- create a project
- create labels
- assign labels to the project
- choose which project is active
- configure recording settings appropriate to the environment

## 2. Data collection mode

Used when the user is in the field or on the production floor capturing examples for model training.

Typical activities:

- open the active project
- record audio examples
- tag each recording with the correct label
- upload clips to the backend dataset
- check whether enough labels now have audio

## 3. Training mode

Used when enough labeled data exists and the team wants to produce a new model version.

Typical activities:

- review readiness in the Train tab
- confirm that at least two labels have audio
- start a cloud training run
- monitor progress
- review newly available model versions

## 4. Deployment mode

Used when a trained model should be put onto the phone for practical use or testing.

Typical activities:

- open the Models tab
- install a cloud version to the device
- set the preferred default version
- keep only the versions needed on the device

## 5. Detection mode

Used when the user wants to apply a trained model to new sound captured on the phone.

Typical activities:

- choose the installed model version
- start listening
- stop recording when the event or sample is complete
- inspect returned detections and confidence values

## 6. Demonstration or validation mode

Used when showing the solution to customers, validating a model in the field, or comparing versions.

Typical activities:

- switch between projects
- install selected model versions
- run sample detections
- confirm that model outputs line up with expected sound events

## User Flows For Each Main Task

## 1. Sign in and enter the app

1. Open the app.
2. Complete Azure-based sign-in if not already authenticated.
3. After sign-in, the app opens the main workspace.
4. The app loads available projects, labels, and known model versions.

## 2. Create a project

1. Open `Settings`.
2. Open `Projects`.
3. Tap the `+` button.
4. Enter a project name and optional description.
5. Tap `Create`.
6. The project becomes available for selection in the app's project context.

## 3. Create a label

1. Open `Settings`.
2. Open `Labels`.
3. Tap the `+` button.
4. Enter the label name.
5. Optionally enter a description and duration in seconds.
6. Tap `Create`.
7. The label becomes available for assignment to projects and for upload selection.

## 4. Assign labels to a project

1. Open `Settings`.
2. Open `Projects`.
3. Select the target project.
4. In the `Labels` section, review available labels.
5. Tap `Assign` next to the labels that should belong to the project.
6. The project's label set is updated immediately.

## 5. Choose the active project

1. Open any workspace that shows the project header.
2. Tap `Switch` in the project context header.
3. Select the desired project in the project switcher.
4. The app reloads project-specific state such as labels, readiness, and model versions.

## 6. Configure recording settings

1. Open `Settings`.
2. Open `Recording settings`.
3. Choose microphone mode.
4. Choose sample rate.
5. Choose channel configuration.
6. Choose encoding format.
7. Leave the screen. The settings are persisted and used for future recordings in both training and detection.

## 7. Record and upload audio for training

1. Open the `Train` tab.
2. Confirm the correct active project in the header.
3. Tap `Record audio`.
4. Grant microphone permission if prompted.
5. Start recording.
6. Stop recording when the example is complete.
7. In the upload sheet, choose one of the labels assigned to the active project.
8. Tap `Upload`.
9. The app uploads the recorded file to the backend and updates the local readiness counts.

## 8. Check whether a project is ready for training

1. Open the `Train` tab.
2. Review the `Readiness` card.
3. Confirm:
   - the project has enough labels assigned
   - at least two labels already contain uploaded audio
   - each relevant label shows clip coverage
4. If readiness is incomplete, use the provided actions to either:
   - record more audio
   - go to label setup

## 9. Train a new model version

1. Open the `Train` tab for the target project.
2. Ensure readiness requirements are satisfied.
3. Start training from the training action on the page.
4. The app sends the training request to the cloud backend.
5. The app polls for status and shows progress updates.
6. When training completes, the newest version becomes available in the model-version list.

## 10. Install a trained model to the device

1. Open the `Train` tab or `Models` tab.
2. Identify the cloud model version you want on the device.
3. Tap the install action.
4. The app downloads the iOS model package and stores it locally on the phone.
5. If no default model exists yet for that project, the installed version can become the default automatically.

## 11. Review and manage model versions

1. Open the `Models` tab.
2. Review the active project's versions.
3. Use the interface to distinguish:
   - versions that exist only in the cloud
   - versions already installed on the device
   - the current default version
4. Install missing versions if needed.
5. Set a version as default for detection if needed.
6. Remove on-device copies you no longer need to free storage without deleting the cloud version.

## 12. Run detection on the device

1. Open the `Detect` tab.
2. Confirm the active project.
3. Choose the installed model version to use.
4. Tap `Start detecting`.
5. The app records a new clip using the current recording settings.
6. Stop the recording when the relevant sound segment is complete.
7. The app runs local inference against the selected installed model.
8. Review the returned events, including time ranges and confidence values.

## 13. Switch projects during detection

1. If detection is idle, tap `Switch` in the header and choose another project.
2. If recording is currently active, the app asks for confirmation before switching.
3. After switching, the Detect screen resets to the chooser state and loads models for the new project.

## 14. Sign out

1. Open `Settings` and then the profile area, or use the account entry point available in the UI.
2. Open the profile sheet.
3. Tap `Sign Out`.
4. The app clears the authenticated session and returns to the sign-in flow.

## End-To-End Example Scenarios

## Scenario A: Build a first model for a new industrial use case

1. Create a project for the use case.
2. Create the labels representing the target sound categories or anomaly classes.
3. Assign the labels to the project.
4. Record and upload examples for each label.
5. Wait until the Train screen shows readiness.
6. Start cloud training.
7. Install the resulting model version on the device.
8. Use the Detect tab to validate the model in a real environment.

## Scenario B: Update an existing deployed model

1. Switch to the existing project.
2. Record more examples for underrepresented labels.
3. Upload the new examples.
4. Start a new training run.
5. Install the new version when available.
6. Set the new version as default if it performs better.

## Scenario C: Run a field detection test

1. Switch to the correct project.
2. Open `Models` and confirm the desired version is installed.
3. Open `Detect`.
4. Select the model version.
5. Record a test sound sample.
6. Review detections and confidence scores.
7. Repeat with another model version if comparison is needed.

## Summary

Rich Sound Recorder is a mobile front end for Expert Analytics' industrial sound AI workflow. It supports the full path from structured sound collection to model training to on-device inference. The app is primarily used by technical and operational users who need a practical way to capture labeled audio in the field, create deployable models, and validate detections close to the asset or process being monitored.
