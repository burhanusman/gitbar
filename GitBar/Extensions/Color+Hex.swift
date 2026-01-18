import SwiftUI

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

struct Theme {
    // MARK: - App Colors
    
    // Deep, rich midnight backgrounds
    static let background = Color(hex: "#090A0C") // Almost black, deep blue tint
    static let sidebarBackground = Color(hex: "#0F1115") // Slightly lighter
    
    // Surfaces
    static let surface = Color(hex: "#1A1D24")
    static let surfaceHover = Color(hex: "#242832")
    static let surfaceActive = Color(hex: "#2C303B")
    
    // Accents
    static let accent = Color(hex: "#3B82F6") // Electric Blue
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // AI / Special
    static let ai = Color(hex: "#8B5CF6") // Violet
    static let aiGradient = LinearGradient(
        colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Semantic
    static let success = Color(hex: "#10B981") // Emerald
    static let warning = Color(hex: "#F59E0B") // Amber
    static let error = Color(hex: "#EF4444") // Red
    
    // Text
    static let textPrimary = Color(hex: "#F8FAFC") // Slate 50
    static let textSecondary = Color(hex: "#94A3B8") // Slate 400
    static let textTertiary = Color(hex: "#64748B") // Slate 500
    
    // Borders & Separators
    static let border = Color(hex: "#2C3038")
    
    // MARK: - Layout Constants
    
    static let radius: CGFloat = 10
    static let cornerRadiusSmall: CGFloat = 6
    static let cornerRadiusMedium: CGFloat = 8
    static let cornerRadiusLarge: CGFloat = 12
    
    static let paddingSmall: CGFloat = 8
    static let padding: CGFloat = 12
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
}
