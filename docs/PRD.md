# Product requirements document — Loopline

Status: validation draft  
Owner: product / iOS engineering  
Date: 15 August 2026  
Platform: iPhone only; portrait-first  
Baseline: iOS 18+, with optional iOS 26 enhancements  
Working name: Loopline

## 1. Product summary

Loopline is an offline multi-track music-video studio for iPhone. It lets musicians record a part, hear it while recording the next part, tune the timing and mix, arrange the video tiles, and save a finished result directly to the device.

The app recreates the useful part of the Acapella experience—one-person choir, layered instruments, synchronized video frames—while removing the social network and arbitrary product limits. A project is a local document. No account, network connection, cloud project, feed, upload, recommendation, or mandatory subscription is needed to create, edit, render, or share the result.

### Product promise

> Record as many parts as your device can hold. Keep every take. Align them with confidence. Export a finished video and high-quality audio file without leaving the device.

## 2. Goals and non-goals

### Goals

- Make a polished two-track performance possible in one sitting with an iPhone and headphones.
- Make the core flow comfortable on a portrait iPhone screen between 390 and 430 pt wide, with one-handed transport controls and bottom-sheet detail panels.
- Support unlimited projects and tracks in software; resource limits are based only on device capability, storage, memory, thermal state, and codec support.
- Record video and audio per track, with prior tracks available as monitored playback.
- Provide a reliable click/metronome with count-in, meter, subdivisions, accents, tap tempo, and project tempo persistence.
- Make timing visible and correctable through waveforms, automatic alignment, confidence, and manual offset controls.
- Provide a deterministic offline mixer with volume, pan, mute, solo, gain, EQ, gate, compressor, limiter, and optional reverb.
- Support flexible grids and aspect ratios without locking the user into an initial layout.
- Export a mixed video, audio-only mix, individual stems, and a portable local project package.
- Save to Photos and Files and use the iOS share sheet only after a local file exists.
- Make interruptions, low storage, route changes, and failed renders recoverable and understandable.

### Non-goals for v1

- Social feed, profiles, likes, follows, public discovery, comments, messaging, or cloud collaboration.
- Network accounts, mandatory login, online project sync, remote rendering, or analytics that require connectivity.
- Capturing or bypassing DRM/protected audio from streaming services.
- Full general-purpose video editing: transitions, keyframes, multicam live switching, captions, green screen, and color grading are later considerations.
- iPad, Mac Catalyst, Android, and web-native production builds are out of scope for v1. The HTML file is only a validation mock for the iPhone UI.
- Pitch correction, AI separation, generative music, or automatic arrangement as a dependency for the core workflow.
- Guaranteed background rendering after the user leaves the app. Rendering may be checkpointed and retried; foreground completion is the reliable path.

## 3. Target users and jobs

### Primary user: one-person ensemble creator

A singer, beatboxer, instrumentalist, or musician who wants to make a layered performance alone, with a visual tile for each part.

Job: “Let me build a convincing multi-part performance from my phone without having to learn a desktop DAW or a video editor.”

### Secondary user: choir / band rehearsal creator

A group member who records guide and practice parts, shares a local render to others, and may export stems for another editor.

Job: “Let me create a clear rehearsal or performance reference that can be shared as a file, even in a room with poor connectivity.”

### Tertiary user: mobile musician

Someone using an external USB interface or microphone and caring more about capture quality and timing than social features.

Job: “Let me use the hardware I already own, monitor safely, and keep the original-quality tracks.”

## 4. Success metrics

These are launch-quality targets to validate during TestFlight; they are not claims about the current prototype.

### Usability

- 90% of first-time testers can create and save a two-track, 60-second video without a tutorial.
- Median time from install to first committed take is under 60 seconds after permissions are granted.
- 80% of testers understand the difference between “recorded locally” and “saved to Photos/Files.”
- No task requires sign-in or an online connection.

### Timing and audio quality

- For sequential takes made on one device with wired/USB monitoring, automatic alignment produces a median audio onset error ≤10 ms and P95 ≤20 ms on the supported test set.
- Video tile start times remain within one output frame of the project timeline after render.
- Preview and export use the same offsets, mute/solo state, gain, pan, and effect order.
- A completed export has no unintended clipping; master true peak target is ≤−1 dBTP.

### Reliability

- ≥99.5% crash-free capture sessions in internal dogfood.
- ≥99% successful renders for supported input assets and presets.
- App survives route change, interruption, force-quit/relaunch after a committed take, and low-storage preflight without losing the project manifest.
- Airplane-mode test passes for project creation, import from local Files/Photos, capture, edit, render, save to Files, and save to Photos.

### Product health

- No artificial limit on track count, recording length, layout count, or audio export quality.
- A visible preflight estimate predicts approximate storage use before long capture or render.
- A project can be copied as a single editable package and reopened on another compatible device through Files/AirDrop.

## 5. Core experience

### 5.1 Project library

On launch, show local projects in a compact iPhone list with title, last edited time, duration, track count, storage used, and latest render status. The library must work with no network.

Actions:

- New project.
- Duplicate project.
- Rename.
- Export project package.
- Import project package.
- Delete with confirmation and optional “keep rendered exports” choice.

### 5.2 New project setup

Required setup is intentionally short:

1. Title.
2. Audio rate: Auto / 48 kHz / 44.1 kHz (default Auto chooses 48 kHz when supported).
3. Video target: Auto / 1080p / 4K where supported.
4. Aspect ratio: 16:9, 9:16, 1:1, 4:5, 4:3, or custom later.
5. Tempo, meter, click sound, count-in, and starting guide choice.

The user may skip layout selection. Layout is editable at any time.

Preflight checks:

- microphone permission;
- camera permission;
- Photos permission only when the user chooses Photos import/save;
- available storage and estimated capture/render footprint;
- active audio route and latency;
- device thermal/pressure state;
- supported camera format and codec.

### 5.3 Capture / overdub

The capture screen is the product’s highest-value surface.

The stage shows the current camera preview and a low-resolution preview of committed tracks. The timeline shows the project playhead, beat markers, count-in, and current take range. Previous tracks can be heard while the new track is recorded; they are not re-recorded into the new track’s file.

Controls:

- record / stop / pause;
- count-in on/off and count-in length;
- click on/off, click volume, subdivisions, accent pattern;
- project tempo and meter;
- monitor level and active input route;
- front/back camera, mirror preview, orientation lock;
- take name and color;
- retake current track, commit take, discard take;
- punch-in / punch-out on a selected time range (P1 if needed for MVP validation);
- re-record a track without deleting the old take.

When the user starts recording, the audio engine schedules the count-in and click by sample time. The capture session starts against a project clock anchor. Each audio/video sample buffer retains its presentation timestamp. UI timers are display-only.

### 5.4 Mix and sync

The mixer is a track-based timeline with a stage preview.

Each track has:

- name, color, thumbnail, and source duration;
- waveform with zoom from overview to millisecond-scale adjustment;
- trim start/end;
- offset in milliseconds and frames;
- volume/gain and peak meter;
- pan;
- mute and solo;
- processing preset and advanced controls;
- video tile visibility, order, crop, fill/fit, mirror, and tile label.

Sync Assist runs on demand or after a take is committed. It compares a bounded region of the take against the chosen guide/reference mix, detects onset/correlation, recommends an offset, shows confidence, and lets the user accept, reject, or manually nudge. It must not silently time-stretch a performance.

For imported clips from another device, an advanced “drift compensation” option may apply a small linear resample when the start aligns but the end drifts beyond the configured tolerance. The user sees the applied percentage and can undo it.

### 5.5 Preview

Preview must use the same composition model as export, at proxy resolution while editing. It should show:

- stage layout;
- mixed audio;
- playhead and beat markers;
- solo/mute changes;
- title/logo overlay if enabled;
- safe-area framing for the chosen aspect ratio.

If the preview falls back to proxies, show a small “Preview quality” status; do not imply the final render has been degraded.

### 5.6 Export and share

Export is a local render job with a visible queue/status record.

Video presets:

- H.264 MP4 — compatibility default, 720p/1080p/4K where supported;
- HEVC MOV or MP4 — smaller file, recommended for local storage;
- ProRes — later, only on compatible devices and with a clear storage warning.

Audio presets:

- AAC M4A — compact;
- Apple Lossless M4A — lossless stereo mix;
- WAV — PCM stereo mix;
- individual stems — one file per track;
- project package — editable local source bundle.

Save destinations:

- Photos library;
- On My iPhone in Files;
- user-selected Files destination;
- system share sheet after the file has been closed and verified.

The completion state must show the filename, duration, file size, codec, resolution, audio format, and the exact destinations confirmed. It must never report “shared” when only a render exists.

## 6. Functional requirements

Priority: P0 = required for first usable release, P1 = high-value follow-up, P2 = later.

### Offline and data ownership

- OFF-01 (P0): Create, open, rename, duplicate, edit, render, and delete projects with no network connection.
- OFF-02 (P0): Do not require an account, login, subscription validation, or remote service for any core action.
- OFF-03 (P0): Store project manifest, source media, waveforms, proxies, render jobs, and completed exports in local app storage.
- OFF-04 (P0): Copy imported source media into the project package; a temporary external URL must not be the only reference.
- OFF-05 (P0): Provide “Export project package” and “Import project package.”
- OFF-06 (P0): Never upload media or project metadata. Optional diagnostics must be local-only unless the user explicitly exports a diagnostic bundle.
- OFF-07 (P0): If a chosen Files provider requires network access, explain that the app remains offline but the provider may not; recommend “On My iPhone” for strict offline storage.

### Capture

- CAP-01 (P0): Record a video and audio take from the selected camera/microphone route.
- CAP-02 (P0): Record one track at a time while previously committed tracks play back.
- CAP-03 (P0): Record an audio-only track with the camera disabled.
- CAP-04 (P0): Support front/back camera selection, preview mirroring, orientation, stabilization where available, and camera format preflight.
- CAP-05 (P0): Show live input meter, clipping warning, route name, sample rate, and approximate input/output latency.
- CAP-06 (P0): Preserve a stopped/paused take as a recoverable draft until the user commits or discards it.
- CAP-07 (P0): Auto-save the manifest before and after capture and on app lifecycle transitions.
- CAP-08 (P0): Provide retake without destroying the previous take; old takes are versioned or moved to a recoverable bin.
- CAP-09 (P1): Punch-in/out recording on an existing track with comp/take selection.
- CAP-10 (P1): External USB microphone/interface input selection and channel mapping.

### Timing and metronome

- TIME-01 (P0): Use one project timebase for audio, video, click, waveform, and export.
- TIME-02 (P0): Schedule count-in and click from sample/host time, never `Timer`/UI frame callbacks.
- TIME-03 (P0): Support BPM, tap tempo, common and asymmetric meters, subdivisions, accent patterns, click sounds, click volume, and count-in length.
- TIME-04 (P0): Store tempo/meter changes in the project manifest and apply them consistently to capture and playback.
- TIME-05 (P0): Account for active route latency in guide playback and show a monitoring recommendation.
- TIME-06 (P0): On route change or interruption, pause safely, preserve the project, and explain what happened.
- TIME-07 (P1): Support tempo maps and gradual tempo changes.
- TIME-08 (P1): Support Bluetooth foot-pedal or keyboard shortcuts for hands-free record/stop.
- TIME-09 (P2): Optional MIDI clock/Ableton Link sync; never required for offline use.

### Sync and edit

- SYNC-01 (P0): Display a waveform for every audio-bearing track.
- SYNC-02 (P0): Provide automatic alignment against a guide/reference track with confidence and an undoable recommendation.
- SYNC-03 (P0): Provide coarse offset nudge in frames/milliseconds and fine nudge at sample-derived precision.
- SYNC-04 (P0): Trim a track without altering the source asset.
- SYNC-05 (P0): Preserve the original take and all edit decisions in the manifest.
- SYNC-06 (P0): Support mute, solo, volume/gain, pan, and per-track audio processing.
- SYNC-07 (P0): Allow layout and tile order to change after any number of takes.
- SYNC-08 (P0): Support tile fit/fill, crop, mirror, aspect-ratio framing, background, border, and optional local logo.
- SYNC-09 (P1): Detect likely sync drift in imported clips and offer small resample compensation.
- SYNC-10 (P1): Provide snap-to-beat and snap-to-waveform-onset options without preventing free movement.

### Mix and processing

- MIX-01 (P0): Mix preview and export use identical track offsets and controls.
- MIX-02 (P0): Include a master limiter and true-peak/clipping preflight.
- MIX-03 (P0): Include built-in high-pass/low-cut, EQ, noise gate, compressor, and reverb presets.
- MIX-04 (P0): Provide bypass per effect and a reset-to-source action.
- MIX-05 (P1): Host AUv3 effects when the user chooses to install them.
- MIX-06 (P1): Render stems with effects bypassed or applied according to explicit export choice.

### Export and local sharing

- EXP-01 (P0): Render a mixed grid video with a selected aspect ratio and layout.
- EXP-02 (P0): Render audio-only AAC/M4A and lossless ALAC; WAV is required for the first high-quality release if feasible.
- EXP-03 (P0): Save final video to Photos after permission and to Files locally.
- EXP-04 (P0): Present the system share sheet only with a verified local file URL.
- EXP-05 (P0): Show render progress, estimated remaining work, cancel, failure reason, retry, and output cleanup.
- EXP-06 (P0): Write export metadata: title, duration, codec, resolution, audio format, sample rate, and project identifier.
- EXP-07 (P0): Check free storage before render and keep source files until export verification succeeds.
- EXP-08 (P0): Write render checkpoints or a resumable job state so an interrupted render can retry without corrupting the source project.
- EXP-09 (P1): Batch render multiple formats and stem bundles.
- EXP-10 (P1): Custom filename template and metadata fields.

## 7. Timing and sync design

### Authoritative timeline

The project timeline uses `CMTime` with a stable timescale and a 48 kHz audio domain where possible. Every track stores:

- source asset URL inside the package;
- source media duration and format;
- project start offset;
- trim range;
- optional drift-compensation ratio;
- capture route and timing diagnostics;
- video transform and tile placement;
- audio mix parameters.

The audio engine owns live playback and click scheduling. Capture sample buffers carry their own presentation timestamps. The UI derives the playhead from the engine/media time. The renderer derives both audio and video output from the manifest, not from the preview’s wall-clock history.

### Count-in and click

1. Preflight the active route and configure `AVAudioSession`.
2. Create one audio-engine graph for click, prior-track playback, monitoring, and metering.
3. Convert the project start beat to sample time.
4. Schedule the count-in and click buffers with `AVAudioPlayerNode` at exact sample times.
5. Start the engine and capture session against a shared anchor.
6. On stop, finalize buffers, flush the writer, and record the take’s exact start/end timestamps.

The default user experience should expose a simple “1–2–3–4” count-in, but the engine must support arbitrary meters and subdivision patterns. A visual beat indicator is a companion cue, never the timing authority.

### Latency policy

Monitoring latency is route-specific. The product must never imply that all Bluetooth routes are equivalent to wired monitoring. Capture policy:

- wired headphones / USB interface: “Best for overdubbing”;
- supported high-quality Bluetooth route: “Usable; latency compensated/measure before take”;
- ordinary Bluetooth hands-free route: “Playback latency may affect timing; use wired/USB for tight overdubs”;
- no headphones: “Speaker disabled or echo risk; use headphones to prevent guide bleed.”

The first take can include an optional calibration pulse. The app records route values, measured round-trip result if available, and the user’s correction. The correction is per route/device and can be reset.

### Automatic alignment

For a new audio-bearing take:

1. Convert the take and reference to a mono analysis buffer at a fixed rate.
2. Remove leading silence only for analysis; do not modify the source.
3. Compute onset/energy envelope and normalized cross-correlation within a safe offset window.
4. Return a proposed offset, confidence score, and analysis range.
5. Apply only after confirmation or an explicit auto-align setting.
6. Keep manual nudge and undo available.

For imported media from another device, the user can run an end-to-end drift check. If drift exceeds tolerance, offer a non-destructive resample, display the ratio, and preserve the source.

## 8. Native architecture recommendation

### Modules

- `ProjectStore`: local document package, manifest versioning, atomic writes, recovery, storage estimates.
- `CaptureCoordinator`: `AVCaptureSession`, camera/mic permissions, route changes, format selection, sample-buffer timestamps.
- `AudioClock`: `AVAudioSession`, `AVAudioEngine`, click scheduler, route latency, interruption handling.
- `TakeRecorder`: `AVAssetWriter` inputs for video/audio, draft recovery, thumbnail/proxy generation.
- `WaveformIndex`: downsampled peaks/RMS/envelope, cached by asset checksum.
- `SyncEngine`: onset detection, correlation, confidence, nudge, drift compensation.
- `MixGraph`: preview and offline graph; built-in effects and per-track parameters.
- `VideoLayoutEngine`: tile geometry, crop/fill/mirror, aspect ratio, borders, overlays.
- `RenderQueue`: preflight, composition construction, checkpointed export, cleanup, verified output.
- `ShareCoordinator`: Photos, Files, and `UIActivityViewController` integration.

### Capture/write strategy

For the sequential take path, configure a standard capture session and write video/audio sample buffers to a local QuickTime asset. Keep the audio as a high-quality source and generate a proxy for preview. On iOS versions/configurations where custom processing is needed, use `AVAssetWriter` rather than treating a convenience movie file as the only source of truth.

### Mix/render strategy

1. Load the project manifest and validate every source asset.
2. Build the audio graph at the project sample rate.
3. Apply track offsets, trim ranges, gain, pan, and effects.
4. Offline-render the mixed audio to an intermediate lossless file using `AVAudioEngine` manual rendering or an equivalent deterministic renderer.
5. Build the video composition with one layer instruction per visible tile.
6. Mux the rendered audio with the video composition through AVFoundation.
7. Verify duration, dimensions, audio presence, peak level, and file readability.
8. Atomically move the verified output to the project’s Exports directory.

### Local package layout

```text
MySong.loopline/
  project.json
  Assets/
    takes/<take-id>.mov
    imported/<asset-id>.<ext>
  Proxies/
    <take-id>.mp4
  Waveforms/
    <asset-id>.json
  Renders/
    <render-id>.mp4
    <render-id>.m4a
  Logs/
    render-<render-id>.json
```

`project.json` is versioned and should be migratable. Every render stores a snapshot hash of the manifest and source checksums so the user can reproduce or inspect an export.

## 9. Data model essentials

```json
{
  "schemaVersion": 1,
  "id": "project-uuid",
  "title": "Night Train — four part arrangement",
  "audio": {
    "sampleRate": 48000,
    "channels": 2,
    "masterPeakTargetDbTP": -1
  },
  "tempoMap": [{"beat": 0, "bpm": 96, "meter": "4/4"}],
  "layout": {"preset": "2x2", "aspectRatio": "16:9", "background": "#0b1020"},
  "tracks": [{
    "id": "track-uuid",
    "name": "Lead",
    "asset": "Assets/takes/track-uuid.mov",
    "proxy": "Proxies/track-uuid.mp4",
    "startOffsetFrames": 0,
    "trim": {"in": 0, "out": 60.0},
    "gainDb": 0,
    "pan": 0,
    "mute": false,
    "solo": false,
    "effects": {"eq": "vocal-clean", "gate": true, "compressor": "light"},
    "tile": {"order": 0, "fit": "fill", "mirror": false, "label": true}
  }],
  "renders": []
}
```

## 10. Error and edge-case behavior

| Situation | Required behavior |
| --- | --- |
| Microphone/camera permission denied | Explain the exact consequence and offer Settings; allow audio-only/video-disabled paths where possible. |
| Headphones removed during take | Pause or stop safely, preserve the draft, show route change, and require confirmation before resuming. |
| Incoming call / audio interruption | Stop click and monitoring, preserve take, show “interrupted,” allow resume as a new take segment. |
| Bluetooth route changes latency | Re-run route preflight and offer recalibration. Do not silently reuse the old correction. |
| Low storage before capture | Show estimated minutes/tracks remaining and offer proxy/quality change or cleanup; never begin a take that cannot be finalized. |
| Low storage during capture | Stop safely, close the writer, preserve the completed portion as a draft, and explain the recovery path. |
| Unsupported video format | Offer proxy transcode on import or explain that the device cannot render that source. |
| Different source durations | Render to project duration with explicit empty regions; never crash or truncate an unrelated track. |
| Missing imported asset | Mark track offline, allow relink through Files, and keep the rest of the project editable. |
| Render fails | Keep sources and manifest, write a readable error log, allow retry with a lower preset or proxy mode. |
| App terminated after take | Reopen a recoverable draft from the atomic manifest and writer checkpoint. |
| Photos save denied | Keep the verified file in Files/app storage and offer permission retry. |

## 11. Privacy and offline requirements

- No network permission is needed for the core product.
- No account screen exists in the core flow.
- No cloud or remote URL is stored as the only copy of a project asset.
- Microphone and camera use are clearly explained before the system prompt.
- The app’s privacy copy states that recordings remain on-device unless the user explicitly shares/exports them.
- Local-only diagnostics can be enabled by the user and exported as a file; they are not transmitted automatically.
- Any file-provider action that might access a network-backed provider is initiated only by the user.

## 12. Accessibility and ergonomics

- VoiceOver labels for record, stop, click, tempo, track name, mute, solo, nudge, render, and share.
- Minimum touch targets of 44 pt for critical controls.
- Do not communicate beat only by color; use text, shape, and haptics.
- High-contrast waveform and playhead modes.
- Dynamic Type support for labels and settings; compact timeline may use a controlled minimum size.
- Haptic downbeat cue as an optional supplement to sound.
- Hands-free transport control is a P1 feature for musicians who cannot reach the screen while performing.

## 13. Test strategy

### Device matrix

At minimum, test one recent high-end iPhone, one mid-range iPhone, one older supported iPhone, wired headphones, AirPods, USB audio interface, built-in speaker/mic, low-storage state, portrait orientation, and a short landscape-camera interruption test.

### Audio/timing tests

- click intervals across BPM and meter combinations;
- count-in start accuracy;
- sample-rate changes;
- route latency measurement and compensation;
- interruption and route-change recovery;
- 2, 8, 16, 32, and 64-track preview/render stress tests;
- auto-sync precision with known offsets and noise;
- imported clips with duration mismatch and drift.

### Video/render tests

- front and back camera orientation/mirroring;
- 24/30/60 fps inputs;
- mixed source resolutions and aspect ratios;
- 1, 2, 4, 9, 16, and arbitrary tile counts;
- portrait, landscape, square, and 4:5 output;
- H.264, HEVC, and audio-only formats;
- interrupted export, low storage, Photos permission denied, Files save, and share-sheet handoff.

### Offline acceptance test

1. Install a clean build.
2. Disable Wi-Fi and cellular data.
3. Create a project.
4. Import a local guide file.
5. Record two video/audio takes.
6. Edit offsets, volume, pan, mute, and tile order.
7. Render H.264 video and lossless audio.
8. Save the video to Photos and both files to “On My iPhone.”
9. Close/relaunch and reopen the project.
10. Share the verified file through AirDrop or another local/system destination.

Pass means every step works without a network request or hidden online dependency.

## 14. Phased delivery

### Phase 0 — technical spike

- one capture session writing a take;
- audio engine click with sample-time scheduling;
- prior-track playback while recording;
- local project package and draft recovery;
- a two-tile composition render.

Exit: a known-good two-track, 60-second video with measured sync and a repeatable render.

### Phase 1 — offline MVP

- project library;
- sequential capture and retake;
- metronome/count-in/meter/subdivision;
- waveform, trim, offset, mute/solo/volume/pan;
- sync assist and confidence;
- 1x1/2x1/2x2/3x3/custom grid;
- H.264/HEVC video, AAC/ALAC audio, Photos/Files/share sheet;
- storage preflight and render recovery.

### Phase 2 — musician depth

- punch-in/takes/comping;
- drift compensation;
- external interface channel mapping;
- AUv3 host;
- tempo maps, hands-free controls, batch exports;
- advanced tile geometry and better proxy controls.

### Phase 3 — optional power features

- iOS 26 input picker and high-quality Bluetooth path;
- optional MultiCam capture;
- ProRes/HDR where it is genuinely useful;
- MIDI clock/Ableton Link;
- optional desktop project interchange.

## 15. Definition of done for v1

The product is ready for validation when a real iPhone can complete the offline acceptance test, the timing targets pass on the supported device matrix, failed renders preserve the project, the final output can be opened outside the app, and a user can understand every local-versus-shared state without reading documentation.

The browser mock in [prototype/index.html](../prototype/index.html) is a product-flow prototype, not an implementation of AVFoundation. Its purpose is to validate the information architecture and the “capture → sync/mix → local export” promise before committing to native engineering.
