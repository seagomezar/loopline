# Offline multi-voice video studio research

Research date: 15 August 2026  
Scope: iPhone-only, offline-first capture and editing of multiple audio/video takes, ending in a locally saved final video and audio file. The editor is designed for portrait iPhone use at roughly 390–430 pt wide. Social feeds, public profiles, cloud collaboration, iPad support, and any feature that requires a network connection are intentionally excluded.

## Executive conclusion

Acapella’s durable product insight is simple: let a person record each part while hearing and seeing the earlier parts, then present the result as a synchronized multi-frame music video. Mixcord’s official product page positions Acapella around up to nine instruments or musicians, synchronized audio/video tracks, EQ, noise gate, processor, metronome, panning, watermarks, HD video, CD-quality audio, and ALAC export. The App Store listing adds a ten-minute recording limit, one imported starter video, social discovery/collaboration, and sharing to social platforms. [Mixcord product page](https://www.mixcord.co/pages/acapella-singing-app) · [App Store listing](https://apps.apple.com/us/app/acapella-from-picplaypost/id924635678)

The opportunity is not to reproduce the social product. It is to make the focused offline studio that musicians expect Acapella to be:

1. Start recording without an account or network.
2. Use a guide track, a click, or the first performance as the time reference.
3. Record unlimited takes, with durable retakes and project autosaves.
4. Hear previous parts through a safe monitoring route while recording the next part.
5. Inspect waveforms, auto-align, and manually nudge timing at sample/millisecond/frame precision.
6. Mix every track and arrange every visual tile.
7. Render a finished video, audio-only mix, stems, or editable project bundle to the device.

“Unlimited” should mean no product or subscription cap. It cannot mean infinite performance: storage, memory, thermal headroom, camera formats, and export time are physical constraints. Those constraints should be predicted and explained rather than hidden behind arbitrary limits.

## 1. What the reference product does well

### Core workflow

The original Acapella workflow is a useful benchmark because it compresses a normally desktop-heavy task into a small number of actions: create a project, record one part, add parts while listening to what came before, tune the mix, and share a tiled performance. The App Store description confirms the important building blocks: multi-frame music video creation, up to ten minutes, import of one video to start, EQ/noise gate/processor, panning, a built-in metronome, CD-quality video audio, and ALAC or M4A audio export. [App Store listing](https://apps.apple.com/us/app/acapella-from-picplaypost/id924635678)

### Feature baseline

| Capability | Acapella baseline | Loopline implication |
| --- | --- | --- |
| Sequential multi-take capture | Yes | Make it the primary flow and persist every take immediately. |
| Hear earlier tracks | Yes | Prioritize low-latency monitoring, route warnings, and headphone checks. |
| Synchronized video grid | Yes | Support presets plus arbitrary custom layouts and per-tile transforms. |
| Audio shaping | EQ, noise gate, processor, pan | Offer safe defaults, per-track controls, and a mix preview that matches export. |
| Timing control | Metronome and sync tools | Make timing measurable: count-in, click, waveform correlation, confidence, and nudge. |
| Audio export | ALAC/M4A | Add ALAC, WAV, AAC, per-track stems, and an editable project package. |
| Video export | HD/CD-quality audio | Add H.264 compatibility, HEVC efficiency, 4K where supported, and local file destinations. |
| Length / track limits | Ten minutes and “up to nine” positioning | Remove artificial caps; expose device/storage-based estimates. |
| Account / social | Discover, profiles, collaboration, platform sharing | Remove from the product. Share only through the system share sheet after local render. |

## 2. Gaps and user pain signals

The App Store listing is unusually direct about the product’s current constraints: the ten-minute limit is treated as a Pro feature, and social/community behavior is part of the product description. Several public reviews also point to the exact places where an offline-first rewrite can be better:

- a recent review praises the unique ease of multi-part video creation but says the app has bugs, lacks editing for a bad section, and asks users to pay for longer recordings;
- another review describes difficulty getting multiple audio/video devices and monitoring routes to behave cleanly;
- an older review says that needing to commit to a layout early and being limited to one project at a time makes the workflow brittle.

These are qualitative signals, not a statistically controlled study, but they align with the product design direction: preserve the single-purpose magic and remove irreversible setup, social dependency, and fragile export edges. [App Store reviews](https://apps.apple.com/us/app/acapella-from-picplaypost/id924635678)

The newer Android app using the name Acapella demonstrates several useful details: up to four video tracks, recording while previous tracks play, front/back camera support, a mixer with latency adjustment, volume and solo/mute, waveforms, 15x zoom, grid export, audio-only export, and fixes for different-duration videos and long-waveform/memory crashes. It is a separate product from Mixcord’s iOS Acapella, so it should not be treated as one product’s specification. [Google Play listing](https://play.google.com/store/apps/details?id=app.acapella.app)

## 3. Competitive and adjacent products

### Mixcord Acapella

Best direct reference. It owns the “one-person choir in a grid” use case, combines video and audio, and has a recognizable social identity. Its weaknesses for this brief are account/social gravity, a ten-minute Pro ceiling, a finite multi-frame model, and a workflow that historically makes retakes/layout changes feel expensive. [Mixcord product page](https://www.mixcord.co/pages/acapella-singing-app) · [App Store listing](https://apps.apple.com/us/app/acapella-from-picplaypost/id924635678)

### The Android app named Acapella

Useful evidence that a musician-oriented mixer needs visible waveforms, latency adjustment, precise zoom, solo/mute, volume boost, and a clear export progress state. Its public changelog mentions crashes with different durations and loading four videos, which reinforces the need for memory-aware proxies and render validation. [Google Play listing](https://play.google.com/store/apps/details?id=app.acapella.app)

### GarageBand for iPhone

Strongest adjacent audio reference. Apple lists support for up to 32 tracks, multi-take recording, 24-bit recording/mixing/export, exact region placement, Audio Unit Extensions, and sharing a song as an audio file or editable GarageBand project. It is not a multi-frame video capture product, which is why musicians often need a second video editor. [GarageBand App Store listing](https://apps.apple.com/us/app/garageband/id408709785) · [Apple support: share songs](https://support.apple.com/guide/garageband-iphone/share-songs-chs39284d66/ios)

### BandLab

BandLab demonstrates the appeal of combining a studio timeline with a “Video Mix” mode, but the product is fundamentally a global community and cloud platform. Its App Store editorial description explicitly frames it around a global community, and its product surface includes Studio and Video Mix. The lesson is to keep the creation surface focused while omitting the network layer entirely. [Apple App Store editorial](https://apps.apple.com/us/iphone/story/id1626976174) · [BandLab Video Mix help](https://help.bandlab.com/hc/en-us/articles/360023612574-Getting-Started-with-Video-Mix)

### LumaFusion

Best adjacent video-editor reference. Its App Store listing advertises six video/audio/graphic tracks, six additional audio tracks, 4K ProRes and HDR handling, and a touch-oriented timeline. It proves a serious local video editor can live on iOS, but its general-purpose editing model is heavier than the simple “record the next voice” task. [LumaFusion App Store listing](https://apps.apple.com/us/app/lumafusion/id1062022008)

### Soundbrenner metronome

Best reference for musician-grade click behavior and control breadth: tap tempo, time signatures, subdivisions, accents, count-in, setlist/preset management, visual effects, and external MIDI/Ableton Link support are all described in its public product materials. Loopline should adopt the useful parts for a self-contained project click without making network sync a requirement. [Soundbrenner metronome](https://metronome.soundbrenner.com/) · [Soundbrenner app listing](https://play.google.com/store/apps/details?hl=en_US&id=com.soundbrenner.pulse)

## 4. State of the art on iOS

### Capture

Apple’s capture model is built around `AVCaptureSession`, camera/microphone inputs, outputs, and connections. A standard session can record a camera and microphone into a movie; orientation, mirroring, stabilization, frame rate, and format are configured on the connections and device format. The app should use a normal single-camera session for the sequential overdub path and reserve `AVCaptureMultiCamSession` for optional simultaneous front/rear capture on supported hardware. Multi-camera is a hardware-budget feature, not a dependency for the core workflow. [Setting up a capture session](https://developer.apple.com/documentation/avfoundation/setting-up-a-capture-session) · [AVCaptureMultiCamSession](https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession) · [AVCaptureConnection](https://developer.apple.com/documentation/avfoundation/avcaptureconnection)

The capture pipeline should keep the source video and audio in a project-local asset, but generate a lower-resolution preview proxy and waveform metadata as soon as a take is committed. This prevents the editor from decoding every 4K frame just to draw a grid or scrubber.

### Timing and synchronization

The correct timing model is one shared project timeline, expressed with Core Media time and anchored to the device’s host/audio clock. Apple describes `CMClock` as a source of time and notes that the host clock and audio device clock can be compared for drift. `AVAudioTime` carries sample-time and/or host-time representations. `AVAudioPlayerNode` can schedule buffers or file segments at explicit sample times, while `AVAudioEngine` supports manual offline rendering. [CMClock](https://developer.apple.com/documentation/coremedia/cmclock) · [AVAudioTime](https://developer.apple.com/documentation/avfaudio/avaudiotime) · [AVAudioPlayerNode](https://developer.apple.com/documentation/avfaudio/avaudioplayernode) · [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine)

That leads to a specific design choice: the metronome and prior-track playback must be scheduled by the audio engine’s sample timeline, not by UI timers. The UI can animate a playhead, but it must never be the time source. Captured audio/video sample-buffer timestamps remain the source of truth for the take, and the project stores an explicit start offset for each track.

### Audio routes and monitoring

`AVAudioSession` is the system coordinator for input, output, interruptions, and route changes. A `.playAndRecord` category supports simultaneous input/output, and route-change notifications cover headphones, Bluetooth, USB interfaces, and disconnections. iOS 26 adds a high-quality Bluetooth recording option for supported AirPods, but Apple notes that it may increase input latency and that availability is region/device dependent. [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession) · [Responding to audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes) · [High-quality Bluetooth recording](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/bluetoothhighqualityrecording)

The product should therefore:

- strongly recommend wired or USB monitoring for the lowest and most stable latency;
- measure and display the active route, sample rate, input/output latency, and whether the route is safe for overdubbing;
- compensate known route latency for the guide playback path;
- warn when Bluetooth latency makes real-time singing against a click less reliable;
- pause safely on interruptions and route removal, preserving the take in progress where possible;
- keep high-fidelity capture separate from optional voice processing. Apple’s Voice Processing I/O exists for echo cancellation and voice processing, but that processing should not silently color a music take. [Voice Processing I/O](https://developer.apple.com/documentation/audiotoolbox/kaudiounitsubtype_voiceprocessingio)

### Audio mixing and effects

`AVAudioEngine` is appropriate for preview and offline rendering because it supports node graphs, mixers, effects, and manual rendering. `AVAudioMix` and `AVMutableAudioMixInputParameters` are appropriate for export-time volume/pan automation when the render path is composition-based. AUv3 hosting allows optional third-party effects, but built-in EQ, high-pass/low-cut, noise gate, compressor, limiter, and reverb should cover the core product without requiring users to install anything. [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine) · [Audio Unit v3 plug-ins](https://developer.apple.com/documentation/audiotoolbox/audio-unit-v3-plug-ins) · [Incorporating audio effects and instruments](https://developer.apple.com/documentation/audiotoolbox/incorporating-audio-effects-and-instruments)

The mix must be deterministic: the audio heard in preview should use the same project offsets, gain/pan values, and effect order as the export renderer. A pre-export “render check” should find clipping, missing media, unsupported sample rates, and silent tracks.

### Video composition and export

Apple’s composition stack provides the exact building blocks needed for a local grid editor:

- `AVMutableComposition` inserts and arranges source time ranges without altering the source files;
- `AVAssetWriter` writes interleaved QuickTime/MP4 media and supports separate audio/video inputs;
- `AVMutableVideoComposition` and layer instructions transform, crop, scale, and place tiles;
- `AVVideoCompositionCoreAnimationTool` can add static or animated overlay layers during offline rendering;
- `AVAssetExportSession` exports an asset with a video composition and audio mix and exposes progress; newer iOS 26 APIs also provide async export and export state monitoring. [AVMutableComposition](https://developer.apple.com/documentation/avfoundation/avmutablecomposition) · [AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter) · [AVAssetWriterInput](https://developer.apple.com/documentation/avfoundation/avassetwriterinput) · [AVVideoCompositionCoreAnimationTool](https://developer.apple.com/documentation/avfoundation/avvideocompositioncoreanimationtool) · [AVAssetExportSession](https://developer.apple.com/documentation/avfoundation/avassetexportsession) · [iOS 26 async export](https://developer.apple.com/documentation/avfoundation/avassetexportsession/export%28to%3Aas%3Aisolation%3A%29)

For a first native implementation, build the final video as a composition with one visual layer per active tile, one audio mix input per track, and a deterministic render-size/aspect-ratio preset. Use a custom compositor only when rounded masks, advanced transitions, or large arbitrary layouts justify the extra complexity.

### Local storage, import, and share

The project should be a local document package with a manifest, source media, proxies, waveforms, and render history. Imported media should be copied into the app sandbox so the project does not silently depend on a temporary or remote provider URL. `UIDocumentPickerViewController` provides access to external documents through security-scoped URLs, and `UIActivityViewController` provides the standard device share surface. Finished video should be savable to Photos via PhotoKit and to the local Files provider. [Document picker](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller) · [Providing access to directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories) · [Activity view controller](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller) · [Photo library changes](https://developer.apple.com/documentation/photokit/requesting-changes-to-the-photo-library)

The app should not attempt to capture protected streaming audio from another app. The supported offline path is a user-owned or user-provided audio/video file imported from Files/Photos, plus takes recorded in the app. This is clearer, more reliable, and more legally defensible than promising to ingest protected streaming services.

### Background work and reliability

iOS background processing is opportunistic. `BGProcessingTask` can run for minutes but may be interrupted and is scheduled for idle time; it is not a guarantee that a foreground export will finish after the user leaves the app. The core renderer should stay foreground-visible, keep the device awake, write checkpoints, and recover after interruption. A background task can be a later convenience for proxy generation or deferred render retries, never the only path to a finished file. [BGProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask) · [BGProcessingTaskRequest](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtaskrequest)

## 5. Product principles

1. **Offline is a capability, not a mode.** Airplane mode must not reduce the core product.
2. **Audio is the master clock.** Video follows the project timeline and is never aligned by visual guesswork alone.
3. **Every destructive action is reversible.** Retakes, trims, layout changes, and mix changes remain editable.
4. **Show the constraint before the failure.** Storage, route latency, thermal pressure, unsupported codecs, and missing permissions are surfaced early.
5. **A real file is the finish line.** The user should always leave with a file in Photos or Files, not a post waiting in a network service.
6. **Simple on first use, precise on demand.** A guided two-track flow can be approachable while the mixer still offers waveform zoom, millisecond nudges, and per-track processing.

## 6. Recommended product wedge

The MVP should beat Acapella on five moments rather than try to become a general-purpose video editor:

- first take starts in under 30 seconds;
- second take is easy to hear and record with safe monitoring;
- automatic sync gives a confidence result and a one-tap fix;
- the layout can change at any time without restarting the project;
- the final video and a high-quality audio mix are saved locally with an explicit completion receipt.

The prototype in this repository follows those five moments.

## 7. Key research-derived decisions

- Target iPhone on iOS 18+ for the baseline implementation; guard iOS 26-only input picker and high-quality Bluetooth features behind availability checks. iPad is explicitly out of scope for v1.
- Use standard sequential capture for the primary experience; do not require MultiCam hardware.
- Store projects in a local package; copy imported media into the package.
- Capture and edit with a 48 kHz project audio rate where the active route supports it; resample explicitly and record the conversion in the project manifest when it does not.
- Render audio through a deterministic float mix, with a limiter on the master bus and optional lossless audio-only export.
- Offer H.264 MP4 for maximum compatibility and HEVC MOV/MP4 for smaller local files; offer ALAC/M4A and WAV audio-only exports.
- Use a soft resource budget, never a subscription cap: estimate storage before capture and provide a proxy-quality recording option on constrained devices.
- Keep social discovery, account login, cloud collaboration, network recommendations, and upload analytics out of the product and out of the native codebase.

## Sources

Primary product sources:

- [Mixcord Acapella product page](https://www.mixcord.co/pages/acapella-singing-app)
- [Acapella from PicPlayPost — App Store](https://apps.apple.com/us/app/acapella-from-picplaypost/id924635678)
- [Acapella — Google Play](https://play.google.com/store/apps/details?id=app.acapella.app)
- [GarageBand — App Store](https://apps.apple.com/us/app/garageband/id408709785)
- [BandLab — App Store editorial](https://apps.apple.com/us/iphone/story/id1626976174)
- [BandLab Video Mix help](https://help.bandlab.com/hc/en-us/articles/360023612574-Getting-Started-with-Video-Mix)
- [LumaFusion — App Store](https://apps.apple.com/us/app/lumafusion/id1062022008)
- [Soundbrenner metronome](https://metronome.soundbrenner.com/)

Primary platform sources:

- [Setting up a capture session](https://developer.apple.com/documentation/avfoundation/setting-up-a-capture-session)
- [AVCaptureMultiCamSession](https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession)
- [AVCaptureConnection](https://developer.apple.com/documentation/avfoundation/avcaptureconnection)
- [CMClock](https://developer.apple.com/documentation/coremedia/cmclock)
- [AVAudioTime](https://developer.apple.com/documentation/avfaudio/avaudiotime)
- [AVAudioPlayerNode](https://developer.apple.com/documentation/avfaudio/avaudioplayernode)
- [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Responding to audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes)
- [High-quality Bluetooth recording](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/bluetoothhighqualityrecording)
- [Voice Processing I/O](https://developer.apple.com/documentation/audiotoolbox/kaudiounitsubtype_voiceprocessingio)
- [Audio Unit v3 plug-ins](https://developer.apple.com/documentation/audiotoolbox/audio-unit-v3-plug-ins)
- [AVMutableComposition](https://developer.apple.com/documentation/avfoundation/avmutablecomposition)
- [AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter)
- [AVAssetWriterInput](https://developer.apple.com/documentation/avfoundation/avassetwriterinput)
- [AVVideoCompositionCoreAnimationTool](https://developer.apple.com/documentation/avfoundation/avvideocompositioncoreanimationtool)
- [AVAssetExportSession](https://developer.apple.com/documentation/avfoundation/avassetexportsession)
- [iOS 26 async export](https://developer.apple.com/documentation/avfoundation/avassetexportsession/export%28to%3Aas%3Aisolation%3A%29)
- [UIDocumentPickerViewController](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller)
- [UIActivityViewController](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller)
- [PhotoKit changes](https://developer.apple.com/documentation/photokit/requesting-changes-to-the-photo-library)
- [BGProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask)
