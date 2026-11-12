import HikeCore
import SwiftUI

/// The passport channel: the walker's level, everything walked so far, and the stamps.
struct PassportView: View {
    @Environment(PlannerModel.self) private var model

    var onMenu: () -> Void

    @State private var shownProgress = 0.0

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let passport = model.passport
        let level = passport.level

        ZStack {
            Pinstripes()

            VStack(spacing: 0) {
                ChannelHeader(title: "Paspoort", onMenu: onMenu)

                ScrollView {
                    VStack(spacing: 16) {
                        // Level
                        HStack(spacing: 12) {
                            Mascot(pose: .cheer, size: 96)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Niveau \(level.number)")
                                    .font(.sign(30, relativeTo: .largeTitle))
                                    .foregroundStyle(Brand.line)
                                    .accessibilityIdentifier("passportLevel")
                                Text(level.title)
                                    .font(.text(18))
                                    .foregroundStyle(Brand.chrome)
                                LevelBar(progress: shownProgress, height: 16)
                                Text(passport.walks == 0
                                     ? "Loop een wandeling en zet er een stempel bij."
                                     : "Nog \(HikeFormat.distance(level.remaining)) tot niveau \(level.number + 1)")
                                    .font(.text(14, relativeTo: .caption))
                                    .foregroundStyle(Brand.chrome)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .card()
                        .popIn()

                        // Totals
                        HStack(alignment: .top, spacing: 8) {
                            total(String(passport.walks), caption: passport.walks == 1 ? "wandeling" : "wandelingen")
                            total(HikeFormat.distance(passport.distance), caption: "gelopen")
                            total(HikeFormat.elevation(passport.ascent), caption: "geklommen")
                        }
                        .padding(14)
                        .card()
                        .popIn(delay: 0.08)
                        .accessibilityIdentifier("passportTotals")

                        Text("Je hebt \(passport.earnedCount) van de \(passport.badges.count) stempels")
                            .font(.sign(18, relativeTo: .headline))
                            .foregroundStyle(Brand.line)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(passport.badges.enumerated()), id: \.element.id) { index, badge in
                                BadgeCard(badge: badge)
                                    .popIn(delay: 0.12 + Double(index) * 0.05)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .task {
            // The bar fills up once the channel has opened.
            try? await Task.sleep(nanoseconds: 400_000_000)
            shownProgress = level.progress
        }
    }

    private func total(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                ForEach(Array(HikeFormat.tokens(value).enumerated()), id: \.offset) { _, token in
                    Text(token.text)
                        .font(token.isFigure ? .sign(28, relativeTo: .title) : .sign(15, relativeTo: .footnote))
                        .foregroundStyle(Brand.line)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            Text(caption)
                .font(.text(14, relativeTo: .caption))
                .foregroundStyle(Brand.chrome)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(caption)")
    }
}

/// One stamp: in colour once earned, grey with its goal while it is still to be earned.
private struct BadgeCard: View {
    let badge: HikeCore.Badge

    var body: some View {
        VStack(spacing: 6) {
            Text(badge.emoji)
                .font(.system(size: 40))
                .grayscale(badge.isEarned ? 0 : 1)
                .opacity(badge.isEarned ? 1 : 0.35)
                .frame(width: 78, height: 78)
                .background(badge.isEarned ? Brand.yellow : Brand.chrome.opacity(0.1), in: Circle())
                .overlay {
                    Circle().strokeBorder(
                        badge.isEarned ? Brand.ink.opacity(0.8) : Brand.chrome.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, dash: badge.isEarned ? [] : [5, 5])
                    )
                }
                .floating(amplitude: badge.isEarned ? 2.5 : 0, period: 3.2, phase: Double(badge.id.count) * 0.13)
            Text(badge.title)
                .font(.sign(17, relativeTo: .headline))
                .foregroundStyle(Brand.line.opacity(badge.isEarned ? 1 : 0.6))
                .multilineTextAlignment(.center)
            Text(badge.isEarned ? "Gehaald!" : badge.goal)
                .font(.text(14, relativeTo: .caption))
                .foregroundStyle(Brand.chrome)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .card()
        .glow(RoundedRectangle(cornerRadius: Brand.tileCorner), isOn: badge.isEarned)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.isEarned ? "\(badge.title), gehaald" : "\(badge.title), nog niet gehaald: \(badge.goal)")
    }
}
