# Loopline verification harness

## Automated checks

```sh
bash harness/run-core-tests.sh
bash harness/run-ios-build.sh
bash harness/run-ui-tests.sh
```

The Swift package contains the Foundation-only domain plus a separate Apple-media test target.
The media tests generate deterministic WAV and H.264 fixtures locally.
They cover sync direction and silence rejection, waveform generation, saved settings and track identity, draft commit/recovery, corrupt-project isolation, safe media paths, preview/export composition parity, audio/video onset preservation, mute behavior, render cancellation, and verified output frames and dimensions.
Every track count from 2 through 8 is composed and exported.
Each output is decoded to check every occupied tile and audio headroom, including the incomplete final row in odd track counts.

The SDK harness builds a generic iPhone app with signing disabled.
The shared Xcode scheme also includes `LooplineUITests`.
The UI tests navigate the real application, verify empty states, create and reopen sessions, change persisted metronome settings, and attach portrait screenshots.
Generated two-track and eight-track sessions exercise Sync Assist apply/undo, mix playback, saved eighth-track volume/mute/solo/timing edits, and actual local video exports.

The default UI destination is the first available iPhone on the newest installed simulator runtime.
Set `LOOPLINE_TEST_DESTINATION` for a different installed simulator.
UI tests use debug-only launch arguments to skip unavailable simulator camera permissions and select an isolated local project root.
Relative project roots resolve inside the application's temporary directory.
The optional seed argument generates six-second H.264 video and deterministic audio for 2 through 8 parts.
Part 2 contains a known 120 ms audio delay for sync verification.
Fixture generation requires both harness mode and an explicit isolated project root.
It is compiled only for Debug simulator builds and does not exercise real camera hardware.

```text
-LooplineHarnessMode
-LooplineProjectRoot <absolute-path-or-app-relative-directory>
-LooplineSeedTrackCount <2-through-8>
```

These arguments are compiled only into Debug builds.
The UI tests do not save to Photos or invoke an external share destination.
The app and media fixtures require no network access.
The remaining SDD harness flags and fault-injection adapters are future work.

Verified on 2026-10-23:

| Check | Target | Result |
| --- | --- | --- |
| Core and media tests | macOS, Swift 6.4 | 23 passed |
| App build | Generic iOS device, signing disabled | Passed |
| UI tests | iPhone SE, iOS 18 | 5 passed |
| UI tests | iPhone 18 Pro, iOS 27 | 5 passed |

The 2-through-8-track export checks use short generated recordings and 720p H.264 output.
Playback tests also verify that starting and stopping the mix keeps its transport button in place.

## Physical iPhone acceptance

This checklist remains required before claiming capture and overdub timing acceptance for sessions with 2 through 8 tracks.

1. Configure signing, install the app, and enable airplane mode.
2. Grant camera and microphone access and connect wired headphones.
3. Record a 60-second lead, then a second take while listening to the lead; continue through an eight-track session.
4. Verify count-in alignment, measured onset error, video orientation, audio level, and end-of-take drift.
5. Adjust volume, mute, solo, and offset; force-quit and reopen; confirm all edits and track durations remain.
6. Run Sync Assist with known early/late content, reject an ambiguous match, apply a reliable recommendation, and undo it.
7. Disconnect the audio route during capture and verify a retained take and a clear interruption message.
8. Interrupt or terminate capture and inspect draft recovery, including a file stopped mid-write.
9. Render H.264 and supported HEVC variants; open each local output outside the app and verify first/middle/last frames and audio.
10. Cancel a render, retry it, and confirm source media is unchanged and no incomplete output is offered for sharing.
11. Save to On My iPhone and Photos; deny Photos permission and confirm the verified local file remains available.
12. Exercise low storage, long takes, all track counts from 2 through 8, and thermal pressure on the oldest supported device.

Measure the PRD onset targets: median at most 10 ms and P95 at most 20 ms for supported wired/USB routes.
Automated simulator and Mac tests do not establish those hardware measurements.
