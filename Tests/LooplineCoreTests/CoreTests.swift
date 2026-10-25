import Foundation
import XCTest
@testable import LooplineCore

final class CoreTests: XCTestCase {
    func testSampleTimebaseUsesIntegerSampleConversions() {
        let timebase = SampleTimebase(sampleRate: .rate48k)

        XCTAssertEqual(timebase.samples(forMilliseconds: 500).rawValue, 24_000)
        XCTAssertEqual(timebase.samples(forMilliseconds: -1).rawValue, -48)
        XCTAssertEqual(timebase.milliseconds(for: SamplePosition(24_000)), 500)
        XCTAssertEqual(timebase.samplePosition(for: FramePosition(30), at: .fps30).rawValue, 48_000)
    }

    func testRationalRoundingIsExplicitForNegativeOffsets() {
        let fraction = Rational(numerator: -1, denominator: 3)

        XCTAssertEqual(fraction.rounded(.towardZero), 0)
        XCTAssertEqual(fraction.rounded(.down), -1)
        XCTAssertEqual(fraction.rounded(.up), 0)
        XCTAssertEqual(fraction.rounded(.nearestAwayFromZero), 0)
    }

    func testMetronomeEventsUseSamplePositionsAndAccents() {
        let configuration = MetronomeConfiguration(
            tempo: .bpm120,
            timeSignature: .commonTime,
            subdivision: .eighth
        )

        let events = MetronomeMath.events(
            for: 0...0,
            at: .rate48k,
            configuration: configuration
        )

        XCTAssertEqual(events.count, 8)
        XCTAssertEqual(events.map(\.samplePosition.rawValue), [0, 12_000, 24_000, 36_000, 48_000, 60_000, 72_000, 84_000])
        XCTAssertEqual(events[0].accent, .downbeat)
        XCTAssertEqual(events[2].accent, .beat)
        XCTAssertEqual(events[1].accent, .subdivision)
    }

    func testCountInIsPlacedBeforeProjectZero() {
        let configuration = MetronomeConfiguration(countInBars: 1)
        let events = MetronomeMath.countInEvents(
            at: .rate48k,
            configuration: configuration
        )

        XCTAssertEqual(events.first?.samplePosition.rawValue, -96_000)
        XCTAssertEqual(events.last?.samplePosition.rawValue, -24_000)
        XCTAssertEqual(MetronomeMath.countInDuration(at: .rate48k, configuration: configuration).rawValue, 96_000)
    }

    func testManifestRoundTripsAndValidatesActiveTake() throws {
        let projectID = ProjectID(rawValue: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)
        let trackID = TrackID(rawValue: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!)
        let takeID = TakeID(rawValue: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!)
        let media = MediaAssetReference(
            mediaPath: "Assets/takes/lead.mov",
            duration: SampleDuration(48_000),
            sampleRate: .rate48k
        )
        let take = TrackTake(
            id: takeID,
            media: media,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let track = Track(
            id: trackID,
            name: "Lead",
            takes: [take],
            activeTakeID: takeID,
            placement: TrackPlacement(
                sourceRange: SampleRange(start: .zero, duration: SampleDuration(48_000)),
                syncOffset: SampleOffset(48)
            )
        )
        let project = Project(
            id: projectID,
            name: "Offline Demo",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            modifiedAt: Date(timeIntervalSince1970: 1_700_000_001),
            duration: SampleDuration(48_000),
            tracks: [track]
        )
        let manifest = ProjectManifest(project: project)

        let data = try manifest.encodedData()
        let decoded = try ProjectManifest.decoded(from: data)

        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(decoded.project.tracks[0].placement.effectiveTimelineStart.rawValue, 48)
    }

    func testSyncOffsetKeepsSamplesCanonicalAcrossViews() {
        let timebase = SampleTimebase(sampleRate: .rate48k)
        let offset = SyncOffset(milliseconds: -10, timebase: timebase, source: .waveformCorrelation)

        XCTAssertEqual(offset.samples.rawValue, -480)
        XCTAssertEqual(offset.milliseconds(in: timebase), -10)
        XCTAssertEqual(offset.frames(in: timebase, at: .fps30), 0)
        XCTAssertEqual(offset.adding(SampleOffset(480)).samples.rawValue, 0)
        XCTAssertEqual(offset.source, .waveformCorrelation)
    }

    func testPulseStatusSynchronizesCountdownAndBeatProgressWithTempoAndMeter() {
        // 120 BPM, 4/4, 1 bar count-in => 4 beats of 0.5s each (total 2.0s count-in)
        let config44 = MetronomeConfiguration(
            tempo: .bpm120,
            timeSignature: .commonTime,
            subdivision: .eighth,
            countInBars: 1
        )

        let preRoll = MetronomeMath.pulseStatus(elapsedFromProjectZero: -2.2, configuration: config44)
        XCTAssertTrue(preRoll.isCountingIn)
        XCTAssertEqual(preRoll.countdownBeatsRemaining, 4)
        XCTAssertEqual(preRoll.barNumber, 1)
        XCTAssertEqual(preRoll.beatInBar, 1)
        XCTAssertTrue(preRoll.isDownbeat)

        let beat1 = MetronomeMath.pulseStatus(elapsedFromProjectZero: -1.9, configuration: config44)
        XCTAssertTrue(beat1.isCountingIn)
        XCTAssertEqual(beat1.countdownBeatsRemaining, 4)
        XCTAssertEqual(beat1.beatInBar, 1)
        XCTAssertTrue(beat1.isDownbeat)
        XCTAssertEqual(beat1.beatProgress, 0.2, accuracy: 0.001)

        let beat2 = MetronomeMath.pulseStatus(elapsedFromProjectZero: -1.4, configuration: config44)
        XCTAssertTrue(beat2.isCountingIn)
        XCTAssertEqual(beat2.countdownBeatsRemaining, 3)
        XCTAssertEqual(beat2.beatInBar, 2)
        XCTAssertFalse(beat2.isDownbeat)

        let beat3 = MetronomeMath.pulseStatus(elapsedFromProjectZero: -0.9, configuration: config44)
        XCTAssertEqual(beat3.countdownBeatsRemaining, 2)
        XCTAssertEqual(beat3.beatInBar, 3)

        let beat4 = MetronomeMath.pulseStatus(elapsedFromProjectZero: -0.4, configuration: config44)
        XCTAssertEqual(beat4.countdownBeatsRemaining, 1)
        XCTAssertEqual(beat4.beatInBar, 4)

        let liveBar1Beat1 = MetronomeMath.pulseStatus(elapsedFromProjectZero: 0.1, configuration: config44)
        XCTAssertFalse(liveBar1Beat1.isCountingIn)
        XCTAssertNil(liveBar1Beat1.countdownBeatsRemaining)
        XCTAssertEqual(liveBar1Beat1.barNumber, 1)
        XCTAssertEqual(liveBar1Beat1.beatInBar, 1)
        XCTAssertTrue(liveBar1Beat1.isDownbeat)

        // 120 BPM, 6/8, 2 bars count-in => 12 eighth-note beats of 0.25s each (total 3.0s count-in)
        let config68 = MetronomeConfiguration(
            tempo: .bpm120,
            timeSignature: .sixEight,
            subdivision: .quarter,
            countInBars: 2
        )
        let bar2Beat1 = MetronomeMath.pulseStatus(elapsedFromProjectZero: -1.45, configuration: config68)
        XCTAssertTrue(bar2Beat1.isCountingIn)
        XCTAssertEqual(bar2Beat1.countdownBeatsRemaining, 6)
        XCTAssertEqual(bar2Beat1.barNumber, 2)
        XCTAssertEqual(bar2Beat1.beatInBar, 1)
        XCTAssertTrue(bar2Beat1.isDownbeat)
    }
}
