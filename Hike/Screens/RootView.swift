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

    private var profile: KidProfile {
        KidProfile(ageGroup: AgeGroup(rawValue: ageGroupRaw) ?? .middle)
    }

    var body: some View {
        ZStack {
            HomeView(profile: profile) { channel, anchor in
                origin = anchor
                show(channel)
            }
            // The menu steps back while a channel is open.
            .scaleEffect(channel == nil ? 1 : 1.1)
            .opacity(channel == nil ? 1 : 0)
            .allowsHitTesting(channel == nil)
            .accessibilityHidden(channel != nil)

            if let channel {
                channelView(channel)
                    .id(channel)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.1, anchor: origin).combined(with: .opacity))
                    .zIndex(1)
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
            ContentView(profile: profile, onMenu: { show(nil) })
        case .routes:
            SavedRoutesView(profile: profile, onMenu: { show(nil) }, onOpened: { show(.plan) })
        case .passport:
            PassportView(onMenu: { show(nil) })
        case .parentGate:
            ParentGateView(onMenu: { show(nil) }, onPassed: { show(.parents) })
        case .parents:
            ParentsView(ageGroupRaw: $ageGroupRaw, onMenu: { show(nil) }, onImported: { show(.plan) })
        }
    }

    private func show(_ channel: Channel?) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.open) {
            self.channel = channel
        }
    }
}
