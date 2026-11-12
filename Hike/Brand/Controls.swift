import SwiftUI

/// The button to press next: a white pill with the breathing cyan glow.
struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sign(20, relativeTo: .headline))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(Brand.line.opacity(isEnabled ? 1 : 0.4))
            .padding(.horizontal, 22)
            .frame(minHeight: Brand.tapTarget)
            .background(Brand.surface, in: Capsule())
            .overlay {
                Capsule().strokeBorder(isEnabled ? Brand.glow : Brand.edge, lineWidth: isEnabled ? 3 : 1.5)
            }
            .glow(Capsule(), isOn: isEnabled)
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// An ordinary action: a white pill with a thin grey border. `compact` makes a smaller one.
/// (`onYellow` is kept for call sites on a yellow plate, where the lettering must stay dark.)
struct OutlineButtonStyle: ButtonStyle {
    var onYellow = false
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let colour = onYellow ? Brand.ink : Brand.line
        configuration.label
            .font(.sign(compact ? 16 : 19, relativeTo: .subheadline))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(colour.opacity(isEnabled ? 1 : 0.35))
            .padding(.horizontal, compact ? 14 : 18)
            .frame(minWidth: compact ? 44 : Brand.tapTarget, minHeight: compact ? 44 : Brand.tapTarget)
            .background(onYellow ? Color.white : Brand.surface, in: Capsule())
            .overlay {
                Capsule().strokeBorder(onYellow ? Brand.ink.opacity(0.8) : Brand.edge, lineWidth: onYellow ? 2 : 1.5)
            }
            .shadow(color: .black.opacity(onYellow ? 0 : 0.08), radius: 4, y: 2)
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// A round button with a cyan ring, as in the bar at the bottom of the menu.
struct RoundButtonLabel: View {
    let systemImage: String
    var size: CGFloat = Brand.tapTarget

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(Brand.chrome)
            .frame(width: size, height: size)
            .background(Brand.surface, in: Circle())
            .overlay {
                Circle().strokeBorder(Brand.glow.opacity(0.85), lineWidth: 2.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
            .contentShape(Circle())
    }
}

/// A row of options of which one is switched on: a white pill whose chosen part glows cyan.
struct SignSwitch<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        var id: Value { value }
    }

    let options: [Option]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isOn = option.value == selection
                Button {
                    withAnimation(Motion.press) {
                        selection = option.value
                    }
                } label: {
                    Text(option.title)
                        .font(.sign(17, relativeTo: .subheadline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isOn ? Color.white : Brand.line)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isOn ? Brand.glow : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Brand.surface, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Brand.edge, lineWidth: 1.5)
        }
        .accessibilityElement(children: .contain)
    }
}

/// The bar at the top of a channel: the round button back to the menu, and the channel's name.
struct ChannelHeader: View {
    let title: String
    var onMenu: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onMenu) {
                RoundButtonLabel(systemImage: "house.fill")
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel("Terug naar het menu")
            .accessibilityIdentifier("menuButton")

            Text(title)
                .font(.sign(26, relativeTo: .title))
                .foregroundStyle(Brand.line)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
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
