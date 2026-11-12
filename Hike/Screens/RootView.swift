import HikeCore
import SwiftUI

/// The parts of the app, each opened from its tile on the home menu.
enum Channel: String, Identifiable {
    case plan, routes, passport, parentGate, parents

    var id: String { rawValue }
}

/// The home menu with the channel that is open on top of it. A channel grows out of the tile
/// that was tapped and shrinks back into it.
struct RootView: View {
    @Environment(PlannerModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Empty until the child has said how old they are.
    @AppStorage("ageGroup") private var ageGroupRaw = ""

    @State private var channel: Channel?
    /// Where on the screen the opened tile sits, as a fraction of the screen.
    @State private var origin = UnitPoint.center
    /// The same for the map, which always grows out of its own tile. It starts near where
    /// that tile is, so that the first opening does not drift across the screen.
    @State private var planOrigin = UnitPoint(x: 0.27, y: 0.34)

    private var profile: KidProfile {
        KidProfile(ageGroup: AgeGroup(rawValue: ageGroupRaw) ?? .middle)
    }

    var body: some View {
        ZStack {
            // Behind everything, so nothing bare shows while one channel makes way for another.
            Pinstripes()

            HomeView(profile: profile) { channel, anchor in
                if channel == .plan {
                    planOrigin = anchor
                } else {
                    origin = anchor
                }
                show(channel)
            }
            // The menu steps back while a channel is open.
            .scaleEffect(channel == nil || reduceMotion ? 1 : 1.1)
            .opacity(channel == nil ? 1 : 0)
            .allowsHitTesting(channel == nil)
            .accessibilityHidden(channel != nil)

            // The map stays ready behind the menu: building it only when its tile is tapped
            // makes the opening stutter, and this way it also remembers where it was. Its
            // buttons and panel only exist while the channel is open.
            ContentView(profile: profile, isActive: channel == .plan, onMenu: { show(nil) })
                .scaleEffect(channel == .plan || reduceMotion ? 1 : 0.1, anchor: planOrigin)
                .opacity(channel == .plan ? 1 : 0)
                .allowsHitTesting(channel == .plan)
                .accessibilityHidden(channel != .plan)
                .zIndex(1)

            if let channel, channel != .plan {
                channelView(channel)
                    .id(channel)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.1, anchor: origin).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .tint(Brand.line)
        .fullScreenCover(isPresented: Binding(get: { ageGroupRaw.isEmpty }, set: { _ in })) {
            AgeView { group in
                ageGroupRaw = group.rawValue
            }
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
    }

    @ViewBuilder
    private func channelView(_ channel: Channel) -> some View {
        switch channel {
        case .plan:
            // Always on screen, see `body`.
            EmptyView()
        case .routes:
            SavedRoutesView(profile: profile, onMenu: { show(nil) }, onOpened: { showRouteOnMap() })
        case .passport:
            PassportView(onMenu: { show(nil) })
        case .parentGate:
            ParentGateView(onMenu: { show(nil) }, onPassed: { show(.parents) })
        case .parents:
            ParentsView(ageGroupRaw: $ageGroupRaw, onMenu: { show(nil) }, onImported: { showRouteOnMap() })
        }
    }

    /// Opens the map on a route that was just loaded. The route is framed once more when the
    /// panel is in place, so that it is not hidden behind it.
    private func showRouteOnMap() {
        show(.plan)
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            model.fitRoute()
        }
    }

    private func show(_ channel: Channel?) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.open) {
            self.channel = channel
        }
    }
}
