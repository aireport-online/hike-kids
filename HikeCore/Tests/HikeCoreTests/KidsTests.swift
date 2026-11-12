import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import HikeCore

final class KidProfileTests: XCTestCase {
    private func stats(distance: Double, ascent: Double = 0) -> RouteStats {
        RouteStats(distance: distance, ascent: ascent, descent: ascent, minElevation: nil, maxElevation: nil)
    }

    func testFlatWalkTimeStepsAndBreaks() {
        // 5 km for a 6-8 year old: 2 hours of walking at 2.5 km/h, a break after 40 and 80 minutes.
        let assessment = KidAssessment(stats: stats(distance: 5000), profile: KidProfile(ageGroup: .middle))
        XCTAssertEqual(assessment.walkingTime, 2 * 3600, accuracy: 1)
        XCTAssertEqual(assessment.breaks, 2)
        XCTAssertEqual(assessment.totalTime, 2 * 3600 + 20 * 60, accuracy: 1)
        XCTAssertEqual(assessment.steps, 9100)
        XCTAssertEqual(assessment.effort, .easy)
    }

    func testShortWalkHasNoBreakAndNoneAtTheFinish() {
        let profile = KidProfile(ageGroup: .middle)
        XCTAssertEqual(KidAssessment(stats: stats(distance: 1000), profile: profile).breaks, 0)
        // Exactly 80 minutes of walking: one break at 40, none on arrival.
        let eightyMinutes = KidAssessment(stats: stats(distance: 2500 * 80 / 60), profile: profile)
        XCTAssertEqual(eightyMinutes.breaks, 1)
    }

    func testClimbingMakesAWalkLongerAndHarder() {
        let profile = KidProfile(ageGroup: .middle)
        let flat = KidAssessment(stats: stats(distance: 4000), profile: profile)
        let steep = KidAssessment(stats: stats(distance: 4000, ascent: 500), profile: profile)
        XCTAssertEqual(steep.walkingTime - flat.walkingTime, 2 * 3600, accuracy: 1)
        XCTAssertEqual(flat.effort, .easy)
        // 4 km plus 500 m of climb is as tiring as 8 km on the flat.
        XCTAssertEqual(steep.effortDistance, 8000)
        XCTAssertEqual(steep.effort, .sturdy)
    }

    func testTheSameWalkIsHarderForSmallerChildren() {
        let walk = stats(distance: 6000)
        XCTAssertEqual(KidAssessment(stats: walk, profile: KidProfile(ageGroup: .small)).effort, .tooFar)
        XCTAssertEqual(KidAssessment(stats: walk, profile: KidProfile(ageGroup: .middle)).effort, .easy)
        XCTAssertEqual(KidAssessment(stats: walk, profile: KidProfile(ageGroup: .big)).effort, .easy)
        XCTAssertGreaterThan(
            KidAssessment(stats: walk, profile: KidProfile(ageGroup: .small)).totalTime,
            KidAssessment(stats: walk, profile: KidProfile(ageGroup: .big)).totalTime
        )
    }

    func testLoopChoicesStayWithinWhatIsComfortableOrSturdy() {
        for group in AgeGroup.allCases {
            let profile = KidProfile(ageGroup: group)
            XCTAssertEqual(profile.loopDistances.count, 3)
            XCTAssertEqual(profile.loopDistances, profile.loopDistances.sorted())
            XCTAssertLessThanOrEqual(profile.loopDistances[1], profile.comfortableDistance)
            XCTAssertLessThanOrEqual(profile.loopDistances[2], profile.maximumDistance)
            XCTAssertFalse(group.title.isEmpty)
        }
    }

    func testStarsRewardAFittingAdventureButNeverOverdoingIt() {
        let profile = KidProfile(ageGroup: .middle)   // comfortable 6 km, maximum 9 km
        XCTAssertEqual(KidAssessment(stats: stats(distance: 2000), profile: profile).stars, 1)
        XCTAssertEqual(KidAssessment(stats: stats(distance: 5000), profile: profile).stars, 2)
        XCTAssertEqual(KidAssessment(stats: stats(distance: 8000), profile: profile).stars, 3)
        XCTAssertEqual(KidAssessment(stats: stats(distance: 12_000), profile: profile).stars, 0)
    }

    func testHeightComparisons() {
        XCTAssertNil(HeightComparison.text(forAscent: 4))
        XCTAssertEqual(HeightComparison.text(forAscent: 30), "Je klimt zo hoog als 6 giraffen op elkaar")
        XCTAssertEqual(HeightComparison.text(forAscent: 120), "Je klimt zo hoog als de Domtoren")
        XCTAssertEqual(HeightComparison.text(forAscent: 230), "Je klimt 2 keer zo hoog als de Domtoren")
        XCTAssertEqual(HeightComparison.text(forAscent: 330), "Je klimt zo hoog als de Eiffeltoren")
        XCTAssertEqual(HeightComparison.text(forAscent: 830), "Je klimt 2,5 keer zo hoog als de Eiffeltoren")
    }

    func testCountFormatting() {
        XCTAssertEqual(HikeFormat.count(0), "0")
        XCTAssertEqual(HikeFormat.count(900), "900")
        XCTAssertEqual(HikeFormat.count(5800), "5.800")
        XCTAssertEqual(HikeFormat.count(1_234_567), "1.234.567")
    }
}

final class LoopPlannerTests: XCTestCase {
    private let start = Coordinate(latitude: 52.09, longitude: 5.12)

    func testDestinationPoint() {
        let north = start.destination(distance: 1000, bearing: 0)
        XCTAssertEqual(start.distance(to: north), 1000, accuracy: 1)
        XCTAssertGreaterThan(north.latitude, start.latitude)
        XCTAssertEqual(north.longitude, start.longitude, accuracy: 1e-9)
        let east = start.destination(distance: 500, bearing: 90)
        XCTAssertEqual(start.distance(to: east), 500, accuracy: 1)
        XCTAssertGreaterThan(east.longitude, start.longitude)
    }

    func testLoopStartsAndEndsAtTheStartAndHasTheRightSize() {
        let points = LoopPlanner.waypoints(start: start, targetDistance: 4000, bearing: 30)
        XCTAssertEqual(points.count, 5)
        XCTAssertEqual(points.first, start)
        XCTAssertEqual(points.last, start)
        let perimeter = zip(points, points.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
        // Straight lines add up to the target divided by the detour factor.
        XCTAssertEqual(perimeter, 4000 / LoopPlanner.defaultDetourFactor, accuracy: 20)
    }

    func testLoopLiesInTheChosenDirection() {
        let north = LoopPlanner.waypoints(start: start, targetDistance: 4000, bearing: 0)
        XCTAssertGreaterThan(north[2].latitude, start.latitude)
        XCTAssertEqual(north[2].longitude, start.longitude, accuracy: 1e-6)
        let south = LoopPlanner.waypoints(start: start, targetDistance: 4000, bearing: 180)
        XCTAssertLessThan(south[2].latitude, start.latitude)
        XCTAssertNotEqual(north[1], south[1])
    }

    func testDetourFactorIsCorrectedTowardsTheTarget() {
        // The routed loop came out 50% too long: next time draw it smaller.
        let adjusted = LoopPlanner.adjustedDetourFactor(current: 1.35, targetDistance: 4000, actualDistance: 6000)
        XCTAssertEqual(adjusted, 1.35 * 1.5, accuracy: 1e-9)
        let smaller = LoopPlanner.waypoints(start: start, targetDistance: 4000, bearing: 0, detourFactor: adjusted)
        let original = LoopPlanner.waypoints(start: start, targetDistance: 4000, bearing: 0)
        XCTAssertLessThan(start.distance(to: smaller[2]), start.distance(to: original[2]))
        XCTAssertEqual(LoopPlanner.adjustedDetourFactor(current: 1.35, targetDistance: 4000, actualDistance: 0), 1.35)
        XCTAssertEqual(LoopPlanner.adjustedDetourFactor(current: 1.35, targetDistance: 1000, actualDistance: 90_000), 3)
    }

    func testReplaceAllIsOneUndoStep() {
        var plan = RoutePlan()
        plan.append(start)
        plan.replaceAll(with: LoopPlanner.waypoints(start: start, targetDistance: 2000, bearing: 0))
        XCTAssertEqual(plan.waypoints.count, 5)
        XCTAssertTrue(plan.isLoop)
        plan.undo()
        XCTAssertEqual(plan.waypoints.map(\.coordinate), [start])
    }
}

/// A real answer from photon.komoot.io/reverse for fun places near a wood east of Utrecht,
/// with one nameless and one unknown kind of place added.
private let nearbyResponse = """
{"type":"FeatureCollection","features":[
{"type":"Feature","properties":{"osm_type":"N","osm_id":2877268223,"osm_key":"tourism","osm_value":"attraction",
"name":"Schaapskooi Heidestein","country":"Nederland"},"geometry":{"type":"Point","coordinates":[5.2758804,52.0745536]}},
{"type":"Feature","properties":{"osm_type":"W","osm_id":71383810,"osm_key":"tourism","osm_value":"zoo",
"name":"Hertenkamp"},"geometry":{"type":"Point","coordinates":[5.2552991,52.084543]}},
{"type":"Feature","properties":{"osm_type":"N","osm_id":2787051532,"osm_key":"amenity","osm_value":"ice_cream",
"name":"Fressini"},"geometry":{"type":"Point","coordinates":[5.2466769,52.0892877]}},
{"type":"Feature","properties":{"osm_key":"leisure","osm_value":"playground","name":"De Kleine Dom"},
"geometry":{"type":"Point","coordinates":[5.2500,52.0850]}},
{"type":"Feature","properties":{"osm_key":"leisure","osm_value":"playground"},
"geometry":{"type":"Point","coordinates":[5.2501,52.0851]}},
{"type":"Feature","properties":{"osm_key":"shop","osm_value":"bakery","name":"Bakker"},
"geometry":{"type":"Point","coordinates":[5.2502,52.0852]}}
]}
"""

private final class StubHTTP: HTTPClient, @unchecked Sendable {
    var status = 200
    var body = nearbyResponse
    private(set) var requests: [URLRequest] = []

    func get(_ request: URLRequest) async throws -> (data: Data, status: Int) {
        requests.append(request)
        return (Data(body.utf8), status)
    }
}

final class DiscoveryTests: XCTestCase {
    func testParsesNamedPlacesOfKnownKinds() async throws {
        let found = try await PhotonClient(http: StubHTTP()).discoveries(
            near: Coordinate(latitude: 52.08, longitude: 5.26), radius: 2000, kinds: Discovery.Kind.allCases
        )
        XCTAssertEqual(found.map(\.name), ["Schaapskooi Heidestein", "Hertenkamp", "Fressini", "De Kleine Dom"])
        XCTAssertEqual(found.map(\.kind), [.attraction, .animals, .iceCream, .playground])
        XCTAssertEqual(found[1].coordinate, Coordinate(latitude: 52.084543, longitude: 5.2552991))
    }

    func testRequestAsksTheReverseEndpointForTheChosenKinds() async throws {
        let http = StubHTTP()
        _ = try await PhotonClient(http: http).discoveries(
            near: Coordinate(latitude: 52.08, longitude: 5.26), radius: 1500, kinds: [.playground, .viewpoint]
        )
        let url = try XCTUnwrap(http.requests.first?.url)
        XCTAssertEqual(url.host, "photon.komoot.io")
        XCTAssertEqual(url.path, "/reverse")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.filter { $0.name == "osm_tag" }.compactMap(\.value), ["leisure:playground", "tourism:viewpoint"])
        XCTAssertEqual(items.first { $0.name == "radius" }?.value, "1.5")
        XCTAssertEqual(items.first { $0.name == "lat" }?.value, "52.08000")
    }

    func testNoKindsMeansNoRequestAndFailureIsReported() async throws {
        let http = StubHTTP()
        let none = try await PhotonClient(http: http).discoveries(near: Coordinate(latitude: 52, longitude: 5), radius: 500, kinds: [])
        XCTAssertTrue(none.isEmpty)
        XCTAssertTrue(http.requests.isEmpty)
        http.status = 503
        do {
            _ = try await PhotonClient(http: http).discoveries(near: Coordinate(latitude: 52, longitude: 5), radius: 500, kinds: [.peak])
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? PlaceSearchError, .unavailable)
        }
    }

    func testEveryKindHasAnEmojiATitleAndATag() {
        for kind in Discovery.Kind.allCases {
            XCTAssertFalse(kind.emoji.isEmpty)
            XCTAssertFalse(kind.title.isEmpty)
            XCTAssertFalse(kind.tags.isEmpty)
        }
    }

    /// A track of 2 km heading east along latitude 52.
    private var track: RouteGeometry {
        RouteGeometry(points: (0...20).map {
            TrackPoint(coordinate: Coordinate(latitude: 52, longitude: 5 + Double($0) * 0.001462))
        })
    }

    func testNearestPointOnTrack() throws {
        // 100 m north of the track's midpoint.
        let nearest = try XCTUnwrap(track.nearest(to: Coordinate(latitude: 52.0009, longitude: 5.01462)))
        XCTAssertEqual(nearest.distanceFromTrack, 100, accuracy: 2)
        XCTAssertEqual(nearest.distanceAlong, 1000, accuracy: 5)
        // Beyond the end: measured to the last point.
        let beyond = try XCTUnwrap(track.nearest(to: Coordinate(latitude: 52, longitude: 5.035)))
        XCTAssertEqual(beyond.distanceAlong, track.totalDistance, accuracy: 1)
        XCTAssertGreaterThan(beyond.distanceFromTrack, 300)
        XCTAssertNil(RouteGeometry(points: []).nearest(to: Coordinate(latitude: 52, longitude: 5)))
    }

    func testOnlyPlacesAlongTheWayAreKeptInWalkingOrder() {
        let places = [
            Discovery(name: "Verderop", kind: .viewpoint, coordinate: Coordinate(latitude: 52.0005, longitude: 5.025)),
            Discovery(name: "Te ver weg", kind: .playground, coordinate: Coordinate(latitude: 52.01, longitude: 5.01)),
            Discovery(name: "Vlakbij start", kind: .playground, coordinate: Coordinate(latitude: 51.9995, longitude: 5.002)),
            Discovery(name: "Vlakbij start", kind: .playground, coordinate: Coordinate(latitude: 51.9996, longitude: 5.0021))
        ]
        let along = DiscoveryFinder.along(track, places: places)
        XCTAssertEqual(along.map(\.name), ["Vlakbij start", "Verderop"])
        XCTAssertLessThan(along[0].distanceAlong, along[1].distanceAlong)
        XCTAssertEqual(along[0].distanceFromRoute, 55, accuracy: 5)
    }

    func testSearchAreaCoversTheWholeTrack() throws {
        let area = try XCTUnwrap(DiscoveryFinder.searchArea(for: track))
        XCTAssertEqual(area.center.longitude, 5.01462, accuracy: 1e-4)
        for point in track.points {
            XCTAssertLessThanOrEqual(area.center.distance(to: point.coordinate), area.radius)
        }
        XCTAssertNil(DiscoveryFinder.searchArea(for: RouteGeometry(points: [])))
    }
}

final class PassportTests: XCTestCase {
    /// A straight walk of `kilometres` heading north, optionally back to the start, climbing `ascent`.
    private func route(kilometres: Double, ascent: Double = 0, loop: Bool = false, walked: Bool = true) -> HikeRoute {
        let start = Coordinate(latitude: 46, longitude: 8)
        let end = start.destination(distance: kilometres * 1000 / (loop ? 2 : 1), bearing: 0)
        var points = [TrackPoint(coordinate: start, elevation: 500), TrackPoint(coordinate: end, elevation: 500 + ascent)]
        var waypoints = [Waypoint(coordinate: start), Waypoint(coordinate: end)]
        if loop {
            points.append(TrackPoint(coordinate: start, elevation: 500))
            waypoints.append(Waypoint(coordinate: start))
        }
        return HikeRoute(
            name: "Tocht",
            waypoints: waypoints,
            legs: [RouteLeg(mode: .trail, points: points)],
            walkedAt: walked ? Date(timeIntervalSince1970: 1_800_000_000) : nil
        )
    }

    private func earned(_ passport: Passport) -> Set<String> {
        Set(passport.badges.filter(\.isEarned).map(\.id))
    }

    func testPlansDoNotCountUntilTheyAreWalked() {
        let passport = Passport(routes: [route(kilometres: 8, walked: false)])
        XCTAssertEqual(passport.walks, 0)
        XCTAssertEqual(passport.distance, 0)
        XCTAssertEqual(passport.earnedCount, 0)
        XCTAssertEqual(passport.badges.count, 8)
    }

    func testFirstWalkEarnsTheFirstBadge() {
        let passport = Passport(routes: [route(kilometres: 2)])
        XCTAssertEqual(passport.walks, 1)
        XCTAssertEqual(passport.distance, 2000, accuracy: 5)
        XCTAssertEqual(earned(passport), ["first"])
    }

    func testBadgesAddUpOverWalks() {
        let routes = [
            route(kilometres: 3, loop: true), route(kilometres: 3, loop: true), route(kilometres: 2, loop: true),
            route(kilometres: 6, ascent: 520), route(kilometres: 1)
        ]
        let passport = Passport(routes: routes)
        XCTAssertEqual(passport.walks, 5)
        XCTAssertEqual(passport.loops, 3)
        XCTAssertEqual(passport.distance, 15_000, accuracy: 30)
        XCTAssertEqual(passport.ascent, 520)
        XCTAssertEqual(earned(passport), ["first", "three-loops", "five-walks", "five-km", "ten-km", "climber"])
    }

    func testNewBadgesAreThoseEarnedSinceBefore() {
        let before = Passport(routes: [])
        let after = Passport(routes: [route(kilometres: 6)])
        XCTAssertEqual(after.newBadges(since: before).map(\.id), ["first", "five-km"])
        XCTAssertTrue(after.newBadges(since: after).isEmpty)
        XCTAssertTrue(before.newBadges(since: after).isEmpty)
    }

    func testLevelsRiseWithEffortAndShowProgress() {
        XCTAssertEqual(WalkerLevel.threshold(forLevel: 1), 0)
        XCTAssertEqual(WalkerLevel.threshold(forLevel: 2), 2000)
        XCTAssertEqual(WalkerLevel.threshold(forLevel: 3), 5000)
        XCTAssertEqual(WalkerLevel.threshold(forLevel: 4), 9000)

        let start = WalkerLevel(effort: 0)
        XCTAssertEqual(start.number, 1)
        XCTAssertEqual(start.title, "Beginner")
        XCTAssertEqual(start.progress, 0)
        XCTAssertEqual(start.remaining, 2000)

        let halfway = WalkerLevel(effort: 3500)
        XCTAssertEqual(halfway.number, 2)
        XCTAssertEqual(halfway.progress, 0.5, accuracy: 1e-9)
        XCTAssertEqual(halfway.remaining, 1500)

        XCTAssertEqual(WalkerLevel(effort: 5000).number, 3)
        // Far beyond the named levels the title stays the highest one.
        let champion = WalkerLevel(effort: 1_000_000)
        XCTAssertGreaterThan(champion.number, 10)
        XCTAssertEqual(champion.title, "Wandelkampioen")
        XCTAssertLessThanOrEqual(champion.progress, 1)
    }

    func testPassportLevelCountsClimbingAsEffort() {
        // 3 km with 250 m of climb is as much effort as 5 km on the flat: level 3.
        XCTAssertEqual(Passport(routes: [route(kilometres: 3, ascent: 250)]).level.number, 3)
        XCTAssertEqual(Passport(routes: [route(kilometres: 3)]).level.number, 2)
        XCTAssertEqual(Passport(routes: [route(kilometres: 3, walked: false)]).level.number, 1)
    }

    func testWalkedDateSurvivesSavingAndOldFilesStillLoad() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let walked = route(kilometres: 2)
        let copy = try decoder.decode(HikeRoute.self, from: encoder.encode(walked))
        XCTAssertEqual(copy.walkedAt, walked.walkedAt)

        // A route saved by the app before walks could be marked has no such field.
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(walked)) as? [String: Any])
        object.removeValue(forKey: "walkedAt")
        let old = try decoder.decode(HikeRoute.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.walkedAt)
        XCTAssertEqual(old.name, "Tocht")
    }
}
