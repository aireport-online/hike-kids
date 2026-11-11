import SwiftUI

/// Asks for the walk's name on a signpost plate laid over the map.
struct SavePrompt: View {
    @Binding var name: String
    var onCancel: () -> Void
    var onSave: () -> Void

    @FocusState private var nameIsFocused: Bool

    private let point: CGFloat = 20

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                Text("Hoe heet je wandeling?")
                    .font(.sign(24, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)

                TextField("Naam", text: $name)
                    .font(.text(19))
                    .focused($nameIsFocused)
                    .submitLabel(.done)
                    .onSubmit(onSave)
                    .padding(.horizontal, 14)
                    .frame(minHeight: Brand.tapTarget)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: Brand.corner))
                    .overlay {
                        RoundedRectangle(cornerRadius: Brand.corner)
                            .strokeBorder(Brand.ink, lineWidth: Brand.outline)
                    }
                    .accessibilityIdentifier("saveNameField")

                HStack(spacing: 10) {
                    Button("Annuleer", action: onCancel)
                        .buttonStyle(OutlineButtonStyle(onYellow: true))
                    Button("Bewaar", action: onSave)
                        .buttonStyle(InkButtonStyle())
                        .accessibilityIdentifier("confirmSaveButton")
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 14 + point)
            .padding(.vertical, 18)
            .frame(maxWidth: 440, alignment: .leading)
            .plate(point: point)
            .padding(.horizontal, 18)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear { nameIsFocused = true }
    }
}
