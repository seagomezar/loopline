# Loopline

An offline iPhone studio for layering vocal or instrumental video takes and saving a finished grid video.
The current implementation targets iOS 18 or later.

The native app includes a local session library, timestamped audio/video capture, count-in and click, prior-part playback, saved mix edits, real waveforms and thumbnails, Sync Assist, composition preview, video export, Files, Photos, and the system share sheet.
Sessions with 2 through 8 tracks are the automated verification baseline.
Additional tracks remain available, subject to device resources; eight is not a software limit.
The interface follows the fonts and colors in the supplied reference deck.
See the [visual system](docs/design-system.md) for exact tokens and font sources.

## Run

Open `Loopline.xcodeproj` and select the shared `Loopline` scheme.
Device installation requires configuring your signing team.
A physical iPhone and wired headphones are needed to validate camera capture and overdub latency.

```sh
bash harness/run-core-tests.sh
bash harness/run-ios-build.sh
bash harness/run-ui-tests.sh
```

The Swift package tests run on macOS 15 or later with Swift 6 and Apple media frameworks.
The UI harness requires an installed iPhone simulator.
Override its destination with `LOOPLINE_TEST_DESTINATION` when necessary.
No tests download media or write to the user's Photos library.

## Current workflow

1. Record a part with an optional count-in.
2. Record another part while earlier parts play through headphones.
3. Preview the same composition used for export, adjust volume, mute, solo, or timing, and optionally apply an undoable Sync Assist recommendation.
4. Create a portrait 30 fps video using H.264 MP4 or HEVC MP4/MOV at 720p, 1080p, or 4K, subject to device codec support.
5. Save the verified local file to Files or Photos, or open the system share sheet.

Each session has one authoritative atomic `project.json`, a previous-save backup, local source takes, and renders.
Edits retain track and take IDs across relaunch.
A take is registered as a draft before capture starts and committed only after the media writer finishes and its duration is read.
Capture uses timestamped sample buffers and fragmented MOV output.
Finalized drafts can be reopened; recovery of a file interrupted mid-write still needs physical-device validation.
An unreadable draft can be set aside without deleting its source file so a session remains usable.

## Validation and remaining work

Automated tests exercise timing math, document round trips, early/late and silent sync fixtures, real waveforms, saved edits, draft recovery, corrupt-document isolation, path containment, video compositions with every track count from 2 through 8, export metadata, decoded output tiles, and eight-track audio headroom.
UI tests use generated local audio/video to exercise two-track sync with apply/undo, eight-track mix edits across relaunch, preview, and real video export, alongside navigation, empty states, session creation, and settings persistence.
Portrait screenshots are attached to each UI test run.
See an [eight-track exported frame](docs/screenshots/eight-track-render.png) from a generated simulator session.
A GitHub Actions workflow runs these checks once the project is hosted in a Git repository.

Physical-device timing, route interruptions, thermal pressure, low-storage capture, and Photos authorization still require device acceptance testing.
The PRD's measured timing and reliability targets have not yet been established.

Audio-only recording/export, stems, pan/effects processing, trim controls, editable package import/export, and advanced layout editing remain follow-up work.
Conservative mix headroom is applied consistently in preview and export; a measured true-peak limiter remains follow-up work.
The [PRD](docs/PRD.md) and [software design](docs/SDD.md) describe the broader target product, not a claim that every requirement is implemented.

## Other material

- [Research](docs/research.md)
- [Test harness and physical-device checklist](harness/README.md)
- [Browser prototype](prototype/index.html), which intentionally uses simulated media

The native core has no account, cloud, analytics, remote-rendering, or runtime font-download dependency.
User-selected Files and share providers remain explicit system handoffs.
