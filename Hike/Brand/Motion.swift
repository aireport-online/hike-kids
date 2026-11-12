import SwiftUI

/// The way things move in Hike Kids: springy, soft and never in a hurry, like a game-console
/// menu. Everything here stands still when the device asks for reduced motion.
///
/// Motion that never ends (floating, glowing, confetti) is drawn from a `TimelineView` clock
/// rather than with repeating animations, so the app still counts as idle between taps.
enum Motion {
    /// The spring used when something is pressed and let go.
    static let press = Animation.spring(response: 0.26, dampingFraction: 0.55)
    /// The spring used when something arrives on screen.
    static let arrive = Animation.spring(response: 0.5, dampingFraction: 0.62)
    /// The spring used when a whole screen opens out of a tile.
    static let open = Animation.spring(response: 0.48, dampingFraction: 0.84)
}

/// Every game button squashes a little under the finger and springs back.
struct BounceButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.93

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Arrives with a springy pop, a moment after the one before it.
private struct PopIn: ViewModifier {
    let delay: Double
    @State private var isShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isShown || reduceMotion ? 1 : 0.55)
            .opacity(isShown ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.arrive.delay(delay)) {
                    isShown = true
                }
            }
    }
}

/// Bobs gently up and down for as long as it is on screen.
private struct Floating: ViewModifier {
    let amplitude: CGFloat
    let period: Double
    let phase: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion || amplitude == 0 {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                content.offset(y: sin((time / period + phase) * 2 * .pi) * amplitude)
            }
        }
    }
}

/// The soft cyan glow around whatever is selected or should be tapped next. It breathes.
private struct Glow<S: InsettableShape>: ViewModifier {
    let shape: S
    let isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if isOn {
                if reduceMotion {
                    ring(strength: 1)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        ring(strength: 0.7 + 0.3 * sin(time * 2 * .pi / 1.8))
                    }
                }
            }
        }
    }

    private func ring(strength: Double) -> some View {
        shape
            .strokeBorder(Brand.glow, lineWidth: 3.5)
            .shadow(color: Brand.glow.opacity(0.9 * strength), radius: 8 * strength)
            .opacity(0.6 + 0.4 * strength)
            .allowsHitTesting(false)
    }
}

extension View {
    /// Pops in with a spring; give neighbours increasing delays to make them arrive in a row.
    func popIn(delay: Double = 0) -> some View {
        modifier(PopIn(delay: delay))
    }

    /// Floats gently up and down. Give neighbours different phases so they do not move as one.
    func floating(amplitude: CGFloat = 4, period: Double = 2.6, phase: Double = 0) -> some View {
        modifier(Floating(amplitude: amplitude, period: period, phase: phase))
    }

    /// Draws the breathing cyan glow around the view when `isOn`.
    func glow<S: InsettableShape>(_ shape: S, isOn: Bool = true) -> some View {
        modifier(Glow(shape: shape, isOn: isOn))
    }
}

/// A burst of paper confetti that falls once, for a few seconds.
struct Confetti: View {
    /// When the burst began; pieces are placed by how long ago that was.
    let start: Date
    var duration: Double = 3.2
    var count = 70

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Set once the last piece has fallen, so the canvas stops redrawing.
    @State private var isDone = false

    private static let colours: [Color] = [Brand.yellow, Brand.glow, Brand.grass, Brand.blaze, .white]

    var body: some View {
        if reduceMotion || isDone {
            EmptyView()
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    guard elapsed >= 0, elapsed < duration else { return }
                    for index in 0..<count {
                        draw(piece: index, elapsed: elapsed, in: size, context: &context)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                try? await Task.sleep(nanoseconds: UInt64((duration + 0.5) * 1_000_000_000))
                isDone = true
            }
        }
    }

    /// Each piece gets its own lane, speed, sway and spin from its index, so the burst looks
    /// random but is the same every time.
    private func draw(piece index: Int, elapsed: Double, in size: CGSize, context: inout GraphicsContext) {
        let seed = Double(index)
        func unit(_ salt: Double) -> Double {
            let value = sin(seed * 12.9898 + salt * 78.233) * 43758.5453
            return value - value.rounded(.down)
        }

        let delay = unit(1) * 0.5
        let time = elapsed - delay
        guard time > 0 else { return }

        let fall = 0.35 + unit(2) * 0.45
        let x = unit(3) * size.width + sin(time * (2 + unit(4) * 3) + seed) * 18
        let y = -20 + time * fall * size.height * (0.7 + time * 0.25)
        guard y < size.height + 20 else { return }

        let width = 7 + unit(5) * 6
        let height = 4 + unit(6) * 5
        let fade = min(1, max(0, (duration - elapsed) / 0.6))

        var piece = context
        piece.opacity = fade
        piece.translateBy(x: x, y: y)
        piece.rotate(by: .radians(time * (3 + unit(7) * 6) + seed))
        // Flipping the piece over makes it flutter.
        piece.scaleBy(x: 1, y: cos(time * (5 + unit(8) * 5)))
        piece.fill(
            Path(roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), cornerRadius: 1.5),
            with: .color(Self.colours[index % Self.colours.count])
        )
    }
}

/// A row of up to three stars; the earned ones pop in one after another.
struct Stars: View {
    let earned: Int
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: size * 0.12) {
            ForEach(0..<3, id: \.self) { index in
                let isEarned = index < earned
                Image(systemName: isEarned ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(isEarned ? Brand.yellow : Brand.chrome.opacity(0.35))
                    .overlay {
                        if isEarned {
                            Image(systemName: "star")
                                .font(.system(size: size, weight: .bold))
                                .foregroundStyle(Brand.ink.opacity(0.75))
                        }
                    }
                    .scaleEffect(isEarned ? 1 : 0.85)
                    .animation(Motion.arrive.delay(Double(index) * 0.12), value: earned)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(earned == 1 ? "1 ster" : "\(earned) sterren")
    }
}

/// A progress bar towards the next level that fills with a spring.
struct LevelBar: View {
    let progress: Double
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Brand.chrome.opacity(0.15))
                Capsule()
                    .fill(Brand.yellow)
                    .frame(width: max(height, proxy.size.width * min(1, max(0, progress))))
                    .animation(Motion.arrive, value: progress)
            }
            .overlay {
                Capsule().strokeBorder(Brand.chrome.opacity(0.45), lineWidth: 1.5)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Voortgang")
        .accessibilityValue("\(Int((progress * 100).rounded())) procent")
    }
}
