import Foundation

/// The rounding policy used when an exact time cannot be represented by a
/// whole number of samples or video frames.
public enum FixedPointRoundingRule: String, Codable, Hashable, Sendable {
    case towardZero
    case down
    case up
    case nearestAwayFromZero
}

/// An exact signed fraction backed by 64-bit integers.
///
/// The core uses this type at conversion boundaries so that sample and frame
/// calculations do not accumulate floating-point error. The denominator is
/// always positive and the fraction is reduced on initialization.
public struct Rational: Codable, Hashable, Sendable, Comparable {
    public let numerator: Int64
    public let denominator: Int64

    public init(numerator: Int64, denominator: Int64) {
        precondition(denominator > 0, "A rational denominator must be positive")
        precondition(numerator != Int64.min, "Int64.min cannot be normalized safely")

        let divisor = Self.greatestCommonDivisor(abs(numerator), denominator)
        self.numerator = numerator / divisor
        self.denominator = denominator / divisor
    }

    public static let zero = Rational(numerator: 0, denominator: 1)

    public var isNegative: Bool { numerator < 0 }

    public func rounded(_ rule: FixedPointRoundingRule = .nearestAwayFromZero) -> Int64 {
        let quotient = numerator / denominator
        let remainder = numerator % denominator

        guard remainder != 0 else { return quotient }

        switch rule {
        case .towardZero:
            return quotient
        case .down:
            return numerator < 0 ? quotient - 1 : quotient
        case .up:
            return numerator > 0 ? quotient + 1 : quotient
        case .nearestAwayFromZero:
            let doubledRemainder = abs(remainder) * 2
            return doubledRemainder >= denominator
                ? quotient + (numerator < 0 ? -1 : 1)
                : quotient
        }
    }

    public static func < (lhs: Rational, rhs: Rational) -> Bool {
        lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
    }

    private static func greatestCommonDivisor(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        var a = lhs
        var b = rhs
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(a, 1)
    }
}

/// A project sample rate in Hertz.
public struct SampleRate: Codable, Hashable, Sendable, Comparable {
    public let hertz: Int

    public init(hertz: Int) {
        precondition(hertz > 0, "A sample rate must be positive")
        self.hertz = hertz
    }

    public static let rate44_1k = SampleRate(hertz: 44_100)
    public static let rate48k = SampleRate(hertz: 48_000)
    public static let rate96k = SampleRate(hertz: 96_000)

    public static func < (lhs: SampleRate, rhs: SampleRate) -> Bool {
        lhs.hertz < rhs.hertz
    }
}

/// A signed sample position on the project timeline.
///
/// Negative positions are intentional: they support count-ins, pre-roll, and
/// a take whose sync recommendation moves it slightly before project zero.
public struct SamplePosition: Codable, Hashable, Sendable, Comparable, ExpressibleByIntegerLiteral {
    public let rawValue: Int64

    public init(_ rawValue: Int64) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int64) {
        self.init(value)
    }

    public static let zero = SamplePosition(0)

    public static func < (lhs: SamplePosition, rhs: SamplePosition) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func advanced(by offset: SampleOffset) -> SamplePosition {
        SamplePosition(rawValue.addingReportingOverflow(offset.rawValue))
    }

    public func advanced(by duration: SampleDuration) -> SamplePosition {
        SamplePosition(rawValue.addingReportingOverflow(duration.rawValue))
    }

    private init(_ addition: (partialValue: Int64, overflow: Bool)) {
        precondition(!addition.overflow, "Sample timeline overflow")
        self.init(addition.partialValue)
    }
}

/// A non-negative number of samples.
public struct SampleDuration: Codable, Hashable, Sendable, Comparable, ExpressibleByIntegerLiteral {
    public let rawValue: Int64

    public init(_ rawValue: Int64) {
        precondition(rawValue >= 0, "A sample duration cannot be negative")
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int64) {
        self.init(value)
    }

    public static let zero = SampleDuration(0)

    public static func < (lhs: SampleDuration, rhs: SampleDuration) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A signed sample delta. It is the canonical representation of a sync nudge.
public struct SampleOffset: Codable, Hashable, Sendable, Comparable, ExpressibleByIntegerLiteral {
    public let rawValue: Int64

    public init(_ rawValue: Int64) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int64) {
        self.init(value)
    }

    public static let zero = SampleOffset(0)

    public static func < (lhs: SampleOffset, rhs: SampleOffset) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var negated: SampleOffset {
        precondition(rawValue != Int64.min, "Sample offset overflow")
        return SampleOffset(-rawValue)
    }

    public func adding(_ other: SampleOffset) -> SampleOffset {
        let result = rawValue.addingReportingOverflow(other.rawValue)
        precondition(!result.overflow, "Sample offset overflow")
        return SampleOffset(result.partialValue)
    }
}

public struct SampleRange: Codable, Hashable, Sendable {
    public let start: SamplePosition
    public let duration: SampleDuration

    public init(start: SamplePosition, duration: SampleDuration) {
        self.start = start
        self.duration = duration
    }

    public var end: SamplePosition { start.advanced(by: duration) }

    public func contains(_ position: SamplePosition) -> Bool {
        position >= start && position < end
    }

    public func intersection(with other: SampleRange) -> SampleRange? {
        let intersectionStart = max(start, other.start)
        let intersectionEnd = min(end, other.end)
        guard intersectionEnd > intersectionStart else { return nil }

        return SampleRange(
            start: intersectionStart,
            duration: SampleDuration(intersectionEnd.rawValue - intersectionStart.rawValue)
        )
    }
}

/// A rational video frame rate. For example, 29.97 fps is 30000/1001.
public struct FrameRate: Codable, Hashable, Sendable, Comparable {
    public let numerator: Int64
    public let denominator: Int64

    public init(numerator: Int64, denominator: Int64 = 1) {
        precondition(numerator > 0, "A frame-rate numerator must be positive")
        precondition(denominator > 0, "A frame-rate denominator must be positive")

        let divisor = Self.greatestCommonDivisor(numerator, denominator)
        self.numerator = numerator / divisor
        self.denominator = denominator / divisor
    }

    public static let fps24 = FrameRate(numerator: 24)
    public static let fps25 = FrameRate(numerator: 25)
    public static let fps30 = FrameRate(numerator: 30)
    public static let fps29_97 = FrameRate(numerator: 30_000, denominator: 1_001)
    public static let fps60 = FrameRate(numerator: 60)

    public static func < (lhs: FrameRate, rhs: FrameRate) -> Bool {
        lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
    }

    private static func greatestCommonDivisor(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        var a = lhs
        var b = rhs
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(a, 1)
    }
}

public struct FramePosition: Codable, Hashable, Sendable, Comparable, ExpressibleByIntegerLiteral {
    public let rawValue: Int64

    public init(_ rawValue: Int64) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int64) {
        self.init(value)
    }

    public static func < (lhs: FramePosition, rhs: FramePosition) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Conversion helpers for an integer sample timeline.
public struct SampleTimebase: Codable, Hashable, Sendable {
    public let sampleRate: SampleRate

    public init(sampleRate: SampleRate = .rate48k) {
        self.sampleRate = sampleRate
    }

    public func samples(
        forMilliseconds milliseconds: Int64,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> SampleOffset {
        let fraction = Rational(
            numerator: milliseconds * Int64(sampleRate.hertz),
            denominator: 1_000
        )
        return SampleOffset(fraction.rounded(rule))
    }

    public func samples(
        forMicroseconds microseconds: Int64,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> SampleOffset {
        let fraction = Rational(
            numerator: microseconds * Int64(sampleRate.hertz),
            denominator: 1_000_000
        )
        return SampleOffset(fraction.rounded(rule))
    }

    public func milliseconds(
        for samples: SamplePosition,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> Int64 {
        Rational(
            numerator: samples.rawValue * 1_000,
            denominator: Int64(sampleRate.hertz)
        ).rounded(rule)
    }

    public func samplePosition(
        for frame: FramePosition,
        at frameRate: FrameRate,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> SamplePosition {
        let fraction = Rational(
            numerator: frame.rawValue * Int64(sampleRate.hertz) * frameRate.denominator,
            denominator: frameRate.numerator
        )
        return SamplePosition(fraction.rounded(rule))
    }

    public func framePosition(
        for sample: SamplePosition,
        at frameRate: FrameRate,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> FramePosition {
        let fraction = Rational(
            numerator: sample.rawValue * frameRate.numerator,
            denominator: Int64(sampleRate.hertz) * frameRate.denominator
        )
        return FramePosition(fraction.rounded(rule))
    }
}
