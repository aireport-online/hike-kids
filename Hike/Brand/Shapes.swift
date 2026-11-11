import SwiftUI

/// A signpost plate: a rectangle whose trailing end is cut to a point, with soft corners.
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

/// A heading with the red rule under it.
struct SignHeading: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.sign(26, relativeTo: .title))
                .foregroundStyle(Brand.line)
            Capsule()
                .fill(Brand.blaze)
                .frame(height: 4)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Mo the marmot, the walking companion, in a round sky-blue frame.
struct Mascot: View {
    enum Pose: String {
        case wave = "MoWave"
        case cheer = "MoCheer"
        case point = "MoPoint"
    }

    var pose: Pose = .wave
    var size: CGFloat = 84

    var body: some View {
        Image(pose.rawValue)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(Brand.ink, lineWidth: Brand.outline)
            }
            .accessibilityHidden(true)
    }
}

/// A yellow signpost plate behind any content.
struct PlateBackground: ViewModifier {
    var point: CGFloat = 18
    var shadow = false

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Brand.ink)
            .background {
                SignpostShape(point: point)
                    .fill(Brand.yellow)
                    .shadow(color: .black.opacity(shadow ? 0.25 : 0), radius: 5, y: 2)
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
    func plate(point: CGFloat = 18, shadow: Bool = false) -> some View {
        modifier(PlateBackground(point: point, shadow: shadow))
    }
}
