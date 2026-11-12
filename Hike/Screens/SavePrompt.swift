import SwiftUI

/// Asks for the walk's name on a card that pops up over the map.
struct SavePrompt: View {
    @Binding var name: String
    var onCancel: () -> Void
    var onSave: () -> Void

    @FocusState private var nameIsFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Mascot(pose: .point, size: 60, floats: false)
                    Text("Hoe heet je wandeling?")
                        .font(.sign(23, relativeTo: .title2))
                        .foregroundStyle(Brand.line)
                        .accessibilityAddTraits(.isHeader)
                }

                TextField("Naam", text: $name)
                    .font(.text(19))
                    .foregroundStyle(Brand.line)
                    .focused($nameIsFocused)
                    .submitLabel(.done)
                    .onSubmit(onSave)
                    .padding(.horizontal, 18)
                    .frame(minHeight: Brand.tapTarget)
                    .background(Brand.haze, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Brand.glow, lineWidth: 2.5)
                    }
                    .accessibilityIdentifier("saveNameField")

                HStack(spacing: 10) {
                    Button("Annuleer", action: onCancel)
                        .buttonStyle(OutlineButtonStyle())
                    Button("Bewaar", action: onSave)
                        .buttonStyle(InkButtonStyle())
                        .accessibilityIdentifier("confirmSaveButton")
                }
            }
            .padding(20)
            .frame(maxWidth: 440, alignment: .leading)
            .card(cornerRadius: 28)
            .padding(.horizontal, 18)
            .popIn()
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear { nameIsFocused = true }
    }
}
