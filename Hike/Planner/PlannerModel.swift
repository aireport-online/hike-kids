import CoreLocation
import Foundation
import HikeCore
import Observation

/// Everything the screens show: the route being planned, its computed track and statistics,
/// and the routes saved on this device.
@MainActor
@Observable
final class PlannerModel {
    // MARK: Route being planned

    private(set) var plan = RoutePlan()
    private(set) var segments: [MapSegment] = []
    /// The waypoints as shown on the map: moved onto the path where the route actually starts,
    /// passes and ends, which can be some way from where the finger landed.
    private(set) var markers: [Waypoint] = []
    private(set) var segmentsVersion = 0
    private(set) var geometry = RouteGeometry(points: [])
    private(set) var stats = RouteStats.empty
    private(set) var profile: [RouteGeometry.Sample] = []
    private(set) var isRouting = false
    /// Why a stretch could not be computed, if any.
    private(set) var routingError: RoutingError?
    /// True when every stretch between the waypoints has a track.
    private(set) var isComplete = false

    /// How the next stretch is drawn.
    var legMode: LegMode = .trail
    var selectedWaypointID: Waypoint.ID?
    /// Distance from the start that the finger is on in the elevation profile.
    var scrubDistance: Double?

    // MARK: Saved routes

    private(set) var savedRoutes: [HikeRoute] = []
    private(set) var currentRouteID: UUID?
    private(set) var currentRouteName: String?
    private(set) var hasUnsavedChanges = false

    // MARK: Map

    private(set) var camera: CameraCommand?
    private(set) var searchPin: MapPin?
    /// Centre of the last search result, so the next search favours places near it.
    private(set) var searchBias: Coordinate?

    /// A message the user should see, e.g. a failed import.
    var alertMessage: String?

    // MARK: For children

    /// The length asked for when the route is a generated round trip; nil once it is edited by hand.
    private(set) var loopTarget: Double?
    /// Fun places along the finished route, in walking order.
    private(set) var discoveries: [Discovery] = []

    private let provider: LegProvider
    private let store: RouteStore
    @ObservationIgnored private var legCache: [LegKey: [TrackPoint]] = [:]
    @ObservationIgnored private var failures: [LegKey: RoutingError] = [:]
    @ObservationIgnored private var routingTask: Task<Void, Never>?
    @ObservationIgnored private var cameraCounter = 0

    private let discoveryService: DiscoveryService
    /// How long a finished route must stand before fun places are looked up, in nanoseconds.
    private let discoveryDelay: UInt64
    @ObservationIgnored private var discoveryTask: Task<Void, Never>?
    @ObservationIgnored private var loopBearing = 30.0
    @ObservationIgnored private var loopDetour = LoopPlanner.defaultDetourFactor
    @ObservationIgnored private var loopCorrections = 0
    @ObservationIgnored private var loopTurnsAfterFailure = 0

    init(
        service: RoutingService? = nil,
        store: RouteStore? = nil,
        discoveryService: DiscoveryService? = nil,
        discoveryDelay: UInt64 = 800_000_000
    ) {
        self.discoveryService = discoveryService ?? PhotonClient()
        self.discoveryDelay = discoveryDelay
        self.provider = LegProvider(service: service ?? BRouterClient())
        self.store = store ?? RouteStore(
            directory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Routes", isDirectory: true)
        )
        savedRoutes = self.store.all()
    }

    // MARK: Derived state

    var waypoints: [Waypoint] { plan.waypoints }
    var canUndo: Bool { plan.canUndo }
    var isLoop: Bool { plan.isLoop }

    var selectedWaypointIndex: Int? {
        guard let selectedWaypointID else { return nil }
        return plan.waypoints.firstIndex { $0.id == selectedWaypointID }
    }

    var scrubCoordinate: Coordinate? {
        guard let scrubDistance else { return nil }
        return geometry.coordinate(atDistance: scrubDistance)
    }

    // MARK: Editing

    func addWaypoint(_ coordinate: Coordinate) {
        plan.append(coordinate, mode: legMode)
        planChanged()
    }

    func moveWaypoint(id: Waypoint.ID, to coordinate: Coordinate) {
        plan.move(id: id, to: coordinate)
        planChanged()
    }

    func removeWaypoint(id: Waypoint.ID) {
        plan.remove(id: id)
        planChanged()
    }

    func undo() {
        plan.undo()
        planChanged()
    }

    func closeLoop() {
        plan.closeLoop(mode: legMode)
        planChanged()
    }

    func reverseRoute() {
        // The same track walked backwards needs no new request.
        for key in plan.legKeys {
            if let points = legCache[key], legCache[key.reversed] == nil {
                legCache[key.reversed] = points.reversed()
            }
        }
        plan.reverse()
        planChanged()
    }

    /// Empties the map but keeps the edit history, so it can be undone.
    func clearRoute() {
        plan.clear()
        planChanged()
    }

    /// Starts from scratch, detached from any saved route.
    func startNewRoute() {
        plan = RoutePlan()
        currentRouteID = nil
        currentRouteName = nil
        selectedWaypointID = nil
        scrubDistance = nil
        failures = [:]
        loopTarget = nil
        refreshRoute()
        hasUnsavedChanges = false
    }

    // MARK: Round trips

    /// Replaces the plan by a round trip of about `distance` metres from the first waypoint.
    func makeLoop(distance: Double) {
        guard let start = plan.waypoints.first?.coordinate else { return }
        resetLoopAttempts()
        applyLoop(from: start, distance: distance, replacingLastAttempt: false)
    }

    /// The same round trip, laid out in another direction.
    func turnLoop() {
        guard let distance = loopTarget, let start = plan.waypoints.first?.coordinate else { return }
        resetLoopAttempts()
        loopBearing = (loopBearing + 72).truncatingRemainder(dividingBy: 360)
        applyLoop(from: start, distance: distance, replacingLastAttempt: false)
    }

    private func resetLoopAttempts() {
        loopDetour = LoopPlanner.defaultDetourFactor
        loopCorrections = 0
        loopTurnsAfterFailure = 0
    }

    private func applyLoop(from start: Coordinate, distance: Double, replacingLastAttempt: Bool) {
        if replacingLastAttempt {
            // A correction of our own takes the place of the attempt it corrects, so that one
            // "undo" still takes the child back to before the loop.
            plan.undo()
        }
        plan.replaceAll(with: LoopPlanner.waypoints(
            start: start,
            targetDistance: distance,
            bearing: loopBearing,
            detourFactor: loopDetour
        ))
        // Set first: answering from the cache finishes routing before planChanged returns.
        loopTarget = distance
        planChanged(keepingLoop: true)
    }

    /// Called when every stretch has been answered. A generated loop that failed is tried in
    /// another direction; one that came out much too long or short is drawn again to size.
    private func routingFinished() {
        if let distance = loopTarget, let start = plan.waypoints.first?.coordinate {
            if routingError != nil, loopTurnsAfterFailure < 4 {
                loopTurnsAfterFailure += 1
                loopBearing = (loopBearing + 72).truncatingRemainder(dividingBy: 360)
                applyLoop(from: start, distance: distance, replacingLastAttempt: true)
                return
            }
            if isComplete, loopCorrections < 1, abs(stats.distance - distance) / distance > 0.25 {
                loopCorrections += 1
                loopDetour = LoopPlanner.adjustedDetourFactor(
                    current: loopDetour,
                    targetDistance: distance,
                    actualDistance: stats.distance
                )
                applyLoop(from: start, distance: distance, replacingLastAttempt: true)
                return
            }
            if isComplete {
                fitRoute()
            }
        }
        refreshDiscoveries()
    }

    // MARK: Discoveries

    private func refreshDiscoveries() {
        discoveryTask?.cancel()
        discoveryTask = nil
        // Long routes cover too large an area to ask a shared service about.
        guard isComplete, let area = DiscoveryFinder.searchArea(for: geometry), area.radius <= 8000 else {
            discoveries = []
            return
        }
        let geometry = self.geometry
        let service = discoveryService
        let delay = discoveryDelay
        discoveryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            if Task.isCancelled { return }
            var places = try? await service.discoveries(near: area.center, radius: area.radius, kinds: Discovery.Kind.allCases)
            if places == nil, !Task.isCancelled {
                // The shared service turns requests away now and then; one more try is fair.
                try? await Task.sleep(nanoseconds: delay * 3)
                if Task.isCancelled { return }
                places = try? await service.discoveries(near: area.center, radius: area.radius, kinds: Discovery.Kind.allCases)
            }
            guard let self, !Task.isCancelled else { return }
            self.discoveries = DiscoveryFinder.along(geometry, places: places ?? [])
        }
    }

    func retryFailedLegs() {
        failures = [:]
        refreshRoute()
    }

    /// Draws every stretch that could not be routed as a straight line instead.
    func useStraightLinesForFailedLegs() {
        let keys = plan.legKeys
        var ids = Set<Waypoint.ID>()
        for (index, key) in keys.enumerated() where failures[key] != nil {
            ids.insert(plan.waypoints[index + 1].id)
        }
        plan.setMode(.straight, forLegsEndingAt: ids)
        planChanged()
    }

    private func planChanged(keepingLoop: Bool = false) {
        if let selectedWaypointID, !plan.waypoints.contains(where: { $0.id == selectedWaypointID }) {
            self.selectedWaypointID = nil
        }
        if !keepingLoop {
            loopTarget = nil
        }
        discoveryTask?.cancel()
        discoveries = []
        scrubDistance = nil
        hasUnsavedChanges = !plan.isEmpty || currentRouteID != nil
        refreshRoute()
    }

    // MARK: Routing

    private func refreshRoute() {
        routingTask?.cancel()
        routingTask = nil
        rebuildTrack()

        var seen = Set<LegKey>()
        let missing = plan.legKeys.filter { key in
            legCache[key] == nil && failures[key] == nil && seen.insert(key).inserted
        }
        guard !missing.isEmpty else {
            isRouting = false
            routingFinished()
            return
        }

        isRouting = true
        // One stretch at a time: the routing server is a shared public service.
        let provider = self.provider
        routingTask = Task { [weak self] in
            for key in missing {
                let result: Result<[TrackPoint], Error>
                do {
                    result = .success(try await provider.points(for: key))
                } catch {
                    result = .failure(error)
                }
                guard let self, !Task.isCancelled else { return }
                switch result {
                case .success(let points):
                    self.legCache[key] = points
                case .failure(let error):
                    self.failures[key] = (error as? RoutingError) ?? .invalidResponse
                }
                self.rebuildTrack()
            }
            guard let self, !Task.isCancelled else { return }
            self.isRouting = false
            self.routingFinished()
        }
    }

    private func rebuildTrack() {
        let keys = plan.legKeys
        var points: [TrackPoint] = []
        var newSegments: [MapSegment] = []
        var firstError: RoutingError?
        var complete = !keys.isEmpty
        var newMarkers = plan.waypoints

        for (index, key) in keys.enumerated() {
            if let legPoints = legCache[key] {
                points.append(contentsOf: legPoints)
                if key.mode == .trail, let first = legPoints.first, let last = legPoints.last {
                    newMarkers[index].coordinate = first.coordinate
                    newMarkers[index + 1].coordinate = last.coordinate
                }
                newSegments.append(MapSegment(
                    coordinates: legPoints.map(\.coordinate),
                    kind: key.mode == .straight ? .straight : .trail
                ))
            } else {
                complete = false
                let failure = failures[key]
                if firstError == nil {
                    firstError = failure
                }
                newSegments.append(MapSegment(
                    coordinates: [key.from, key.to],
                    kind: failure == nil ? .pending : .failed
                ))
            }
        }

        segments = newSegments
        segmentsVersion += 1
        markers = newMarkers
        geometry = RouteGeometry(points: points)
        stats = RouteStats(points: points)
        profile = geometry.elevationProfile(maxSamples: 300)
        routingError = firstError
        isComplete = complete
    }

    // MARK: Saved routes

    /// A name to offer when saving: the route's own name, or one based on where it starts.
    func suggestedName() async -> String {
        if let currentRouteName {
            return currentRouteName
        }
        let fallback = "Wandeling"
        guard let start = plan.waypoints.first?.coordinate else { return fallback }
        let location = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        guard let place = placemark?.locality ?? placemark?.name else { return fallback }
        return plan.isLoop ? "Rondje \(place)" : "Wandeling bij \(place)"
    }

    /// Saves the route under `name`. Returns whether it was saved.
    @discardableResult
    func save(name: String) -> Bool {
        guard let route = currentRoute(named: name) else { return false }
        do {
            try store.save(route)
            currentRouteID = route.id
            currentRouteName = route.name
            hasUnsavedChanges = false
            savedRoutes = store.all()
            return true
        } catch {
            alertMessage = "Opslaan is mislukt: \(error.localizedDescription)"
            return false
        }
    }

    private func currentRoute(named name: String) -> HikeRoute? {
        let keys = plan.legKeys
        let legs = keys.compactMap { key in
            legCache[key].map { RouteLeg(mode: key.mode, points: $0) }
        }
        guard !keys.isEmpty, legs.count == keys.count else { return nil }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = savedRoutes.first { $0.id == currentRouteID }
        let now = Date()
        return HikeRoute(
            id: existing?.id ?? UUID(),
            name: trimmed.isEmpty ? "Wandeling" : trimmed,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            waypoints: plan.waypoints,
            legs: legs,
            walkedAt: existing?.walkedAt
        )
    }

    /// Marks a saved route as walked today, or as a plan again.
    func setWalked(_ route: HikeRoute, walked: Bool) {
        var updated = route
        updated.walkedAt = walked ? Date() : nil
        do {
            try store.save(updated)
            savedRoutes = store.all()
        } catch {
            alertMessage = "Bewaren is mislukt: \(error.localizedDescription)"
        }
    }

    /// Everything that was walked, added up, with the badges it earned.
    var passport: Passport {
        Passport(routes: savedRoutes)
    }

    func open(_ route: HikeRoute) {
        plan = RoutePlan(waypoints: route.waypoints)
        for (key, leg) in zip(plan.legKeys, route.legs) {
            legCache[key] = leg.points
        }
        currentRouteID = route.id
        currentRouteName = route.name
        selectedWaypointID = nil
        scrubDistance = nil
        failures = [:]
        searchPin = nil
        loopTarget = nil
        discoveryTask?.cancel()
        discoveries = []
        refreshRoute()
        hasUnsavedChanges = false
        fitRoute()
    }

    func delete(_ route: HikeRoute) {
        do {
            try store.delete(id: route.id)
        } catch {
            alertMessage = "Verwijderen is mislukt: \(error.localizedDescription)"
        }
        savedRoutes = store.all()
        if currentRouteID == route.id {
            currentRouteID = nil
            currentRouteName = nil
            hasUnsavedChanges = !plan.isEmpty
        }
    }

    // MARK: GPX

    /// Reads a GPX file, saves it as a route and opens it. Returns false when it could not be read.
    @discardableResult
    func importGPX(from url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let document = try GPX.parse(try Data(contentsOf: url))
            let name = document.name ?? url.deletingPathExtension().lastPathComponent
            guard let route = HikeRoute(name: name, importedTrack: document.points) else {
                throw GPXError.noTrack
            }
            try store.save(route)
            savedRoutes = store.all()
            open(route)
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    /// Writes the route being planned to a temporary GPX file for sharing.
    func exportCurrentRoute() -> URL? {
        guard let route = currentRoute(named: currentRouteName ?? "Wandeling") else { return nil }
        return export(route)
    }

    func export(_ route: HikeRoute) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gpx-export", isDirectory: true)
        let url = directory.appendingPathComponent(GPX.fileName(for: route.name))
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try GPX.data(for: route).write(to: url, options: .atomic)
            return url
        } catch {
            alertMessage = "Het GPX-bestand kon niet worden gemaakt: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: Map

    func fitRoute() {
        let coordinates = geometry.points.map(\.coordinate) + plan.waypoints.map(\.coordinate)
        guard !coordinates.isEmpty else { return }
        send(.fit(coordinates))
    }

    func show(_ place: Place) {
        searchPin = MapPin(title: place.name, coordinate: place.coordinate)
        searchBias = place.coordinate
        // Towns need a wider view than a hut or a summit.
        send(.center(place.coordinate, meters: place.kind == .settlement ? 12_000 : 4_000))
    }

    /// Turns the search result on the map into the next waypoint.
    func addSearchPinToRoute() {
        guard let pin = searchPin else { return }
        searchPin = nil
        addWaypoint(pin.coordinate)
    }

    func followUser() {
        send(.followUser)
    }

    private func send(_ request: CameraCommand.Request) {
        cameraCounter += 1
        camera = CameraCommand(id: cameraCounter, request: request)
    }
}
