import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Design System

struct Theme {
    // MARK: - Color Palette

    // Backgrounds - Deep, rich midnight with subtle blue tint
    static let background = Color(hex: "#08090B")
    static let sidebarBackground = Color(hex: "#0D0F12")

    // Surfaces - Layered depths
    static let surface = Color(hex: "#161920")
    static let surfaceHover = Color(hex: "#1E222B")
    static let surfaceActive = Color(hex: "#262B36")
    static let surfaceElevated = Color(hex: "#1A1E27")

    // Accent - Refined blue
    static let accent = Color(hex: "#3B82F6")
    static let accentHover = Color(hex: "#60A5FA")
    static let accentMuted = Color(hex: "#3B82F6").opacity(0.15)

    // Semantic colors
    static let success = Color(hex: "#22C55E")
    static let successMuted = Color(hex: "#22C55E").opacity(0.15)
    static let warning = Color(hex: "#EAB308")
    static let warningMuted = Color(hex: "#EAB308").opacity(0.15)
    static let error = Color(hex: "#EF4444")
    static let errorMuted = Color(hex: "#EF4444").opacity(0.15)

    // Text hierarchy
    static let textPrimary = Color(hex: "#F1F5F9")
    static let textSecondary = Color(hex: "#94A3B8")
    static let textTertiary = Color(hex: "#64748B")
    static let textMuted = Color(hex: "#475569")

    // Borders
    static let border = Color(hex: "#1E2330")
    static let borderSubtle = Color(hex: "#1E2330").opacity(0.6)
    static let borderFocus = Color(hex: "#3B82F6").opacity(0.5)

    // Syntax Highlighting - Softer, muted palette (easier on eyes)
    static let syntaxKeyword = Color(hex: "#C586C0")   // Muted pink - keywords
    static let syntaxString = Color(hex: "#CE9178")    // Soft orange - strings
    static let syntaxComment = Color(hex: "#6A737D")   // Subtle gray - comments
    static let syntaxNumber = Color(hex: "#B5CEA8")    // Soft green - numbers
    static let syntaxType = Color(hex: "#9CDCFE")      // Light blue - types
    static let syntaxFunction = Color(hex: "#DCDCAA")  // Muted yellow - functions
    static let syntaxOperator = Color(hex: "#D4D4D4")  // Light gray - operators
    static let syntaxProperty = Color(hex: "#9CDCFE")  // Light blue - properties

    // MARK: - Spacing Scale (4px base)

    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24
    static let space8: CGFloat = 32

    // Legacy aliases
    static let paddingSmall: CGFloat = space2
    static let padding: CGFloat = space3
    static let paddingMedium: CGFloat = space4
    static let paddingLarge: CGFloat = space6

    // MARK: - Corner Radius

    static let radiusSmall: CGFloat = 6
    static let radius: CGFloat = 8
    static let radiusLarge: CGFloat = 12

    // Legacy aliases
    static let cornerRadiusSmall: CGFloat = radiusSmall
    static let cornerRadiusMedium: CGFloat = radius
    static let cornerRadiusLarge: CGFloat = radiusLarge

    // MARK: - Typography

    static let fontXS: CGFloat = 10
    static let fontSM: CGFloat = 11
    static let fontBase: CGFloat = 13
    static let fontLG: CGFloat = 15
    static let fontXL: CGFloat = 17

    // MARK: - Animation

    static let animationFast: Double = 0.15
    static let animationBase: Double = 0.2
    static let animationSlow: Double = 0.3

    // MARK: - Shadows

    static func shadowSmall(_ color: Color = .black) -> some View {
        Color.clear.shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    static func shadowMedium(_ color: Color = .black) -> some View {
        Color.clear.shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    static func glowEffect(_ color: Color) -> some View {
        Color.clear.shadow(color: color.opacity(0.25), radius: 12, x: 0, y: 4)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a subtle hover scale effect
    func hoverScale(_ isHovered: Bool, scale: CGFloat = 1.02) -> some View {
        self.scaleEffect(isHovered ? scale : 1.0)
            .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
    }

    /// Applies a fade transition
    func fadeTransition(_ isVisible: Bool) -> some View {
        self.opacity(isVisible ? 1.0 : 0.0)
            .animation(.easeOut(duration: Theme.animationBase), value: isVisible)
    }

    /// Changes cursor to pointing hand on hover - use for clickable elements
    func pointingHandCursor() -> some View {
        self.onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
