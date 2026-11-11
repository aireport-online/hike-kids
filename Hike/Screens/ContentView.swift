import HikeCore
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(PlannerModel.self) private var model

    @AppStorage("mapStyle") private var mapStyleRaw = MapStyle.topo.rawValue
    @AppStorage("showsTrails") private var showsTrails = true
    /// Empty until the child has said how old they are.
    @AppStorage("ageGroup") private var ageGroupRaw = ""

    @State private var permission = LocationPermission()
    @State private var activeSheet: ActiveSheet?
    @State private var showsLocationDenied = false
    /// The user asked for their position before permission was given; follow once it is.
    @State private var followsWhenAuthorized = false
    /// Whether the save prompt is open. Kept apart from the name: the text field writes an empty
    /// name back while it is being taken away, and that must not open the prompt again.
    @State private var isNamingRoute = false
    @State private var saveName = ""
    @State private var topInset: CGFloat = 0
    @State private var bottomInset: CGFloat = 0

    private enum ActiveSheet: String, Identifiable {
        case search, routes, passport, parentGate, parents
        var id: String { rawValue }
    }

    private var mapStyle: MapStyle { MapStyle(rawValue: mapStyleRaw) ?? .topo }
    private var profile: KidProfile { KidProfile(ageGroup: AgeGroup(rawValue: ageGroupRaw) ?? .middle) }

    var body: some View {
        ZStack {
            MapView(
                style: mapStyle,
                showsTrails: showsTrails,
                showsUserLocation: permission.isAuthorized,
                segments: model.segments,
                segmentsVersion: model.segmentsVersion,
                waypoints: model.markers,
                discoveries: model.discoveries,
                scrubCoordinate: model.scrubCoordinate,
                searchPin: model.searchPin,
                camera: model.camera,
                topInset: topInset,
                bottomInset: bottomInset,
                onTap: { model.addWaypoint($0) },
                onMoveWaypoint: { id, coordinate in model.moveWaypoint(id: id, to: coordinate) },
                onSelectWaypoint: { model.selectedWaypointID = $0 },
                onTapSearchPin: { model.addSearchPinToRoute() }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topControls
                    .background { heightReader { topInset = $0 } }
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    attribution
                    RoutePanel(profile: profile, onSave: { promptForSave() })
                }
                .background { heightReader { bottomInset = $0 } }
            }

            if isNamingRoute {
                SavePrompt(
                    name: $saveName,
                    onCancel: { isNamingRoute = false },
                    onSave: {
                        model.save(name: saveName)
                        isNamingRoute = false
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isNamingRoute)
        .tint(Brand.line)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .search:
                SearchView(near: model.searchBias ?? model.waypoints.last?.coordinate) { place in
                    model.show(place)
                }
            case .routes:
                SavedRoutesView(profile: profile, onShowPassport: { activeSheet = .passport })
            case .passport:
                PassportView()
            case .parentGate:
                ParentGateView(onPassed: { activeSheet = .parents })
            case .parents:
                ParentsView(mapStyleRaw: $mapStyleRaw, showsTrails: $showsTrails, ageGroupRaw: $ageGroupRaw)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { ageGroupRaw.isEmpty }, set: { _ in })) {
            AgeView { group in
                ageGroupRaw = group.rawValue
            }
        }
        .alert("Locatie staat uit", isPresented: $showsLocationDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Vraag een ouder om Hike Kids je locatie te laten zien. Dat kan in Instellingen.")
        }
        .alert(
            "Er ging iets mis",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        .onChange(of: permission.isAuthorized) { _, authorized in
            if authorized, followsWhenAuthorized {
                followsWhenAuthorized = false
                model.followUser()
            }
        }
    }

    // MARK: - Pieces

    private var topControls: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Button {
                activeSheet = .search
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Brand.line)
                    Text("Zoek een plek")
                        .font(.text(19))
                        .foregroundStyle(Brand.line.opacity(0.65))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: Brand.tapTarget)
                .background(Brand.paper, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Brand.line, lineWidth: Brand.outline)
                }
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("searchButton")

            VStack(spacing: 8) {
                mapButton("location.fill", label: "Waar ben ik?") {
                    showUserLocation()
                }
                mapButton("signpost.right.fill", label: "Mijn wandelingen") {
                    activeSheet = .routes
                }
                .accessibilityIdentifier("routesButton")
                mapButton("rosette", label: "Wandelpaspoort") {
                    activeSheet = .passport
                }
                .accessibilityIdentifier("passportButton")
                mapButton("figure.and.child.holdinghands", label: "Voor ouders") {
                    activeSheet = .parentGate
                }
                .accessibilityIdentifier("parentsButton")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private func mapButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Brand.line)
                .frame(width: Brand.tapTarget, height: Brand.tapTarget)
                .background(Brand.paper, in: Circle())
                .overlay {
                    Circle().strokeBorder(Brand.line, lineWidth: Brand.outline)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var attribution: some View {
        if let text = mapStyle.attribution(showsTrails: showsTrails) {
            HStack {
                Spacer(minLength: 0)
                Text(text)
                    .font(.text(9, relativeTo: .caption2))
                    .foregroundStyle(Brand.line.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Brand.paper.opacity(0.85), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
        }
    }

    private func promptForSave() {
        Task {
            saveName = await model.suggestedName()
            isNamingRoute = true
        }
    }

    private func showUserLocation() {
        if permission.isAuthorized {
            model.followUser()
        } else if permission.isDenied {
            showsLocationDenied = true
        } else {
            followsWhenAuthorized = true
            permission.request()
        }
    }

    /// Reports the height of the view it is the background of.
    private func heightReader(_ update: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { update(proxy.size.height) }
                .onChange(of: proxy.size.height) { _, height in update(height) }
        }
    }
}
