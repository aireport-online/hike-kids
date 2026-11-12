import HikeCore
import SwiftUI
import UniformTypeIdentifiers

/// The gate in front of the parents' channel: a sum that a young child cannot do yet.
struct ParentGateView: View {
    var onMenu: () -> Void
    var onPassed: () -> Void

    @State private var left = Int.random(in: 6...9)
    @State private var right = Int.random(in: 6...9)
    @State private var answer = ""
    @State private var wasWrong = false
    @FocusState private var answerIsFocused: Bool

    var body: some View {
        ZStack {
            Pinstripes()

            VStack(alignment: .leading, spacing: 0) {
                ChannelHeader(title: "Voor ouders", onMenu: onMenu)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Dit deel is voor een volwassene. Los de som op om verder te gaan.")
                        .font(.text(17))
                        .foregroundStyle(Brand.chrome)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Text("\(left) × \(right) =")
                            .font(.sign(30, relativeTo: .title))
                            .foregroundStyle(Brand.line)
                            .accessibilityIdentifier("gateQuestion")
                        TextField("?", text: $answer)
                            .font(.sign(28, relativeTo: .title))
                            .foregroundStyle(Brand.line)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .focused($answerIsFocused)
                            .frame(width: 104, height: Brand.tapTarget)
                            .background(Brand.haze, in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(wasWrong ? Brand.blaze : Brand.glow, lineWidth: 2.5)
                            }
                            .accessibilityIdentifier("gateAnswer")
                    }

                    if wasWrong {
                        Text("Dat klopt niet. Probeer deze som.")
                            .font(.text(15, relativeTo: .footnote))
                            .foregroundStyle(Brand.blaze)
                    }

                    Button("Verder") { check() }
                        .buttonStyle(InkButtonStyle())
                        .accessibilityIdentifier("gateContinue")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(cornerRadius: 28)
                .padding(.horizontal, 16)
                .popIn(delay: 0.1)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: 560)
        }
        .onAppear { answerIsFocused = true }
    }

    private func check() {
        if Int(answer.trimmingCharacters(in: .whitespaces)) == left * right {
            onPassed()
        } else {
            // A new sum each time, so guessing does not get anyone in.
            wasWrong = true
            answer = ""
            left = Int.random(in: 6...9)
            right = Int.random(in: 6...9)
        }
    }
}

/// The grown-ups' corner: the child's age, the map, sharing and importing routes, and how the
/// app works out what it tells the child.
struct ParentsView: View {
    @Environment(PlannerModel.self) private var model

    @Binding var ageGroupRaw: String
    var onMenu: () -> Void
    /// Called after a GPX file was imported and opened on the map.
    var onImported: () -> Void

    @AppStorage("mapStyle") private var mapStyleRaw = MapStyle.simple.rawValue
    @AppStorage("showsTrails") private var showsTrails = false

    @State private var isImporting = false
    @State private var shareItem: ShareItem?

    private static let gpxTypes: [UTType] = [UTType(filenameExtension: "gpx") ?? .xml, .xml]

    private var profile: KidProfile {
        KidProfile(ageGroup: AgeGroup(rawValue: ageGroupRaw) ?? .middle)
    }

    var body: some View {
        @Bindable var model = model

        ZStack {
            Pinstripes()

            VStack(spacing: 0) {
                ChannelHeader(title: "Voor ouders", onMenu: onMenu)

                ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section("Leeftijd") {
                        SignSwitch(
                            options: AgeGroup.allCases.map { SignSwitch<String>.Option(value: $0.rawValue, title: $0.title) },
                            selection: $ageGroupRaw
                        )
                        note("""
                        Voor deze leeftijd rekent de app met \(HikeFormat.distance(profile.speed)) per uur, \
                        \(Int(profile.climbRate)) m stijgen per uur en 10 minuten pauze na elke \
                        \(Int(profile.minutesBetweenBreaks)) minuten lopen. Tot ongeveer \
                        \(HikeFormat.distance(profile.comfortableDistance)) heet een wandeling een lekker rondje, \
                        boven \(HikeFormat.distance(profile.maximumDistance)) erg ver; 100 m klimmen telt als 800 m lopen. \
                        Het zijn vuistregels: u kent uw kind het best.
                        """)
                    }

                    section("Kaart") {
                        VStack(spacing: 8) {
                            ForEach(MapStyle.allCases) { style in
                                styleRow(style)
                            }
                        }
                        Toggle(isOn: $showsTrails) {
                            Text("Gemarkeerde wandelroutes tonen")
                                .font(.text(17))
                                .foregroundStyle(Brand.line)
                        }
                        .tint(Brand.glow)
                    }

                    section("De wandeling op de kaart") {
                        SignSwitch(
                            options: [
                                SignSwitch<LegMode>.Option(value: .trail, title: "Over paden"),
                                SignSwitch<LegMode>.Option(value: .straight, title: "Rechte lijn")
                            ],
                            selection: $model.legMode
                        )
                        note("Zo wordt het volgende punt verbonden dat op de kaart wordt getikt.")
                        HStack(spacing: 10) {
                            Button {
                                model.reverseRoute()
                            } label: {
                                Label("Keer om", systemImage: "arrow.left.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(model.waypoints.count < 2)
                            Button {
                                if let url = model.exportCurrentRoute() {
                                    shareItem = ShareItem(url: url)
                                }
                            } label: {
                                Label("Deel als GPX", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(!model.isComplete)
                        }
                        .buttonStyle(OutlineButtonStyle())
                        Button {
                            isImporting = true
                        } label: {
                            Label("Importeer een GPX-bestand", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(OutlineButtonStyle())
                    }

                    section("Privacy") {
                        note("""
                        Hike Kids heeft geen account, geen reclame en geen aankopen, en houdt niet bij wat uw kind doet. \
                        Wandelingen blijven op dit toestel. Om kaarten te tonen, te zoeken en routes te berekenen \
                        vraagt de app openbare diensten om gegevens; daarbij gaat alleen de plek op de kaart mee.
                        """)
                    }

                    section("Bronnen") {
                        note("""
                        Kaartgegevens © OpenStreetMap-bijdragers. Topografische kaart: OpenTopoMap (CC-BY-SA), \
                        hoogtegegevens SRTM. Wandelroutes: Waymarked Trails. Routeberekening: BRouter. \
                        Zoeken en plekken onderweg: Photon van Komoot. Lettertype: Fredoka (SIL Open Font License).
                        """)
                    }
                }
                .padding(20)
                .card(cornerRadius: 28)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: Self.gpxTypes) { result in
            if case .success(let url) = result, model.importGPX(from: url) {
                onImported()
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(url: item.url)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SignHeading(title: title)
            content()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.text(15, relativeTo: .footnote))
            .foregroundStyle(Brand.line.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The chosen map glows cyan; the others are plain outlined cards.
    private func styleRow(_ style: MapStyle) -> some View {
        let isOn = style.rawValue == mapStyleRaw

        return Button {
            mapStyleRaw = style.rawValue
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.title)
                        .font(.sign(19, relativeTo: .headline))
                        .foregroundStyle(Brand.line)
                    Text(style.subtitle)
                        .font(.text(15, relativeTo: .caption))
                        .foregroundStyle(Brand.chrome)
                }
                Spacer(minLength: 0)
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Brand.glow)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? Brand.glow.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isOn ? Brand.glow : Brand.edge, lineWidth: isOn ? 2.5 : 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BounceButtonStyle(pressedScale: 0.97))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
