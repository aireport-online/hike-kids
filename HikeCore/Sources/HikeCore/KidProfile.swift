import Foundation

/// How old the walker is. Decides how far and how fast a walk may be.
public enum AgeGroup: String, Codable, CaseIterable, Sendable {
    /// 4 and 5 years old.
    case small
    /// 6 to 8 years old.
    case middle
    /// 9 to 12 years old.
    case big

    public var title: String {
        switch self {
        case .small: return "4–5 jaar"
        case .middle: return "6–8 jaar"
        case .big: return "9–12 jaar"
        }
    }
}

/// Rules of thumb for walking with children of an age group. They are deliberately on the
/// careful side: a walk that turns out easy is a better day out than one that is too long.
public struct KidProfile: Equatable, Sendable {
    public var ageGroup: AgeGroup

    public init(ageGroup: AgeGroup) {
        self.ageGroup = ageGroup
    }

    /// Metres per hour on the flat, dawdling and looking at beetles included.
    public var speed: Double {
        switch ageGroup {
        case .small: return 2000
        case .middle: return 2500
        case .big: return 3500
        }
    }

    /// Metres of climb per hour.
    public var climbRate: Double {
        switch ageGroup {
        case .small: return 200
        case .middle: return 250
        case .big: return 300
        }
    }

    /// A walk up to this effort is comfortable; see `KidAssessment.effortDistance`.
    public var comfortableDistance: Double {
        switch ageGroup {
        case .small: return 3000
        case .middle: return 6000
        case .big: return 10_000
        }
    }

    /// Beyond this effort the walk is too much for one day.
    public var maximumDistance: Double {
        switch ageGroup {
        case .small: return 5000
        case .middle: return 9000
        case .big: return 14_000
        }
    }

    /// Minutes of walking between two breaks.
    public var minutesBetweenBreaks: Double {
        switch ageGroup {
        case .small: return 30
        case .middle: return 40
        case .big: return 50
        }
    }

    public static let breakMinutes = 10.0

    /// Length of one step in metres.
    public var stepLength: Double {
        switch ageGroup {
        case .small: return 0.45
        case .middle: return 0.55
        case .big: return 0.65
        }
    }

    /// The short, middle and long loop this age group can choose from, in metres.
    public var loopDistances: [Double] {
        switch ageGroup {
        case .small: return [1000, 2000, 3000]
        case .middle: return [2000, 4000, 6000]
        case .big: return [3000, 6000, 9000]
        }
    }
}

/// What a route means for a child: how long it takes with breaks, how many steps, how hard.
public struct KidAssessment: Equatable, Sendable {
    public enum Effort: String, Sendable {
        case easy
        case sturdy
        case tooFar

        public var title: String {
            switch self {
            case .easy: return "Lekker rondje!"
            case .sturdy: return "Stevige tocht"
            case .tooFar: return "Erg ver voor één dag"
            }
        }
    }

    /// Seconds on the move.
    public var walkingTime: TimeInterval
    public var breaks: Int
    /// Seconds from start to finish, breaks included.
    public var totalTime: TimeInterval
    public var steps: Int
    /// The distance on the flat that would be as tiring: every 100 m of climb counts as 800 m.
    public var effortDistance: Double
    public var effort: Effort

    public init(stats: RouteStats, profile: KidProfile) {
        let walkingHours = stats.distance / profile.speed + stats.ascent / profile.climbRate
        walkingTime = walkingHours * 3600

        // A break after every full stretch of walking, but none right at the finish.
        let walkingMinutes = walkingHours * 60
        breaks = walkingMinutes > profile.minutesBetweenBreaks
            ? Int(((walkingMinutes - 1) / profile.minutesBetweenBreaks).rounded(.down))
            : 0
        totalTime = walkingTime + Double(breaks) * KidProfile.breakMinutes * 60

        steps = Int((stats.distance / profile.stepLength / 100).rounded()) * 100
        effortDistance = stats.distance + stats.ascent * 8
        if effortDistance <= profile.comfortableDistance {
            effort = .easy
        } else if effortDistance <= profile.maximumDistance {
            effort = .sturdy
        } else {
            effort = .tooFar
        }
    }
}

/// Turns metres of climbing into something a child can picture.
public enum HeightComparison {
    public static func text(forAscent metres: Double) -> String? {
        if metres < 10 {
            return nil
        }
        if metres < 75 {
            let giraffes = max(2, Int((metres / 5).rounded()))
            return "Je klimt zo hoog als \(giraffes) giraffen op elkaar"
        }
        if metres < 280 {
            return "Je klimt " + times(metres / 112, of: "de Domtoren")
        }
        return "Je klimt " + times(metres / 330, of: "de Eiffeltoren")
    }

    /// "zo hoog als de Domtoren", "2 keer zo hoog als …", "2,5 keer zo hoog als …".
    private static func times(_ ratio: Double, of thing: String) -> String {
        let halves = max(2, Int((ratio * 2).rounded()))
        if halves == 2 {
            return "zo hoog als \(thing)"
        }
        let count = halves % 2 == 0 ? "\(halves / 2)" : "\(halves / 2),5"
        return "\(count) keer zo hoog als \(thing)"
    }
}

extension HikeFormat {
    /// "5.800 stappen": a count with a Dutch thousands separator.
    public static func count(_ value: Int) -> String {
        let digits = String(abs(value))
        var result = ""
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 {
                result.append(".")
            }
            result.append(digit)
        }
        return (value < 0 ? "-" : "") + result
    }
}
