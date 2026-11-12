import HikeCore
import SwiftUI

/// The white card at the bottom of the map. It leads a child through planning a walk: pick a
/// start, choose how far, see what the walk is like and how many stars it is worth, keep it.
struct RoutePanel: View {
    @Environment(PlannerModel.self) private var model
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let profile: KidProfile
    var onSave: () -> Void

    @State private var showsDiscardConfirmation = false

    /// Which step of planning the panel shows; the card springs when it changes.
    private var step: Int {
        min(model.waypoints.count, 2)
    }

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
                        .foregroundStyle(Brand.chrome)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !model.discoveries.isEmpty {
                    discoveries
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                if verticalSizeClass != .compact, model.profile.count >= 2 {
                    ElevationChart(samples: model.profile, scrubDistance: $model.scrubDistance)
                        .frame(height: 64)
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
        .padding(16)
        .frame(maxWidth: 560, alignment: .leading)
        .card(cornerRadius: 26)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .animation(Motion.arrive, value: step)
        .animation(Motion.arrive, value: model.isComplete)
        .animation(Motion.arrive, value: model.discoveries.count)
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .sensoryFeedback(.success, trigger: model.isComplete) { _, isComplete in isComplete }
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
        HStack(alignment: .center, spacing: 10) {
            Mascot(pose: .wave, size: 78)
            VStack(alignment: .leading, spacing: 2) {
                Text("Waar beginnen we?")
                    .font(.sign(24, relativeTo: .title2))
                    .foregroundStyle(Brand.line)
                Text("Tik op de kaart waar je wilt starten.")
                    .font(.text(16, relativeTo: .subheadline))
                    .foregroundStyle(Brand.chrome)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if model.canUndo {
                undoButton
            }
        }
        .transition(.opacity)
    }

    // MARK: - Step 2: how far?

    private var chooseDistance: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Mascot(pose: .point, size: 66)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hoe ver wil je lopen?")
                        .font(.sign(22, relativeTo: .title2))
                        .foregroundStyle(Brand.line)
                    Text("Ik maak een rondje voor je.")
                        .font(.text(16, relativeTo: .subheadline))
                        .foregroundStyle(Brand.chrome)
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
                    .foregroundStyle(Brand.chrome)
            }
        }
        .transition(.opacity)
    }

    private func loopButton(_ title: String, index: Int) -> some View {
        let distance = profile.loopDistances[index]
        return Button {
            model.makeLoop(distance: distance)
        } label: {
            VStack(spacing: 2) {
                // One, two or three little stars: how big an adventure this is.
                HStack(spacing: 1) {
                    ForEach(0...index, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Brand.yellow)
                    }
                }
                Text(title)
                    .font(.sign(19, relativeTo: .headline))
                    .foregroundStyle(Brand.line)
                Text(HikeFormat.distance(distance))
                    .font(.text(15, relativeTo: .subheadline))
                    .foregroundStyle(Brand.chrome)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .card(cornerRadius: 18)
            .glow(RoundedRectangle(cornerRadius: 18), isOn: index == 1)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(BounceButtonStyle())
        .popIn(delay: Double(index) * 0.07)
        .accessibilityIdentifier("loopButton-\(index)")
        .accessibilityLabel("\(title), \(HikeFormat.distance(distance))")
    }

    // MARK: - Step 3: the walk

    private var title: String {
        if let name = model.currentRouteName {
            return name
        }
        return model.loopTarget != nil || model.isLoop ? "Jouw rondje" : "Jouw wandeling"
    }

    private var assessment: KidAssessment {
        KidAssessment(stats: model.stats, profile: profile)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.sign(23, relativeTo: .title2))
                        .foregroundStyle(Brand.line)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if model.isRouting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if model.isComplete {
                    HStack(spacing: 8) {
                        Stars(earned: assessment.stars, size: 20)
                        effortBadge
                    }
                    .transition(.scale(scale: 0.7, anchor: .leading).combined(with: .opacity))
                }
            }
            Spacer(minLength: 0)
            Button {
                startOver()
            } label: {
                RoundButtonLabel(systemImage: "xmark", size: 40)
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel("Opnieuw beginnen")
        }
    }

    /// Tells at a glance whether the walk suits the child's age.
    private var effortBadge: some View {
        let effort = assessment.effort
        let background: Color
        let foreground: Color
        switch effort {
        case .easy:
            background = Brand.grass
            foreground = .white
        case .sturdy:
            background = Brand.yellow
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
            .padding(.vertical, 4)
            .background(background, in: Capsule())
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
            figure(HikeFormat.distance(model.stats.distance), symbol: "mappin.and.ellipse", caption: "ver", label: "Afstand")
            figure(HikeFormat.duration(assessment.totalTime), symbol: "clock", caption: breaks, label: "Tijd")
            figure(HikeFormat.count(assessment.steps), symbol: "shoeprints.fill", caption: "stappen", label: "Stappen")
        }
        .opacity(model.isComplete ? 1 : 0.45)
    }

    /// A figure set large with its unit small beside it; the digits roll when it changes.
    private func figure(_ value: String, symbol: String, caption: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                ForEach(Array(HikeFormat.tokens(value).enumerated()), id: \.offset) { _, token in
                    Text(token.text)
                        .font(token.isFigure ? .sign(28, relativeTo: .title) : .sign(15, relativeTo: .footnote))
                        .foregroundStyle(Brand.line)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                }
            }
            .animation(.snappy, value: value)
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Brand.glow)
                Text(caption)
                    .font(.text(14, relativeTo: .caption))
                    .foregroundStyle(Brand.chrome)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
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
                .foregroundStyle(Brand.chrome)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(model.discoveries.enumerated()), id: \.element.id) { index, discovery in
                        Text("\(discovery.kind.emoji) \(discovery.name)")
                            .font(.text(15, relativeTo: .subheadline))
                            .foregroundStyle(Brand.line)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Brand.glow.opacity(0.14), in: Capsule())
                            .overlay { Capsule().strokeBorder(Brand.glow.opacity(0.6), lineWidth: 1.5) }
                            .popIn(delay: Double(index) * 0.08)
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
                .foregroundStyle(Brand.line)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Nog eens") { model.retryFailedLegs() }
                if model.loopTarget != nil {
                    Button("Andere kant") { model.turnLoop() }
                        .disabled(model.isRouting)
                } else {
                    Button("Rechte lijn") { model.useStraightLinesForFailedLegs() }
                        .accessibilityIdentifier("straightLineFallbackButton")
                }
            }
            .buttonStyle(OutlineButtonStyle(compact: true))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.blaze.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).strokeBorder(Brand.blaze.opacity(0.7), lineWidth: 2)
        }
    }

    private func selectedWaypoint(index: Int) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(waypointTitle(index: index))
                    .font(.sign(17, relativeTo: .subheadline))
                    .foregroundStyle(Brand.line)
                Text("Houd vast om te verschuiven")
                    .font(.text(14, relativeTo: .caption))
                    .foregroundStyle(Brand.chrome)
            }
            Spacer(minLength: 0)
            Button {
                if let id = model.selectedWaypointID {
                    model.removeWaypoint(id: id)
                }
            } label: {
                Label("Weg", systemImage: "trash")
            }
            .buttonStyle(OutlineButtonStyle(compact: true))
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
            RoundButtonLabel(systemImage: "arrow.uturn.backward", size: 48)
        }
        .buttonStyle(BounceButtonStyle())
        .disabled(!model.canUndo)
        .opacity(model.canUndo ? 1 : 0.4)
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
                .buttonStyle(OutlineButtonStyle())
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
