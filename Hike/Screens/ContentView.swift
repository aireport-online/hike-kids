import HikeCore
import SwiftUI
import UIKit

/// The planning channel: the map, with the route panel at the bottom.
struct ContentView: View {
    @Environment(PlannerModel.self) private var model

    let profile: KidProfile
    var onMenu: () -> Void

    // Children start on the simple map without the web of marked trails; a parent can switch
    // to a hiking map in the parents' corner.
    @AppStorage("mapStyle") private var mapStyleRaw = MapStyle.simple.rawValue
    @AppStorage("showsTrails") private var showsTrails = false

    @State private var permission = LocationPermission()
    @State private var showsSearch = false
    @State private var showsLocationDenied = false
    /// The user asked for their position before permission was given; follow once it is.
    @State private var followsWhenAuthorized = false
    /// Whether the save prompt is open. Kept apart from the name: the text field writes an empty
    /// name back while it is being taken away, and that must not open the prompt again.
    @State private var isNamingRoute = false
    @State private var saveName = ""
    /// Counts saves, to show "Bewaard!" for a moment after each one.
    @State private var saves = 0
    @State private var showsSaved = false
    @State private var topInset: CGFloat = 0
    @State private var bottomInset: CGFloat = 0

    private var mapStyle: MapStyle { MapStyle(rawValue: mapStyleRaw) ?? .simple }

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
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    attribution
                    RoutePanel(profile: profile, onSave: { promptForSave() })
                }
                .background { heightReader { bottomInset = $0 } }
            }

            if showsSaved {
                savedToast
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            if isNamingRoute {
                SavePrompt(
                    name: $saveName,
                    onCancel: { isNamingRoute = false },
                    onSave: {
                        model.save(name: saveName)
                        isNamingRoute = false
                        saves += 1
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isNamingRoute)
        .sensoryFeedback(.success, trigger: saves)
        .task(id: saves) {
            // "Bewaard!" pops up after a save and leaves by itself.
            guard saves > 0 else { return }
            withAnimation(Motion.arrive) { showsSaved = true }
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation(.easeIn(duration: 0.25)) { showsSaved = false }
        }
        .sheet(isPresented: $showsSearch) {
            SearchView(near: model.searchBias ?? model.waypoints.last?.coordinate) { place in
                model.show(place)
            }
        }
        .alert("Locatie staat uit", isPresented: $showsLocationDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Vraag een ouder om Hike Kids je locatie te laten zien. Dat kan in Instellingen.")
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
            HStack(spacing: 10) {
                Button(action: onMenu) {
                    RoundButtonLabel(systemImage: "house.fill")
                }
                .buttonStyle(BounceButtonStyle())
                .accessibilityLabel("Terug naar het menu")
                .accessibilityIdentifier("menuButton")

                Button {
                    showsSearch = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Brand.chrome)
                        Text("Zoek een plek")
                            .font(.text(19))
                            .foregroundStyle(Brand.chrome.opacity(0.8))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: Brand.tapTarget)
                    .background(Brand.surface, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Brand.edge, lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                    .contentShape(Capsule())
                }
                .buttonStyle(BounceButtonStyle(pressedScale: 0.97))
                .accessibilityIdentifier("searchButton")
            }
            // Only this row spans the map's width; the button below it sits at the edge,
            // which the map allows for when it frames a route.
            .background { heightReader { topInset = $0 + 10 } }

            Button {
                showUserLocation()
            } label: {
                RoundButtonLabel(systemImage: "location.fill")
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel("Waar ben ik?")
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var savedToast: some View {
        HStack(spacing: 10) {
            Mascot(pose: .cheer, size: 64, floats: false)
            VStack(alignment: .leading, spacing: 0) {
                Text("Bewaard!")
                    .font(.sign(22, relativeTo: .title2))
                    .foregroundStyle(Brand.line)
                Text("Je wandeling hangt aan de wegwijzer.")
                    .font(.text(15, relativeTo: .subheadline))
                    .foregroundStyle(Brand.chrome)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .card()
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("savedToast")
    }

    @ViewBuilder
    private var attribution: some View {
        if let text = mapStyle.attribution(showsTrails: showsTrails) {
            HStack {
                Spacer(minLength: 0)
                Text(text)
                    .font(.text(9, relativeTo: .caption2))
                    .foregroundStyle(Brand.chrome)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Brand.surface.opacity(0.85), in: Capsule())
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
