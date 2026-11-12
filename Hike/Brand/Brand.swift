import CoreText
import SwiftUI
import UIKit

/// The identity of Hike Kids, "Kanalen": the calm white home menu of a game console. Bright,
/// softly glossy surfaces, big rounded channel tiles, a cyan glow around whatever is chosen,
/// pill-shaped buttons and friendly grey lettering. Signal yellow is kept for the things that
/// matter most on a walk: the route, the stars and the saved walks on their signpost.
enum Brand {
    // MARK: Colours

    /// Signpost yellow. Always carries ink-coloured content, in light and dark mode alike.
    static let yellow = Color(uiColor: UI.yellow)
    /// Charcoal: lettering on yellow, the route outline, the main button.
    static let ink = Color(uiColor: UI.ink)
    /// The red of a trail blaze. An accent only: warnings and the blaze mark.
    static let blaze = Color(uiColor: UI.blaze)
    /// Sky blue: behind the mascot, and for calm highlights.
    static let sky = Color(uiColor: UI.sky)
    /// Grass green: "this is a good walk for you".
    static let grass = Color(uiColor: UI.grass)
    /// The glow around the selected tile and the button to press next.
    static let glow = Color(uiColor: UI.glow)
    /// Lettering, icons and thin lines of the menu chrome: a friendly mid grey.
    static let chrome = Color(uiColor: UI.chrome)
    /// Cards, tiles and buttons.
    static let surface = Color(uiColor: UI.surface)
    /// The page behind the tiles.
    static let haze = Color(uiColor: UI.haze)
    /// The thin border of a tile or card.
    static let edge = Color(uiColor: UI.edge)
    /// Background of sheets and white controls.
    static let paper = Color(uiColor: UI.paper)
    /// Page background behind plates and cards.
    static let ground = Color(uiColor: UI.ground)
    /// Headings and figures on white: a dark slate by day, near-white by night.
    static let line = Color(uiColor: UI.line)

    enum UI {
        static let yellow = UIColor(red: 1.0, green: 0.831, blue: 0.0, alpha: 1)
        static let ink = UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1)
        static let blaze = UIColor(red: 0.890, green: 0.149, blue: 0.180, alpha: 1)
        static let sky = UIColor(red: 0.710, green: 0.890, blue: 0.988, alpha: 1)
        static let grass = UIColor(red: 0.357, green: 0.749, blue: 0.416, alpha: 1)
        static let glow = UIColor(red: 0.208, green: 0.761, blue: 0.941, alpha: 1)
        static let chrome = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.80, green: 0.83, blue: 0.87, alpha: 1)
                : UIColor(red: 0.369, green: 0.404, blue: 0.447, alpha: 1)
        }
        static let surface = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.16, alpha: 1) : .white
        }
        static let haze = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.08, alpha: 1)
                : UIColor(red: 0.953, green: 0.961, blue: 0.973, alpha: 1)
        }
        static let edge = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.30, alpha: 1)
                : UIColor(red: 0.835, green: 0.859, blue: 0.886, alpha: 1)
        }
        static let paper = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.13, alpha: 1) : .white
        }
        static let ground = haze
        static let line = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.95, alpha: 1)
                : UIColor(red: 0.255, green: 0.286, blue: 0.325, alpha: 1)
        }
    }

    // MARK: Measures

    /// Outlines of the yellow signpost plates are thick, like a felt-tip drawing.
    static let outline: CGFloat = 2.5
    /// Corners of small controls.
    static let corner: CGFloat = 14
    /// Corners of tiles and cards.
    static let tileCorner: CGFloat = 22
    /// Nothing a child must tap is smaller than this.
    static let tapTarget: CGFloat = 52

    // MARK: Fonts

    enum FontName {
        static let sign = "Fredoka-SemiBold"
        static let text = "Fredoka-Medium"

        static let all = [sign, text]
    }

    /// Makes the bundled fonts available. Call once, before the first view is built.
    static func registerFonts() {
        for name in FontName.all {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Missing font file \(name).ttf")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Headings, figures and buttons.
    static func sign(_ size: CGFloat, relativeTo style: Font.TextStyle = .title3) -> Font {
        .custom(Brand.FontName.sign, size: size, relativeTo: style)
    }

    /// Running text and small labels.
    static func text(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(Brand.FontName.text, size: size, relativeTo: style)
    }
}
