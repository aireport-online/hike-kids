import HikeCore
import SwiftUI

/// The saved walks as plates on a signpost. A walk that was done gets a stamp.
struct SavedRoutesView: View {
    @Environment(PlannerModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let profile: KidProfile
    var onShowPassport: () -> Void

    @State private var routeAwaitingConfirmation: HikeRoute?

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.savedRoutes) { route in
                    RoutePlate(
                        route: route,
                        profile: profile,
                        isCurrent: route.id == model.currentRouteID,
                        onOpen: { requestOpen(route) },
                        onToggleWalked: { model.setWalked(route, walked: route.walkedAt == nil) }
                    )
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
                // The pole the plates hang on. It starts below the title bar.
                ZStack {
                    Brand.ground
                        .ignoresSafeArea()
                    if !model.savedRoutes.isEmpty {
                        Capsule()
                            .fill(Brand.line)
                            .frame(width: 12)
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
            .overlay {
                if model.savedRoutes.isEmpty {
                    emptyState
                }
            }
            .signTitle("Mijn wandelingen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Klaar") { dismiss() }
                        .font(.sign(17))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onShowPassport) {
                        Label("Wandelpaspoort", systemImage: "rosette")
                    }
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
        .tint(Brand.line)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Mascot(pose: .point, size: 120)
            Text("Nog geen wandelingen")
                .font(.sign(24, relativeTo: .title2))
                .foregroundStyle(Brand.line)
            Text("Maak een rondje op de kaart en bewaar het. Dan hangt het hier.")
                .font(.text(17))
                .foregroundStyle(Brand.line.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(32)
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
        dismiss()
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
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(isWalked ? Brand.grass : Brand.ink.opacity(0.55))
                    Text(isWalked ? "Gelopen!" : "Gelopen?")
                        .font(.sign(13, relativeTo: .caption))
                }
                .frame(width: 70, height: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                SignpostShape(point: point).stroke(Brand.ink, lineWidth: 5)
            }
        }
    }
}
