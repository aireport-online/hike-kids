import SwiftUI

/// The main action: charcoal with yellow lettering, big enough for small fingers.
struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sign(20, relativeTo: .headline))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(Brand.yellow.opacity(isEnabled ? 1 : 0.55))
            .padding(.horizontal, 18)
            .frame(minHeight: Brand.tapTarget)
            .background(
                Brand.ink.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4),
                in: RoundedRectangle(cornerRadius: Brand.corner)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Rectangle())
    }
}

/// A secondary action: a white or outlined button. `onYellow` keeps the lettering ink-coloured
/// when the button sits on a yellow plate, where it must not turn light in dark mode.
struct OutlineButtonStyle: ButtonStyle {
    var onYellow = false
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let colour = onYellow ? Brand.ink : Brand.line
        let fill = onYellow ? Color.white : Brand.paper
        configuration.label
            .font(.sign(compact ? 16 : 19, relativeTo: .subheadline))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(colour.opacity(isEnabled ? 1 : 0.35))
            .padding(.horizontal, compact ? 12 : 16)
            .frame(minWidth: compact ? 44 : Brand.tapTarget, minHeight: compact ? 44 : Brand.tapTarget)
            .background(
                fill.opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.5)),
                in: RoundedRectangle(cornerRadius: Brand.corner)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Brand.corner)
                    .strokeBorder(colour.opacity(isEnabled ? 1 : 0.35), lineWidth: Brand.outline)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Rectangle())
    }
}

/// A row of options of which one is switched on.
struct SignSwitch<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        var id: Value { value }
    }

    let options: [Option]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isOn = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.sign(17, relativeTo: .subheadline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isOn ? Brand.paper : Brand.line)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(isOn ? Brand.line : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Brand.corner))
        .overlay {
            RoundedRectangle(cornerRadius: Brand.corner)
                .strokeBorder(Brand.line, lineWidth: Brand.outline)
        }
        .accessibilityElement(children: .contain)
    }
}

extension View {
    /// A sheet's title in the app's own letter, in place of the system title.
    func signTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.sign(22, relativeTo: .headline))
                        .foregroundStyle(Brand.line)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}
