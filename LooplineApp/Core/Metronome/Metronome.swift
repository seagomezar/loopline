import Foundation

/// Tempo stored as milli-beats-per-minute so persisted timing never depends
/// on a binary floating-point value.
public struct Tempo: Codable, Hashable, Sendable, Comparable {
    public let milliBeatsPerMinute: Int64

    public init(milliBeatsPerMinute: Int64) {
        precondition(milliBeatsPerMinute > 0, "Tempo must be positive")
        self.milliBeatsPerMinute = milliBeatsPerMinute
    }

    public init(beatsPerMinute: Double) {
        precondition(beatsPerMinute.isFinite && beatsPerMinute > 0, "Tempo must be finite and positive")
        self.init(milliBeatsPerMinute: Int64((beatsPerMinute * 1_000).rounded()))
    }

    public static let bpm120 = Tempo(milliBeatsPerMinute: 120_000)

    public var beatsPerMinute: Double {
        Double(milliBeatsPerMinute) / 1_000.0
    }

    public static func < (lhs: Tempo, rhs: Tempo) -> Bool {
        lhs.milliBeatsPerMinute < rhs.milliBeatsPerMinute
    }
}

public struct TimeSignature: Codable, Hashable, Sendable {
    public let beatsPerBar: Int
    public let beatUnitDenominator: Int

    public init(beatsPerBar: Int, beatUnitDenominator: Int) {
        precondition(beatsPerBar > 0, "A time signature needs at least one beat")
        precondition(
            beatUnitDenominator > 0 && (beatUnitDenominator & (beatUnitDenominator - 1)) == 0,
            "The time-signature denominator must be a power of two"
        )
        self.beatsPerBar = beatsPerBar
        self.beatUnitDenominator = beatUnitDenominator
    }

    public static let commonTime = TimeSignature(beatsPerBar: 4, beatUnitDenominator: 4)
    public static let cutTime = TimeSignature(beatsPerBar: 2, beatUnitDenominator: 4)
    public static let sixEight = TimeSignature(beatsPerBar: 6, beatUnitDenominator: 8)
}

public struct MetronomeSubdivision: Codable, Hashable, Sendable, Comparable {
    public let divisionsPerBeat: Int

    public init(divisionsPerBeat: Int) {
        precondition(divisionsPerBeat > 0, "A subdivision must be positive")
        precondition(
            BeatPosition.ticksPerBeat % Int64(divisionsPerBeat) == 0,
            "Subdivision must divide the fixed beat resolution"
        )
        self.divisionsPerBeat = divisionsPerBeat
    }

    public static let quarter = MetronomeSubdivision(divisionsPerBeat: 1)
    public static let eighth = MetronomeSubdivision(divisionsPerBeat: 2)
    public static let triplet = MetronomeSubdivision(divisionsPerBeat: 3)
    public static let sixteenth = MetronomeSubdivision(divisionsPerBeat: 4)
    public static let thirtySecond = MetronomeSubdivision(divisionsPerBeat: 8)

    public static func < (lhs: MetronomeSubdivision, rhs: MetronomeSubdivision) -> Bool {
        lhs.divisionsPerBeat < rhs.divisionsPerBeat
    }
}

/// A fixed-point musical beat. One beat is exactly 9,600 ticks.
///
/// The resolution is deliberately divisible by common straight and triplet
/// subdivisions while remaining small enough for practical project lengths.
public struct BeatPosition: Codable, Hashable, Sendable, Comparable, ExpressibleByIntegerLiteral {
    public static let ticksPerBeat: Int64 = 9_600
    public let rawValue: Int64

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    public init(wholeBeats: Int64) {
        self.init(rawValue: wholeBeats * Self.ticksPerBeat)
    }

    public init(integerLiteral value: Int64) {
        self.init(wholeBeats: value)
    }

    public static let zero = BeatPosition(rawValue: 0)

    public func advanced(by ticks: Int64) -> BeatPosition {
        let result = rawValue.addingReportingOverflow(ticks)
        precondition(!result.overflow, "Beat-position overflow")
        return BeatPosition(rawValue: result.partialValue)
    }

    public static func < (lhs: BeatPosition, rhs: BeatPosition) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct TempoChange: Codable, Hashable, Sendable {
    public let position: BeatPosition
    public let tempo: Tempo

    public init(position: BeatPosition, tempo: Tempo) {
        self.position = position
        self.tempo = tempo
    }
}

public struct MeterChange: Codable, Hashable, Sendable {
    public let position: BeatPosition
    public let timeSignature: TimeSignature

    public init(position: BeatPosition, timeSignature: TimeSignature) {
        self.position = position
        self.timeSignature = timeSignature
    }
}

/// The serializable tempo and meter map for a project.
public struct TempoMap: Codable, Hashable, Sendable {
    public let initialTempo: Tempo
    public let initialTimeSignature: TimeSignature
    public let tempoChanges: [TempoChange]
    public let meterChanges: [MeterChange]

    public init(
        initialTempo: Tempo = .bpm120,
        initialTimeSignature: TimeSignature = .commonTime,
        tempoChanges: [TempoChange] = [],
        meterChanges: [MeterChange] = []
    ) {
        self.initialTempo = initialTempo
        self.initialTimeSignature = initialTimeSignature
        self.tempoChanges = tempoChanges.sorted { $0.position < $1.position }
        self.meterChanges = meterChanges.sorted { $0.position < $1.position }
    }

    public func tempo(at position: BeatPosition) -> Tempo {
        tempoChanges.last(where: { $0.position <= position })?.tempo ?? initialTempo
    }

    public func timeSignature(at position: BeatPosition) -> TimeSignature {
        meterChanges.last(where: { $0.position <= position })?.timeSignature ?? initialTimeSignature
    }

    public func validate() -> Bool {
        Self.isStrictlyIncreasing(tempoChanges.map(\.position)) &&
            Self.isStrictlyIncreasing(meterChanges.map(\.position))
    }

    private static func isStrictlyIncreasing(_ positions: [BeatPosition]) -> Bool {
        zip(positions, positions.dropFirst()).allSatisfy { $0.0 < $0.1 }
    }
}

public struct MetronomeConfiguration: Codable, Hashable, Sendable {
    public let tempo: Tempo
    public let timeSignature: TimeSignature
    public let subdivision: MetronomeSubdivision
    public let countInBars: Int

    public init(
        tempo: Tempo = .bpm120,
        timeSignature: TimeSignature = .commonTime,
        subdivision: MetronomeSubdivision = .quarter,
        countInBars: Int = 0
    ) {
        precondition(countInBars >= 0, "Count-in bars cannot be negative")
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.subdivision = subdivision
        self.countInBars = countInBars
    }
}

public enum MetronomeAccent: String, Codable, Hashable, Sendable {
    case downbeat
    case beat
    case subdivision
}

public struct MetronomeEvent: Codable, Hashable, Sendable {
    public let barIndex: Int64
    public let beatIndex: Int
    public let subdivisionIndex: Int
    public let samplePosition: SamplePosition
    public let accent: MetronomeAccent

    public init(
        barIndex: Int64,
        beatIndex: Int,
        subdivisionIndex: Int,
        samplePosition: SamplePosition,
        accent: MetronomeAccent
    ) {
        self.barIndex = barIndex
        self.beatIndex = beatIndex
        self.subdivisionIndex = subdivisionIndex
        self.samplePosition = samplePosition
        self.accent = accent
    }
}

/// Pure beat/sample math. Audio scheduling belongs to the AVFoundation layer;
/// this type only produces deterministic event decisions and sample positions.
public enum MetronomeMath {
    public static func samplesPerBeat(
        at sampleRate: SampleRate,
        tempo: Tempo,
        timeSignature: TimeSignature
    ) -> Rational {
        // Tempo is quarter-note BPM. A meter beat is 4 / denominator quarter notes.
        Rational(
            numerator: Int64(sampleRate.hertz) * 60_000 * 4,
            denominator: tempo.milliBeatsPerMinute * Int64(timeSignature.beatUnitDenominator)
        )
    }

    public static func samplePosition(
        for beat: BeatPosition,
        startingAt start: SamplePosition = .zero,
        at sampleRate: SampleRate,
        tempo: Tempo,
        timeSignature: TimeSignature,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> SamplePosition {
        let samplesPerBeat = samplesPerBeat(
            at: sampleRate,
            tempo: tempo,
            timeSignature: timeSignature
        )
        let offset = Rational(
            numerator: beat.rawValue * samplesPerBeat.numerator,
            denominator: BeatPosition.ticksPerBeat * samplesPerBeat.denominator
        ).rounded(rule)
        return start.advanced(by: SampleOffset(offset))
    }

    public static func countInDuration(
        at sampleRate: SampleRate,
        configuration: MetronomeConfiguration,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> SampleDuration {
        let totalBeats = Int64(configuration.countInBars * configuration.timeSignature.beatsPerBar)
        let samples = Rational(
            numerator: totalBeats * samplesPerBeat(
                at: sampleRate,
                tempo: configuration.tempo,
                timeSignature: configuration.timeSignature
            ).numerator,
            denominator: samplesPerBeat(
                at: sampleRate,
                tempo: configuration.tempo,
                timeSignature: configuration.timeSignature
            ).denominator
        ).rounded(rule)
        return SampleDuration(samples)
    }

    public static func events(
        for bars: ClosedRange<Int64>,
        startingAt start: SamplePosition = .zero,
        at sampleRate: SampleRate,
        configuration: MetronomeConfiguration,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> [MetronomeEvent] {
        var result: [MetronomeEvent] = []
        result.reserveCapacity(
            Int(bars.upperBound - bars.lowerBound + 1) *
                configuration.timeSignature.beatsPerBar *
                configuration.subdivision.divisionsPerBeat
        )

        for barIndex in bars {
            for beatIndex in 0..<configuration.timeSignature.beatsPerBar {
                for subdivisionIndex in 0..<configuration.subdivision.divisionsPerBeat {
                    let eventBeat = BeatPosition(
                        rawValue: (
                            (barIndex * Int64(configuration.timeSignature.beatsPerBar) + Int64(beatIndex)) *
                                BeatPosition.ticksPerBeat
                        ) +
                            Int64(subdivisionIndex) * BeatPosition.ticksPerBeat /
                            Int64(configuration.subdivision.divisionsPerBeat)
                    )
                    let position = samplePosition(
                        for: eventBeat,
                        startingAt: start,
                        at: sampleRate,
                        tempo: configuration.tempo,
                        timeSignature: configuration.timeSignature,
                        rounding: rule
                    )
                    let accent: MetronomeAccent
                    if beatIndex == 0 && subdivisionIndex == 0 {
                        accent = .downbeat
                    } else if subdivisionIndex == 0 {
                        accent = .beat
                    } else {
                        accent = .subdivision
                    }

                    result.append(
                        MetronomeEvent(
                            barIndex: barIndex,
                            beatIndex: beatIndex,
                            subdivisionIndex: subdivisionIndex,
                            samplePosition: position,
                            accent: accent
                        )
                    )
                }
            }
        }

        return result
    }

    public static func countInEvents(
        startingAt projectZero: SamplePosition = .zero,
        at sampleRate: SampleRate,
        configuration: MetronomeConfiguration,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> [MetronomeEvent] {
        guard configuration.countInBars > 0 else { return [] }
        let lastBar = -Int64(1)
        let firstBar = -Int64(configuration.countInBars)
        return events(
            for: firstBar...lastBar,
            startingAt: projectZero,
            at: sampleRate,
            configuration: configuration,
            rounding: rule
        )
    }
}
