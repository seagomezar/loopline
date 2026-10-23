# Software design document — Loopline

Status: implementation baseline  
Owner: iOS engineering  
Date: 15 August 2026  
Platform: iPhone only; portrait-first  
Minimum OS: iOS 18  
Working name: Loopline

## 1. Purpose and design decisions

Loopline is a native iPhone application for recording sequential vocal or instrumental parts with video, overdubbing while hearing earlier parts, editing timing and mix, arranging video tiles, and exporting a finished video and audio file locally.

The design is deliberately narrower than a general video editor and deliberately independent from social or cloud products. The app must create, edit, render, reopen, import, export, and share a project while the device is offline. The only network-capable operation is a user-initiated system action such as choosing a network-backed Files provider or a share destination; the Loopline core never uploads, synchronizes, authenticates, or depends on a server.

The following decisions are normative for the first native implementation:

1. The app target is iPhone only. The UI is portrait-first and the core workflow is designed for a 390–430 pt wide screen. iPad, Mac Catalyst, Android, and web are not implementation targets.
2. iOS 18 is the baseline. iOS 26-only APIs are optional availability-gated enhancements and cannot be required for capture, editing, rendering, or export.
3. The authoritative project timeline is an integer audio-sample timeline at 48,000 Hz whenever the device route permits it. Core Media time is used at module boundaries and for video composition.
4. Sequential overdubbing uses one standard `AVCaptureSession`; `AVCaptureMultiCamSession` is not a dependency for the core path.
5. Audio timing is owned by `AVAudioEngine`/`AVAudioTime` and the audio device clock. UI timers and display callbacks are never timing authorities.
6. Source media is copied into a local project package. A security-scoped URL, Photos asset identifier, or external provider URL is never the only reference to a project asset.
7. Preview and export are built from the same immutable `MixPlan` and `VideoCompositionPlan` models. They may use different quality and execution backends, but not different timing or mix rules.
8. Capture drafts and renders are transactional. A failed, cancelled, interrupted, or terminated operation must leave the last valid project manifest and source assets usable.
9. Apple system frameworks are sufficient for the core product. Third-party libraries and network SDKs are not required.

## 2. Scope and non-goals

### In scope for the native MVP

- Local project library and versioned project packages.
- Video/audio capture of one take at a time.
- Audio-only takes.
- Camera and microphone permissions, front/back camera, mirroring, orientation metadata, stabilization where supported, and input meters.
- Prior-track playback while recording the next track.
- Sample-time count-in and metronome with BPM, meter, subdivisions, accents, click volume, and project persistence.
- Track retakes without deleting prior takes.
- Waveform indexing, trim, millisecond/frame/sample-derived offset adjustment, mute, solo, gain, pan, and built-in processing presets.
- Automatic alignment with confidence and reversible application.
- Portrait, landscape, square, 4:5, and custom output framing through a local tile layout model.
- H.264 and HEVC video export where supported, AAC/ALAC/WAV audio export, stems where feasible, and editable project package export.
- Photos, Files, and system share handoff only after a local output is verified.
- Recovery from interruptions, route changes, low storage, app termination, missing assets, and failed renders.

### Explicitly out of scope

- Social feed, profiles, comments, likes, discovery, messaging, public collaboration, cloud projects, remote rendering, account login, subscription validation, and upload analytics.
- Protected-stream capture or extraction from another app.
- General-purpose transitions, captions, keyframes, green screen, color grading, pitch correction, AI separation, or generative features.
- Guaranteed completion of a foreground render after the user leaves the app. Background processing can retry or generate derivatives, but the reliable path remains a foreground render with checkpoints.

## 3. Architecture overview

The application is a layered Swift module graph. Domain models and algorithms are independent of AVFoundation; Apple framework adapters enter at explicit boundaries.

```text
LooplineApp
    └── FeatureUI (portrait SwiftUI screens + UIKit bridges)
            └── ApplicationServices (workflow orchestration)
                    ├── ProjectStore
                    ├── CaptureCoordinator ──┐
                    ├── AudioClock / AudioPlayback ─┤
                    ├── TakeRecorder              │
                    ├── WaveformIndex              │
                    ├── SyncEngine                  ├── CoreDomain / CoreAlgorithms
                    ├── MixGraph                    │
                    ├── VideoLayoutEngine ─────────┘
                    └── RenderQueue
                            ├── AudioRenderer
                            ├── VideoCompositionBuilder
                            ├── OutputVerifier
                            └── ShareCoordinator

Apple platform adapters: AVFoundation, AVFAudio, CoreMedia, CoreVideo,
Photos, UniformTypeIdentifiers, UIKit, SwiftUI, os, and optional BackgroundTasks.
```

### 3.1 Concurrency model

- UI state and presentation objects are `@MainActor` owned.
- `ProjectStore`, `RenderQueue`, and the capture session coordinator are actors or serial isolation domains. Their mutable state is never accessed directly from a view.
- Audio render callbacks and capture output queues do not allocate, log synchronously, touch SwiftUI state, or perform file I/O. They enqueue small immutable records to a dedicated serial media queue.
- `AVAudioEngine` graph mutation occurs on an audio coordinator isolation domain and only at safe transport boundaries. The realtime render thread is read-only with respect to the active graph.
- Media decoding, waveform generation, proxy generation, hashing, package import/export, and output verification run off the main actor with bounded concurrency.
- One foreground render runs at a time per process. Multiple projects may have queued jobs, but video and audio render memory is not multiplied by queue length.
- All values crossing actor or queue boundaries are value types and must be `Sendable`; AVFoundation objects remain inside their owning adapter.

### 3.2 Application composition root

`LooplineApp` creates one dependency container for production and one for tests. Feature screens receive use-case protocols, not concrete AVFoundation objects. The composition root is the only location allowed to select production versus harness adapters.

The production container contains no network client. A user-initiated system share is represented by a `SharePresenter` capability and is not part of the domain or render pipeline.

## 4. Module boundaries and contracts

The following module names are logical boundaries. They may initially be grouped into a small number of Swift packages or Xcode targets, but the dependency direction and public contracts must remain intact.

| Module | Owns | Public contract | Must not own |
| --- | --- | --- | --- |
| `CoreDomain` | IDs, project value types, timeline positions, tempo maps, layouts, mix settings, render requests, errors, state machines | Codable/sendable domain models and validation | AVFoundation, UIKit, filesystem, network, UI |
| `CoreAlgorithms` | Beat mapping, rational time conversion, peak math, deterministic hash inputs, basic geometry | Pure functions with fixture-driven tests | Device state, media decoding, presentation |
| `ProjectStore` | Local package lifecycle, manifest migration, checksums, atomic writes, recovery, storage estimates | `ProjectRepository`, `PackageCodec`, `RecoveryScanner` | Camera/audio session, UI, remote URLs |
| `CaptureCoordinator` | Camera/microphone permission, `AVCaptureSession`, format selection, capture connections, route notifications, sample-buffer delivery | `CaptureDriver`, `CaptureReadiness`, `CaptureEvent` stream | Project mutation, mix effects, waveform analysis |
| `AudioClock` | `AVAudioSession`, engine start/stop, host/sample anchor, route latency, click scheduling, interruption handling | `AudioClockService`, `RouteSnapshot`, `TransportEvent` stream | Writing media files, UI timers, persistent project edits |
| `AudioPlayback` | Guide-track scheduling, monitor mix, live meters, click and haptic cue requests | `GuidePlayback`, `PlaybackPlan`, `MeterStream` | Camera capture, final export policy |
| `TakeRecorder` | Audio/video sample-buffer persistence, segmented drafts, finalize/abort, source metadata | `TakeRecordingSession`, `DraftHandle`, `TakeAsset` | Project library presentation, automatic sync decisions |
| `WaveformIndex` | Asset decoding and bounded-resolution peak/RMS/envelope indexes | `WaveformService` | Timeline placement decisions, UI rendering |
| `SyncEngine` | Onset/energy extraction, bounded cross-correlation, confidence, drift estimate, undoable proposals | `SyncAnalyzer`, `SyncProposal` | Silent mutation of project state, video composition |
| `MixGraph` | Immutable mix plans, preview graph construction, offline audio graph, built-in effects, peak analysis | `MixPlanner`, `AudioRenderer` | Package ownership, camera, share sheet |
| `VideoLayoutEngine` | Tile geometry, crop/fill/fit, transforms, mirror, safe area, output dimensions | `LayoutPlanner`, `VideoCompositionPlan` | Audio timing, source file copying |
| `RenderQueue` | Preflight, immutable snapshots, phase checkpoints, cancellation, retry, staging cleanup, output verification | `RenderService`, `RenderProgress` | UI decisions, Photos authorization details |
| `ShareCoordinator` | Photos write, Files destination handoff, `UIActivityViewController` presentation | `ShareService`, `ExportReceipt` | Rendering, package mutation, network upload |
| `FeatureUI` | Portrait-first screens, accessibility, user intent, status and error presentation | Views and view models | Direct AVFoundation calls, filesystem paths, timing calculations |
| `TestSupport` | Fakes, synthetic media, clocks, fixture loading, assertions, offline guard | Harness contract described in Section 13 | Production runtime behavior |

### 4.1 Domain boundary rules

`CoreDomain` persists integer/rational values, not UI-specific `Double` values. AVFoundation `CMTime`, `AVAudioTime`, `AVAsset`, `CMSampleBuffer`, `URL`, `PHAsset`, and `UIView` types are adapter concerns. Conversion is explicit at the boundary and must retain enough precision to round-trip the persisted value.

`FeatureUI` can request a use case such as `startTake`, `applySyncProposal`, or `enqueueRender`; it cannot call `AVAudioPlayerNode.schedule`, `AVAssetExportSession.export`, `FileManager`, or `PHPhotoLibrary` directly.

## 5. Core data model

### 5.1 Timeline representation

The canonical project clock is:

```text
ProjectSample = signed Int64 sample index at 48,000 samples/second
ProjectTime   = CMTime(value: ProjectSample, timescale: 48,000)
FrameTime     = CMTime from source/output frame rate
BeatPosition  = rational beat number resolved through the tempo map
```

Persisted offsets use `ProjectSample` wherever an audio relationship is intended. Video source ranges retain exact `CMTime` values and nominal frame rates. No persisted placement uses a rounded millisecond as its only representation.

The timeline invariant is:

```text
projectTime = startSample / canonicalSampleRate
             + sourceTime - trimIn
             + optional drift transform
```

`startSample`, `trimIn`, and `trimOut` are integer or rational values. Floating-point values may be used during DSP, but are quantized at an explicit boundary and recorded in diagnostics when quantization occurs.

### 5.2 Project entities

- `Project`: identity, title, creation/update timestamps, audio settings, tempo map, layout, logical tracks, render history, calibration records, and schema version.
- `Track`: stable logical lane, name, color, selected take, ordered take references, audio placement, mix controls, effects, and optional video tile.
- `Take`: immutable capture/import record, one or more source segments, canonical audio derivative, proxy reference, waveform reference, provenance, duration, and capture state.
- `AssetRef`: relative package path, media kind, byte size, checksum, format description, duration, and creation source.
- `TempoMap`: ordered tempo/meter events. MVP supports a constant project tempo plus future tempo events without changing the persisted shape.
- `MixSettings`: gain, pan, mute, solo, effect chain, bypass states, and master settings.
- `TileSpec`: order, normalized frame, fit/fill mode, crop, mirror, label, border, and background.
- `RenderRecord`: request, snapshot hash, phase state, staging paths, output references, verification results, and failure diagnostics.
- `RouteCalibration`: route UID/model, sample rate, input/output latency snapshot, measured correction, date, and confidence.

### 5.3 Required invariants

1. Every referenced asset path is relative, normalized, contained by the project package, and checksum-verifiable.
2. A committed take references at least one readable source segment and has a stable ID that is never reused.
3. A logical track may have many retained takes but exactly one active take for preview/render.
4. Track edits are non-destructive. Source segments are immutable after commit.
5. A render is tied to a manifest snapshot hash and source checksum set. Changing the project creates a new render identity.
6. A project with missing media remains openable. Missing tracks are marked offline and never silently substituted.
7. `solo` is an effective mix decision, not a destructive edit: if any track is soloed, only soloed tracks contribute to the mix.
8. The master limiter is present in every final mix plan unless a future explicit expert export mode says otherwise.
9. A completed export cannot be referenced by the UI until output verification has succeeded.

### 5.4 Manifest shape

The manifest is JSON for inspectability and migration. The following is representative rather than a complete schema:

```json
{
  "schemaVersion": 1,
  "id": "project-uuid",
  "title": "Night Train",
  "audio": {
    "canonicalSampleRate": 48000,
    "mixChannels": 2,
    "masterTruePeakTargetDbTP": -1
  },
  "tempoMap": [
    { "beat": 0, "bpm": 96, "meterNumerator": 4, "meterDenominator": 4 }
  ],
  "layout": {
    "preset": "2x2",
    "aspectRatio": "16:9",
    "background": "#0B1020"
  },
  "tracks": [
    {
      "id": "track-uuid",
      "name": "Lead",
      "activeTakeID": "take-uuid",
      "takes": ["take-uuid", "older-take-uuid"],
      "placement": { "startSample": 0, "trimInSample": 0, "trimOutSample": 2880000 },
      "mix": {
        "gainDb": 0,
        "pan": 0,
        "mute": false,
        "solo": false,
        "effects": ["highPass", "vocalEQ", "lightCompressor"]
      },
      "tile": { "order": 0, "fit": "fill", "mirror": false, "showLabel": true }
    }
  ],
  "takes": {
    "take-uuid": {
      "sourceSegments": ["Assets/takes/take-uuid/segment-000.mov"],
      "canonicalAudio": "Assets/audio/take-uuid.caf",
      "proxy": "Proxies/take-uuid.mp4",
      "waveform": "Waveforms/take-uuid.json",
      "duration": { "value": 60000, "timescale": 1000 },
      "status": "committed"
    }
  },
  "renders": []
}
```

## 6. Offline storage and package format

### 6.1 Internal storage

Projects live under the app’s local application-support directory:

```text
Application Support/
  Projects/
    <project-id>.loopline/
  Library/Caches/
    PreviewProxies/
    WaveformIndexes/
    RenderScratch/
```

The project directory is the authoritative local document. Caches are disposable and keyed by source checksum plus processing parameters. Source media, manifests, committed take metadata, and verified outputs are not caches.

The app must not use CloudKit, an iCloud project URL, a remote database, or a remote asset URL. Normal device backup behavior remains controlled by the OS and user; Loopline itself performs no upload or sync. Cache directories are excluded from backup when appropriate. Authoritative project data is retained unless the user deletes or exports it.

### 6.2 Package layout

```text
<Title>.loopline/
  project.json
  package.json
  Assets/
    takes/<take-id>/segment-000.mov
    takes/<take-id>/segment-001.mov
    imported/<asset-id>.<ext>
    audio/<take-id>.caf
  Proxies/
    <take-id>.mp4
  Waveforms/
    <take-id>.json
  Renders/
    <render-id>/video.mp4
    <render-id>/mix.m4a
    <render-id>/stems/<track-id>.wav
    <render-id>/receipt.json
  Logs/
    render-<render-id>.json
  Recovery/
    capture-journal.json
    manifest.bak
```

`package.json` records package format version, project ID, created/exported dates, manifest checksum, asset count, and a checksum index. It allows an importer to reject malformed archives before extracting media.

The external editable project format is a ZIP archive with the `.loopline` extension. Media may be stored without compression when compression would increase CPU or memory cost. The archive must reject absolute paths, `..` traversal, symlinks, duplicate paths, oversized declared entries, and a manifest/project-ID mismatch.

### 6.3 Atomic writes and migration

Project mutation uses a two-phase local commit:

1. Validate the proposed domain snapshot and all referenced relative paths.
2. Write a canonical JSON representation to `project.json.tmp`.
3. Flush and close the temporary file; compute its checksum.
4. Rename the existing manifest to `Recovery/manifest.bak` if present.
5. Atomically replace `project.json` with the temporary file.
6. Write a small commit record containing the new manifest checksum.
7. Remove stale temporary state after the new manifest is readable.

On open, `RecoveryScanner` selects the newest valid manifest whose checksum and referenced package entries pass validation. It can restore `.bak` or complete a pending commit, but it never guesses at a partial domain edit.

Schema migrations are pure functions from `ManifestVn` to `ManifestVn+1`, run before the project enters the editable state. The original manifest is preserved in a migration backup until the new version has been successfully written. Unknown future schema versions open read-only with an actionable import/export message.

### 6.4 Import/export rules

- Import from Files or a user-selected local source copies bytes into the package before the import is committed.
- Import uses security-scoped access only for the duration of the copy and checksum operation.
- Photos imports are copied into package-owned media; a `PHAsset` local identifier is provenance metadata only.
- Project export includes `project.json`, package metadata, source media, and optionally proxies, waveforms, render outputs, and logs based on the user’s selection. The default editable export includes source media and manifest, not disposable caches.
- Package import is staged under a temporary directory, validated, migrated, then moved into `Projects/<id>.loopline` under a new transaction. Existing projects are never overwritten silently.
- “On My iPhone” is the recommended strict-offline destination. Any network-backed Files provider is a user-selected system operation and is not treated as a Loopline service.

## 7. Data flow

### 7.1 Project lifecycle

```text
User intent
  → use case
  → domain validation
  → ProjectStore transaction
  → manifest snapshot
  → UI state refresh
```

Views never mutate a live object graph in place. A user edit produces a validated value snapshot. The store persists it atomically and publishes a new read model.

### 7.2 Capture and commit

```text
Preflight
  → AVAudioSession route/configuration
  → AVCaptureSession configured
  → AudioClock establishes project/audio/host anchor
  → count-in + guide playback scheduled by sample time
  → capture sample buffers arrive with CMSampleBuffer PTS
  → TakeRecorder writes segmented local draft
  → stop/interruption finalizes completed segments
  → source checksums + canonical audio + proxy + waveform
  → Take record committed in one ProjectStore transaction
```

The capture writer never writes directly into the active manifest. A take is visible as a recoverable draft until its media and derived artifacts are valid. Only then does the logical track reference it.

### 7.3 Edit, preview, and sync

```text
Project snapshot
  → WaveformIndex / SyncEngine analysis
  → explicit SyncProposal
  → user accepts or nudges
  → new manifest snapshot
  → MixPlan + VideoCompositionPlan
  → proxy video preview + realtime AVAudioEngine mix
```

Sync analysis may suggest an offset, but no analysis result silently changes a track. Manual nudge, undo, and reset-to-source remain available.

### 7.4 Render and share

```text
Project snapshot + RenderRequest
  → storage/codec/media/thermal preflight
  → RenderJob checkpoint
  → offline audio mix
  → video composition
  → mux/export to staging
  → output verification
  → atomic move into Renders/<render-id>
  → ExportReceipt
  → Photos / Files / UIActivityViewController on explicit user action
```

## 8. Timing, metronome, and synchronization strategy

### 8.1 Clock ownership

There are three relevant clocks:

- **Project clock:** canonical 48 kHz sample positions and tempo-map mapping. This is the persisted musical timeline.
- **Audio device/engine clock:** `AVAudioTime` sample time and host time used to schedule playback and click output.
- **Media clock:** `CMSampleBuffer`/`CMTime` timestamps used for capture and video composition.

`AudioClock` maintains a `ProjectClockAnchor`:

```text
projectStartSample
audioEngineSampleTime
hostTime
sessionSampleRate
```

The mapping is captured once per transport start and invalidated by an audio route change or interruption. The renderer does not reuse the live anchor; it reconstructs timing from the project manifest and source timestamps.

### 8.2 Audio session and route policy

The primary category is `.playAndRecord` with a music-safe mode. Voice processing is not enabled for music takes unless the user explicitly chooses a later voice-processing option. The session is configured before the capture session starts and revalidated after every route event.

Every take stores a route snapshot containing route UID, input/output port, sample rate, channel count, buffer duration, input latency, output latency, and optional calibration correction.

Route guidance:

- Wired headphones or USB interface: best for overdubbing.
- Supported high-quality Bluetooth recording: usable after calibration; availability-gated.
- Ordinary Bluetooth hands-free route: warn about unstable/high monitoring latency.
- Built-in speaker while using the microphone: warn about guide bleed and recommend headphones.

Latency correction shifts guide playback or click presentation for the current route. It does not rewrite the captured source or silently change a track’s project offset. A user-visible calibration record can be reset. If the route changes during a take, the current draft is safely paused/stopped and a new route preflight is required before resuming.

### 8.3 Metronome and count-in

The metronome implementation is a deterministic click scheduler:

1. Resolve the project beat events from the tempo map using rational arithmetic.
2. Convert each beat/subdivision to a canonical sample position, carrying fractional remainders so long sessions do not accumulate rounding drift.
3. Generate or load short click buffers for downbeat, beat, and subdivision accents.
4. Convert project sample positions to the active engine sample/host-time anchor.
5. Schedule click buffers on an `AVAudioPlayerNode` sufficiently ahead of the render cursor.
6. Schedule prior-track guide regions on separate player nodes or an equivalent graph using the same anchor.
7. Use transport and engine callbacks to refill future click windows; never use `Timer`, `DispatchQueue.asyncAfter`, or a display callback for audio timing.

Count-in is part of the transport plan and is not inserted into the recorded track. The default is one bar, but meter and count-in length are project settings. Click may be monitored during recording and is excluded from final export unless a future explicit “include click” export mode is selected.

The visual beat indicator reads engine/media time and may lag or skip frames without changing the audio schedule. Optional haptics are supplemental and never the timing authority.

### 8.4 Capture timestamp mapping

`AVCaptureAudioDataOutput` and `AVCaptureVideoDataOutput` deliver sample buffers with presentation timestamps. The recorder preserves original PTS, duration, format description, and dropped-buffer diagnostics.

For each take:

- The first valid audio PTS establishes the recorded audio source origin.
- The project placement is derived from the transport anchor and count-in plan, not from when the UI button callback ran.
- Video PTS are mapped through the same capture session start and retained at their source frame rate.
- If audio and video PTS disagree beyond the capture tolerance, the take is marked with a diagnostic and is not silently repaired.

The canonical audio derivative is explicitly resampled to 48 kHz when the source route or imported media uses another rate. The original media remains unchanged and the conversion is recorded in provenance.

### 8.5 Sync assist

`SyncEngine` receives immutable mono analysis buffers and a bounded search window:

1. Decode audio without changing the stored source.
2. Resample analysis data to a fixed low analysis rate.
3. Compute an energy/onset envelope and remove leading silence only for analysis.
4. Run normalized cross-correlation against the selected guide/reference window.
5. Return offset, confidence, peak ratio, analysis range, and drift estimate.
6. Require user confirmation unless the user enabled an explicit auto-apply preference.

Confidence is low when the reference is silent, clipped, too short, highly repetitive, or ambiguous. Low-confidence proposals are displayed as suggestions and never auto-applied.

For imported clips, drift is estimated from start and end windows. A small linear resample is offered only when the result exceeds the configured tolerance. The source remains intact; the derived placement records the ratio and provides undo.

## 9. Capture interfaces and implementation behavior

### 9.1 CaptureCoordinator contract

The coordinator exposes domain-level operations equivalent to:

```text
prepare(CaptureConfiguration) → CaptureReadiness
start(TransportPlan) → CaptureSessionHandle
pause(reason) → DraftCheckpoint
stop() → DraftCheckpoint
cancel() → void
events() → AsyncStream<CaptureEvent>
```

`CaptureConfiguration` includes camera choice, audio-only/video mode, target dimensions, frame rate, stabilization, mirroring, preferred sample rate, channel map, and storage budget. `CaptureReadiness` includes permissions, selected formats, route, estimated bytes/minute, thermal state, free space, and warnings.

The P0 implementation uses:

- `AVCaptureSession` with one camera input at a time.
- `AVCaptureAudioDataOutput` and `AVCaptureVideoDataOutput` on dedicated serial queues.
- `AVCaptureVideoPreviewLayer` for the low-latency portrait preview.
- A bounded preview path that may drop display frames but never drops a frame accepted by the recording writer without recording a diagnostic.
- Capture connection orientation, mirroring, stabilization, and active format configured before `startRunning`.

`AVCaptureMultiCamSession` is an optional later adapter and must not change the core `CaptureCoordinator` contract.

### 9.2 TakeRecorder contract

```text
beginDraft(TakeConfiguration, CaptureAnchor) → DraftHandle
appendAudio(CMSampleBuffer)
appendVideo(CMSampleBuffer)
checkpoint() → DraftCheckpoint
finish() → FinalizedTake
abort() → void
recover(DraftHandle) → RecoveryResult
```

The writer stores media in short independently finalized segments under a draft directory. Segment boundaries are controlled by the recorder, not by UI events. A normal take may later be consolidated into a single derived asset, but the source segments remain available until project cleanup.

Each segment has a journal entry with sequence number, source PTS range, byte size, checksum, audio/video presence, and finalized flag. On interruption or termination, finalized segments can be committed into a recoverable draft; an open, unfinalized segment is discarded or validated independently.

Derived artifacts are generated only after the source segment set passes validation:

- Canonical 48 kHz audio derivative.
- Preview proxy at a device-appropriate resolution.
- Waveform index.
- Thumbnail and media metadata.

### 9.3 Capture state machine

```text
idle
  → preflighting
  → armed
  → countingIn
  → recording
  → stopping
  → draftReady
  → committed
```

Exceptional states are `pausedByInterruption`, `pausedByRouteChange`, `storageStopped`, and `failed`. An exceptional state always retains a draft handle or a recorded reason why no media was accepted. Resuming after an interruption creates a new segment or take segment; it does not pretend that a continuous audio clock survived an invalidated route.

## 10. Mixing and rendering

### 10.1 MixPlan

`MixGraph` produces an immutable `MixPlan` from a project snapshot. It contains:

- canonical sample rate and output channel layout;
- effective active tracks after mute/solo resolution;
- each track’s source asset, trim, start sample, optional drift transform, gain, pan, and effect chain;
- effect parameters and bypass states;
- master limiter and true-peak target;
- output duration and silence policy.

The same plan configures a realtime preview graph and an offline graph. Any preview-only optimization must preserve the plan’s timing, gain, pan, mute/solo, and effect order. Proxy video quality is allowed to differ; musical output is not.

### 10.2 Preview audio

Preview uses `AVAudioEngine` with one logical source/player path per active track or a bounded equivalent that schedules source regions at project sample offsets. Track effects are applied in the documented order. The graph is rebuilt or updated at safe transport boundaries after a manifest edit.

Meters are computed from the active audio path and exposed as a throttled stream to the UI. They are display data, not persisted timing data. Preview protects the output with the same limiter target as final export, while showing a clipping/limiter status when the source mix is excessive.

### 10.3 Offline audio render

`AudioRenderer` uses `AVAudioEngine` manual offline rendering or a deterministic equivalent:

1. Allocate an offline graph at the canonical output format.
2. Attach the same source spans, trims, offsets, and effect chain represented by `MixPlan`.
3. Render fixed-size blocks to a lossless intermediate file in the render staging directory.
4. Analyze true peak, RMS, silence, NaN/Inf values, and sample count.
5. Fail pre-verification if the output is corrupt or violates the master safety target.

The renderer writes canonical audio once and derives AAC, ALAC, WAV, and stem outputs from that stable result. Stem export is an explicit request and uses the same source placement/effects policy selected by the user.

### 10.4 Video composition

`VideoLayoutEngine` converts normalized tile specifications into output pixel rectangles, crop transforms, safe-area bounds, and layer ordering. It is pure geometry and can be tested without media.

`VideoCompositionBuilder` then:

1. Validates every visible take’s source video track and trim range.
2. Inserts source video time ranges into an `AVMutableComposition` at the track’s project placement.
3. Creates one `AVMutableVideoCompositionLayerInstruction` per visible tile.
4. Applies source orientation, mirror, crop/fill/fit, scale, translation, borders, and output aspect ratio.
5. Adds optional static overlay layers through `AVVideoCompositionCoreAnimationTool` only when required.
6. Sets a deterministic output frame rate, render size, color properties, and pixel aspect ratio.

The P0 path uses standard AVFoundation composition and export. A custom compositor is deferred until rounded masks, animated layouts, or other requirements cannot be expressed safely through layer instructions.

### 10.5 RenderQueue contract

```text
enqueue(RenderRequest) → RenderJobID
observe(RenderJobID) → AsyncStream<RenderProgress>
cancel(RenderJobID) → void
retry(RenderJobID, RetryPolicy) → RenderJobID
recoverPendingJobs() → [RenderJob]
```

Each job stores a snapshot hash, requested output formats, estimated bytes, and phase checkpoint. Phases are:

```text
queued → preflighting → renderingAudio → composingVideo → encoding
       → verifying → completed
       ↘ cancelled / failed / recoverable
```

The render runs in a staging directory. A completed output is moved into `Renders/<render-id>` only after verification. Cancellation removes staging files where possible and retains the source project. Failure records a user-readable error code plus a developer diagnostic, leaves the manifest and sources untouched, and offers a retry policy such as lower resolution, proxy video, or audio-only export.

### 10.6 Storage preflight

Before capture or render, estimate:

- source media bytes for the requested duration and format;
- canonical audio and proxy derivatives;
- peak staging usage, including at least one intermediate audio file and one output;
- retained source and render history;
- safety reserve for manifest recovery and OS variance.

The operation starts only if free storage exceeds the estimate plus reserve. If free space drops below the safe threshold during capture, the recorder finalizes the last valid segment, marks the draft `storageStopped`, and presents a recovery action. It never deletes source media automatically.

### 10.7 Output verification

Before exposing a file to Photos, Files, or the share sheet, `OutputVerifier` must confirm:

- file exists at the expected local URL and has non-zero size;
- `AVAsset` loads successfully;
- expected audio/video tracks exist;
- duration is within the configured tolerance of the project output duration;
- video dimensions, frame rate, orientation, and codec match the request;
- audio sample rate, channel count, codec, and duration match the request;
- timestamps are monotonic and the asset can decode its first, middle, and last validation samples;
- true peak is at or below the configured safety target, unless the request explicitly records a warning;
- checksum is recorded in the export receipt.

Only a verified output receives `ExportReceipt.status = ready`.

## 11. Failure recovery and edge behavior

| Failure | Detection | Recovery |
| --- | --- | --- |
| Camera/microphone permission denied | Preflight or authorization callback | Explain the missing capability; offer Settings; retain audio-only or video-disabled paths when valid. |
| Unsupported camera format | Format negotiation | Offer a supported resolution/frame rate; never start with a format that the writer cannot accept. |
| Route changed during take | `AVAudioSession.routeChangeNotification` | Stop click, finalize current segment, preserve draft, rerun route preflight/calibration, and resume as a new segment only after confirmation. |
| Audio interruption/incoming call | Interruption begin/end notifications | Stop transport and monitoring, finalize the valid segment, mark interrupted, and offer resume as a new segment. |
| App moved inactive or terminated | Lifecycle event or recovery scan on launch | Persist the journal and manifest transaction; recover finalized segments and discard only unfinalized data that fails validation. |
| Low storage before operation | Storage preflight | Show estimate and options to lower quality, remove user-selected renders, or cancel. No automatic source deletion. |
| Low storage during capture/render | Write failure/free-space threshold | Close the current writer safely, retain all valid outputs, mark the operation recoverable, and offer retry after user action. |
| Thermal pressure | `ProcessInfo.thermalState` and observed media backpressure | Warn, reduce proxy/preview quality if safe, pause or stop capture if writer integrity is at risk, and defer retry. |
| Missing/corrupt asset | Package checksum/readability validation | Mark the track offline; offer relink through Files; keep the rest of the project editable. |
| Package corruption | Manifest/checksum/path validation | Open a read-only diagnostic state; restore backup manifest if valid; otherwise offer package repair/import report without deleting the package. |
| Different source durations | Composition validation | Render explicit empty regions; output duration is determined by project/active track policy, never by truncating unrelated tracks. |
| Render cancelled | Cancellation token at every phase | Remove only staging output, keep snapshot and source assets, mark cancelled, and allow a fresh retry. |
| Render failed | Backend error or output verification | Retain source and manifest, persist phase/error code/log, clean invalid output, and offer supported retry options. |
| Photos authorization denied | PhotoKit authorization result | Keep the verified local file in the project and Files; offer permission retry. |
| Files provider unavailable | Picker/provider callback | Keep the verified local output; distinguish local render success from destination failure. |
| Share presenter dismissed | Activity result/cancellation | Leave the verified local file ready; do not report a share as completed. |

All user-visible failures have a stable domain error code, a short explanation, a safe next action, and a retained local state where possible. Developer diagnostics include phase, project ID, render/take ID, route snapshot, OS/device, and a redacted error chain; they never include network-upload attempts because no such path exists.

## 12. Portrait-first iPhone presentation boundary

The feature UI is SwiftUI-first with UIKit bridges for `AVCaptureVideoPreviewLayer`, document picker, Photos authorization, and activity sharing. The core workflow is portrait locked. Camera sensor orientation and source transforms are handled by capture/composition metadata, not by rotating the entire application UI.

The UI must:

- target 390–430 pt portrait widths and remain usable on smaller supported iPhones;
- keep transport controls and record/stop at least 44 pt;
- use bottom sheets for detail controls such as metronome, route calibration, effects, and export options;
- keep the current project, track name, route, tempo, and save state visible without requiring landscape;
- use Dynamic Type, VoiceOver labels, high-contrast waveforms, text and shape in addition to color, and optional haptic downbeat cues;
- show “local file ready,” “saved to Photos,” “saved to Files,” and “shared” as separate states.

No view is responsible for deciding whether a file is local, verified, or shareable. It displays the state returned by the corresponding service.

## 13. Dependency and privacy rules

### 13.1 Allowed production dependencies

Use Apple frameworks already present on iPhone:

- Swift standard library and Swift Concurrency.
- SwiftUI and UIKit for presentation and system bridges.
- AVFoundation and AVFAudio for capture, composition, export, and audio engine.
- Core Media, Core Video, and Video Toolbox only where required for timestamps, buffers, or codec support.
- Photos and Uniform Type Identifiers for local destinations and file types.
- `os` signposts/logging with privacy redaction.
- BackgroundTasks only for optional deferred proxy/retry work.

The core product must not depend on a package manager, cloud SDK, analytics SDK, ad SDK, login SDK, social SDK, or remote feature flag. An AUv3 effect is an optional user-installed extension behind an adapter; built-in effects remain complete without it.

### 13.2 Forbidden dependency directions

- `CoreDomain` and `CoreAlgorithms` must not import Apple media/UI frameworks.
- UI must not import or construct storage, renderer, audio-session, or camera adapters directly.
- Capture must not mutate project manifests directly.
- Render must not read UI state or wall-clock playback history.
- Share must not initiate rendering or mutate mix/layout state.
- Test fakes must not be linked into the production application target.
- No module may introduce `URLSession`, WebSocket, CloudKit, remote database, or an HTTP client.

### 13.3 Privacy rules

- Request microphone and camera permissions only when the user reaches the relevant workflow and explain on-device storage first.
- No media, project metadata, route diagnostics, or usage events are transmitted.
- User-selected Files and share providers may be outside the app sandbox; their availability is treated as an explicit user action, not a product dependency.
- Logs contain stable local IDs and error codes, not raw audio, video, file contents, access tokens, or full external paths.
- The app does not capture protected streaming audio from another process.

## 14. Test strategy and harness contract

The test system must validate both the pure design and real iPhone media behavior. A green simulator test suite is not sufficient for timing, route, camera, thermal, or Photos behavior.

### 14.1 Test targets

| Target | Purpose | Environment |
| --- | --- | --- |
| `CoreDomainTests` | Manifest validation, migrations, state machines, rational beat math, layout geometry | macOS/iOS simulator; no media or filesystem dependency |
| `ProjectStoreTests` | Atomic writes, checksums, package import/export, corruption recovery, storage estimates | Simulator with isolated temporary directories |
| `SyncEngineTests` | Known offsets, confidence thresholds, noise/clipping/repetition cases, drift proposal math | Deterministic synthetic audio |
| `WaveformAndMixTests` | Waveform generation, effect ordering, mute/solo, offline audio output, peak safety | Deterministic fixture renderer |
| `MediaCompositionTests` | Video transforms, tile placement, aspect ratios, duration policy, output metadata | Synthetic video/audio fixtures |
| `RenderIntegrationTests` | Full local capture-package-preview-render-verify path with fakes for camera and destinations | Simulator or test device; no network |
| `LooplineUITests` | Portrait navigation, accessibility labels, state presentation, permission and error flows | iPhone simulator at supported widths |
| `DeviceMediaTests` | Real AVAudioEngine, AVAudioSession routes, AVCaptureSession, interruptions, thermals, Photos | Physical iPhones and specified audio hardware |
| `OfflineAcceptanceTests` | End-to-end airplane-mode/local-destination workflow | Physical iPhone with Wi-Fi/cellular disabled |

### 14.2 Harness dependency contract

Every application service that touches a nondeterministic or external capability receives a protocol-backed adapter:

```text
TestClock
  nowHostTime() → UInt64
  nowProjectSample() → Int64
  advance(to:) → void

FileSystem
  read/write/replace/remove/list
  freeSpace(at:)
  atomicReplace(_:with:)

CaptureDriver
  prepare(_:)
  start(anchor:)
  emitSyntheticOrRealSampleBuffers()
  stop()

AudioSessionDriver
  currentRoute()
  configure(_:)
  startEngine()
  stopEngine()
  interruptionEvents()
  routeEvents()

MediaReaderWriter
  readMetadata(_:)
  readAudio(_:)
  writeSegment(_:)
  verify(_:)

PhotoLibraryClient
  authorization()
  save(_:)

SharePresenter
  present(localVerifiedURL:)

NetworkPolicy
  assertNoCoreNetworkAccess()
```

Production adapters wrap Apple APIs. Harness adapters are injected at the composition root and are never selected through runtime remote configuration.

### 14.3 Required launch/test configuration

UI and end-to-end harness launches must support the following debug/test-only arguments:

```text
-LooplineHarnessMode
-LooplineOfflineOnly
-LooplineFixture <fixture-name>
-LooplineProjectRoot <isolated-temp-url>
-LooplineMockPermissions <all|cameraDenied|microphoneDenied|photosDenied>
-LooplineMockRoute <wired|airpods|usb|speaker>
-LooplineDisableAnimations
-LooplineDeterministicSeed <integer>
```

When `-LooplineHarnessMode` is present:

1. The app uses an isolated project root supplied by the harness.
2. The clock, filesystem, capture, audio-session, media, Photos, and share adapters are injectable.
3. A deterministic locale, calendar, timezone, random seed, and filename clock are used.
4. All animations are disabled or made clock-driven.
5. The app exposes test-readable state through accessibility identifiers and a structured in-memory event log; it does not require screen-pixel interpretation for business assertions.

When `-LooplineOfflineOnly` is present, any attempted core network operation is a hard test failure. The production container has no such operation; this guard exists to detect accidental framework or dependency additions. User-initiated share/provider presentation is recorded as an allowed capability boundary and is not counted as a core network request.

### 14.4 Deterministic media fixtures

`TestSupport` must generate or load fixtures without downloading anything:

- 48 kHz mono/stereo impulse and tone files with impulses at exact known sample positions.
- Click fixtures for every supported meter/subdivision/accent pattern.
- Synthetic video at 24, 30, and 60 fps with frame-number overlays and known durations.
- Front-camera mirrored and back-camera orientation metadata cases.
- Different resolutions and aspect ratios, including portrait, landscape, square, and 4:5.
- Source pairs with known fixed offsets, noise, clipping, silence, repeated motifs, and linear drift.
- 2, 8, 16, 32, and 64-track projects using lightweight proxy assets for memory/stress tests.
- Corrupt, truncated, missing, duplicate-path, and checksum-mismatch package fixtures.

Each fixture has a declared expected duration, sample rate, frame rate, checksum, and semantic purpose. Test output should record fixture name and seed so a failure is reproducible.

### 14.5 Timing assertions

Pure and offline timing assertions:

- Click intervals equal the rational tempo mapping within one canonical sample after accumulated rounding is accounted for.
- Count-in starts at the requested project sample and produces the expected number of beats/subdivisions.
- The renderer never uses wall-clock timestamps from the test runner to place media.
- Track placement round-trips through JSON without changing a sample-derived offset.

Physical-device timing assertions:

- Sequential two-track and multi-track captures meet the PRD target: median onset error no greater than 10 ms and P95 no greater than 20 ms for the supported test set.
- Output video tile starts are within one output frame of their project placements.
- Route changes and interruptions produce a recoverable draft and never silently reuse stale latency compensation.
- Wired/USB routes are reported as preferred; Bluetooth warnings are present when applicable.

### 14.6 Audio, video, storage, and recovery assertions

Every render integration test must assert:

- preview and export consume the same serialized `MixPlan` inputs;
- mute, solo, gain, pan, trim, offset, effect bypass, and layout order survive a save/reopen cycle;
- output audio contains no NaN/Inf and respects the true-peak target;
- output metadata matches the requested codec, dimensions, frame rate, duration, channels, and sample rate;
- first/middle/last video frames decode;
- a failed export leaves source media and the last good manifest unchanged;
- cancellation leaves no output that can be mistaken for a completed export;
- app termination after a finalized capture segment recovers that segment on relaunch;
- low storage stops safely and reports a useful retry action;
- missing assets preserve the rest of the project and support relink;
- Photos denial leaves a verified local file ready for Files/share;
- an editable package imported into a clean project produces the same manifest and source checksums.

### 14.7 Offline acceptance harness contract

The release gate runs this exact scenario on a physical iPhone:

1. Install a clean build and launch with no account setup.
2. Disable Wi-Fi and cellular data; assert `NetworkPolicy` records zero core network attempts.
3. Create a portrait project with a local guide fixture.
4. Record or inject two video/audio takes with click and prior-track playback.
5. Relaunch after committing the first take and confirm the project reopens locally.
6. Apply trim, offset, volume, pan, mute, solo, and tile-order changes.
7. Render H.264 video and lossless audio.
8. Verify the local output receipt, save to Photos, and save to “On My iPhone” in Files.
9. Cancel one render and fail one render using harness fault injection; confirm source and manifest recovery.
10. Reopen the project and invoke the system share sheet only with the verified local file.

The pass condition is that every core step completes without network access, source loss, manifest corruption, or a false “shared”/“saved” state. The test report includes device model, iOS version, route, fixture seed, render settings, timing metrics, output checksums, and failure-injection results.

### 14.8 Device matrix

At minimum, the device run includes one recent high-end iPhone, one current mid-range iPhone, and one oldest supported iPhone, all in portrait UI mode. Each class is tested with:

- built-in microphone/speaker;
- wired headphones;
- AirPods or another Bluetooth route;
- USB audio interface where supported;
- low-storage simulation or controlled low-free-space device;
- camera interruption/orientation and app lifecycle transitions;
- Photos permission granted and denied;
- 2, 8, 16, 32, and 64 lightweight tracks for performance boundaries.

The suite records physical resource limits rather than presenting them as product track limits. A device may reject a request because of storage, memory, thermal pressure, or codec support; that rejection must be preflighted and explained.

## 15. Traceability to PRD acceptance areas

| PRD area | Design owners | Release evidence |
| --- | --- | --- |
| OFF-01–07 | `ProjectStore`, dependency rules, package importer/exporter | Airplane-mode acceptance and package round trip |
| CAP-01–10 | `CaptureCoordinator`, `TakeRecorder`, `AudioClock` | Physical capture matrix and draft-recovery tests |
| TIME-01–09 | `CoreAlgorithms`, `AudioClock`, `AudioPlayback` | Rational click fixtures, route tests, timing metrics |
| SYNC-01–10 | `WaveformIndex`, `SyncEngine`, domain placement | Known-offset/drift fixtures and undo tests |
| MIX-01–06 | `MixGraph`, `AudioRenderer` | Plan parity, peak, effect, stem, and offline audio tests |
| EXP-01–10 | `VideoLayoutEngine`, `RenderQueue`, `ShareCoordinator` | Codec/layout/output verification and local-share tests |
| Reliability and privacy | `ProjectStore`, `RenderQueue`, harness offline guard | Fault injection, corruption recovery, and zero-network report |
| Portrait/accessibility | `FeatureUI` | UI tests at iPhone widths, VoiceOver identifiers, touch-target audit |

## 16. Implementation sequence and exit criteria

### Phase 0: timing and media spike

- Establish `CoreDomain` timeline types and `ProjectClock` mapping.
- Implement a real iPhone `AVAudioSession`/`AVAudioEngine` click and prior-track playback path.
- Capture one camera/microphone take through `AVCaptureSession` and `AVAssetWriter`-backed segments.
- Persist a local package and recover a finalized segment after termination.
- Compose a two-tile video with a rendered audio track.

Exit: a real iPhone can produce and reopen a known two-track, 60-second local render with measured sync and no network.

### Phase 1: offline MVP

- Project library, manifest migration, import/export package, and recovery scanner.
- Capture retakes, audio-only mode, route status, count-in, meter, subdivisions, and storage preflight.
- Waveforms, trim, offset, mute/solo/gain/pan, built-in effects, sync assist, and confidence.
- Flexible tile layouts and H.264/HEVC plus AAC/ALAC/WAV outputs.
- Photos/Files/share handoff only after verification.
- Full harness contract and offline acceptance test.

Exit: all P0 PRD requirements pass on the supported device matrix.

### Phase 2: musician depth

- Punch-in and comping, drift compensation, external channel mapping, AUv3 hosting, tempo maps, hands-free controls, batch exports, and stronger proxy controls.

### Phase 3: optional platform enhancements

- Availability-gated iOS 26 input-picker/high-quality Bluetooth path, optional MultiCam, ProRes/HDR where useful, MIDI clock/Ableton Link, and optional desktop interchange.

## 17. Definition of done

The native implementation is ready for product validation when:

1. The physical-device offline acceptance harness passes with zero core network attempts.
2. A first-time user can complete the two-track capture → sync/mix → local export flow in portrait without an account.
3. Timing targets pass for the supported route/device test set, and Bluetooth limitations are disclosed.
4. Preview and export use the same serialized plan and produce equivalent timing/mix decisions.
5. Failed, cancelled, interrupted, and low-storage operations preserve the project and offer a recoverable next step.
6. The final video and audio files can be opened outside the app and their receipts clearly distinguish local readiness, Photos save, Files save, and sharing.
7. No social, cloud, login, analytics-upload, or remote-rendering dependency exists in the native target.

