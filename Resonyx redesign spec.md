# Resonyx — Redesign Implementation Spec

Companion to the hi-fi screens (`Sound App Hi-Fi.dc.html`). The PDF/screens carry layout intent; **this document is the source of truth for behavior, priorities, copy, and edge cases.** Where the two disagree, follow this document and flag it.

---

## 0. Global rules (apply to every screen)

**Goal:** Reorganize the app around the two actions users actually perform — **Train** and **Detect** — and make setup (projects, labels) recede.

**Information architecture**
- Four tabs only: **Train · Detect · Models · Settings**. No nested tab bars, no "More".
- Projects and Labels move *out* of the tab bar into **Settings → Setup**.

**Sticky context**
- A persisted **active project** is shown in the header on Train, Detect, and Models. It survives app restarts (store the selected project id).
- Detect additionally shows the **active model version** in the header subtitle (e.g. `v3 · on device`).
- The header **Switch** control opens the project switcher sheet (see Screen 02) from anywhere it appears.
- Home and Settings have **no** context header.

**Color semantics — do not break these**
- **Orange (`#E87951`) = action / operation:** primary CTAs, record/stop, install, in-progress operations.
- **Blue (`#68CDFF`) = analysis / selection:** waveform selection windows, detection markers, selected rows, verified states, the default-model star.
- Never use orange as a generic "make it pop" fill; never use blue as a global brand accent.

**Visual consistency (holds across all screens)**
- System font (SF Pro). Monospaced (SF Mono) **only** for technical metadata: timestamps, version tags (`v3`), sizes (`12 MB`), confidence (`94%`), label-count strings.
- Dark navy background; content panels are **more solid** than chrome. Liquid-glass material is reserved for chrome only (header, tab bar, sheets, the Switch capsule).
- One primary (orange) action per screen, maximum.
- Radii: large cards 20–24, rows 14–16, capsules native. No oversized pills.

---

## 1. Home / Launch

**Goal:** Orient the user to their current project and route them into Train or Detect in one tap. Not onboarding, not a dashboard.

**Required changes**
- New screen; becomes the app's default landing surface.
- Shows `Working in` + active project name + **Switch**.
- Two task rows: **Train** ("Record & improve a model") and **Detect** ("Listen & label live sound").
- Secondary status row at the bottom: on-device model count + total storage, tapping it opens the **Models** tab.

**Interaction details**
- Tapping **Train** → Train tab (Screen 04). Tapping **Detect** → Detect tab (Screen 09, model chooser).
- **Switch** opens the project switcher sheet (Screen 02).
- If no project exists yet, the project name area becomes a "Create your first project" affordance routing to Settings → Projects.

**Stay visually consistent**
- Train row carries a faint **orange** edge/icon tint; Detect a faint **blue** one — these are accents, not fills.
- Rows are tasks, not marketing tiles: title + one-line description + chevron.

---

## 2. Switch project (sheet)

**Goal:** Change the active project from anywhere, with enough info to choose well.

**Required changes**
- Presented as a native bottom sheet (dark glass material) with a grabber.
- Each row: project name + mono metadata (`N labels · vX on device` / `vX cloud` / `not ready`).
- `+ New project` row at the bottom.

**Interaction details**
- Single-select. Tapping a row sets the active project and dismisses the sheet; the header updates immediately.
- The currently active project is shown selected (blue radio + subtle blue row tint).
- `+ New project` pushes the project-create flow (Settings).
- Reachable from the header **Switch** control on Train, Detect, Models.

**Edge cases**
- A project with `0 labels` shows `not ready` and is still selectable (the user may be setting it up).
- Switching project while a Detect session is active: stop the session first, then switch (or block with a confirm — implementer's call, but do not silently swap the running model).

**Stay visually consistent**
- Selected row uses the **blue** selection accent. Rows sit more solid than the sheet behind them. One tint color in the sheet only.

---

## 3. Settings

**Goal:** Hold account + the demoted setup (Projects, Labels) and app preferences.

**Required changes**
- Move Projects and Labels here, grouped under a **Setup** header.
- Account row (name, "Signed in via Azure").
- **App** group: Recording quality, Notifications.

**Interaction details**
- `Projects` → list (Screen 12 in the wireframes / your existing project list); `Labels` → label management.
- Standard iOS grouped-list navigation (push).

**Stay visually consistent**
- Grouped lists on solid dark cards; mono for the count badges (`4`, `12`).

---

## 4. Train — Readiness

**Goal:** Tell the user at a glance whether the project is ready to train, and let them either **add more labeled data** (primary) or **kick off a training run** (secondary).

**Required changes**
- Replace today's stacked per-label recording-count list with a single **Readiness** card.
- Readiness card lists check items with satisfied / unsatisfied states and an overall `READY` / `NOT READY` badge.
- **Action priority (important):**
  - **Primary (orange): `Record audio`** — opens recording to capture & label new training data.
  - **Secondary (glass): `Train new version from uploads`** — starts a cloud training run from data already uploaded.
- Show the latest existing version inline (`Latest: v3 · trained 2 days ago`).

**Interaction details**
- Each unsatisfied readiness item should offer an inline fix (e.g. `"Alarm" has no clips yet → Add`).
- `Train new version from uploads` is enabled only when readiness = READY; when NOT READY, disable it and surface the blocking item. `Record audio` is always enabled.
- Starting a training run → Screen 05.

**Edge cases**
- 0 labels assigned → readiness NOT READY, training disabled, primary action still `Record audio` (but consider routing to label setup first).
- A label with no audio is a soft warning, not a hard block, unless your backend requires ≥1 clip per label — mirror the backend rule here.

**Stay visually consistent**
- Readiness card is a solid instrument panel. Satisfied checks use **blue** (verified); unsatisfied are muted outline rings. Exactly one orange button.

---

## 5. Train — Training (live)

**Goal:** Show cloud training progress and let the user leave without losing the run.

**Required changes**
- Stepper: Uploading data → Preprocessing → Training model → Packaging for device. Current step highlighted.
- Progress bar + `~N min remaining`.
- `Leave running` secondary action.

**Interaction details**
- Training runs server-side; the screen polls/streams status. Leaving the screen or backgrounding the app does **not** cancel the run.
- On completion, the version becomes installable (Screen 06 / Models).
- **Push notification on completion is explicitly out of scope for now** — do not build it. Copy must therefore *not* promise a notification. Current copy: "Training continues in the cloud if you leave — come back to Train any time to check progress." When the user returns to the Train tab and a run finished, show the install state (Screen 06).

**Edge cases**
- Training failure: show an error state with a `Retry` action; keep the previous version intact.
- Re-entering Train while a run is in progress should resume on this live screen, not restart training.

**Stay visually consistent**
- Instrument panel, **orange** = operation-in-progress (current step ring + progress fill). No glow halos.

---

## 6. Train — Trained → Install

**Goal:** Make installing the freshly trained version the obvious next step.

**Required changes**
- Summary card: `vX · READY` badge, "New model version trained", metadata chips (labels, samples, ~size).
- **Primary (orange): `Install on this device`**.
- Secondary: `View in Models`.

**Interaction details**
- Install downloads the device model package (~size shown); show progress, then a success state.
- After install, offer to set it as the default for Detect (or auto-set if it's the first installed version for the project).
- `View in Models` → Models tab scoped to this project.

**Edge cases**
- Install interrupted (network/offline): keep the version in `CLOUD` state, allow retry from Models.
- Works offline once installed — state copy says so.

**Stay visually consistent**
- One orange CTA. Metadata in mono chips. Card is a solid panel.

---

## 7. Models — Versions (per project)

**Goal:** One place for the whole model lifecycle for the **active project**: see versions, set the default, install cloud versions, and (via Edit) remove downloads.

**Required changes**
- **Scope the list to the active project only.** Do not show other projects' models here.
- Each row: version tag (`v4`), date, size (if on device), state badges, and a trailing control.
- State badges: `CLOUD`, `ON DEVICE`, `DEFAULT`.
- Trailing controls by state:
  - **Cloud (not installed):** orange circular **`+`** to install.
  - **On device, default:** filled **★** (blue).
  - **On device, not default:** outline **☆** → tap to make default.
- Top-right **`Edit`** button enters remove mode (Screen 08).
- Footer: `On device: N versions · total MB`.

**Interaction details**
- **★ / ☆ sets the project's default model version** used by Detect. Exactly one default per project. Tapping ☆ on another version moves the default to it.
- Tapping **`+`** installs that cloud version (download progress on the row); on success it gains `ON DEVICE`.
- `Edit` → Screen 08.

**Edge cases**
- Only **on-device** versions can be set as default; cloud versions show `+` (install first).
- If no version is installed yet, there is no default; Detect will prompt to install/choose.

**Stay visually consistent**
- The default/active marker is the **★** (blue) — this replaces the old generic "ACTIVE" tag. Install affordance is the orange `+`. Rows are solid panels; badges are compact mono.

---

## 8. Models — Edit / Remove

**Goal:** Remove a downloaded model following standard iOS conventions. **Removal deletes only the on-device copy** — never the cloud-trained version.

**Required changes**
- Entered via `Edit` (top-right toggles to `Done`).
- Installed rows show the iOS red **`−`** affordance; revealing a red **`Remove`** action (swipe-to-delete equivalent also acceptable).
- Cloud-only versions are **dimmed / non-removable** in this mode (nothing local to delete), labeled `CLOUD · NOT ON DEVICE`.
- Persistent explanation: "Removing deletes only the on-device copy and frees space. The trained version stays in the cloud — re-install any time."

**Interaction details**
- `Remove` deletes the local package and frees its storage; the row returns to `CLOUD` state with a `+` once `Done` is tapped.
- **If the removed version was the project's default:** clear the default. Detect then falls back to "choose a model" (Screen 09) on next entry — do not auto-promote another version silently; let the user pick, or auto-select only if exactly one on-device version remains.
- Swipe-to-delete on a row (outside Edit mode) is an acceptable shortcut for the same action.

**Edge cases**
- Removing the model currently selected in an active Detect session: block until the session ends, or stop the session first.
- Confirm destructive remove only if it's the default or last on-device copy; otherwise a single tap is fine (it's re-installable).

**Stay visually consistent**
- Standard iOS red (`#E5484D`) for delete affordances only — this red is *not* part of the brand palette and must not be reused decoratively. Orange/blue semantics unchanged elsewhere.

---

## 9. Detect — Choose model

**Goal:** Pick which installed model version runs, then start detecting. Practical, no decoration.

**Required changes**
- **Scope to the active project's on-device versions only.** Do not list other projects or cloud-only versions here.
- Header: `DETECT WITH` + project name + `Choose a version`.
- Rows: `Version N`, label count + size; the **default (★)** is preselected.
- Helper line: "Showing versions of *{project}* installed on this device. Switch project in the header to detect with another."
- **Primary (orange): `Start detecting`**.

**Interaction details**
- Single-select; the project default is selected on entry.
- Selecting a row updates the choice (blue selection state) but does not start detection — `Start detecting` does.
- The chosen version persists into the active context (header subtitle on the listening/results screens).

**Edge cases**
- **No on-device versions for this project:** replace the list with an empty state — "No models installed for this project" + a button to Models (to install) or Train (to create one). `Start detecting` is hidden/disabled.
- Exactly one installed version: preselect it; user can go straight to Start.

**Stay visually consistent**
- Selected row uses **blue**; `Start detecting` is the single orange action. Mono for size/label metadata. The ★ matches the Models default marker.

---

## 10. Detect — Listening (live)

**Goal:** A focused live-capture surface. Recording activity is the centerpiece.

**Required changes**
- Solid dark instrument panel containing: a `● Listening` indicator, a live level/waveform meter, the elapsed `MM:SS` timer, and a hint ("Tap stop to see detected events").
- Single action: **`Stop`** (orange).

**Interaction details**
- Recording is an **action** → the live meter and indicator are **orange**.
- Timer counts up from `00:00`. `Stop` ends capture and transitions to results (Screen 11).
- Keep the screen sparse — no extra copy, no per-event cards while listening.

**Edge cases**
- Mic permission denied → standard iOS permission prompt / settings deep-link before this screen.
- Interruptions (call, route change): pause/stop gracefully and preserve what was captured.

**Stay visually consistent**
- Waveform stays inside the panel bounds with a stable baseline. Glow is faint ambient only, behind the meter — never a hard halo. Timer in mono.

---

## 11. Detect — Detected events (results / timeline)

**Goal:** Read detection results analytically: a waveform timeline with highlighted event regions tied to a compact event list. This mirrors the existing app's timeline view.

**Required changes**
- Header block: "Latest detection" + timestamp; trailing **`Record again`** (orange) to start a new capture.
- **Analysis panel (solid, dark):** the recorded waveform with **blue selection windows** framing each detected event, and **blue numbered marker chips** summarizing counts above the waveform. Time axis labels at the panel's edges.
- **Event list:** one row per event — blue numbered marker, label name, mono time range, mono confidence `%`. The marker number ties the list row to its highlighted region on the waveform.

**Interaction details**
- Tapping a marker chip or list row highlights/scrolls to that region on the waveform (selection emphasized).
- Selection windows must be **proportional to the actual event duration** and positioned at the real time offset — not mechanically centered or stretched to fill the chart.
- `Record again` → listening screen (Screen 10).

**Edge cases**
- No events detected → keep the waveform panel, show "No labeled events found" in the list area; still offer `Record again`.
- Many events: list scrolls; the waveform stays fixed at the top as the dominant analysis surface.
- Overlapping events: stack/offset markers so numbers stay legible.

**Stay visually consistent**
- **All analysis elements are blue**; markers/selection windows never use orange. Confidence is present but quieter than the event label (the label is what the eye lands on first). The numbered-marker style is shared between the waveform chips and the list rows.

---

## Decisions log (context for the above)

- **Tab-based IA** (Train · Detect · Models · Settings) with a **sticky, switchable active project**, confirmed over a hub-only or adaptive model.
- **Models default** is chosen via **★**, one per project; it pre-selects in Detect.
- **Remove** is local-only, via iOS **Edit** mode; cloud versions are never deleted from the app.
- **Push notifications** for training completion are a parked idea, **not in this scope**.
- Visual direction: dark "audio instrument" surface, **orange = action / blue = analysis**, liquid-glass chrome over solid content panels, SF Pro + mono metadata.

## Out of scope (parked)
- Push notification on training completion.
- Save/Share of a detection clip (was in an early wireframe; removed — revisit later if needed).
- Cross-project model browsing inside the Models tab (Models is per active project by design).
