import HikeCore
import SwiftUI

/// The first thing a child sees: Mo asks how old they are, so walks fit their legs.
struct AgeView: View {
    var onChoose: (AgeGroup) -> Void

    @State private var taps = 0

    var body: some View {
        ZStack {
            Pinstripes()

            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Mascot(pose: .wave, size: 200)
                    .popIn()
                VStack(spacing: 4) {
                    Text("Hoi! Ik ben Mo.")
                        .font(.sign(34, relativeTo: .largeTitle))
                        .foregroundStyle(Brand.line)
                    Text("Ik help je een wandeling maken.\nHoe oud ben jij?")
                        .font(.text(20, relativeTo: .title3))
                        .foregroundStyle(Brand.chrome)
                        .multilineTextAlignment(.center)
                }
                .popIn(delay: 0.1)

                VStack(spacing: 12) {
                    ForEach(Array(AgeGroup.allCases.enumerated()), id: \.element.rawValue) { index, group in
                        Button {
                            taps += 1
                            onChoose(group)
                        } label: {
                            Text(group.title)
                                .font(.sign(24, relativeTo: .title2))
                                .foregroundStyle(Brand.line)
                                .frame(maxWidth: .infinity, minHeight: 66)
                                .card(cornerRadius: 33)
                                .glow(Capsule(), isOn: index == 1)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(BounceButtonStyle())
                        .popIn(delay: 0.2 + Double(index) * 0.09)
                        .accessibilityIdentifier("age-\(group.rawValue)")
                    }
                }
                .frame(maxWidth: 340)
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .sensoryFeedback(.selection, trigger: taps)
    }
}
