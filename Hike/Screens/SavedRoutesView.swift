import HikeCore
import SwiftUI

/// The channel with the saved walks, as plates on a signpost. Stamping a walk as done brings
/// the reward.
struct SavedRoutesView: View {
    @Environment(PlannerModel.self) private var model

    let profile: KidProfile
    var onMenu: () -> Void
    /// Called after a walk was opened on the map.
    var onOpened: () -> Void

    @State private var routeAwaitingConfirmation: HikeRoute?
    @State private var reward: Reward?

    private struct Reward: Identifiable {
        let id = UUID()
        let routeName: String
        let stars: Int
        let before: Passport
        let after: Passport
    }

    var body: some View {
        ZStack {
            Pinstripes()

            VStack(spacing: 0) {
                ChannelHeader(title: "Mijn wandelingen", onMenu: onMenu)

                if model.savedRoutes.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(Array(model.savedRoutes.enumerated()), id: \.element.id) { index, route in
                            RoutePlate(
                                route: route,
                                profile: profile,
                                isCurrent: route.id == model.currentRouteID,
                                onOpen: { requestOpen(route) },
                                onToggleWalked: { toggleWalked(route) }
                            )
                            .popIn(delay: min(Double(index), 6) * 0.06)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 14))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    model.delete(route)
                                } label: {
                                    Label("Weg", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background {
                        // The pole the plates hang on.
                        Capsule()
                            .fill(Brand.chrome.opacity(0.55))
                            .frame(width: 12)
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
            }

            if let reward {
                RewardView(
                    routeName: reward.routeName,
                    stars: reward.stars,
                    before: reward.before,
                    after: reward.after,
                    onDone: {
                        withAnimation(.easeIn(duration: 0.2)) { self.reward = nil }
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .confirmationDialog(
            "Je wandeling op de kaart is nog niet bewaard",
            isPresented: Binding(
                get: { routeAwaitingConfirmation != nil },
                set: { if !$0 { routeAwaitingConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Toch openen", role: .destructive) {
                if let route = routeAwaitingConfirmation {
                    open(route)
                }
            }
            Button("Annuleer", role: .cancel) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Mascot(pose: .point, size: 150)
                .popIn()
            Text("Nog geen wandelingen")
                .font(.sign(24, relativeTo: .title2))
                .foregroundStyle(Brand.line)
            Text("Maak een rondje op de kaart en bewaar het. Dan hangt het hier.")
                .font(.text(17))
                .foregroundStyle(Brand.chrome)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(32)
    }

    private func toggleWalked(_ route: HikeRoute) {
        let before = model.passport
        let nowWalked = route.walkedAt == nil
        model.setWalked(route, walked: nowWalked)
        guard nowWalked else { return }
        // A stamp is worth celebrating; taking one away is not.
        let stars = KidAssessment(stats: route.stats, profile: profile).stars
        withAnimation(.easeOut(duration: 0.2)) {
            reward = Reward(routeName: route.name, stars: stars, before: before, after: model.passport)
        }
    }

    private func requestOpen(_ route: HikeRoute) {
        if model.hasUnsavedChanges, model.isComplete, route.id != model.currentRouteID {
            routeAwaitingConfirmation = route
        } else {
            open(route)
        }
    }

    private func open(_ route: HikeRoute) {
        model.open(route)
        onOpened()
    }
}

/// One saved walk as a signpost plate: its name, how far, how long, and whether it was walked.
private struct RoutePlate: View {
    let route: HikeRoute
    let profile: KidProfile
    let isCurrent: Bool
    var onOpen: () -> Void
    var onToggleWalked: () -> Void

    private let point: CGFloat = 18

    var body: some View {
        let stats = route.stats
        let assessment = KidAssessment(stats: stats, profile: profile)
        let isWalked = route.walkedAt != nil

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(route.name)
                    .font(.sign(21, relativeTo: .title3))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(HikeFormat.distance(stats.distance)) · \(HikeFormat.duration(assessment.totalTime)) · \(HikeFormat.count(assessment.steps)) stappen")
                    .font(.text(15, relativeTo: .subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opent de wandeling op de kaart")

            Button(action: onToggleWalked) {
                VStack(spacing: 0) {
                    Image(systemName: isWalked ? "checkmark.seal.fill" : "seal")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(isWalked ? Brand.grass : Brand.ink.opacity(0.55))
                        .symbolEffect(.bounce, value: isWalked)
                    Text(isWalked ? "Gelopen!" : "Gelopen?")
                        .font(.sign(13, relativeTo: .caption))
                }
                .frame(width: 70, height: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(BounceButtonStyle(pressedScale: 0.85))
            .accessibilityIdentifier("walkedButton")
            .accessibilityLabel(isWalked ? "Gelopen. Tik om het stempel weg te halen" : "Zet een stempel: gelopen")
        }
        .padding(.leading, 26)
        .padding(.trailing, point + 4)
        .padding(.vertical, 10)
        .plate(point: point)
        .overlay(alignment: .leading) {
            // The blaze is painted on the blunt end of the plate.
            BlazeMark()
                .frame(width: 10)
                .padding(.vertical, 14)
                .padding(.leading, 8)
        }
        .overlay {
            if isCurrent {
                SignpostShape(point: point).stroke(Brand.glow, lineWidth: 4)
            }
        }
    }
}
