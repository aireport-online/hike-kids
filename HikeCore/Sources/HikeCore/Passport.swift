import Foundation

/// A reward for walking: earned once its goal is reached.
public struct Badge: Identifiable, Equatable, Sendable {
    public var id: String
    public var emoji: String
    public var title: String
    /// What it takes, in a child's words.
    public var goal: String
    public var isEarned: Bool

    public init(id: String, emoji: String, title: String, goal: String, isEarned: Bool) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.goal = goal
        self.isEarned = isEarned
    }
}

/// How far a child has come as a walker. Levels are earned with effort: metres walked plus
/// eight times the metres climbed, the same measure that decides whether a walk is too far.
public struct WalkerLevel: Equatable, Sendable {
    public var number: Int
    public var title: String
    /// Effort gathered so far, in metres.
    public var effort: Double
    /// Effort at which this level began and at which the next one begins.
    public var floor: Double
    public var ceiling: Double

    /// How far along this level, from 0 to 1.
    public var progress: Double {
        ceiling > floor ? min(1, max(0, (effort - floor) / (ceiling - floor))) : 0
    }

    /// Effort still needed for the next level, in metres.
    public var remaining: Double {
        max(0, ceiling - effort)
    }

    /// Effort needed to reach a level: 0, 2, 5, 9, 14, 20, 27 … km. Each level asks for one
    /// kilometre more than the one before.
    public static func threshold(forLevel level: Int) -> Double {
        let n = Double(max(1, level))
        return 1000 * (n - 1) * (n + 2) / 2
    }

    private static let titles = [
        "Beginner", "Stapper", "Padvinder", "Bosloper", "Trekker",
        "Heuvelheld", "Bergwandelaar", "Topklimmer", "Alpenkenner", "Wandelkampioen"
    ]

    public init(effort: Double) {
        var level = 1
        while WalkerLevel.threshold(forLevel: level + 1) <= effort, level < 99 {
            level += 1
        }
        number = level
        title = WalkerLevel.titles[min(level, WalkerLevel.titles.count) - 1]
        self.effort = effort
        floor = WalkerLevel.threshold(forLevel: level)
        ceiling = WalkerLevel.threshold(forLevel: level + 1)
    }
}

/// The walks that were actually done, added up, and the badges they earned.
public struct Passport: Equatable, Sendable {
    public var walks: Int
    /// Metres walked in total.
    public var distance: Double
    /// Metres climbed in total.
    public var ascent: Double
    public var loops: Int
    public var badges: [Badge]
    public var level: WalkerLevel

    public init(routes: [HikeRoute]) {
        let walked = routes.filter { $0.walkedAt != nil }
        let stats = walked.map(\.stats)
        let walks = walked.count
        let distance = stats.reduce(0) { $0 + $1.distance }
        let ascent = stats.reduce(0) { $0 + $1.ascent }
        let loops = walked.filter(\.isLoop).count
        let longest = stats.map(\.distance).max() ?? 0

        level = WalkerLevel(effort: distance + ascent * 8)
        self.walks = walks
        self.distance = distance
        self.ascent = ascent
        self.loops = loops
        badges = [
            Badge(id: "first", emoji: "👟", title: "Eerste stappen", goal: "Loop je eerste wandeling", isEarned: walks >= 1),
            Badge(id: "three-loops", emoji: "🔁", title: "Rondjesmaker", goal: "Loop 3 rondjes", isEarned: loops >= 3),
            Badge(id: "five-walks", emoji: "🥾", title: "Echte wandelaar", goal: "Loop 5 wandelingen", isEarned: walks >= 5),
            Badge(id: "five-km", emoji: "💪", title: "Doorzetter", goal: "Loop een wandeling van 5 km", isEarned: longest >= 5000),
            Badge(id: "ten-km", emoji: "🚀", title: "Kilometervreter", goal: "Loop samen 10 km", isEarned: distance >= 10_000),
            Badge(id: "marathon", emoji: "🏅", title: "Marathonloper", goal: "Loop samen 42 km", isEarned: distance >= 42_195),
            Badge(id: "climber", emoji: "🐐", title: "Klimgeit", goal: "Klim samen 500 m omhoog", isEarned: ascent >= 500),
            Badge(id: "mountaineer", emoji: "🏔️", title: "Bergbeklimmer", goal: "Klim samen 2000 m omhoog", isEarned: ascent >= 2000)
        ]
    }

    public var earnedCount: Int {
        badges.filter(\.isEarned).count
    }

    /// The badges earned here that were not yet earned in an earlier state of the passport.
    public func newBadges(since earlier: Passport) -> [Badge] {
        let had = Set(earlier.badges.filter(\.isEarned).map(\.id))
        return badges.filter { $0.isEarned && !had.contains($0.id) }
    }
}
