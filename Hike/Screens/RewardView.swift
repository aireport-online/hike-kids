import HikeCore
import SwiftUI

/// What a child gets for a walk that was done: confetti, Mo cheering, the stars the walk was
/// worth, the level bar filling up, and any stamps that were earned with it.
struct RewardView: View {
    let routeName: String
    let stars: Int
    /// The passport just before and just after the walk was stamped.
    let before: Passport
    let after: Passport
    var onDone: () -> Void

    @State private var start = Date()
    /// Nil until the bar starts filling; until then it shows where the walker was.
    @State private var shownProgress: Double?
    @State private var shownStars = 0

    private var leveledUp: Bool {
        after.level.number > before.level.number
    }

    var body: some View {
        let newBadges = after.newBadges(since: before)

        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                Mascot(pose: .cheer, size: 150)
                    .popIn()

                Text(leveledUp ? "Niveau \(after.level.number)!" : "Goed gelopen!")
                    .font(.sign(34, relativeTo: .largeTitle))
                    .foregroundStyle(Brand.line)
                    .popIn(delay: 0.1)
                    .accessibilityIdentifier("rewardTitle")

                Text(routeName)
                    .font(.text(17))
                    .foregroundStyle(Brand.chrome)
                    .lineLimit(1)

                if stars > 0 {
                    Stars(earned: shownStars, size: 40)
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("Niveau \(after.level.number) · \(after.level.title)")
                        Spacer(minLength: 0)
                        if after.level.remaining > 0 {
                            Text("nog \(HikeFormat.distance(after.level.remaining))")
                        }
                    }
                    .font(.text(15, relativeTo: .subheadline))
                    .foregroundStyle(Brand.chrome)
                    LevelBar(progress: shownProgress ?? (leveledUp ? 0 : before.level.progress), height: 18)
                }
                .popIn(delay: 0.2)

                if !newBadges.isEmpty {
                    VStack(spacing: 6) {
                        Text(newBadges.count == 1 ? "Nieuw stempel!" : "Nieuwe stempels!")
                            .font(.sign(18, relativeTo: .headline))
                            .foregroundStyle(Brand.line)
                        HStack(spacing: 10) {
                            ForEach(Array(newBadges.enumerated()), id: \.element.id) { index, badge in
                                VStack(spacing: 2) {
                                    Text(badge.emoji)
                                        .font(.system(size: 30))
                                        .frame(width: 58, height: 58)
                                        .background(Brand.yellow, in: Circle())
                                        .overlay { Circle().strokeBorder(Brand.ink.opacity(0.8), lineWidth: 2) }
                                    Text(badge.title)
                                        .font(.text(13, relativeTo: .caption))
                                        .foregroundStyle(Brand.chrome)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: 96)
                                .popIn(delay: 0.5 + Double(index) * 0.15)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Nieuw stempel: \(badge.title)")
                            }
                        }
                    }
                }

                Button("Joepie!", action: onDone)
                    .buttonStyle(InkButtonStyle())
                    .popIn(delay: 0.4)
                    .accessibilityIdentifier("rewardDone")
            }
            .padding(22)
            .frame(maxWidth: 420)
            .card(cornerRadius: 30)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)

            Confetti(start: start)
                .ignoresSafeArea()
        }
        .sensoryFeedback(.success, trigger: start)
        .onAppear { start = Date() }
        .task {
            // The stars and the bar wait until the card has arrived, so the child sees them
            // pop and fill. The bar starts where the walker was, or empty on a new level.
            try? await Task.sleep(nanoseconds: 350_000_000)
            shownStars = stars
            try? await Task.sleep(nanoseconds: 250_000_000)
            shownProgress = after.level.progress
        }
    }
}
