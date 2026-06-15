# Endpoint Notes

Supplementary backend notes that are not fully captured in `openapi.json`.

## `GET /projects/{project_uid}/available_model_versions`

- This endpoint should show a new model version once training has completed.
- It does **not** return the iOS/Core ML model artifact.

## `GET /projects/{project_uid}/get_ios_model`

Returns the trained project model converted to Core ML and streamed back as a binary ZIP archive.

- The response is a ZIP file.
- Unzipping it yields a standard Core ML package/folder structure.
- This endpoint performs the Core ML conversion on demand for the requested project model version.

### Required query parameters

- `model_version`: the trained model version to fetch.
- `sampling_rate`: the sampling rate used by the client device/input.
- `input_n_samples`: the exact input size in samples.

### Input size semantics

- `input_n_samples / sampling_rate` is the snippet duration.
- The duration must remain consistent for the converted iOS model.
- `input_n_samples` must be mathematically exact because the converted model expects a fixed-size input tensor.

### Why the query parameters matter

- The Python model can resample audio and pad/clip adaptively.
- The iOS/Core ML conversion uses model tracing.
- Because of tracing, dynamic branches/adaptive input handling are effectively fixed during conversion.
- That is why the backend must convert the model for a specific `sampling_rate` and `input_n_samples`.

### Inference contract

The client must:

- load audio samples,
- convert them into a waveform tensor,
- pass a rank-1 tensor of exact size `input_n_samples`.

The model output is:

- a rank-1 tensor,
- length equals the number of labels/classes,
- each element is the probability for a class.

### Label mapping

- Output tensor index corresponds to a project label using the mapping returned by `GET /projects/{project_uid}/model_specs`.

## `GET /projects/{project_uid}/model_specs`

### `trained_sample_size`

- `trained_sample_size` is the snippet length the model was trained on, expressed in number of samples.
- It indicates how much padding/clipping may happen conceptually relative to training.
- Current backend guidance: it does not matter much right now because the model only picks one time interval out of the whole snippet.
- Practical implication: as long as the client does not lie about `sampling_rate` or input length, inference should work.

## Provenance

These notes are based on direct backend clarification and should be treated as a companion to the OpenAPI spec, not a replacement for it.

## `POST /data_upload/single`

The OpenAPI spec only documents multipart fields:

- `file`
- `metadata`

### Timestamp clarification

- `audio_end_timestamp` does not need to be provided for the current app flow.
- If `audio_start_timestamp` / `audio_end_timestamp` are omitted, the endpoint will use `start_timestamp` and `end_timestamp`.
- `audio_start_timestamp` and `audio_end_timestamp` are only needed when the uploaded audio is padded relative to the labeled interval.
- Current backend guidance: we are not doing padded-audio uploads right now.

### Important field names

- For `POST /data_upload/single`, use `start_timestamp` and `end_timestamp`.
- Do **not** use `start` and `end` for this upload endpoint.
- This endpoint has two timestamp sets for future development; the correct pair for current uploads is `start_timestamp` / `end_timestamp`.
- This naming rule is specific to the upload endpoint.
- The `data_download` endpoints still use `start` and `end`.
