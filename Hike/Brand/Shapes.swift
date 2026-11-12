import SwiftUI

/// A signpost plate: a rectangle whose trailing end is cut to a point, with soft corners.
/// Saved walks hang on the signpost as plates.
struct SignpostShape: Shape {
    /// How far the point reaches beyond the body of the plate.
    var point: CGFloat = 18
    var cornerRadius: CGFloat = Brand.corner

    func path(in rect: CGRect) -> Path {
        let tip = min(point, rect.width / 3)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX - tip, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.maxX - tip, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]
        let radius = min(cornerRadius, rect.height / 2, rect.width / 4)

        // Start halfway down the blunt end, then round every corner on the way around.
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for index in corners.indices {
            let next = corners[(index + 1) % corners.count]
            path.addArc(tangent1End: corners[index], tangent2End: next, radius: radius)
        }
        path.closeSubpath()
        return path
    }
}

/// The white-red-white blaze that marks mountain trails, as painted on rocks and signposts.
struct BlazeMark: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.white
            Brand.blaze
            Color.white
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3).strokeBorder(Brand.ink.opacity(0.4), lineWidth: 0.75)
        }
        .accessibilityHidden(true)
    }
}

/// A section heading with a soft cyan rule under it.
struct SignHeading: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.sign(24, relativeTo: .title))
                .foregroundStyle(Brand.line)
            Capsule()
                .fill(Brand.glow.opacity(0.7))
                .frame(height: 4)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Mo the marmot, the walking companion. He stands freely on the page and is never quite still.
struct Mascot: View {
    enum Pose: String {
        case wave = "MoWave"
        case cheer = "MoCheer"
        case point = "MoPoint"
    }

    var pose: Pose = .wave
    var size: CGFloat = 84
    /// Whether Mo bobs gently; switch off where he sits inside something that already moves.
    var floats = true

    var body: some View {
        Image(pose.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .floating(amplitude: floats ? max(2, size * 0.025) : 0, period: 2.8)
            .accessibilityHidden(true)
    }
}

/// The faint horizontal pinstripes behind the menu, as on a console's home screen.
struct Pinstripes: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(Brand.chrome.opacity(0.07))
                )
                y += 5
            }
        }
        .background(Brand.haze)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A white, softly shadowed card with a thin border: the surface everything sits on.
private struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Brand.surface)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Brand.edge, lineWidth: 1.5)
            }
    }
}

/// A yellow signpost plate behind any content.
private struct PlateBackground: ViewModifier {
    var point: CGFloat

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Brand.ink)
            .background {
                SignpostShape(point: point)
                    .fill(Brand.yellow)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            }
            .overlay {
                SignpostShape(point: point)
                    .stroke(Brand.ink, lineWidth: Brand.outline)
            }
            // A plate is yellow by day and by night, so everything on it stays dark-on-light.
            .environment(\.colorScheme, .light)
            .tint(Brand.ink)
    }
}

extension View {
    func card(cornerRadius: CGFloat = Brand.tileCorner) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }

    func plate(point: CGFloat = 18) -> some View {
        modifier(PlateBackground(point: point))
    }
}
