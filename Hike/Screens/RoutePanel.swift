import HikeCore
import SwiftUI

/// The signpost plate at the bottom of the map. It leads a child through planning a walk:
/// pick a start, choose how far, see what the walk is like, keep it.
struct RoutePanel: View {
    @Environment(PlannerModel.self) private var model
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let profile: KidProfile
    var onSave: () -> Void

    @State private var showsDiscardConfirmation = false

    /// Depth of the plate's pointed end; content keeps clear of it.
    private let point: CGFloat = 18

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 10) {
            if model.waypoints.isEmpty {
                welcome
            } else if model.waypoints.count == 1 {
                chooseDistance
            } else {
                header
                figures
                if let comparison = HeightComparison.text(forAscent: model.stats.ascent), model.isComplete {
                    Text("⛰️ \(comparison)")
                        .font(.text(15, relativeTo: .subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !model.discoveries.isEmpty {
                    discoveries
                }
                if verticalSizeClass != .compact, model.profile.count >= 2 {
                    ElevationChart(samples: model.profile, scrubDistance: $model.scrubDistance)
                        .frame(height: 70)
                }
                if let error = model.routingError {
                    failure(error)
                }
                if let index = model.selectedWaypointIndex {
                    selectedWaypoint(index: index)
                }
                actions
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12 + point)
        .padding(.vertical, 14)
        .frame(maxWidth: 560, alignment: .leading)
        .plate(point: point, shadow: true)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .confirmationDialog(
            "Deze wandeling is nog niet bewaard",
            isPresented: $showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Weggooien en opnieuw beginnen", role: .destructive) { model.startNewRoute() }
            Button("Annuleer", role: .cancel) {}
        }
    }

    // MARK: - Step 1: where do we start?

    private var welcome: some View {
        HStack(alignment: .center, spacing: 12) {
            Mascot(pose: .wave, size: 76)
            VStack(alignment: .leading, spacing: 2) {
                Text("Waar beginnen we?")
                    .font(.sign(24, relativeTo: .title2))
                Text("Tik op de kaart waar je wilt starten.")
                    .font(.text(16, relativeTo: .subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if model.canUndo {
                undoButton
            }
        }
    }

    // MARK: - Step 2: how far?

    private var chooseDistance: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Mascot(pose: .point, size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hoe ver wil je lopen?")
                        .font(.sign(22, relativeTo: .title2))
                    Text("Ik maak een rondje voor je.")
                        .font(.text(16, relativeTo: .subheadline))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                loopButton("Kort", index: 0)
                loopButton("Middel", index: 1)
                loopButton("Lang", index: 2)
            }
            HStack(spacing: 8) {
                undoButton
                Text("Of tik zelf verder op de kaart.")
                    .font(.text(15, relativeTo: .footnote))
                    .foregroundStyle(Brand.ink.opacity(0.8))
            }
        }
    }

    private func loopButton(_ title: String, index: Int) -> some View {
        let distance = profile.loopDistances[index]
        return Button {
            model.makeLoop(distance: distance)
        } label: {
            VStack(spacing: 0) {
                Text(title)
                    .font(.sign(19, relativeTo: .headline))
                Text(HikeFormat.distance(distance))
                    .font(.text(15, relativeTo: .subheadline))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(OutlineButtonStyle(onYellow: true))
        .accessibilityIdentifier("loopButton-\(index)")
    }

    // MARK: - Step 3: the walk

    private var title: String {
        if let name = model.currentRouteName {
            return name
        }
        return model.loopTarget != nil || model.isLoop ? "Jouw rondje" : "Jouw wandeling"
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.sign(24, relativeTo: .title2))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if model.isRouting {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer(minLength: 0)
            if model.isComplete {
                effortBadge
            }
            Button {
                startOver()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .heavy))
                    .frame(width: 36, height: 36)
                    .background(Color.white, in: Circle())
                    .overlay { Circle().strokeBorder(Brand.ink, lineWidth: 2) }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Opnieuw beginnen")
        }
    }

    private var assessment: KidAssessment {
        KidAssessment(stats: model.stats, profile: profile)
    }

    /// Tells at a glance whether the walk suits the child's age.
    private var effortBadge: some View {
        let effort = assessment.effort
        let background: Color
        let foreground: Color
        switch effort {
        case .easy:
            background = Brand.grass
            foreground = Brand.ink
        case .sturdy:
            background = .white
            foreground = Brand.ink
        case .tooFar:
            background = Brand.blaze
            foreground = .white
        }
        return Text(effort.title)
            .font(.sign(14, relativeTo: .footnote))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .overlay { Capsule().strokeBorder(Brand.ink, lineWidth: 2) }
            .accessibilityIdentifier("effortBadge")
    }

    private var figures: some View {
        let assessment = self.assessment
        let breaks: String
        switch assessment.breaks {
        case 0: breaks = "zonder pauze"
        case 1: breaks = "met 1 pauze"
        default: breaks = "met \(assessment.breaks) pauzes"
        }
        return HStack(alignment: .top, spacing: 8) {
            figure(HikeFormat.distance(model.stats.distance), caption: "ver", label: "Afstand")
            figure(HikeFormat.duration(assessment.totalTime), caption: breaks, label: "Tijd")
            figure(HikeFormat.count(assessment.steps), caption: "stappen", label: "Stappen")
        }
        .opacity(model.isComplete ? 1 : 0.45)
    }

    /// A figure set large with its unit small beside it, and a few words underneath.
    private func figure(_ value: String, caption: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                ForEach(Array(HikeFormat.tokens(value).enumerated()), id: \.offset) { _, token in
                    Text(token.text)
                        .font(token.isFigure ? .sign(28, relativeTo: .title) : .sign(15, relativeTo: .footnote))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            Text(caption)
                .font(.text(14, relativeTo: .caption))
                .foregroundStyle(Brand.ink.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value), \(caption)")
    }

    /// What there is to see and do along the way.
    private var discoveries: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Onderweg kom je tegen")
                .font(.text(14, relativeTo: .caption))
                .foregroundStyle(Brand.ink.opacity(0.8))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.discoveries) { discovery in
                        Text("\(discovery.kind.emoji) \(discovery.name)")
                            .font(.text(15, relativeTo: .subheadline))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white, in: Capsule())
                            .overlay { Capsule().strokeBorder(Brand.ink, lineWidth: 1.5) }
                            .accessibilityLabel("\(discovery.kind.title): \(discovery.name)")
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .accessibilityIdentifier("discoveries")
    }

    private func failure(_ error: RoutingError) -> some View {
        let message: String
        switch error {
        case .offline:
            message = "Er is geen internet. Vraag even hulp."
        case .serverBusy, .legTooLong:
            message = "Dat is te ver of het is druk. Probeer het zo nog eens."
        default:
            message = "Hier vind ik geen wandelpad."
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Oeps! \(message)")
                .font(.text(16, relativeTo: .subheadline))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Nog eens") { model.retryFailedLegs() }
                if model.loopTarget != nil {
                    Button("Andere kant") { model.turnLoop() }
                } else {
                    Button("Rechte lijn") { model.useStraightLinesForFailedLegs() }
                        .accessibilityIdentifier("straightLineFallbackButton")
                }
            }
            .buttonStyle(OutlineButtonStyle(onYellow: true, compact: true))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Brand.corner))
        .overlay {
            RoundedRectangle(cornerRadius: Brand.corner)
                .strokeBorder(Brand.blaze, lineWidth: Brand.outline)
        }
    }

    private func selectedWaypoint(index: Int) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(waypointTitle(index: index))
                    .font(.sign(17, relativeTo: .subheadline))
                Text("Houd vast om te verschuiven")
                    .font(.text(14, relativeTo: .caption))
                    .foregroundStyle(Brand.ink.opacity(0.8))
            }
            Spacer(minLength: 0)
            Button {
                if let id = model.selectedWaypointID {
                    model.removeWaypoint(id: id)
                }
            } label: {
                Label("Weg", systemImage: "trash")
            }
            .buttonStyle(OutlineButtonStyle(onYellow: true, compact: true))
        }
    }

    private func waypointTitle(index: Int) -> String {
        if index == 0 {
            return "Start"
        }
        if index == model.waypoints.count - 1 {
            return "Einde"
        }
        return "Punt \(index)"
    }

    private var undoButton: some View {
        Button {
            model.undo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 18, weight: .bold))
        }
        .buttonStyle(OutlineButtonStyle(onYellow: true))
        .disabled(!model.canUndo)
        .accessibilityLabel("Stap terug")
    }

    private var actions: some View {
        HStack(spacing: 8) {
            undoButton

            if model.loopTarget != nil {
                Button {
                    model.turnLoop()
                } label: {
                    Label("Andere kant", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle(onYellow: true))
                .disabled(model.isRouting)
                .accessibilityIdentifier("turnLoopButton")
            } else {
                Spacer(minLength: 0)
            }

            Button("Bewaar", action: onSave)
                .buttonStyle(InkButtonStyle())
                .disabled(!model.isComplete || (model.currentRouteName != nil && !model.hasUnsavedChanges))
                .accessibilityIdentifier("saveButton")
        }
    }

    private func startOver() {
        if model.hasUnsavedChanges, model.isComplete {
            showsDiscardConfirmation = true
        } else {
            model.startNewRoute()
        }
    }
}
