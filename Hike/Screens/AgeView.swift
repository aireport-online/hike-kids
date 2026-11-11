import HikeCore
import SwiftUI

/// The first thing a child sees: Mo asks how old they are, so walks fit their legs.
struct AgeView: View {
    var onChoose: (AgeGroup) -> Void

    var body: some View {
        ZStack {
            Brand.sky.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Mascot(pose: .wave, size: 190)
                VStack(spacing: 4) {
                    Text("Hoi! Ik ben Mo.")
                        .font(.sign(34, relativeTo: .largeTitle))
                    Text("Ik help je een wandeling maken.\nHoe oud ben jij?")
                        .font(.text(20, relativeTo: .title3))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Brand.ink)

                VStack(spacing: 12) {
                    ForEach(AgeGroup.allCases, id: \.rawValue) { group in
                        Button {
                            onChoose(group)
                        } label: {
                            Text(group.title)
                                .font(.sign(24, relativeTo: .title2))
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .padding(.trailing, 14)
                                .plate(point: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("age-\(group.rawValue)")
                    }
                }
                .frame(maxWidth: 360)
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        // The sky is the same by day and by night.
        .environment(\.colorScheme, .light)
    }
}
