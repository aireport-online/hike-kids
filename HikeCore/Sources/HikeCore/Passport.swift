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

/// The walks that were actually done, added up, and the badges they earned.
public struct Passport: Equatable, Sendable {
    public var walks: Int
    /// Metres walked in total.
    public var distance: Double
    /// Metres climbed in total.
    public var ascent: Double
    public var loops: Int
    public var badges: [Badge]

    public init(routes: [HikeRoute]) {
        let walked = routes.filter { $0.walkedAt != nil }
        let stats = walked.map(\.stats)
        let walks = walked.count
        let distance = stats.reduce(0) { $0 + $1.distance }
        let ascent = stats.reduce(0) { $0 + $1.ascent }
        let loops = walked.filter(\.isLoop).count
        let longest = stats.map(\.distance).max() ?? 0

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
}
