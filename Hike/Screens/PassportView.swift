import HikeCore
import SwiftUI

/// The walking passport: everything walked so far, and the badges it earned.
struct PassportView: View {
    @Environment(PlannerModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let passport = model.passport

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 14) {
                        Mascot(pose: .cheer, size: 96)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(passport.walks == 0 ? "Nog leeg!" : "Goed gedaan!")
                                .font(.sign(26, relativeTo: .title))
                            Text(passport.walks == 0
                                 ? "Loop een wandeling en zet er een stempel bij."
                                 : "Je hebt \(passport.earnedCount) van de \(passport.badges.count) stempels.")
                                .font(.text(17))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(Brand.line)
                        Spacer(minLength: 0)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        total(String(passport.walks), caption: passport.walks == 1 ? "wandeling" : "wandelingen")
                        total(HikeFormat.distance(passport.distance), caption: "gelopen")
                        total(HikeFormat.elevation(passport.ascent), caption: "geklommen")
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 30)
                    .padding(.vertical, 14)
                    .plate(point: 18)
                    .accessibilityIdentifier("passportTotals")

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(passport.badges) { badge in
                            BadgeCard(badge: badge)
                        }
                    }
                }
                .padding(20)
            }
            .background(Brand.ground.ignoresSafeArea())
            .signTitle("Wandelpaspoort")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                        .font(.sign(17))
                }
            }
        }
        .tint(Brand.line)
    }

    private func total(_ value: String, caption: String) -> some View {
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
    let badge: Badge

    var body: some View {
        VStack(spacing: 6) {
            Text(badge.emoji)
                .font(.system(size: 40))
                .grayscale(badge.isEarned ? 0 : 1)
                .opacity(badge.isEarned ? 1 : 0.35)
                .frame(width: 78, height: 78)
                .background(badge.isEarned ? Brand.yellow : Brand.line.opacity(0.08), in: Circle())
                .overlay {
                    Circle().strokeBorder(
                        Brand.line.opacity(badge.isEarned ? 1 : 0.3),
                        style: StrokeStyle(lineWidth: Brand.outline, dash: badge.isEarned ? [] : [5, 5])
                    )
                }
            Text(badge.title)
                .font(.sign(17, relativeTo: .headline))
                .foregroundStyle(Brand.line.opacity(badge.isEarned ? 1 : 0.6))
                .multilineTextAlignment(.center)
            Text(badge.isEarned ? "Gehaald!" : badge.goal)
                .font(.text(14, relativeTo: .caption))
                .foregroundStyle(Brand.line.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Brand.paper, in: RoundedRectangle(cornerRadius: Brand.corner))
        .overlay {
            RoundedRectangle(cornerRadius: Brand.corner)
                .strokeBorder(Brand.line.opacity(badge.isEarned ? 1 : 0.25), lineWidth: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.isEarned ? "\(badge.title), gehaald" : "\(badge.title), nog niet gehaald: \(badge.goal)")
    }
}
