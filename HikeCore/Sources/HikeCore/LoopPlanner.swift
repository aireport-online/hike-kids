import Foundation

/// Lays out a round trip from a starting point: out one way, around, and back.
public enum LoopPlanner {
    /// Paths wind, so a loop drawn as straight lines of this total length ends up about this
    /// much longer once it follows them.
    public static let defaultDetourFactor = 1.35

    /// The corner points of a loop of roughly `targetDistance` metres that starts and ends at
    /// `start` and lies in the direction `bearing` (degrees, 0 is north).
    ///
    /// The corners are those of a square standing on its tip at `start`; the routing service
    /// then pulls each one onto the nearest path.
    public static func waypoints(
        start: Coordinate,
        targetDistance: Double,
        bearing: Double,
        detourFactor: Double = LoopPlanner.defaultDetourFactor
    ) -> [Coordinate] {
        let side = max(50, targetDistance / max(detourFactor, 0.5) / 4)
        let left = start.destination(distance: side, bearing: bearing - 45)
        let far = start.destination(distance: side * 2.0.squareRoot(), bearing: bearing)
        let right = start.destination(distance: side, bearing: bearing + 45)
        return [start, left, far, right, start]
    }

    /// The detour factor to try next, given how long the routed loop turned out.
    public static func adjustedDetourFactor(current: Double, targetDistance: Double, actualDistance: Double) -> Double {
        guard targetDistance > 0, actualDistance > 0 else { return current }
        return min(3, max(0.8, current * actualDistance / targetDistance))
    }
}
