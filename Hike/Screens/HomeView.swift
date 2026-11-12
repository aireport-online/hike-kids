import HikeCore
import SwiftUI

/// The home menu: four big channel tiles, Mo saying hello, the walker's level, and a bar with
/// a clock at the bottom, like the home screen of a game console.
struct HomeView: View {
    @Environment(PlannerModel.self) private var model

    let profile: KidProfile
    /// Called with the channel to open and where its tile sits on the screen.
    var onOpen: (Channel, UnitPoint) -> Void

    @State private var tipIndex: Int?
    @State private var taps = 0

    private static let tips = [
        "Neem water en iets lekkers mee.",
        "Trek schoenen aan waar je fijn op loopt.",
        "Blijf op het pad en bij elkaar.",
        "Kijk onderweg naar sporen van dieren.",
        "Neem je afval weer mee naar huis.",
        "Vertel thuis waar je gaat wandelen."
    ]

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        let passport = model.passport

        GeometryReader { screen in
            ZStack {
                Pinstripes()

                VStack(spacing: 14) {
                    greeting(level: passport.level)

                    LazyVGrid(columns: columns, spacing: 14) {
                        tile(.plan, "Nieuwe wandeling", image: "TilePlan", order: 0, highlighted: true, screen: screen.size)
                        tile(.routes, "Mijn wandelingen", image: "TileRoutes", order: 1, screen: screen.size)
                        tile(.passport, "Paspoort", image: "TilePassport", order: 2, screen: screen.size)
                        tile(.parentGate, "Voor ouders", image: "TileParents", order: 3, screen: screen.size)
                    }

                    Spacer(minLength: 0)
                    bottomBar(passport: passport, screen: screen.size)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)

                if let tipIndex {
                    tipBubble(Self.tips[tipIndex % Self.tips.count])
                        .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
                }
            }
            .coordinateSpace(.named("home"))
        }
        .sensoryFeedback(.selection, trigger: taps)
    }

    // MARK: - Greeting and level

    private func greeting(level: WalkerLevel) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Mascot(pose: .wave, size: 92)
                .popIn()

            VStack(alignment: .leading, spacing: 6) {
                Text("Hoi! Waar gaan we heen?")
                    .font(.sign(22, relativeTo: .title2))
                    .foregroundStyle(Brand.line)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Niveau \(level.number) · \(level.title)")
                        .font(.text(15, relativeTo: .subheadline))
                        .foregroundStyle(Brand.chrome)
                    LevelBar(progress: level.progress)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("homeLevel")
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Tiles

    private func tile(
        _ channel: Channel,
        _ title: String,
        image: String,
        order: Int,
        highlighted: Bool = false,
        screen: CGSize
    ) -> some View {
        GeometryReader { proxy in
            Button {
                taps += 1
                let frame = proxy.frame(in: .named("home"))
                onOpen(channel, UnitPoint(
                    x: screen.width > 0 ? frame.midX / screen.width : 0.5,
                    y: screen.height > 0 ? frame.midY / screen.height : 0.5
                ))
            } label: {
                VStack(spacing: 6) {
                    Image(image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.tileCorner - 8))
                    Text(title)
                        .font(.sign(17, relativeTo: .headline))
                        .foregroundStyle(Brand.line)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(8)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .card()
                .glow(RoundedRectangle(cornerRadius: Brand.tileCorner), isOn: highlighted)
                .contentShape(RoundedRectangle(cornerRadius: Brand.tileCorner))
            }
            .buttonStyle(BounceButtonStyle(pressedScale: 0.94))
            .accessibilityIdentifier("tile-\(channel.rawValue)")
            .accessibilityLabel(title)
        }
        .aspectRatio(1.05, contentMode: .fit)
        .popIn(delay: 0.08 + Double(order) * 0.09)
    }

    // MARK: - Bottom bar

    private func bottomBar(passport: Passport, screen: CGSize) -> some View {
        HStack(spacing: 12) {
            Button {
                taps += 1
                withAnimation(Motion.arrive) {
                    tipIndex = tipIndex == nil ? Int.random(in: 0..<Self.tips.count) : nil
                }
            } label: {
                RoundButtonLabel(systemImage: "lightbulb.fill")
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel("Tip van Mo")

            Spacer(minLength: 0)

            // The clock in the middle of the bar, as on a console's home menu.
            TimelineView(.everyMinute) { timeline in
                VStack(spacing: 0) {
                    Text(timeline.date.formatted(date: .omitted, time: .shortened))
                        .font(.sign(28, relativeTo: .title))
                        .monospacedDigit()
                        .foregroundStyle(Brand.line)
                    Text(timeline.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.text(14, relativeTo: .caption))
                        .foregroundStyle(Brand.chrome)
                }
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 0)

            Button {
                taps += 1
                onOpen(.passport, UnitPoint(x: 0.85, y: 0.92))
            } label: {
                RoundButtonLabel(systemImage: "star.fill")
                    .overlay(alignment: .topTrailing) {
                        Text("\(passport.earnedCount)")
                            .font(.sign(13, relativeTo: .caption))
                            .foregroundStyle(Brand.ink)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Brand.yellow, in: Circle())
                            .overlay { Circle().strokeBorder(Brand.ink.opacity(0.7), lineWidth: 1.5) }
                            .offset(x: 6, y: -6)
                    }
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel("\(passport.earnedCount) stempels. Open het paspoort")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .card(cornerRadius: 30)
    }

    private func tipBubble(_ text: String) -> some View {
        VStack {
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 8) {
                Mascot(pose: .point, size: 72, floats: false)
                Text(text)
                    .font(.text(17))
                    .foregroundStyle(Brand.line)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .card(cornerRadius: 20)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
        }
        .frame(maxWidth: 560)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Motion.press) { tipIndex = nil }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Tip van Mo: \(text)")
    }
}
