import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Something along a route that makes the walk fun: a playground, a view, animals, an ice cream.
public struct Discovery: Hashable, Identifiable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case playground, picnic, viewpoint, animals, iceCream, castle, waterfall, cave, peak, hut, attraction

        public var emoji: String {
            switch self {
            case .playground: return "🛝"
            case .picnic: return "🧺"
            case .viewpoint: return "🔭"
            case .animals: return "🐐"
            case .iceCream: return "🍦"
            case .castle: return "🏰"
            case .waterfall: return "💦"
            case .cave: return "🦇"
            case .peak: return "⛰️"
            case .hut: return "🛖"
            case .attraction: return "⭐️"
            }
        }

        public var title: String {
            switch self {
            case .playground: return "Speeltuin"
            case .picnic: return "Picknickplek"
            case .viewpoint: return "Uitkijkpunt"
            case .animals: return "Dieren"
            case .iceCream: return "IJsje"
            case .castle: return "Kasteel"
            case .waterfall: return "Waterval"
            case .cave: return "Grot"
            case .peak: return "Bergtop"
            case .hut: return "Berghut"
            case .attraction: return "Bijzondere plek"
            }
        }

        /// The OpenStreetMap tags that mean this kind of place.
        public var tags: [(key: String, value: String)] {
            switch self {
            case .playground: return [("leisure", "playground")]
            case .picnic: return [("tourism", "picnic_site")]
            case .viewpoint: return [("tourism", "viewpoint")]
            case .animals: return [("tourism", "zoo")]
            case .iceCream: return [("amenity", "ice_cream")]
            case .castle: return [("historic", "castle")]
            case .waterfall: return [("waterway", "waterfall")]
            case .cave: return [("natural", "cave_entrance")]
            case .peak: return [("natural", "peak")]
            case .hut: return [("tourism", "alpine_hut")]
            case .attraction: return [("tourism", "attraction")]
            }
        }

        init?(key: String?, value: String?) {
            guard let match = Kind.allCases.first(where: { kind in
                kind.tags.contains { $0.key == key && $0.value == value }
            }) else { return nil }
            self = match
        }
    }

    public var name: String
    public var kind: Kind
    public var coordinate: Coordinate
    /// Metres from the start of the route to the spot nearest this place.
    public var distanceAlong: Double
    /// Metres from the route to this place.
    public var distanceFromRoute: Double

    public var id: String { "\(kind.rawValue)|\(name)|\(coordinate.latitude)|\(coordinate.longitude)" }

    public init(name: String, kind: Kind, coordinate: Coordinate, distanceAlong: Double = 0, distanceFromRoute: Double = 0) {
        self.name = name
        self.kind = kind
        self.coordinate = coordinate
        self.distanceAlong = distanceAlong
        self.distanceFromRoute = distanceFromRoute
    }
}

/// Finds fun places in an area.
public protocol DiscoveryService: Sendable {
    /// Named places of the given kinds within `radius` metres of `center`, nearest first.
    func discoveries(near center: Coordinate, radius: Double, kinds: [Discovery.Kind]) async throws -> [Discovery]
}

extension PhotonClient: DiscoveryService {
    func nearbyRequest(center: Coordinate, radius: Double, kinds: [Discovery.Kind], limit: Int) -> URLRequest {
        var components = URLComponents(url: reverseURL, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "lat", value: String(format: "%.5f", center.latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.5f", center.longitude)),
            // The service takes kilometres.
            URLQueryItem(name: "radius", value: String(format: "%.1f", max(0.2, radius / 1000))),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        for kind in kinds {
            for tag in kind.tags {
                items.append(URLQueryItem(name: "osm_tag", value: "\(tag.key):\(tag.value)"))
            }
        }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    public func discoveries(near center: Coordinate, radius: Double, kinds: [Discovery.Kind]) async throws -> [Discovery] {
        guard !kinds.isEmpty else { return [] }
        let response: (data: Data, status: Int)
        do {
            response = try await http.get(nearbyRequest(center: center, radius: radius, kinds: kinds, limit: 50))
        } catch {
            throw PlaceSearchError.unavailable
        }
        guard response.status == 200 else { throw PlaceSearchError.unavailable }
        return try Self.parseDiscoveries(response.data)
    }

    private struct NearbyGeoJSON: Decodable {
        struct Feature: Decodable {
            struct Properties: Decodable {
                var name: String?
                var osm_key: String?
                var osm_value: String?
            }
            struct Geometry: Decodable {
                var coordinates: [Double]
            }
            var properties: Properties
            var geometry: Geometry
        }
        var features: [Feature]
    }

    static func parseDiscoveries(_ data: Data) throws -> [Discovery] {
        guard let geoJSON = try? JSONDecoder().decode(NearbyGeoJSON.self, from: data) else {
            throw PlaceSearchError.unavailable
        }
        return geoJSON.features.compactMap { feature in
            guard feature.geometry.coordinates.count >= 2,
                  let name = feature.properties.name, !name.isEmpty,
                  let kind = Discovery.Kind(key: feature.properties.osm_key, value: feature.properties.osm_value)
            else { return nil }
            return Discovery(
                name: name,
                kind: kind,
                coordinate: Coordinate(latitude: feature.geometry.coordinates[1], longitude: feature.geometry.coordinates[0])
            )
        }
    }
}

public enum DiscoveryFinder {
    /// The area to search so that everything along the track is in it.
    public static func searchArea(for geometry: RouteGeometry, margin: Double = 300) -> (center: Coordinate, radius: Double)? {
        guard let box = BoundingBox(geometry.points.map(\.coordinate)) else { return nil }
        let center = box.center
        let corner = Coordinate(latitude: box.maxLatitude, longitude: box.maxLongitude)
        return (center, center.distance(to: corner) + margin)
    }

    /// Keeps the places a child would actually pass: within `maxDistance` metres of the track,
    /// each place once, in the order they come along the way.
    public static func along(_ geometry: RouteGeometry, places: [Discovery], maxDistance: Double = 250) -> [Discovery] {
        var seen = Set<String>()
        var result: [Discovery] = []
        for place in places {
            guard let nearest = geometry.nearest(to: place.coordinate),
                  nearest.distanceFromTrack <= maxDistance,
                  seen.insert("\(place.kind.rawValue)|\(place.name)").inserted else { continue }
            var found = place
            found.distanceAlong = nearest.distanceAlong
            found.distanceFromRoute = nearest.distanceFromTrack
            result.append(found)
        }
        return result.sorted { $0.distanceAlong < $1.distanceAlong }
    }
}
